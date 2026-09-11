import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/booking_provider.dart';
import '../utils/analytics.dart';
import '../utils/formatters.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/premium_card.dart';
import '../widgets/responsive.dart';

/// Spending and booking trends over the last six months.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      if (booking.history.isEmpty && !booking.historyLoading) {
        booking.loadHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final months = AnalyticsService.lastMonths(6);
    final fare = booking.selectedTrip?.fare ??
        (booking.allTrips.isNotEmpty ? booking.allTrips.first.fare : 5000.0);
    final spend = AnalyticsService.monthlySpend(
      transactions: booking.transactions,
      bookings: booking.history.isEmpty
          ? booking.recentBookings
          : booking.history,
      farePerBooking: fare,
    );
    final counts = AnalyticsService.monthlyBookings(
      bookings: booking.history.isEmpty
          ? booking.recentBookings
          : booking.history,
    );
    final totalTrips = counts.fold(0, (a, b) => a + b);
    final isPhone = Breakpoints.isPhone(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Travel insights')),
      body: RefreshIndicator(
        onRefresh: () => booking.loadHistory(),
        child: ContentShell(
          maxWidth: isPhone ? 720 : 900,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // ── Headline ──────────────────────────────────────────
              Text('Your last six months',
                  style: Lux.headline(context, size: 25)),
              const SizedBox(height: 6),
              Text(
                'A look at how you travel and what you spend.',
                style: Lux.body(context, size: 13),
              ),
              const SizedBox(height: 22),
              // ── Stats ─────────────────────────────────────────────
              Row(
                children: [
                  _StatCard(
                    value: '$totalTrips',
                    label: 'Trips taken',
                    icon: Icons.route_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: Formatters.currency(
                        AnalyticsService.totalSpend(spend),
                        withDecimals: false),
                    label: 'Total spend',
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: Formatters.currency(AnalyticsService.average(spend),
                        withDecimals: false),
                    label: 'Monthly avg',
                    icon: Icons.trending_up_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // ── Spend chart ───────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow('Spending'),
                              const SizedBox(height: 6),
                              Text('Fare spend by month',
                                  style: Lux.headline(context, size: 19)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Lux.gold.withValues(alpha: 0.12),
                            border: Border.all(
                                color: Lux.gold.withValues(alpha: 0.28)),
                          ),
                          child: const Icon(Icons.bar_chart_rounded,
                              size: 18, color: Lux.goldDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SpendChart(monthly: spend, months: months),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Trend chart ───────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow('Frequency'),
                              const SizedBox(height: 6),
                              Text('Journeys per month',
                                  style: Lux.headline(context, size: 19)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Lux.gold.withValues(alpha: 0.12),
                            border: Border.all(
                                color: Lux.gold.withValues(alpha: 0.28)),
                          ),
                          child: const Icon(Icons.show_chart_rounded,
                              size: 18, color: Lux.goldDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    BookingTrendChart(monthly: counts, months: months),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ── Footnote ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: isDark
                          ? Lux.textOnDarkMuted
                          : Lux.ink.withValues(alpha: 0.45)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Spend is derived from your wallet ledger where '
                      'available, otherwise estimated from your booking '
                      'history at the current fare.',
                      style: Lux.caption(context, size: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 17, color: Lux.goldDeep),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Lux.ivory : Lux.ink,
              ),
            ),
            const SizedBox(height: 3),
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
    );
  }
}
