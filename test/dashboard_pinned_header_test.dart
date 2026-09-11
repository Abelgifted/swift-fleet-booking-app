// Verifies the dashboard greeting header is PINNED.
//
// Regression guard: the hero used to be a SliverAppBar inside the
// dashboard's CustomScrollView, so scrolling pushed "Hello, …" off the top
// of the screen. The header now lives in a Column *above* the scroll view,
// so it must not move at all while the content beneath it scrolls.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleet_booking/providers/app_settings_provider.dart';
import 'package:fleet_booking/providers/auth_provider.dart';
import 'package:fleet_booking/providers/booking_provider.dart';
import 'package:fleet_booking/providers/theme_provider.dart';
import 'package:fleet_booking/screens/dashboard_screen.dart';
import 'package:fleet_booking/services/connectivity_service.dart';
import 'package:fleet_booking/services/fleet_service.dart';
import 'package:fleet_booking/services/notification_service.dart';
import 'package:fleet_booking/utils/constants.dart';

import 'helpers/stub_api_service.dart';

Widget _wrap({required AuthProvider auth, required BookingProvider booking}) {
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

/// Same light-weight settle the dashboard regression suite uses: enough
/// pumps for the catalog future and the first frames, without waiting on
/// animations that never end.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _pumpDashboard(WidgetTester tester) async {
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

  await tester.pumpWidget(_wrap(auth: auth, booking: booking));
  await _settle(tester);
}

/// Scrolls the dashboard content up by [dy] (negative = content moves up).
Future<void> _scrollContent(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(CustomScrollView), Offset(0, dy));
  await _settle(tester);
  await _settle(tester);
}

void main() {
  testWidgets('greeting header does not move when the content scrolls',
      (tester) async {
    await _pumpDashboard(tester);

    final header = find.byKey(const Key('dashboard_hero_header'));
    final greeting = find.textContaining('Hello,');
    final wallet = find.text('Wallet balance');

    expect(header, findsOneWidget);
    expect(greeting, findsOneWidget);
    expect(wallet, findsOneWidget);

    final headerTop = tester.getTopLeft(header).dy;
    final greetingTop = tester.getTopLeft(greeting).dy;
    final walletTopBefore = tester.getTopLeft(wallet).dy;

    // The header is flush with the top of the screen.
    expect(headerTop, 0);

    await _scrollContent(tester, -160);

    // 1. The header did not move…
    expect(tester.getTopLeft(header).dy, headerTop);
    // 2. …nor did the greeting inside it…
    expect(tester.getTopLeft(greeting).dy, greetingTop);
    // 3. …while the content below it did scroll.
    expect(tester.getTopLeft(wallet).dy, lessThan(walletTopBefore));
    // 4. And the greeting is still on screen rather than scrolled away.
    expect(greeting, findsOneWidget);
    expect(tester.getTopLeft(greeting).dy, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('header stays pinned through repeated scrolls to the bottom',
      (tester) async {
    await _pumpDashboard(tester);

    final greeting = find.textContaining('Hello,');
    final greetingTop = tester.getTopLeft(greeting).dy;

    // Flick downwards four times, the way a user would to reach the end.
    for (var i = 0; i < 4; i++) {
      await _scrollContent(tester, -260);
      expect(
        tester.getTopLeft(greeting).dy,
        greetingTop,
        reason: 'greeting drifted on scroll #$i',
      );
    }

    expect(greeting, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('content scrolls underneath without overlapping the header',
      (tester) async {
    await _pumpDashboard(tester);

    final header = find.byKey(const Key('dashboard_hero_header'));
    final headerBottom = tester.getBottomLeft(header).dy;

    await _scrollContent(tester, -200);

    // Whatever is at the top of the scroll view stays at or below the
    // header's bottom edge — a pinned header must not be overlapped.
    final scrollViewTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(scrollViewTop, greaterThanOrEqualTo(headerBottom));

    // Header geometry is unchanged.
    expect(tester.getTopLeft(header).dy, 0);
    expect(tester.getBottomLeft(header).dy, headerBottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation still works with the pinned header',
      (tester) async {
    await _pumpDashboard(tester);
    expect(find.byKey(const Key('dashboard_hero_header')), findsOneWidget);

    // Away from Home the hero is not part of the layout…
    await tester.tap(find.byKey(const Key('dashboard_nav_search')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Plan your journey'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_hero_header')), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard_nav_bookings')));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('dashboard_nav_profile')));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // …and comes back pinned at the top when returning to Home.
    await tester.tap(find.byKey(const Key('dashboard_nav_home')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('dashboard_hero_header')), findsOneWidget);
    expect(find.textContaining('Hello,'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('dashboard_hero_header'))).dy,
        0);
  });

  testWidgets('scrolling after a tab round-trip still leaves the header pinned',
      (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard_nav_bookings')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('dashboard_nav_home')));
    await _settle(tester);

    final greeting = find.textContaining('Hello,');
    final greetingTop = tester.getTopLeft(greeting).dy;

    await _scrollContent(tester, -180);
    expect(tester.getTopLeft(greeting).dy, greetingTop);
    expect(tester.takeException(), isNull);
  });
}
