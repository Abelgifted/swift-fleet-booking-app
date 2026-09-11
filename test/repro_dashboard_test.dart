// TEMPORARY reproduction harness for the blank-dashboard bug.
// Not part of the final deliverable; used to observe real behavior.
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
import 'package:fleet_booking/services/notification_service.dart';
import 'package:fleet_booking/utils/constants.dart';

void main() {
  testWidgets('REPRO: dashboard after registration', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyUserJson: jsonEncode({
        'CustomerId': 'C-1',
        'CustomerName': 'Jane Doe',
        'Email': 'jane@example.com',
        'Phone': '08030000000',
        'Token': 'tok-123',
        'Balance': 0,
      }),
    });

    final auth = AuthProvider();
    await auth.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => BookingProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(
              create: (_) => NotificationService()..initialize()),
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    final err = tester.takeException();
    debugPrint('>>> takeException: $err');

    final scaffold = find.byType(Scaffold);
    debugPrint('>>> scaffold count: ${scaffold.evaluate().length}');
    debugPrint('>>> nav bar count: ${find.byType(NavigationBar).evaluate().length}');

    // Try to find key dashboard content.
    debugPrint('>>> "Wallet balance" found: '
        '${find.text('Wallet balance').evaluate().length}');
    debugPrint('>>> "Hello, Jane" found: '
        '${find.textContaining('Hello, Jane').evaluate().length}');
    debugPrint('>>> text widgets: '
        '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((t) => t != null && t.isNotEmpty).take(20).toList()}');
  });
}
