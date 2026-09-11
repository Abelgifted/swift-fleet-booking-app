import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/premium_theme.dart';

/// Shimmer skeleton block (placeholder while imagery/content loads).
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = const BorderRadius.all(Radius.circular(Lux.rSm)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Lux.hairlineDark.withValues(alpha: 0.5) : Lux.cream,
      highlightColor: isDark
          ? Lux.darkCard.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.85),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Lux.darkCard : Lux.cream,
          borderRadius: radius,
        ),
      ),
    );
  }
}

/// Full trip-card skeleton mirroring the premium trip card silhouette.
class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumSkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 130, radius: BorderRadius.circular(Lux.rMd)),
          const SizedBox(height: 16),
          ShimmerBox(height: 18, width: 180),
          const SizedBox(height: 10),
          ShimmerBox(height: 14, width: 240),
          const SizedBox(height: 16),
          Row(
            children: [
              ShimmerBox(height: 32, width: 110,
                  radius: BorderRadius.circular(999)),
              const Spacer(),
              ShimmerBox(height: 20, width: 90),
            ],
          ),
        ],
      ),
    );
  }
}

/// Generic skeleton card wrapper.
class PremiumSkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PremiumSkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Lux.gap),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? Lux.darkCard : Lux.cardLight,
        borderRadius: BorderRadius.circular(Lux.rLg),
        border: Border.all(
          color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
        ),
      ),
      child: child,
    );
  }
}

/// Minimal branded loader: a quietly pulsing gold monogram dot.
class LuxuryLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const LuxuryLoader({super.key, this.size = 34, this.color});

  @override
  State<LuxuryLoader> createState() => _LuxuryLoaderState();
}

class _LuxuryLoaderState extends State<LuxuryLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Lux.goldBright
            : Lux.gold);
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.4),
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.32,
            height: widget.size * 0.32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
