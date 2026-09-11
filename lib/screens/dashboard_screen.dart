import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/imagery.dart';
import '../config/premium_theme.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/feedback.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_fx.dart';
import '../widgets/premium_hero_header.dart';
import '../widgets/premium_loader.dart';
import '../widgets/responsive.dart';
import '../widgets/trip_card.dart';
import 'booking_history_screen.dart';
import 'profile_screen.dart';
import 'trip_search_screen.dart';

/// Home shell: hero header, metallic wallet, quick actions, stats,
/// upcoming trips and recent bookings, with a four-tab bottom bar.
///
/// Hardened against blank screens:
/// - an explicit background is painted before anything loads;
/// - the shell (header + wallet + quick actions) is static data and
///   always renders, even with zero network;
/// - every tab body is built inside a try/catch boundary;
/// - API failures surface a friendly error view with a Retry button.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final booking = context.read<BookingProvider>();
      await booking.loadCatalog(authToken: auth.token);
      if (!mounted) return;
      setState(() => _loadError = booking.errorMessage);
    } catch (error, stack) {
      debugPrint('Dashboard load failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _loadError = ErrorHandler.friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final auth = context.read<AuthProvider>();
      final booking = context.read<BookingProvider>();
      await auth.refreshProfile();
      if (!mounted) return;
      await booking.refresh(authToken: auth.token);
    } catch (error) {
      debugPrint('Dashboard refresh failed: $error');
    }
  }

  // ── Safe-tab boundary ───────────────────────────────────────────
  //
  // Construction-time throws (bad data shaping a builder, missing
  // provider, …) are caught here and replaced with a visible fallback
  // so one broken tab can never blank the whole dashboard.

  Widget _safeTab(Widget Function() builder, String tabName) {
    try {
      return KeyedSubtree(
        key: ValueKey('dashboard-tab-$tabName'),
        child: builder(),
      );
    } catch (error, stack) {
      debugPrint('Dashboard: $tabName failed to build: $error\n$stack');
      return _TabFallback(tabName: tabName, onRetry: () => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: background,
      body: SizedBox.expand(
        child: _safeTab(() {
          switch (_tab) {
            case 1:
              return const TripSearchScreen(embedded: true);
            case 2:
              return const BookingHistoryScreen(embedded: true);
            case 3:
              return const ProfileScreen(embedded: true);
            default:
              return _homeTab();
          }
        }, 'tab-$_tab'),
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('dashboard_nav_bar'),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            key: Key('dashboard_nav_home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            key: Key('dashboard_nav_search'),
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            key: Key('dashboard_nav_bookings'),
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            key: Key('dashboard_nav_profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ── Home tab ──────────────────────────────────────────────────

  Widget _homeTab() {
    final auth = context.watch<AuthProvider>();
    final booking = context.watch<BookingProvider>();
    final online = context.watch<ConnectivityService>().isOnline;
    final unread = context.watch<NotificationService>().unreadCount;
    final user = auth.user;
    final catalogFailed = _loadError != null && booking.locations.isEmpty;
    final isPhone = Breakpoints.isPhone(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_loading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                key: Key('dashboard_loading_indicator'),
                minHeight: 2.5,
              ),
            ),
          if (!online) const SliverToBoxAdapter(child: OfflineBar()),
          _heroHeader(context, user, unread),
          SliverToBoxAdapter(
            child: ContentShell(
              maxWidth: isPhone ? 720 : 900,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WalletCard(
                    user: user,
                    onTopUp: () =>
                        Navigator.of(context).pushNamed(AppConstants.routeWallet),
                  ),
                  const SizedBox(height: 26),
                  _QuickActions(
                    onSearch: () => setState(() => _tab = 1),
                    onBookings: () => setState(() => _tab = 2),
                    onWallet: () =>
                        Navigator.of(context).pushNamed(AppConstants.routeWallet),
                    onProfile: () => setState(() => _tab = 3),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      _StatTile(
                        value: '${booking.allTrips.length}',
                        label: 'Trips found',
                        icon: Icons.route_rounded,
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppConstants.routeAnalytics),
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        value: '${booking.recentBookings.length}',
                        label: 'Bookings',
                        icon: Icons.confirmation_number_outlined,
                        onTap: () => setState(() => _tab = 2),
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        value: Formatters.currency(user?.balance ?? 0,
                            withDecimals: false),
                        label: 'Balance',
                        icon: Icons.savings_outlined,
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppConstants.routeWallet),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // API error → friendly message + retry (full view when
                  // nothing could be loaded, slim banner when cached data
                  // keeps the dashboard usable).
                  if (catalogFailed)
                    AppErrorView(
                      key: const Key('dashboard_error_view'),
                      message: _loadError!,
                      onRetry: _load,
                    )
                  else if (_loadError != null)
                    _errorBanner(),
                  SectionHeader(
                    eyebrowText: 'Your journeys',
                    title: 'Upcoming trips',
                    actionLabel: 'Search',
                    onAction: () =>
                        Navigator.of(context).pushNamed(AppConstants.routeSearch),
                  ),
                  const SizedBox(height: 14),
                  if (booking.catalogLoading && booking.upcomingTrips.isEmpty)
                    const TripCardSkeleton()
                  else if (catalogFailed)
                    const SizedBox.shrink()
                  else if (booking.upcomingTrips.isEmpty)
                    _emptyTrips()
                  else
                    ...booking.upcomingTrips.asMap().entries.map((entry) {
                      final index = entry.key;
                      final t = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: HoverLift(
                          child: Hero(
                            // Unique per position so repeated/empty
                            // masterIds from the API can't duplicate
                            // Hero tags.
                            tag: 'dashboard-trip-$index-${t.masterId}',
                            child: TripCard(
                              trip: t,
                              onSelect: () {
                                context.read<BookingProvider>().selectTrip(t);
                                Navigator.of(context).pushNamed(
                                  AppConstants.routeSeatSelection,
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  SectionHeader(
                    eyebrowText: 'Activity',
                    title: 'Recent bookings',
                    actionLabel: 'See all',
                    onAction: () => setState(() => _tab = 2),
                  ),
                  const SizedBox(height: 14),
                  if (booking.recentBookings.isEmpty)
                    PremiumCard(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Lux.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(Icons.history_rounded,
                                size: 20, color: Lux.goldDeep),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'No bookings yet — search a trip to get started.',
                              style: Lux.body(context, size: 13.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    PremiumCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < booking.recentBookings.take(5).length;
                              i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 66),
                            _recentRow(booking.recentBookings[i]),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────

  Widget _heroHeader(BuildContext context, User? user, int unread) {
    return PremiumHeroHeader(
      greeting: 'Hello, ${_firstName(user)}',
      subtitle: 'Where shall we take you today?',
      eyebrow: 'MEMBERS TRAVEL',
      imageUrl: Imagery.highway,
      leading: _avatar(user),
      trailing: _bellButton(context, unread),
    );
  }

  Widget _avatar(User? user) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Lux.goldGradient,
        border: Border.all(color: Lux.ivory.withValues(alpha: 0.85), width: 2),
        boxShadow: Lux.goldGlow,
      ),
      child: Center(
        child: Text(
          _initial(user),
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Lux.ink,
          ),
        ),
      ),
    );
  }

  Widget _bellButton(BuildContext context, int unread) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () =>
            Navigator.of(context).pushNamed(AppConstants.routeSettings),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Lux.ivory,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _recentRow(dynamic b) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Lux.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.confirmation_number_rounded,
            size: 19, color: Lux.goldDeep),
      ),
      title: Text('Seat ${b.seatNumber}', style: Lux.title(context, size: 14.5)),
      subtitle: Text(Formatters.date(b.bookedAt),
          style: Lux.caption(context, size: 12)),
      trailing: Text(
        b.paymentReference,
        style: Lux.caption(context, size: 11),
      ),
    );
  }

  Widget _errorBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PremiumCard(
        key: const Key('dashboard_error_banner'),
        color: isDark ? Lux.darkCard : Lux.errorSoft,
        border: Border.all(color: Lux.error.withValues(alpha: 0.3)),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Lux.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _loadError!,
                style: Lux.body(context, size: 13).copyWith(color: Lux.error),
              ),
            ),
            IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  // ── User display helpers (null/empty-safe) ─────────────────────

  String _firstName(User? user) {
    final name = user?.customerName.trim() ?? '';
    if (name.isEmpty) return 'Traveller';
    return name.split(RegExp(r'\s+')).first;
  }

  String _initial(User? user) {
    final name = user?.customerName.trim() ?? '';
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  Widget _emptyTrips() {
    return PremiumCard(
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lux.gold.withValues(alpha: 0.1),
              border: Border.all(color: Lux.gold.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.route_outlined,
                size: 28, color: Lux.goldDeep),
          ),
          const SizedBox(height: 16),
          Text('No journeys on the horizon',
              style: Lux.headline(context, size: 18)),
          const SizedBox(height: 6),
          Text(
            'Run a search to see available departures and fares.',
            textAlign: TextAlign.center,
            style: Lux.body(context, size: 13),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => setState(() => _tab = 1),
            child: const Text('Search trips'),
          ),
        ],
      ),
    );
  }
}

// ── Metallic wallet card ──────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final User? user;
  final VoidCallback onTopUp;

  const _WalletCard({required this.user, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lux.rLg),
        gradient: Lux.metallic,
        boxShadow: Lux.floating,
        border: Border.all(color: Lux.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 17, color: Lux.goldBright),
              const SizedBox(width: 8),
              Text(
                'Wallet balance',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Lux.ivory.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                'SWIFT FLEET',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: Lux.gold.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedCounter(
            key: const Key('dashboard_wallet_balance'),
            value: user?.balance ?? 0,
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              height: 1,
              color: Lux.ivory,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  user?.customerName ?? 'Guest traveller',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: Lux.ivory.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _TopUpButton(onTap: onTopUp),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TopUpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: Lux.goldGradient,
            boxShadow: Lux.goldGlow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Lux.ink),
              const SizedBox(width: 5),
              Text(
                'Top up',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Lux.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onBookings;
  final VoidCallback onWallet;
  final VoidCallback onProfile;

  const _QuickActions({
    required this.onSearch,
    required this.onBookings,
    required this.onWallet,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          icon: Icons.search_rounded,
          label: 'Search',
          onTap: onSearch,
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.confirmation_number_rounded,
          label: 'Bookings',
          onTap: onBookings,
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
          onTap: onWallet,
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.person_rounded,
          label: 'Profile',
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: HoverLift(
        lift: 4,
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Lux.darkCard : Lux.cardLight,
              borderRadius: BorderRadius.circular(Lux.rMd),
              border: Border.all(
                color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
              ),
              boxShadow: Lux.soft,
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [
                        Lux.gold.withValues(alpha: 0.22),
                        Lux.gold.withValues(alpha: 0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Lux.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(icon, size: 19, color: Lux.goldDeep),
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lux.caption(context, size: 11.5)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 18, color: Lux.goldDeep),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Lux.ivory
                      : Lux.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lux.caption(context, size: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a tab body throws while building — keeps the nav bar and
/// background visible and offers a way back instead of a blank screen.
class _TabFallback extends StatelessWidget {
  final String tabName;
  final VoidCallback onRetry;

  const _TabFallback({required this.tabName, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppErrorView(
        key: const Key('dashboard_tab_fallback'),
        message: 'This section failed to load.',
        onRetry: onRetry,
      ),
    );
  }
}
