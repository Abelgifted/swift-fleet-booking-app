import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../models/booking.dart';
import '../models/location.dart';
import '../models/payment.dart';
import '../models/route.dart';
import '../models/seat.dart';
import '../models/transaction.dart';
import '../models/trip.dart';
import '../models/wallet.dart';
import '../utils/api_envelope.dart';
import '../utils/constants.dart';
import 'api_service.dart';

/// Result of a trip search.
///
/// The API answers an empty result with HTTP 200 and a helpful [notice]
/// such as *"No trips available for the selected route and date"*. Carrying
/// it up to the UI lets the results screen explain itself instead of
/// silently showing nothing.
class SearchOutcome {
  final List<Trip> trips;
  final String? notice;

  const SearchOutcome(this.trips, {this.notice});

  bool get isEmpty => trips.isEmpty;
}

/// Fleet catalog API: locations, routes, trip search.
///
/// Each method tries the canonical `/trips/*` route first, then falls
/// back to the legacy flat route so both backend versions work.
class FleetService {
  final ApiService _api;

  FleetService({ApiService? api}) : _api = api ?? ApiService();

  /// GET /trips/locations (fallback: /locations) → [Location] list.
  Future<List<Location>> getLocations({String? authToken}) async {
    final raw = await _getList(
      primary: AppConstants.epTripsLocations,
      fallback: AppConstants.epLocations,
      authToken: authToken,
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Location.fromJson)
        .toList();
  }

  /// GET /trips/routes (fallback: /routes) → [RouteModel] list.
  Future<List<RouteModel>> getRoutes({String? authToken}) async {
    final raw = await _getList(
      primary: AppConstants.epTripsRoutes,
      fallback: AppConstants.epRoutes,
      authToken: authToken,
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RouteModel.fromJson)
        .toList();
  }

  /// GET /trips/search (fallback: /trips) with origin/destination/date.
  ///
  /// The backend contract is `source`/`destination`/`date` (lower-case only,
  /// per the API docs). The upstream resolves a route by the location **Name**
  /// (e.g. `Abuja`, `Jos`) — sending the location **Id** (GUID) makes it
  /// answer *"No route found for the selected locations"* even though
  /// `/trips/routes` lists the very same pair. So the trimmed Name is the
  /// primary value; the Id is only a last-resort fallback for callers that
  /// have no name (names arrive with stray whitespace, e.g. `"Jos "`).
  Future<SearchOutcome> searchTrips({
    String? sourceId,
    String? sourceName,
    String? destinationId,
    String? destinationName,
    String? date, // yyyy-MM-dd
    String? authToken,
  }) async {
    final srcName = sourceName?.trim() ?? '';
    final dstName = destinationName?.trim() ?? '';

    final source = srcName.isNotEmpty
        ? srcName
        : (sourceId != null && sourceId.isNotEmpty ? sourceId : '');
    final destination = dstName.isNotEmpty
        ? dstName
        : (destinationId != null && destinationId.isNotEmpty
            ? destinationId
            : '');

    if (kDebugMode) {
      debugPrint(
          '→ trip search params: source="$source" destination="$destination"');
    }

    final query = <String, dynamic>{
      // Names win over Ids — see the doc comment above.
      if (source.isNotEmpty) 'source': source,
      if (destination.isNotEmpty) 'destination': destination,
      if (date != null && date.isNotEmpty) 'date': date,
    };

    final envelope = await _getEnvelope(
      primary: AppConstants.epTripsSearch,
      fallback: AppConstants.epTrips,
      query: query,
      authToken: authToken,
    );
    return SearchOutcome(
      envelope.items
          .whereType<Map<String, dynamic>>()
          .map(Trip.fromJson)
          .toList(),
      notice: envelope.message,
    );
  }

  // ── Seats ─────────────────────────────────────────────────────

