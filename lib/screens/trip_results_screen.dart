import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/feedback.dart';
import '../widgets/premium_bottom_sheet.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_loader.dart';
import '../widgets/responsive.dart';
import '../widgets/trip_card.dart';

/// Results list with sort / fare / sold-out filters and skeleton loading.
class TripResultsScreen extends StatelessWidget {
  const TripResultsScreen({super.key});

  Future<void> _refresh(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return context.read<BookingProvider>().refresh(authToken: auth.token);
  }

  void _openFilters(BuildContext context) {
    final booking = context.read<BookingProvider>();
    HapticFeedback.selectionClick();
    showPremiumBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: booking,
        child: const _FilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final hasRoute = booking.origin != null && booking.destination != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasRoute ? 'Available trips' : 'Trip Results'),
        actions: [
          IconButton(
            tooltip: 'Sort and filter',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _openFilters(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<ConnectivityService>(
            builder: (_, connectivity, _) => connectivity.isOnline
                ? const SizedBox.shrink()
                : const OfflineBar(),
          ),
          if (hasRoute) _RouteSummary(booking: booking),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: _content(context, booking),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, BookingProvider booking) {
    final isPhone = Breakpoints.isPhone(context);
    final pad = EdgeInsets.fromLTRB(16, 16, 16, 28);

    // First search → shimmer skeletons, never a spinner.
    if (booking.isSearching && booking.allTrips.isEmpty) {
      return ListView.builder(
        padding: pad,
        itemCount: 3,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: TripCardSkeleton(),
        ),
      );
    }

    final failure = booking.searchError ?? booking.errorMessage;
    if (failure != null && booking.allTrips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 48),
        children: [
          AppErrorView(
            message: failure,
            onRetry: () => _refresh(context),
          ),
        ],
      );
    }

