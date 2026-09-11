import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../models/location.dart';
import '../models/payment.dart';
import '../models/route.dart';
import '../models/seat.dart';
import '../models/transaction.dart';
import '../models/trip.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/fleet_service.dart';
import '../utils/constants.dart';

/// Sort options for the trip results list.
enum TripSort { earliest, cheapest, mostSeats }

/// Trip catalog + search + selection state (Phase 3).
///
/// Holds locations/routes cache, last search results, active filters,
/// selected trip, and a lightweight recent-bookings list used by the
/// dashboard until the bookings endpoint lands in Phase 4.
class BookingProvider extends ChangeNotifier {
  final FleetService _fleet;

  BookingProvider({FleetService? fleet})
      : _fleet = fleet ?? FleetService();

  // ── Catalog ───────────────────────────────────────────────────
  List<Location> _locations = [];
  List<RouteModel> _routes = [];
  bool _catalogLoading = false;

  // ── Search state ──────────────────────────────────────────────
  Location? _origin;
  Location? _destination;
  DateTime _travelDate = DateTime.now();
  List<Trip> _trips = [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _searchNotice;
  String? _searchError;

  // ── Filters ───────────────────────────────────────────────────
  TripSort _sort = TripSort.earliest;
  double? _maxFare;
  bool _hideSoldOut = true;

  // ── Selection ─────────────────────────────────────────────────
  Trip? _selectedTrip;

  // ── Dashboard feeds (local until Phase 4 bookings API) ────────
  final List<Booking> _recentBookings = [];

  // ── Getters ───────────────────────────────────────────────────
  List<Location> get locations => _locations;
  List<RouteModel> get routes => _routes;
  bool get catalogLoading => _catalogLoading;
  Location? get origin => _origin;
  Location? get destination => _destination;
  DateTime get travelDate => _travelDate;
  String get travelDateIso => DateFormat('yyyy-MM-dd').format(_travelDate);
  List<Trip> get trips => _filteredTrips;
  List<Trip> get allTrips => List.unmodifiable(_trips);
  bool get isSearching => _searching;
  bool get hasSearched => _hasSearched;
  String? get errorMessage => _errorMessage;

  /// Server-supplied explanation for an empty result, e.g.
  /// "No trips available for the selected route and date".
  String? get searchNotice => _searchNotice;

  /// Set when the last search itself failed (as opposed to returning no
  /// trips). Drives the retry card on the search screen.
  String? get searchError => _searchError;
  TripSort get sort => _sort;
  double? get maxFare => _maxFare;
  bool get hideSoldOut => _hideSoldOut;
  Trip? get selectedTrip => _selectedTrip;
  List<Booking> get recentBookings => List.unmodifiable(_recentBookings);

  /// Trips after sort + fare + sold-out filters.
  List<Trip> get _filteredTrips {
    var list = List<Trip>.from(_trips);
    if (_hideSoldOut) list = list.where((t) => !t.isSoldOut).toList();
    if (_maxFare != null) {
      list = list.where((t) => t.fare <= _maxFare!).toList();
    }
    switch (_sort) {
      case TripSort.cheapest:
        list.sort((a, b) => a.fare.compareTo(b.fare));
        break;
      case TripSort.mostSeats:
        list.sort((a, b) => b.availableSeats.compareTo(a.availableSeats));
        break;
      case TripSort.earliest:
        list.sort((a, b) =>
            '${a.departureDate} ${a.departureTime}'
                .compareTo('${b.departureDate} ${b.departureTime}'));
        break;
    }
    return list;
  }

  /// Upcoming trips for the dashboard (soonest first, max 3).
  List<Trip> get upcomingTrips => _filteredTrips.take(3).toList();

  /// True when origin + destination are set and differ.
  bool get canSearch =>
      _origin != null && _destination != null && _origin!.id != _destination!.id;

  // ── Catalog ───────────────────────────────────────────────────

  Future<void> loadCatalog({String? authToken}) async {
    _catalogLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // NOTE: the catalog is a store-scoped public read — it authenticates
      // with X-Api-Key + apiKey/storeId, and the upstream rejects requests
      // that carry an unexpected `Authorization` header. So the user's
      // bearer token is deliberately *not* forwarded here; doing so used to
      // empty the location list and leave the search button disabled.
      final results = await Future.wait([
        _fleet.getLocations(),
        _fleet.getRoutes(),
      ]);
      _locations = results[0] as List<Location>;
      _routes = results[1] as List<RouteModel>;
      _seedDefaults();
      // Persist for offline fallback.
      await CacheService.put(
        AppConstants.keyCacheLocations,
        _locations.map((l) => l.toJson()).toList(),
      );
      await CacheService.put(
        AppConstants.keyCacheRoutes,
        _routes.map((r) => r.toJson()).toList(),
      );
    } on ApiException catch (e) {
      // Network-first failed → hydrate from cache (any age), but keep the
      // server's own explanation so the UI can show what actually broke.
      await _hydrateCatalogFromCache(fallbackMessage: e.message);
    } catch (_) {
      // Network-first failed → hydrate from cache (any age).
      await _hydrateCatalogFromCache(
        fallbackMessage: 'Unable to load locations. Pull to retry.',
      );
    } finally {
      _catalogLoading = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateCatalogFromCache({
    required String fallbackMessage,
  }) async {
    try {
      final cachedLoc =
          await CacheService.getStale(AppConstants.keyCacheLocations);
      final cachedRoutes =
          await CacheService.getStale(AppConstants.keyCacheRoutes);
      if (cachedLoc is List && cachedLoc.isNotEmpty) {
        _locations = cachedLoc
            .whereType<Map<String, dynamic>>()
            .map(Location.fromJson)
            .toList();
        if (cachedRoutes is List) {
          _routes = cachedRoutes
              .whereType<Map<String, dynamic>>()
              .map(RouteModel.fromJson)
              .toList();
        }
        _seedDefaults();
        _errorMessage = 'Offline — showing cached locations';
      } else {
        // Nothing cached to fall back on. Surface the failure even when we
        // still hold locations from an earlier successful load, so a stale
        // list is never silently presented as fresh.
        _errorMessage = fallbackMessage;
      }
    } catch (_) {
      _errorMessage = fallbackMessage;
    }
  }

  void _seedDefaults() {
    if (_locations.length >= 2) {
      _origin ??= _locations.first;
      _destination ??= _locations[1];
    }
  }

  // ── Search form mutations ─────────────────────────────────────

  void setOrigin(Location? v) {
    _origin = v;
    notifyListeners();
  }

  void setDestination(Location? v) {
    _destination = v;
    notifyListeners();
  }

  void swapOriginDestination() {
    final tmp = _origin;
    _origin = _destination;
    _destination = tmp;
    notifyListeners();
  }

  void setTravelDate(DateTime v) {
    _travelDate = v;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────

  Future<bool> searchTrips({String? authToken}) async {
    if (!canSearch) {
      _errorMessage = 'Select different origin and destination';
      notifyListeners();
      return false;
    }
    _searching = true;
    _errorMessage = null;
    _searchNotice = null;
    _searchError = null;
    notifyListeners();
    try {
      final outcome = await _fleet.searchTrips(
        sourceId: _origin!.id,
        sourceName: _origin!.name,
        destinationId: _destination!.id,
        destinationName: _destination!.name,
        date: travelDateIso,
        // Same reasoning as loadCatalog: /trips/search is a public
        // store-scoped endpoint and rejects a stray bearer token.
      );
      _trips = outcome.trips;
      _searchNotice = outcome.notice;
      _hasSearched = true;
      await CacheService.put(
        AppConstants.keyCacheTrips,
        _trips.map((t) => t.toJson()).toList(),
      );
      return true;
    } on ApiException catch (e) {
      // A real failure: surface the server's own words plus the URL so the
      // cause (proxy down vs. bad route) is obvious.
      _searchError = e.message;
      _errorMessage = e.message;
      _searchNotice = null;
      _hasSearched = true;
      return false;
    } catch (_) {
      final cached =
          await CacheService.getStale(AppConstants.keyCacheTrips);
      if (cached is List && cached.isNotEmpty) {
        _trips = cached
            .whereType<Map<String, dynamic>>()
            .map(Trip.fromJson)
            .toList();
        _hasSearched = true;
        _errorMessage = 'Offline — showing cached trips';
        return true;
      }
      _searchError = 'Search failed. Please try again.';
      _errorMessage = _searchError;
      return false;
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  /// Re-runs the last search (pull-to-refresh on results/dashboard).
  Future<void> refresh({String? authToken}) async {
    if (_hasSearched && canSearch) {
      await searchTrips(authToken: authToken);
    } else {
      await loadCatalog(authToken: authToken);
    }
  }

  // ── Filters ───────────────────────────────────────────────────

  void setSort(TripSort v) {
    _sort = v;
    notifyListeners();
  }

  void setMaxFare(double? v) {
    _maxFare = v;
    notifyListeners();
  }

  void setHideSoldOut(bool v) {
    _hideSoldOut = v;
    notifyListeners();
  }

  void clearFilters() {
    _sort = TripSort.earliest;
    _maxFare = null;
    _hideSoldOut = true;
    notifyListeners();
  }

  // ── Selection ─────────────────────────────────────────────────

  void selectTrip(Trip? trip) {
    _selectedTrip = trip;
    // New trip → reset downstream flow state.
    _seats = [];
    _selectedSeats.clear();
    _holdReference = null;
    _passenger = null;
    _payment = null;
    _confirmedBookings = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Phase 4: seats ────────────────────────────────────────────

  List<Seat> _seats = [];
  final Set<String> _selectedSeats = {};
  bool _seatsLoading = false;
  String? _holdReference;

  List<Seat> get seats => List.unmodifiable(_seats);
  List<String> get selectedSeats => _selectedSeats.toList()..sort();
  bool get seatsLoading => _seatsLoading;
  String? get holdReference => _holdReference;

  /// Fare × selected seats.
  double get totalPrice =>
      (_selectedTrip?.fare ?? 0) * _selectedSeats.length;

  bool isSeatSelected(String seatNumber) =>
      _selectedSeats.contains(seatNumber);

  /// Loads the seat map for the selected trip.
  Future<void> loadSeats({String? authToken}) async {
    final trip = _selectedTrip;
    if (trip == null) {
      _errorMessage = 'Select a trip first';
      notifyListeners();
      return;
    }
    _seatsLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _seats = await _fleet.getSeatLayout(trip.masterId,
          authToken: authToken);
      // Drop selections that are no longer selectable.
      _selectedSeats.removeWhere((n) {
        final seat = _seats.where((s) => s.seatNumber == n);
        return seat.isEmpty || !seat.first.isSelectable;
      });
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load seats. Pull to retry.';
    } finally {
      _seatsLoading = false;
      notifyListeners();
    }
  }

  /// Toggles a seat (respects [AppConstants.maxSeatSelection]).
  /// Returns a message for UI feedback, or null on success.
  String? toggleSeat(String seatNumber) {
    final seat =
        _seats.where((s) => s.seatNumber == seatNumber).toList();
    if (seat.isEmpty || !seat.first.isSelectable) return 'Seat unavailable';
    if (_selectedSeats.contains(seatNumber)) {
      _selectedSeats.remove(seatNumber);
    } else {
      if (_selectedSeats.length >= AppConstants.maxSeatSelection) {
        return 'You can select at most ${AppConstants.maxSeatSelection} seats';
      }
      _selectedSeats.add(seatNumber);
    }
    notifyListeners();
    return null;
  }

  void clearSeats() {
    _selectedSeats.clear();
    notifyListeners();
  }

  // ── Phase 4: passenger ────────────────────────────────────────

  Map<String, dynamic>? _passenger;
  Map<String, dynamic>? get passenger => _passenger;

  void savePassenger({
    required String name,
    required String email,
    required String phone,
    String? nextOfKin,
    String? nextOfKinPhone,
  }) {
    _passenger = {
      'PassengerName': name,
      'passengerName': name,
      'Email': email,
      'email': email,
      'Phone': phone,
      'phone': phone,
      if (nextOfKin != null && nextOfKin.isNotEmpty) ...{
        'NextOfKin': nextOfKin,
        'nextOfKin': nextOfKin,
      },
      if (nextOfKinPhone != null && nextOfKinPhone.isNotEmpty) ...{
        'NextOfKinPhone': nextOfKinPhone,
        'nextOfKinPhone': nextOfKinPhone,
      },
    };
    notifyListeners();
  }

  // ── Phase 4: hold / payment / booking ─────────────────────────

  bool _processing = false;
  Payment? _payment;
  List<Booking> _confirmedBookings = [];

  bool get isProcessing => _processing;
  Payment? get payment => _payment;
  List<Booking> get confirmedBookings =>
      List.unmodifiable(_confirmedBookings);
  String? get bookingReference => _payment?.bookingReference;

  Future<bool> holdSelectedSeats({String? authToken}) async {
    final trip = _selectedTrip;
    if (trip == null || _selectedSeats.isEmpty) return false;
    _processing = true;
    notifyListeners();
    try {
      _holdReference = await _fleet.holdSeats(
        masterId: trip.masterId,
        seatNumbers: selectedSeats,
        authToken: authToken,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<bool> pay({
    required String method,
    String? authToken,
  }) async {
    final trip = _selectedTrip;
    if (trip == null || _selectedSeats.isEmpty) return false;
    _processing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _payment = await _fleet.initiatePayment(
        masterId: trip.masterId,
        seatNumbers: selectedSeats,
        amount: totalPrice,
        method: method,
        authToken: authToken,
        passenger: _passenger,
      );
      return _payment?.isCompleted ?? false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<bool> confirmBooking({String? authToken}) async {
    final trip = _selectedTrip;
    final ref = _payment?.paymentReference;
    if (trip == null || ref == null || _selectedSeats.isEmpty) {
      _errorMessage = 'Complete payment first';
      notifyListeners();
      return false;
    }
    _processing = true;
    notifyListeners();
    try {
      _confirmedBookings = await _fleet.createBooking(
        masterId: trip.masterId,
        seatNumbers: selectedSeats,
        paymentReference: ref,
        passenger: _passenger,
        authToken: authToken,
      );
      _recentBookings.insertAll(0, _confirmedBookings);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  /// Resets the whole flow (called from confirmation Done).
  void resetFlow() {
    _selectedSeats.clear();
    _holdReference = null;
    _passenger = null;
    _payment = null;
    _confirmedBookings = [];
    notifyListeners();
  }

  // ── Phase 5: booking history ──────────────────────────────────

  /// Status filter for the history screen ('all' | 'upcoming' | 'past').
  String _historyFilter = 'all';
  List<Booking> _history = [];
  bool _historyLoading = false;

  String get historyFilter => _historyFilter;
  List<Booking> get history => List.unmodifiable(_history);
  bool get historyLoading => _historyLoading;

  /// History after the active status filter.
  List<Booking> get filteredHistory {
    final now = DateTime.now();
    switch (_historyFilter) {
      case 'upcoming':
        return _history
            .where((b) => _bookingDate(b)?.isAfter(now) ?? true)
            .toList();
      case 'past':
        return _history
            .where((b) => !(_bookingDate(b)?.isAfter(now) ?? true))
            .toList();
      case 'all':
      default:
        return history;
    }
  }

  /// Upcoming = future-dated bookings, soonest first (max 5).
  List<Booking> get upcomingBookings {
    final now = DateTime.now();
    final list = _history
        .where((b) => _bookingDate(b)?.isAfter(now) ?? false)
        .toList()
      ..sort((a, b) => a.bookedAt.compareTo(b.bookedAt));
    return list.take(5).toList();
  }

  static DateTime? _bookingDate(Booking b) {
    final tripDate = b.tripDetails?.departureDate;
    if (tripDate != null && tripDate.isNotEmpty) {
      final parsed = DateTime.tryParse(tripDate);
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(b.bookedAt);
  }

  void setHistoryFilter(String v) {
    _historyFilter = v;
    notifyListeners();
  }

  /// Loads server history and merges local session bookings on top.
  Future<void> loadHistory({String? authToken}) async {
    _historyLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _fleet.getBookingHistory(authToken: authToken),
        _fleet.getUpcomingBookings(authToken: authToken),
      ]);
      final merged = <Booking>[..._recentBookings];
      for (final list in results) {
        for (final b in list) {
          if (merged.every((m) => m.bookingId != b.bookingId)) {
            merged.add(b);
          }
        }
      }
      _history = merged;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _history = List.from(_recentBookings);
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  /// Cancels a booking locally + on the server (best-effort server).
  Future<bool> cancelBooking(String bookingId,
      {String? authToken}) async {
    bool ok;
    try {
      ok = await _fleet.cancelBooking(
          bookingId: bookingId, authToken: authToken);
    } catch (_) {
      ok = true; // server best-effort: still remove locally
    }
    if (ok) {
      _history.removeWhere((b) => b.bookingId == bookingId);
      _recentBookings.removeWhere((b) => b.bookingId == bookingId);
      notifyListeners();
    }
    return ok;
  }

  // ── Phase 5: wallet ───────────────────────────────────────────

  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _walletLoading = false;

  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions =>
      List.unmodifiable(_transactions);
  bool get walletLoading => _walletLoading;
  double get walletBalance => _wallet?.balance ?? 0;

  Future<void> loadWallet({
    required String customerId,
    required String customerName,
    String? authToken,
  }) async {
    _walletLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _fleet.getWalletBalance(
          customerId: customerId,
          customerName: customerName,
          authToken: authToken,
        ),
        _fleet.getTransactions(authToken: authToken),
      ]);
      _wallet = results[0] as Wallet;
      _transactions = results[1] as List<WalletTransaction>;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load wallet. Pull to retry.';
    } finally {
      _walletLoading = false;
      notifyListeners();
    }
  }

  Future<bool> fundWallet({
    required double amount,
    required String customerId,
    required String customerName,
    String? authToken,
  }) async {
    _processing = true;
    notifyListeners();
    try {
      _wallet = await _fleet.fundWallet(
        amount: amount,
        customerId: customerId,
        customerName: customerName,
        currentBalance: walletBalance,
        authToken: authToken,
      );
      _transactions = [
        WalletTransaction(
          id: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
          type: 'credit',
          amount: amount,
          description: 'Wallet top-up',
          date: DateTime.now().toIso8601String(),
          status: 'completed',
        ),
        ..._transactions,
      ];
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }
}