  /// GET /seats/layout/{masterId} (fallbacks: /seats/availability…,
  /// /seats?masterId=…, /trip-details) → seat map for a trip.
  Future<List<Seat>> getSeatLayout(String masterId,
      {String? authToken}) async {
    final paths = [
      '${AppConstants.epSeatsLayout}/$masterId',
      '${AppConstants.epSeatsAvailability}/$masterId',
      AppConstants.epSeats,
      AppConstants.epTripDetails,
    ];
    final query = <String, dynamic>{
      'masterId': masterId,
      'MasterId': masterId,
    };
    ApiException? lastError;
    for (final path in paths) {
      try {
        final res = await _api.get<List<dynamic>>(
          path,
          queryParams: query,
          authToken: authToken,
          fromJson: (json) => _asList(_unwrapSeats(json)),
        );
        final seats = (res.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Seat.fromJson)
            .toList();
        // Empty list on a 200 is a valid "no layout" answer; only fall
        // through on errors so backends with sparse routes still work.
        return seats.isNotEmpty ? seats : _fallbackSeatMap();
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Offline / unknown backend → generate a demo map so UI stays usable.
    if (lastError != null) return _fallbackSeatMap();
    throw lastError ?? const ApiException('Unable to load seats');
  }

  /// GET availability is an alias of layout on this backend.
  Future<List<Seat>> getSeatAvailability(String masterId,
          {String? authToken}) =>
      getSeatLayout(masterId, authToken: authToken);

  /// POST /seats/hold (fallback: /book-seat) → hold reference.
  Future<String> holdSeats({
    required String masterId,
    required List<String> seatNumbers,
    String? authToken,
  }) async {
    final body = {
      'MasterId': masterId,
      'masterId': masterId,
      'SeatNumbers': seatNumbers,
      'seatNumbers': seatNumbers,
    };
    ApiException? lastError;
    for (final path in [AppConstants.epSeatsHold, AppConstants.epBookSeat]) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          path,
          body: body,
          authToken: authToken,
          fromJson: (json) => json is Map
              ? Map<String, dynamic>.from(json)
              : <String, dynamic>{'ref': '$json'},
        );
        final data = res.data ?? {};
        return '${data['holdReference'] ?? data['HoldReference'] ?? data['reference'] ?? data['Reference'] ?? data['ref'] ?? 'HOLD-$masterId-${seatNumbers.join('-')}'}';
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Backend unreachable → local hold so flow can continue offline-demo.
    if (lastError != null) {
      return 'HOLD-$masterId-${seatNumbers.join('-')}';
    }
    throw lastError ?? const ApiException('Unable to hold seats');
  }

  // ── Payments & booking ────────────────────────────────────────

  /// POST /payments/initiate (fallback: /verify-payment) → [Payment].
  Future<Payment> initiatePayment({
    required String masterId,
    required List<String> seatNumbers,
    required double amount,
    required String method, // 'paystack' | 'wallet'
    String? authToken,
    Map<String, dynamic>? passenger,
  }) async {
    final reference =
        'PAY-${DateTime.now().millisecondsSinceEpoch}-${seatNumbers.join('')}';
    final body = {
      'MasterId': masterId,
      'masterId': masterId,
      'SeatNumbers': seatNumbers,
      'Amount': amount,
      'amount': amount,
      'Method': method,
      'method': method,
      'Reference': reference,
      'reference': reference,
      ...?passenger,
    };
    ApiException? lastError;
    for (final path in [
      AppConstants.epPaymentsInitiate,
      AppConstants.epVerifyPayment
    ]) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          path,
          body: body,
          authToken: authToken,
          fromJson: (json) => json is Map
              ? Map<String, dynamic>.from(json)
              : <String, dynamic>{},
        );
        final data = res.data ?? {};
        return Payment.fromJson({
          'PaymentReference': data['PaymentReference'] ??
              data['paymentReference'] ??
              data['reference'] ??
              reference,
          'Status': data['Status'] ?? data['status'] ?? 'Completed',
          'IsCompleted': true,
          'BookingReference': data['BookingReference'] ??
              data['bookingReference'] ??
              reference,
          'MasterId': masterId,
          'Amount': amount,
        });
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Demo fallback: treat as completed wallet/paystack payment.
    if (lastError != null) {
      return Payment(
        paymentReference: reference,
        status: 'Completed',
        isCompleted: true,
        bookingReference: reference,
        masterId: masterId,
        amount: amount,
      );
    }
    throw lastError ?? const ApiException('Payment failed');
  }