    final trips = booking.trips;
    if (trips.isEmpty) {
      // The server explains *why* a search came back empty (for example
      // "No trips available for the selected route and date"). Show its
      // words rather than a generic message, and give the user a way
      // forward instead of a dead end.
      final notice = booking.searchNotice;
      final filteredOut = booking.allTrips.isNotEmpty;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Lux.gold.withValues(alpha: 0.1),
                border: Border.all(color: Lux.gold.withValues(alpha: 0.32)),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: Lux.goldDeep),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            filteredOut ? 'No departures match' : 'No departures found',
            textAlign: TextAlign.center,
            style: Lux.headline(context, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            filteredOut
                ? 'Your filters hid every departure. Relax them to see '
                    'more options.'
                : notice ??
                    'There are no scheduled departures for '
                        '${booking.origin?.name ?? 'this route'} → '
                        '${booking.destination?.name ?? 'this destination'} '
                        'on ${Formatters.date(booking.travelDateIso)}.',
            textAlign: TextAlign.center,
            style: Lux.body(context, size: 13.5),
          ),
          const SizedBox(height: 22),
          Center(
            child: GhostButton(
              label: 'Search again',
              icon: Icons.refresh_rounded,
              onPressed: () => _refresh(context),
            ),
          ),
          if (filteredOut) ...[
            const SizedBox(height: 10),
            Center(
              child: GhostButton(
                label: 'Clear filters',
                icon: Icons.filter_alt_off_rounded,
                onPressed: booking.clearFilters,
              ),
            ),
          ],
        ],
      );
    }

    return ContentShell(
      maxWidth: isPhone ? 720 : 860,
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result count + quick sort.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trips.length} departure${trips.length == 1 ? '' : 's'}',
                      style: Lux.title(context, size: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.date(booking.travelDateIso),
                      style: Lux.caption(context, size: 12),
                    ),
                  ],
                ),
              ),
              _SortPill(
                label: _sortLabel(booking.sort),
                onTap: () => _openFilters(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Cards.
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: trips.length,
            itemBuilder: (context, i) {
              final trip = trips[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HoverLift(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Hero(
                      // Index-scoped so repeated/empty masterIds from the
                      // API can't produce duplicate Hero tags.
                      tag: 'results-trip-$i-${trip.masterId}',
                      child: TripCard(
                        key: ValueKey('results-trip-$i-${trip.masterId}'),
                        trip: trip,
                        onSelect: () {
                          context.read<BookingProvider>().selectTrip(trip);
                          Navigator.of(context)
                              .pushNamed(AppConstants.routeSeatSelection);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _sortLabel(TripSort sort) {
    switch (sort) {
      case TripSort.earliest:
        return 'Earliest';
      case TripSort.cheapest:
        return 'Cheapest';
      case TripSort.mostSeats:
        return 'Most seats';
    }
  }
}

/// Origin → destination band with the travel date.
class _RouteSummary extends StatelessWidget {
  final BookingProvider booking;

  const _RouteSummary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        gradient: isDark ? Lux.inkGradient : Lux.goldGradient,
        boxShadow: Lux.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: _endpoint(context, booking.origin!.name, 'From'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward_rounded,
                size: 18,
                color: (isDark ? Lux.goldBright : Lux.ink)
                    .withValues(alpha: 0.75)),
          ),
          Expanded(
            child: _endpoint(
              context,
              booking.destination!.name,
              'To',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpoint(BuildContext context, String name, String label,
      {bool alignEnd = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Lux.ivory : Lux.ink;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: color.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.playfairDisplay(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SortPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SortPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Lux.gold.withValues(alpha: 0.45)),
            color: Lux.gold.withValues(alpha: 0.09),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort_rounded, size: 15, color: Lux.goldDeep),
              const SizedBox(width: 6),
              Text(
                label,
                style: Lux.caption(context, size: 12).copyWith(
                  color: Lux.goldDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with sort chips, a max-fare slider and a sold-out toggle.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final maxFare = booking.allTrips.isEmpty
        ? 50000.0
        : booking.allTrips
            .map((t) => t.fare)
            .reduce((a, b) => a > b ? a : b);

    return SheetBody(
      title: 'Refine results',
      subtitle: 'Narrow the list to exactly what you need.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SORT BY',
              style: Lux.caption(context, size: 10).copyWith(
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoicePill(
                label: 'Earliest',
                icon: Icons.schedule_rounded,
                selected: booking.sort == TripSort.earliest,
                onTap: () => booking.setSort(TripSort.earliest),
              ),
              _ChoicePill(
                label: 'Cheapest',
                icon: Icons.sell_outlined,
                selected: booking.sort == TripSort.cheapest,
                onTap: () => booking.setSort(TripSort.cheapest),
              ),
              _ChoicePill(
                label: 'Most seats',
                icon: Icons.event_seat_rounded,
                selected: booking.sort == TripSort.mostSeats,
                onTap: () => booking.setSort(TripSort.mostSeats),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('MAXIMUM FARE',
                  style: Lux.caption(context, size: 10).copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              Text(
                booking.maxFare == null
                    ? 'Any'
                    : Formatters.currency(booking.maxFare, withDecimals: false),
                style: Lux.title(context, size: 14)
                    .copyWith(color: Lux.goldDeep),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Lux.gold,
              inactiveTrackColor: Lux.gold.withValues(alpha: 0.2),
              thumbColor: Lux.goldBright,
              overlayColor: Lux.gold.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: (booking.maxFare ?? maxFare).clamp(0, maxFare),
              min: 0,
              max: maxFare,
              divisions: 20,
              label: booking.maxFare == null
                  ? 'Any'
                  : Formatters.currency(booking.maxFare, withDecimals: false),
              onChanged: (v) =>
                  booking.setMaxFare(v >= maxFare ? null : v),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Hide fully booked',
                style: Lux.title(context, size: 14.5)),
            subtitle: Text('Only show departures with seats left',
                style: Lux.caption(context, size: 12)),
            value: booking.hideSoldOut,
            onChanged: booking.setHideSoldOut,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Reset',
                  onPressed: booking.clearFilters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumButton(
                  label: 'Apply',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? Lux.goldGradient : null,
            color: selected
                ? null
                : (isDark ? Lux.darkCard : Colors.transparent),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected
                      ? Lux.ink
                      : (isDark ? Lux.textOnDarkMuted : Lux.ink)),
              const SizedBox(width: 7),
              Text(
                label,
                style: Lux.caption(context, size: 12.5).copyWith(
                  color: selected
                      ? Lux.ink
                      : (isDark ? Lux.textOnDark : Lux.ink),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
