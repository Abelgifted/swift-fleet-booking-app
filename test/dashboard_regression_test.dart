// REGRESSION SUITE for the blank-dashboard bug.
//
// Guards the guarantees that were missing when the dashboard rendered
// blank after registration:
//   1. The shell (header, wallet card, nav bar) always renders.
//   2. API failures show a friendly error view with a Retry button.
//   3. Cached data keeps the dashboard usable (banner instead of a
//      full error view).
//   4. All four tabs render content.
//   5. Repeated/empty masterIds from the API cannot crash the screen
//      (duplicate Hero tags / duplicate keys).
//   6. Parsing degrades gracefully on hostile payloads.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleet_booking/config/api_config.dart';
import 'package:fleet_booking/models/booking.dart';
import 'package:fleet_booking/models/location.dart';
import 'package:fleet_booking/models/trip.dart';
import 'package:fleet_booking/models/user.dart';
import 'package:fleet_booking/providers/app_settings_provider.dart';
import 'package:fleet_booking/providers/auth_provider.dart';
import 'package:fleet_booking/providers/booking_provider.dart';
import 'package:fleet_booking/providers/theme_provider.dart';
import 'package:fleet_booking/screens/dashboard_screen.dart';
import 'package:fleet_booking/services/auth_service.dart';
import 'package:fleet_booking/services/connectivity_service.dart';
import 'package:fleet_booking/services/fleet_service.dart';
import 'package:fleet_booking/services/notification_service.dart';
import 'package:fleet_booking/utils/constants.dart';
import 'package:fleet_booking/widgets/trip_card.dart';

import 'helpers/stub_api_service.dart';

Widget _wrap({
  required AuthProvider auth,
  required BookingProvider booking,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: booking),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ChangeNotifierProvider(
          create: (_) => NotificationService()..initialize()),
      ChangeNotifierProvider(create: (_) => ConnectivityService()),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  );
}

/// A fresh-registered user as persisted by [AuthProvider.register].
Map<String, String> _registeredUserJson() => {
      AppConstants.keyUserJson: jsonEncode({
        'CustomerId': 'C-1',
        'CustomerName': 'Jane Doe',
        'Email': 'jane@example.com',
        'Phone': '08030000000',
        'Token': 'tok-123',
        'Balance': 0,
      }),
    };

const _locationsPayload = [
  {'Id': '1', 'Name': 'Lagos', 'Code': 'LOS'},
  {'Id': '2', 'Name': 'Abuja', 'Code': 'ABV'},
];

const _routesPayload = [
  {
    'Id': 'R1',
    'Name': 'Lagos-Abuja',
    'SourceId': '1',
    'SourceName': 'Lagos',
    'DestinationId': '2',
    'DestinationName': 'Abuja',
    'Fare': 25000,
    'EstimatedDuration': 480,
  },
];

