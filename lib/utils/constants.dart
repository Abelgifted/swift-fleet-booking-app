/// App-wide static constants: routes, keys, UI copy, and API endpoints.
class AppConstants {
  AppConstants._();

  // ── App meta ──────────────────────────────────────────────────
  static const String appName = 'Fleet Booking';
  static const String appTagline = 'Book your seat in seconds';

  // ── Storage keys ──────────────────────────────────────────────
  static const String keyAuthToken = 'auth_token';
  static const String keyCustomerId = 'customer_id';
  static const String keyCustomerName = 'customer_name';
  static const String keyUserJson = 'user_json';
  static const String keyThemeMode = 'theme_mode';

  // ── Navigation routes ─────────────────────────────────────────
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeSearch = '/search';
  static const String routeTrips = '/trips';
  static const String routeSeatSelection = '/seats';
  static const String routeCheckout = '/checkout';
  static const String routePassenger = '/passenger';
  static const String routePayment = '/payment';
  static const String routeBookingConfirmation = '/booking-confirmation';
  static const String routeMyBookings = '/my-bookings';
  static const String routeWallet = '/wallet';
  static const String routeAnalytics = '/analytics';
  static const String routeSettings = '/settings';
  /// Hidden developer screen: backend health check + raw API traffic.
  static const String routeApiDiagnostics = '/api-diagnostics';

  // ── Cache keys / TTL ────────────────────────────────────────────
  static const String keyCacheLocations = 'cache_locations';
  static const String keyCacheRoutes = 'cache_routes';
  static const String keyCacheTrips = 'cache_trips';
  static const String keyCacheTime = 'cache_time';
  static const Duration cacheTtl = Duration(minutes: 15);

  // ── Settings keys ───────────────────────────────────────────────
  static const String keyFontScale = 'font_scale';
  static const String keyHighContrast = 'high_contrast';
  static const String keyNotifications = 'notifications_enabled';

  // ── Fleet API endpoints (relative to ApiConfig.baseUrl) ──────
  static const String epLocations = '/locations';
  static const String epRoutes = '/routes';
  static const String epTrips = '/trips';
  static const String epTripDetails = '/trip-details';
  static const String epSeats = '/seats';
  static const String epBookSeat = '/book-seat';
  static const String epBookingDetails = '/booking-details';
  static const String epVerifyPayment = '/verify-payment';
  static const String epWalletBalance = '/wallet-balance';
  static const String epWalletFund = '/wallet-fund';
  static const String epLogin = '/login';
  static const String epRegister = '/register';
  static const String epLogout = '/logout';
  static const String epProfile = '/profile';

  // ── Bookings & wallet endpoints (canonical first, legacy fallback) ─
  static const String epBookingsHistory = '/bookings/history';
  static const String epBookingsUpcoming = '/bookings/upcoming';
  static const String epBookingsCancel = '/bookings/cancel';
  static const String epWalletBalanceNew = '/wallet/balance';
  static const String epWalletTransactions = '/wallet/transactions';

  // ── Seat & payment endpoints (canonical first, legacy fallback) ─
  static const String epSeatsLayout = '/seats/layout';
  static const String epSeatsAvailability = '/seats/availability';
  static const String epSeatsHold = '/seats/hold';
  static const String epPaymentsInitiate = '/payments/initiate';
  static const String epFleetBook = '/api/Fleet';

  // ── Trip API endpoints (canonical /trips/* — preferred by Phase 3) ─
  static const String epTripsLocations = '/trips/locations';
  static const String epTripsRoutes = '/trips/routes';
  static const String epTripsSearch = '/trips/search';

  // ── Auth API endpoints (canonical /auth/* — preferred by Phase 2) ─
  static const String epAuthLogin = '/auth/login';
  static const String epAuthRegister = '/auth/register';
  static const String epAuthLogout = '/auth/logout';
  static const String epAuthProfile = '/auth/profile';

  // ── UI defaults ───────────────────────────────────────────────
  static const double defaultPadding = 16.0;
  static const double cardRadius = 16.0;
  static const double buttonHeight = 52.0;

  // ── Currency ──────────────────────────────────────────────────
  static const String currencySymbol = '₦';
  static const String currencyCode = 'NGN';

  // ── Validation limits ─────────────────────────────────────────
  static const int minPasswordLength = 6;
  static const int maxSeatSelection = 6;
}
