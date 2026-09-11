import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/premium_theme.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/booking_confirmation_screen.dart';
import 'screens/booking_history_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/passenger_details_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/register_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'screens/api_diagnostics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/trip_results_screen.dart';
import 'screens/trip_search_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'widgets/feedback.dart';

/// Entry point — providers + global error handling + navigation (Phase 6).
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorHandler.init();
    runApp(const FleetBookingApp());
  }, (error, stack) {
    // TODO(prod): crashReporter.recordError(error, stack);
    debugPrint('Uncaught zone error: $error');
  });
}

class FleetBookingApp extends StatelessWidget {
  const FleetBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(
            create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => AppSettingsProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => NotificationService()..initialize()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: Consumer3<ThemeProvider, AppSettingsProvider,
          NotificationService>(
        builder: (_, theme, settings, _, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: settings.highContrast
              ? Lux.highContrast(Lux.light())
              : Lux.light(),
          darkTheme: settings.highContrast
              ? Lux.highContrast(Lux.dark())
              : Lux.dark(),
          themeMode: theme.mode,
          // Smooth theme cross-fade on toggle.
          themeAnimationDuration:
              const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOut,
          // Accessibility font scaling (0.85×–1.3× from settings).
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                    settings.fontScale.clamp(0.85, 1.3)),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          initialRoute: AppConstants.routeSplash,
          routes: {
            AppConstants.routeSplash: (_) => const SplashScreen(),
            AppConstants.routeLogin: (_) => const LoginScreen(),
            AppConstants.routeRegister: (_) =>
                const RegisterScreen(),
            // Dashboard is the post-login home.
            AppConstants.routeHome: (_) => const DashboardScreen(),
            AppConstants.routeSearch: (_) =>
                const TripSearchScreen(),
            AppConstants.routeTrips: (_) =>
                const TripResultsScreen(),
            // Phase 4 booking flow.
            AppConstants.routeSeatSelection: (_) =>
                const SeatSelectionScreen(),
            AppConstants.routePassenger: (_) =>
                const PassengerDetailsScreen(),
            AppConstants.routeCheckout: (_) =>
                const PassengerDetailsScreen(),
            AppConstants.routePayment: (_) => const PaymentScreen(),
            AppConstants.routeBookingConfirmation: (_) =>
                const BookingConfirmationScreen(),
            // Phase 5 account screens.
            AppConstants.routeWallet: (_) => const WalletScreen(),
            AppConstants.routeMyBookings: (_) =>
                const BookingHistoryScreen(),
            // Phase 6 insights + settings.
            AppConstants.routeAnalytics: (_) =>
                const AnalyticsScreen(),
            AppConstants.routeSettings: (_) =>
                const SettingsScreen(),
            AppConstants.routeApiDiagnostics: (_) =>
                const ApiDiagnosticsScreen(),
          },
          onUnknownRoute: (_) => MaterialPageRoute(
            builder: (_) => const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