Future<void> _pumpAndSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  parsingTests();

  testWidgets('dashboard renders full content after registration',
      (tester) async {
    SharedPreferences.setMockInitialValues(_registeredUserJson());
    final auth = AuthProvider();
    await auth.initialize();
    final booking = BookingProvider(
      fleet: FleetService(
        api: StubApiService(responses: {
          AppConstants.epTripsLocations: _locationsPayload,
          AppConstants.epTripsRoutes: _routesPayload,
        }),
      ),
    );

    await tester.pumpWidget(
        _wrap(auth: auth, booking: booking));
    await _pumpAndSettle(tester);

    expect(tester.takeException(), isNull);
    // Always-visible shell.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Wallet balance'), findsOneWidget);
    expect(find.textContaining('Hello,'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_wallet_balance')), findsOneWidget);
    // Catalog data actually loaded into the search tab state.
    expect(booking.locations.map((l) => l.name), containsAll(['Lagos', 'Abuja']));
    // All four tabs exist.
    expect(find.byKey(const Key('dashboard_nav_home')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_nav_search')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_nav_bookings')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_nav_profile')), findsOneWidget);
    // No error UI on the happy path.
    expect(find.byKey(const Key('dashboard_error_view')), findsNothing);
  });

  testWidgets('API failure shows friendly error with retry, never blank',
      (tester) async {
    SharedPreferences.setMockInitialValues(_registeredUserJson());
    final auth = AuthProvider();
    await auth.initialize();
    final booking = BookingProvider(
      fleet: FleetService(
        api: StubApiService(
          failurePaths: {
            AppConstants.epTripsLocations,
            AppConstants.epTripsRoutes,
            AppConstants.epLocations,
            AppConstants.epRoutes,
          },
        ),
      ),
    );

    await tester.pumpWidget(
        _wrap(auth: auth, booking: booking));
    await _pumpAndSettle(tester);

    expect(tester.takeException(), isNull);
    // Error view with retry…
    expect(find.byKey(const Key('dashboard_error_view')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // …rendered alongside the always-visible shell (not a blank screen).
    expect(find.text('Wallet balance'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Retry stays on a friendly, non-crashing screen when offline.
    // FilledButton routes hit tests through its inner InkWell, so the
    // finder's own render object is not the hit target — benign warning.
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'),
        warnIfMissed: false);
    await _pumpAndSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('dashboard_error_view')), findsOneWidget);
  });

  testWidgets('cached catalog keeps dashboard usable (banner, not error view)',
      (tester) async {
    final prefs = _registeredUserJson();
    prefs[AppConstants.keyCacheLocations] = jsonEncode({
      'at': '2026-09-10T10:00:00.000',
      'data': _locationsPayload,
    });
    prefs[AppConstants.keyCacheRoutes] = jsonEncode({
      'at': '2026-09-10T10:00:00.000',
      'data': _routesPayload,
    });
    SharedPreferences.setMockInitialValues(prefs);
    final auth = AuthProvider();
    await auth.initialize();
    final booking = BookingProvider(
      fleet: FleetService(
        api: StubApiService(
          failurePaths: {
            AppConstants.epTripsLocations,
            AppConstants.epTripsRoutes,
            AppConstants.epLocations,
            AppConstants.epRoutes,
          },
        ),
      ),
    );

    await tester.pumpWidget(
        _wrap(auth: auth, booking: booking));
    await _pumpAndSettle(tester);

    expect(tester.takeException(), isNull);
    // Slim banner (cached data available), not the full error view.
    expect(find.byKey(const Key('dashboard_error_banner')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_error_view')), findsNothing);
    // Cached locations still populated for the search tab.
    expect(booking.locations, isNotEmpty);
    expect(find.text('Wallet balance'), findsOneWidget);
  });

  testWidgets('all four tabs render content', (tester) async {
    SharedPreferences.setMockInitialValues(_registeredUserJson());
    final auth = AuthProvider();
    await auth.initialize();
    final booking = BookingProvider(
      fleet: FleetService(
        api: StubApiService(responses: {
          AppConstants.epTripsLocations: _locationsPayload,
          AppConstants.epTripsRoutes: _routesPayload,
        }),
      ),
    );

    await tester.pumpWidget(
        _wrap(auth: auth, booking: booking));
    await _pumpAndSettle(tester);

    // Home (default)
    expect(find.text('Wallet balance'), findsOneWidget);

    // Search tab
    await tester.tap(find.byKey(const Key('dashboard_nav_search')));
    await _pumpAndSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Plan your journey'), findsOneWidget);

    // Bookings tab
    await tester.tap(find.byKey(const Key('dashboard_nav_bookings')));
    await _pumpAndSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('No bookings found'), findsOneWidget);

    // Profile tab
    await tester.tap(find.byKey(const Key('dashboard_nav_profile')));
    await _pumpAndSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Edit profile'), findsOneWidget);
    // 'Log out' sits below the fold in the test viewport — scroll to it.
    await tester.dragUntilVisible(
      find.text('Log out'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await _pumpAndSettle(tester);
    expect(find.text('Log out'), findsOneWidget);

    // Back to Home
    await tester.tap(find.byKey(const Key('dashboard_nav_home')));
    await _pumpAndSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Wallet balance'), findsOneWidget);
  });

  testWidgets('duplicate masterIds from the API do not crash the dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues(_registeredUserJson());
    final auth = AuthProvider();
    await auth.initialize();
    final booking = BookingProvider(
      fleet: FleetService(
        api: StubApiService(responses: {
          AppConstants.epTripsLocations: _locationsPayload,
          AppConstants.epTripsRoutes: _routesPayload,
          // Real backends can return several departures sharing a
          // masterId (or empty ids when fields are missing).
          AppConstants.epTripsSearch: [
            {
              'MasterId': 'M-1',
              'Source': 'Lagos',
              'Destination': 'Abuja',
              'DepartureDate': '2026-09-11',
              'DepartureTime': '08:00',
              'Fare': 25000,
              'TotalSeats': 28,
              'BookedSeats': 3,
              'AvailableSeats': 25,
            },
            {
              'MasterId': 'M-1',
              'Source': 'Lagos',
              'Destination': 'Abuja',
              'DepartureDate': '2026-09-11',
              'DepartureTime': '13:00',
              'Fare': 25000,
              'TotalSeats': 28,
              'AvailableSeats': 20,
            },
            {
              // Missing MasterId entirely.
              'Source': 'Lagos',
              'Destination': 'Abuja',
              'DepartureDate': '2026-09-11',
              'DepartureTime': '18:00',
              'Fare': 25000,
              'TotalSeats': 28,
              'AvailableSeats': 15,
            },
          ],
        }),
      ),
    );

    await tester.pumpWidget(
        _wrap(auth: auth, booking: booking));
    await _pumpAndSettle(tester);

    // Run a search the same way the UI would (origin/destination were
    // seeded from the catalog).
    final ok = await booking.searchTrips(authToken: 'tok-123');
    expect(ok, isTrue);
    await _pumpAndSettle(tester);

    // Three cards on the dashboard — used to throw
    // "Multiple heroes share the same tag within a subtree".
    expect(find.byType(TripCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}

// ── Parsing regressions (pure Dart) ─────────────────────────────────

void parsingTests() {
  test('Trip.fromJson tolerates nulls, wrong types and missing fields', () {
    final trip = Trip.fromJson({
      'MasterId': 42, // numeric id
      'Fare': '2500.75', // numeric as string
      'TotalSeats': 28.0, // double where int expected
      'BookedSeats': null,
      'HeldSeats': 'x', // garbage
      'AvailableSeats': null,
      'Source': null,
      'Destination': 123,
    });
    expect(trip.masterId, '42');
    expect(trip.fare, 2500.75);
    expect(trip.totalSeats, 28);
    expect(trip.bookedSeats, 0);
    expect(trip.heldSeats, 0);
    expect(trip.availableSeats, 28); // derived: 28 - 0 - 0
    expect(trip.source, '');
    expect(trip.destination, '123');
  });

  test('User.fromJson unwraps wrapper payloads and lifts tokens', () {
    final user = User.fromJson({
      'Token': 'tok-abc',
      'Data': {
        'CustomerId': 'C-9',
        'CustomerName': 'Ada Obi',
        'Email': 'ada@example.com',
        'Phone': '08011122233',
        'Balance': '1500.50', // string balance
      },
    });
    expect(user.token, 'tok-abc');
    expect(user.customerId, 'C-9');
    expect(user.customerName, 'Ada Obi');
    expect(user.balance, 1500.50);
  });

  test('AuthService.extractUserMap keeps top-level token beside nested user',
      () {
    final map = AuthService.extractUserMap({
      'Token': 'tok-xyz',
      'Customer': {'CustomerId': 'C-2', 'CustomerName': 'Test User'},
    });
    expect(map['Token'], 'tok-xyz');
    expect(map['CustomerName'], 'Test User');
  });

  test('AuthService.extractUserMap degrades to empty map on non-map payload',
      () {
    expect(AuthService.extractUserMap('plain string'), isEmpty);
    expect(AuthService.extractUserMap(null), isEmpty);
  });

  test('Booking.fromJson accepts loosely-typed trip details', () {
    final booking = Booking.fromJson({
      'BookingId': 'BK-1',
      'SeatNumber': 7, // numeric seat
      'TripDetails': Map<dynamic, dynamic>.from({
        'MasterId': 'M-2',
        'Source': 'Lagos',
        'Destination': 'Abuja',
      }),
    });
    expect(booking.seatNumber, '7');
    expect(booking.tripDetails?.masterId, 'M-2');
    expect(booking.tripDetails?.source, 'Lagos');
  });

  test('Location.fromJson coerces numeric ids', () {
    final location = Location.fromJson({'Id': 12, 'Name': 'Ibadan'});
    expect(location.id, '12');
    expect(location.name, 'Ibadan');
    expect(location.code, '');
  });

  test('ApiConfig.baseUrl is valid and points at the fleet path', () {
    expect(ApiConfig.baseUrl, isNotEmpty);
    expect(ApiConfig.baseUrl.startsWith('http'), isTrue);
    expect(ApiConfig.baseUrl.endsWith('/api/fleet'), isTrue);
  });
}
