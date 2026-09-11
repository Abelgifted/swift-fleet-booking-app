import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/imagery.dart';
import '../config/premium_theme.dart';
import '../models/location.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_image.dart';
import '../widgets/responsive.dart';

/// Origin → destination + date search with an animated swap.
class TripSearchScreen extends StatefulWidget {
  /// When true, renders without its own Scaffold (dashboard tab).
  final bool embedded;

  const TripSearchScreen({super.key, this.embedded = false});

  @override
  State<TripSearchScreen> createState() => _TripSearchScreenState();
}

class _TripSearchScreenState extends State<TripSearchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swapAnim;

  @override
  void initState() {
    super.initState();
    _swapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      if (booking.locations.isEmpty && !booking.catalogLoading) {
        booking.loadCatalog(authToken: context.read<AuthProvider>().token);
      }
    });
  }

  @override
  void dispose() {
    _swapAnim.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BookingProvider booking) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: booking.travelDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Lux.darkCard
                : Lux.cardLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Lux.rLg),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) booking.setTravelDate(picked);
  }

  Future<void> _search() async {
    HapticFeedback.mediumImpact();
    final booking = context.read<BookingProvider>();
    final ok = await booking.searchTrips(
      authToken: context.read<AuthProvider>().token,
    );
    if (!mounted) return;
    if (!ok) {
      // The durable explanation is the inline card under the button; this
      // is just immediate feedback with a one-tap retry.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(booking.searchError ?? 'Search failed'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Lux.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Lux.ivory,
              onPressed: _search,
            ),
          ),
        );
      return;
    }
    if (widget.embedded) {
      Navigator.of(context).pushNamed(AppConstants.routeTrips);
    } else {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeTrips);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Search Trips')),
      body: body,
    );
  }

  Widget _body() {
    final booking = context.watch<BookingProvider>();
    final isPhone = Breakpoints.isPhone(context);

    return RefreshIndicator(
      onRefresh: () =>
          booking.loadCatalog(authToken: context.read<AuthProvider>().token),
      child: Stack(
        children: [
          // Fixed hero band behind the scrolling card.
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 214,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PremiumImage(
                    url: Imagery.roadTrip,
                    fit: BoxFit.cover,
                    overlayBuilder: (_) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x990A1628), Color(0xE60A1628)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESERVE YOUR SEAT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.6,
                              color: Lux.goldBright,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Plan your journey',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: Lux.ivory,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose your origin, destination and date.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Lux.ivory.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 176),
              ContentShell(
                maxWidth: isPhone ? 720 : 860,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Route card ────────────────────────────────
                    PremiumCard(
                      padding: const EdgeInsets.all(18),
                      shadows: Lux.floating,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              _LocationField(
                                label: 'From',
                                icon: Icons.trip_origin_rounded,
                                accent: Lux.goldDeep,
                                value: booking.origin,
                                locations: booking.locations,
                                loading: booking.catalogLoading,
                                onChanged: booking.setOrigin,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  height: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              _LocationField(
                                label: 'To',
                                icon: Icons.location_on_rounded,
                                accent: Lux.ink,
                                value: booking.destination,
                                locations: booking.locations,
                                loading: booking.catalogLoading,
                                onChanged: booking.setDestination,
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: RotationTransition(
                                turns: Tween<double>(begin: 0, end: 0.5)
                                    .animate(_swapAnim),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _swapAnim.forward(from: 0);
                                      booking.swapOriginDestination();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: Lux.goldGradient,
                                        boxShadow: Lux.goldGlow,
                                      ),
                                      child: const Icon(
                                        Icons.swap_vert_rounded,
                                        size: 20,
                                        color: Lux.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Date card ────────────────────────────────
                    PremiumCard(
                      padding: EdgeInsets.zero,
                      onTap: () => _pickDate(booking),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Lux.gold.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: Lux.gold.withValues(alpha: 0.32),
                                ),
                              ),
                              child: const Icon(Icons.calendar_month_rounded,
                                  size: 20, color: Lux.goldDeep),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Travel date',
                                      style: Lux.caption(context, size: 11.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('EEEE, d MMMM yyyy')
                                        .format(booking.travelDate),
                                    style: Lux.title(context, size: 15),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Theme.of(context).dividerColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // The catalog is what populates the pickers. When it
                    // never arrived the search button stays disabled, so
                    // say why and offer a way out instead of leaving a
                    // dead button on screen.
                    if (booking.locations.isEmpty &&
                        !booking.catalogLoading &&
                        booking.errorMessage != null) ...[
                      _ApiErrorCard(
                        title: 'Cannot reach the booking service',
                        message: booking.errorMessage!,
                        onRetry: () => booking.loadCatalog(
                          authToken: context.read<AuthProvider>().token,
                        ),
                        onDiagnostics: () => Navigator.of(context)
                            .pushNamed(AppConstants.routeApiDiagnostics),
                      ),
                      const SizedBox(height: 20),
                    ],
                    PremiumButton(
                      label: 'Search available trips',
                      icon: Icons.search_rounded,
                      loading: booking.isSearching,
                      onPressed: booking.isSearching || !booking.canSearch
                          ? null
                          : _search,
                    ),
                    if (booking.searchError != null) ...[
                      const SizedBox(height: 18),
                      _ApiErrorCard(
                        title: 'Search failed',
                        message: booking.searchError!,
                        onRetry: _search,
                        onDiagnostics: () => Navigator.of(context)
                            .pushNamed(AppConstants.routeApiDiagnostics),
                      ),
                    ],
                    if (booking.locations.length < 2 &&
                        booking.errorMessage == null &&
                        !booking.catalogLoading) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Waiting for the location list from the server.',
                          textAlign: TextAlign.center,
                          style: Lux.caption(context, size: 12),
                        ),
                      ),
                    ] else if (!booking.canSearch &&
                        booking.locations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Pick a different origin and destination to search.',
                          textAlign: TextAlign.center,
                          style: Lux.caption(context, size: 12),
                        ),
                      ),
                    ],
                    // ── Popular routes ────────────────────────────
                    if (booking.routes.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      SectionHeader(
                        eyebrowText: 'Inspiration',
                        title: 'Popular routes',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: booking.routes.take(6).map((route) {
                          return _RouteChip(
                            label: route.label,
                            meta: Formatters.currency(route.fare,
                                withDecimals: false),
                            duration: Formatters.duration(route.estimatedDuration),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final origin = booking.locations.firstWhere(
                                (l) => l.id == route.sourceId,
                                orElse: () => booking.locations.firstWhere(
                                  (l) => l.name == route.sourceName,
                                  orElse: () => Location(
                                    id: route.sourceId,
                                    name: route.sourceName,
                                    code: '',
                                  ),
                                ),
                              );
                              final destination = booking.locations.firstWhere(
                                (l) => l.id == route.destinationId,
                                orElse: () => booking.locations.firstWhere(
                                  (l) => l.name == route.destinationName,
                                  orElse: () => Location(
                                    id: route.destinationId,
                                    name: route.destinationName,
                                    code: '',
                                  ),
                                ),
                              );
                              booking.setOrigin(origin);
                              booking.setDestination(destination);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating-label location selector.
class _LocationField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final Location? value;
  final List<Location> locations;
  final bool loading;
  final ValueChanged<Location?> onChanged;

  const _LocationField({
    required this.label,
    required this.icon,
    required this.accent,
    required this.value,
    required this.locations,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: Lux.caption(context, size: 10).copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                DropdownButtonHideUnderline(
                  child: DropdownButton<Location>(
                    value: locations.any((l) => l.id == value?.id)
                        ? locations.firstWhere((l) => l.id == value!.id)
                        : null,
                    hint: Text(
                      'Select ${label.toLowerCase()}',
                      style: Lux.body(context, size: 14.5)
                          .copyWith(color: Lux.caption(context).color),
                    ),
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(Lux.rMd),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Theme.of(context).dividerColor),
                    style: Lux.title(context, size: 15),
                    items: locations
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(l.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: Lux.title(context, size: 14.5)),
                                  ),
                                  if (l.code.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Lux.gold.withValues(alpha: 0.14),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        l.code,
                                        style: Lux.caption(context, size: 10)
                                            .copyWith(
                                          color: Lux.goldDeep,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 52), // room for the swap button
      ],
    );
  }
}

/// Popular-route shortcut chip.
class _RouteChip extends StatelessWidget {  final String label;
  final String meta;
  final String duration;
  final VoidCallback onTap;

  const _RouteChip({
    required this.label,
    required this.meta,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return HoverLift(
      lift: 3,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Lux.rMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lux.rMd),
              color: isDark ? Lux.darkCard : Lux.cardLight,
              border: Border.all(
                color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
              ),
              boxShadow: Lux.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Lux.title(context, size: 13)),
                const SizedBox(height: 3),
                Text(
                  '$meta  ·  $duration',
                  style: Lux.caption(context, size: 11).copyWith(
                    color: Lux.goldDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline failure card used for catalog and search errors.
///
/// Without the catalog the origin/destination pickers stay empty and the
/// search button stays disabled; a failed search leaves the user on this
/// screen. Both cases need to say *why* and offer a way forward rather than
/// leaving an inert button on screen.
class _ApiErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onDiagnostics;

  const _ApiErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
    this.onDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      color: Lux.errorSoft,
      border: Border.all(color: Lux.error.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_outlined, color: Lux.error, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Lux.title(context, size: 14.5)
                          .copyWith(color: Lux.error),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: Lux.body(context, size: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            ApiService.resolvedBaseUrl,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: Lux.goldDeep,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ),
              if (onDiagnostics != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Diagnostics',
                    icon: Icons.monitor_heart_outlined,
                    onPressed: onDiagnostics,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
