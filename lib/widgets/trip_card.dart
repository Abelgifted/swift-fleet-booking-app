import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/imagery.dart';
import '../config/premium_theme.dart';
import '../models/trip.dart';
import '../utils/formatters.dart';
import 'premium_button.dart';
import 'premium_card.dart';
import 'premium_image.dart';

/// Premium trip card: full-bleed vehicle imagery with a gradient scrim,
/// a route timeline, fare in editorial serif, seat-availability meter,
/// driver identity and a gold call to action.
///
/// Intentionally does **not** own a [Hero] — callers wrap it so the
/// transition tag can be scoped to the list position (the API can return
/// several departures sharing one `masterId`).
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onSelect;
  final bool compact;

  const TripCard({
    super.key,
    required this.trip,
    this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soldOut = trip.isSoldOut;
    final image = Imagery.forTrip('${trip.masterId}-${trip.assetName}');

    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: soldOut ? null : onSelect,
      shadows: Lux.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagery + overlay ────────────────────────────────────
          Stack(
            children: [
              PremiumImage(
                url: image,
                height: 128,
                width: double.infinity,
                radius: const BorderRadius.vertical(
                  top: Radius.circular(Lux.rLg),
                ),
                overlayBuilder: (_) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x22000000),
                        Color(0x66000000),
                        Color(0xCC0A1628),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _ClassBadge(label: _vehicleClass),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _SeatPill(
                  soldOut: soldOut,
                  available: trip.availableSeats,
                ),
              ),
              // Fare sits on the imagery, editorial style.
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        trip.assetName.isEmpty
                            ? 'Executive Coach'
                            : trip.assetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Text(
                      Formatters.currency(trip.fare, withDecimals: false),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Lux.goldBright,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteTimeline(source: trip.source, destination: trip.destination),
                const SizedBox(height: 14),
                _MetaRow(trip: trip),
                const SizedBox(height: 12),
                _SeatMeter(
                  available: trip.availableSeats,
                  total: trip.totalSeats,
                  soldOut: soldOut,
                ),
                if (trip.driverName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DriverRow(
                    name: trip.driverName,
                    rating: _rating,
                    isDark: isDark,
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(height: 16),
                  PremiumButton(
                    label: soldOut ? 'Sold out' : 'Select seats',
                    icon: soldOut
                        ? Icons.block_rounded
                        : Icons.event_seat_rounded,
                    onPressed: soldOut ? null : onSelect,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vehicle class, inferred from the asset name (no API field exists).
  String get _vehicleClass {
    final n = trip.assetName.toLowerCase();
    if (n.contains('vip')) return 'VIP';
    if (n.contains('lux') || n.contains('exec') || n.contains('premium')) {
      return 'Luxury';
    }
    return 'Standard';
  }

  /// Stable pseudo-rating derived from the driver name.
  ///
  /// NOTE: [Trip] carries no rating field, so this is a deterministic
  /// placeholder purely for presentation. Replace with the real value as
  /// soon as the API exposes one.
  double get _rating {
    final seed = trip.driverName.isEmpty ? trip.assetName : trip.driverName;
    if (seed.isEmpty) return 4.8;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) % 9973;
    }
    return 4.5 + (hash % 50) / 100;
  }
}

// ── Pieces ────────────────────────────────────────────────────────

class _RouteTimeline extends StatelessWidget {
  final String source;
  final String destination;

  const _RouteTimeline({required this.source, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _dot(Lux.gold),
            const SizedBox(height: 3),
            // Dotted connector.
            for (var i = 0; i < 3; i++)
              Container(
                width: 1.5,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                color: Theme.of(context).dividerColor,
              ),
            const SizedBox(height: 3),
            _dot(Lux.ink),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.isEmpty ? 'Origin' : source,
                style: Lux.title(context, size: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                destination.isEmpty ? 'Destination' : destination,
                style: Lux.title(context, size: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
          ],
        ),
      );
}

class _MetaRow extends StatelessWidget {
  final Trip trip;

  const _MetaRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final muted = Lux.caption(context);
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: muted.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${Formatters.date(trip.departureDate)} • '
            '${Formatters.time(trip.departureTime)}',
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trip.vehicleRegNo.isNotEmpty) ...[
          const SizedBox(width: 10),
          Icon(Icons.confirmation_number_outlined,
              size: 14, color: muted.color),
          const SizedBox(width: 4),
          Text(trip.vehicleRegNo, style: muted),
        ],
      ],
    );
  }
}

class _SeatMeter extends StatelessWidget {
  final int available;
  final int total;
  final bool soldOut;

  const _SeatMeter({
    required this.available,
    required this.total,
    required this.soldOut,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (available / total).clamp(0.0, 1.0);
    final color = soldOut
        ? Lux.error
        : available <= 5
            ? Lux.warning
            : Lux.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              soldOut ? 'Fully booked' : '$available of $total seats available',
              style: Lux.caption(context, size: 11.5),
            ),
            const Spacer(),
            if (!soldOut && available <= 5)
              Text(
                'Selling fast',
                style: Lux.caption(context, size: 11.5)
                    .copyWith(color: Lux.warning, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).dividerColor.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  final String name;
  final double rating;
  final bool isDark;

  const _DriverRow({
    required this.name,
    required this.rating,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Lux.goldGradient,
            border: Border.all(
              color: isDark ? Lux.hairlineDark : Lux.cardLight,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Lux.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: Lux.title(context, size: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('Professional chauffeur',
                  style: Lux.caption(context, size: 11)),
            ],
          ),
        ),
        Icon(Icons.star_rounded, size: 15, color: Lux.gold),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Lux.goldDeep,
          ),
        ),
      ],
    );
  }
}

class _ClassBadge extends StatelessWidget {
  final String label;

  const _ClassBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Lux.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 12, color: Lux.goldBright),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Lux.goldBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatPill extends StatelessWidget {
  final bool soldOut;
  final int available;

  const _SeatPill({required this.soldOut, required this.available});

  @override
  Widget build(BuildContext context) {
    final color = soldOut ? Lux.error : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_seat_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            soldOut ? 'Sold out' : '$available left',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