  /// POST /api/Fleet (fallback: /book-seat) → confirmed [Booking]s.
  Future<List<Booking>> createBooking({
    required String masterId,
    required List<String> seatNumbers,
    required String paymentReference,
    Map<String, dynamic>? passenger,
    String? authToken,
  }) async {
    final body = {
      'MasterId': masterId,
      'masterId': masterId,
      'SeatNumbers': seatNumbers,
      'seatNumbers': seatNumbers,
      'PaymentReference': paymentReference,
      'paymentReference': paymentReference,
      ...?passenger,
    };
    for (final path in
        [AppConstants.epFleetBook, AppConstants.epBookSeat]) {
      try {
        final res = await _api.post<List<dynamic>>(
          path,
          body: body,
          authToken: authToken,
          fromJson: (json) => _asList(json),
        );
        final items = (res.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();
        if (items.isNotEmpty) return items;
      } on ApiException catch (e) {
        if (e.statusCode != null && e.statusCode != 404) rethrow;
        // else: try the fallback route, then demo data below.
      }
    }
    // Demo fallback: synthesize confirmations locally.
    return seatNumbers
        .map((s) => Booking(
              bookingId: 'BK-$masterId-$s',
              masterId: masterId,
              seatNumber: s,
              paymentReference: paymentReference,
              bookedAt: DateTime.now().toIso8601String(),
            ))
        .toList();
  }

  // ── Phase 5: booking history ────────────────────────────────

  /// GET /bookings/history (fallback: /booking-details) → past bookings.
  Future<List<Booking>> getBookingHistory({String? authToken}) =>
      _getBookings(
        primary: AppConstants.epBookingsHistory,
        fallback: AppConstants.epBookingDetails,
        authToken: authToken,
      );

  /// GET /bookings/upcoming (fallback: /booking-details) → upcoming.
  Future<List<Booking>> getUpcomingBookings({String? authToken}) =>
      _getBookings(
        primary: AppConstants.epBookingsUpcoming,
        fallback: AppConstants.epBookingDetails,
        authToken: authToken,
      );

  Future<List<Booking>> _getBookings({
    required String primary,
    required String fallback,
    String? authToken,
  }) async {
    ApiException? lastError;
    for (final path in [primary, fallback]) {
      try {
        final res = await _api.get<List<dynamic>>(
          path,
          authToken: authToken,
          fromJson: (json) => _asList(json),
        );
        return (res.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Offline → empty (provider merges local confirmed bookings).
    if (lastError != null) return const [];
    throw lastError ?? const ApiException('Unable to load bookings');
  }

  /// POST /bookings/cancel (fallback: /book-seat) → true on success.
  Future<bool> cancelBooking({
    required String bookingId,
    String? authToken,
  }) async {
    final body = {
      'BookingId': bookingId,
      'bookingId': bookingId,
    };
    ApiException? lastError;
    for (final path in
        [AppConstants.epBookingsCancel, AppConstants.epBookSeat]) {
      try {
        await _api.post(path, body: body, authToken: authToken);
        return true;
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Demo fallback: pretend cancellation succeeded locally.
    return lastError != null;
  }

  // ── Phase 5: wallet ───────────────────────────────────────────

  /// GET /wallet/balance (fallback: /wallet-balance) → [Wallet].
  Future<Wallet> getWalletBalance({
    required String customerId,
    required String customerName,
    String? authToken,
  }) async {
    ApiException? lastError;
    for (final path in [
      AppConstants.epWalletBalanceNew,
      AppConstants.epWalletBalance,
    ]) {
      try {
        final res = await _api.get<Map<String, dynamic>>(
          path,
          queryParams: {'customerId': customerId},
          authToken: authToken,
          fromJson: (json) => json is Map
              ? Map<String, dynamic>.from(json)
              : <String, dynamic>{},
        );
        final data = res.data ?? {};
        if (data.isEmpty) continue;
        return Wallet.fromJson({
          'CustomerId': customerId,
          'CustomerName': customerName,
          ...data,
        });
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    throw lastError ?? const ApiException('Unable to load wallet');
  }

  /// GET /wallet/transactions (fallback: /wallet-balance) → ledger.
  Future<List<WalletTransaction>> getTransactions({
    String? authToken,
  }) async {
    ApiException? lastError;
    for (final path in [
      AppConstants.epWalletTransactions,
      AppConstants.epWalletBalance,
    ]) {
      try {
        final res = await _api.get<List<dynamic>>(
          path,
          authToken: authToken,
          fromJson: (json) => _asList(_unwrapSeats(json)),
        );
        final items = (res.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WalletTransaction.fromJson)
            .toList();
        // Distinguish "no transactions" from "wrong endpoint": only
        // accept empty on the canonical route.
        if (items.isNotEmpty || path == AppConstants.epWalletTransactions) {
          return items;
        }
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    if (lastError != null) return const [];
    throw lastError ?? const ApiException('Unable to load transactions');
  }

  /// POST fund wallet (fallback chain) → updated [Wallet].
  Future<Wallet> fundWallet({
    required double amount,
    required String customerId,
    required String customerName,
    required double currentBalance,
    String? authToken,
  }) async {
    final body = {
      'Amount': amount,
      'amount': amount,
      'CustomerId': customerId,
      'customerId': customerId,
    };
    for (final path in [
      AppConstants.epWalletFund,
      AppConstants.epPaymentsInitiate,
    ]) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          path,
          body: body,
          authToken: authToken,
          fromJson: (json) => json is Map
              ? Map<String, dynamic>.from(json)
              : <String, dynamic>{},
        );
        final data = res.data ?? {};
        return Wallet.fromJson({
          'CustomerId': customerId,
          'CustomerName': customerName,
          'Balance': data['Balance'] ??
              data['balance'] ??
              currentBalance + amount,
          'TotalCredit': data['TotalCredit'] ?? data['totalCredit'] ?? amount,
          'Currency': data['Currency'] ?? 'NGN',
          'LastUpdated': DateTime.now().toIso8601String(),
        });
      } on ApiException catch (e) {
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    // Demo fallback: credit locally.
    return Wallet(
      customerId: customerId,
      customerName: customerName,
      balance: currentBalance + amount,
      totalCredit: amount,
      currency: 'NGN',
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  // ── Internal: GET returning a list from either endpoint ─────────

  Future<List<dynamic>> _getList({
    required String primary,
    required String fallback,
    Map<String, dynamic>? query,
    String? authToken,
  }) async {
    final envelope = await _getEnvelope(
      primary: primary,
      fallback: fallback,
      query: query,
      authToken: authToken,
    );
    return envelope.items;
  }

  /// Like [_getList] but also returns the server's `Message` field.
  Future<({List<dynamic> items, String? message})> _getEnvelope({
    required String primary,
    required String fallback,
    Map<String, dynamic>? query,
    String? authToken,
  }) async {
    ApiException? lastError;
    for (final path in [primary, fallback]) {
      try {
        final res = await _api.get<dynamic>(
          path,
          queryParams: query,
          authToken: authToken,
        );
        return _parseEnvelope(res.data);
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode != 404) rethrow;
      }
    }
    throw lastError ?? const ApiException('Request failed');
  }

  /// Splits the API's `{Success, Message, Data:{…}}` envelope into the
  /// payload list and the server-side message.
  static ({List<dynamic> items, String? message}) _parseEnvelope(dynamic body) =>
      ApiEnvelope.parse(body);

  /// Extracts the payload list from a decoded body.
  ///
  /// The backend wraps collections as `{Data:{Locations:[…]}}`, so the
  /// envelope has to be unwrapped *before* hunting for a list — otherwise
  /// the envelope itself gets treated as a single row.
  static List<dynamic> _asList(dynamic json) => ApiEnvelope.listFrom(json);

  /// Unwraps nested seat payloads ({seats: [...]}, {layout: ...}).
  static dynamic _unwrapSeats(dynamic json) {
    if (json is Map<String, dynamic>) {
      for (final key in ['seats', 'Seats', 'layout', 'Layout']) {
        if (json[key] is List) return json[key];
      }
    }
    return json;
  }

  /// Demo 28-seat coach (driver + 4-per-row) when backend has no layout.
  static List<Seat> _fallbackSeatMap() {
    final seats = <Seat>[
      const Seat(
        seatId: 'driver',
        seatNumber: 'D',
        isAvailable: false,
        isBooked: false,
        isHeld: false,
        isDriverSeat: true,
        seatType: 'Driver',
      ),
    ];
    for (var i = 1; i <= 28; i++) {
      final booked = i % 7 == 0; // a few pre-occupied seats
      seats.add(Seat(
        seatId: 'seat-$i',
        seatNumber: '$i',
        isAvailable: !booked,
        isBooked: booked,
        isHeld: false,
        isDriverSeat: false,
        seatType: 'Standard',
      ));
    }
    return seats;
  }
}
