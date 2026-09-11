import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../models/booking.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_loader.dart';
import '../widgets/responsive.dart';

/// Past and upcoming bookings with a status filter, swipe-to-cancel and
/// pull-to-refresh.
class BookingHistoryScreen extends StatefulWidget {
  final bool embedded;

  const BookingHistoryScreen({super.key, this.embedded = false});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<BookingProvider>().loadHistory(
        authToken: context.read<AuthProvider>().token,
      );

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Release this seat?',
            style: Lux.headline(ctx, size: 20)),
        content: Text(
          'Seat ${booking.seatNumber} on booking ${booking.bookingId} '
          'will be released. Refunds follow the fare rules.',
          style: Lux.body(ctx, size: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Lux.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    final ok = await context.read<BookingProvider>().cancelBooking(
          booking.bookingId,
          authToken: context.read<AuthProvider>().token,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Booking cancelled'
            : context.read<BookingProvider>().errorMessage ??
                'Cancellation failed'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? Lux.success : Lux.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: body,
    );
  }

  Widget _body() {
    final booking = context.watch<BookingProvider>();
    final items = booking.filteredHistory;
    final isPhone = Breakpoints.isPhone(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ContentShell(
        maxWidth: isPhone ? 720 : 860,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Text('Your journeys',
                style: Lux.headline(context, size: 24)),
            const SizedBox(height: 4),
            Text(
              'Every booking, past and upcoming.',
              style: Lux.body(context, size: 13),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: booking.historyFilter == 'all',
                  onTap: () => booking.setHistoryFilter('all'),
                ),
                _FilterChip(
                  label: 'Upcoming',
                  selected: booking.historyFilter == 'upcoming',
                  onTap: () => booking.setHistoryFilter('upcoming'),
                ),
                _FilterChip(
                  label: 'Past',
                  selected: booking.historyFilter == 'past',
                  onTap: () => booking.setHistoryFilter('past'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (booking.historyLoading && booking.history.isEmpty)
              ...List.generate(3, (_) => const _BookingSkeleton())
            else if (items.isEmpty)
              _emptyState()
            else
              ...items.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Dismissible(
                      key: ValueKey('booking-${b.bookingId}-${b.seatNumber}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _cancel(b);
                        return false;
                      },
                      background: _swipeBackground(context),
                      child: _BookingCard(
                        booking: b,
                        onCancel: () => _cancel(b),
                        onTap: () {
                          if (b.tripDetails != null) {
                            context
                                .read<BookingProvider>()
                                .selectTrip(b.tripDetails);
                            Navigator.of(context).pushNamed(
                                AppConstants.routeSeatSelection);
                          }
                        },
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lux.rLg),
        color: Lux.error.withValues(alpha: 0.12),
        border: Border.all(color: Lux.error.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.cancel_outlined, color: Lux.error, size: 20),
          SizedBox(width: 8),
          Text('Cancel',
              style: TextStyle(
                  color: Lux.error, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return PremiumCard(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lux.gold.withValues(alpha: 0.1),
              border: Border.all(color: Lux.gold.withValues(alpha: 0.32)),
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                size: 30, color: Lux.goldDeep),
          ),
          const SizedBox(height: 18),
          Text('No bookings found', style: Lux.headline(context, size: 19)),
          const SizedBox(height: 6),
          Text(
            'Your journeys will appear here once you book.',
            textAlign: TextAlign.center,
            style: Lux.body(context, size: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: PremiumButton(
              label: 'Search trips',
              icon: Icons.search_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppConstants.routeSearch),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  const _BookingCard({
    required this.booking,
    required this.onCancel,
    required this.onTap,
  });

  /// [Booking] carries no status field, so upcoming vs past is derived
  /// from the departure date.
  static bool isUpcoming(Booking b) {
    final raw = b.tripDetails?.departureDate;
    if (raw == null || raw.isEmpty) return false;
    final date = DateTime.tryParse(raw);
    if (date == null) return false;
    final today = DateTime.now();
    return date.isAfter(DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final trip = booking.tripDetails;
    final upcoming = isUpcoming(booking);
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip == null
                        ? 'Booking ${booking.bookingId}'
                        : '${trip.source} → ${trip.destination}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lux.title(context, size: 15.5),
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge(
                  label: upcoming ? 'Upcoming' : 'Completed',
                  color: upcoming ? Lux.success : Lux.goldDeep,
                  icon: upcoming
                      ? Icons.schedule_rounded
                      : Icons.check_circle_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _meta(context, Icons.event_seat_rounded,
                    'Seat ${booking.seatNumber}'),
                const SizedBox(width: 16),
                Flexible(
                  child: _meta(
                    context,
                    Icons.schedule_rounded,
                    trip == null
                        ? Formatters.date(booking.bookedAt)
                        : '${Formatters.date(trip.departureDate)} · '
                            '${Formatters.time(trip.departureTime)}',
                  ),
                ),
              ],
            ),
            if (trip != null && trip.assetName.isNotEmpty) ...[
              const SizedBox(height: 8),
              _meta(context, Icons.directions_bus_filled_rounded,
                  '${trip.assetName}'
                  '${trip.vehicleRegNo.isEmpty ? '' : ' · ${trip.vehicleRegNo}'}'),
            ],
            const SizedBox(height: 8),
            Text('Ref: ${booking.paymentReference}',
                style: Lux.caption(context, size: 11)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'View trip',
                    onPressed: onTap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Lux.error,
                      side: BorderSide(
                          color: Lux.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Lux.caption(context).color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Lux.caption(context, size: 12),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? Lux.goldGradient : null,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
            ),
          ),
          child: Text(
            label,
            style: Lux.caption(context, size: 12.5).copyWith(
              color: selected
                  ? Lux.ink
                  : (isDark ? Lux.textOnDark : Lux.ink),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: PremiumSkeletonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 18, width: 190),
            SizedBox(height: 12),
            ShimmerBox(height: 13, width: 240),
            SizedBox(height: 18),
            ShimmerBox(height: 44),
          ],
        ),
      ),
    );
  }
}
