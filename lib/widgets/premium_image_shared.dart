import 'package:flutter/material.dart';

import '../config/premium_theme.dart';
import 'premium_loader.dart';

/// Shared pieces for the platform-specific [PremiumImage] builds.
///
/// Web uses Image.network (browser cache); Android/iOS use
/// CachedNetworkImage (disk cache). Both fade in over a shimmer and
/// collapse to a branded gradient when the network fails.

typedef PremiumImageOverlayBuilder = Widget Function(BuildContext context);

class PremiumImageFrame extends StatelessWidget {
  final Widget image;
  final double? height;
  final double? width;
  final BorderRadius radius;
  final PremiumImageOverlayBuilder? overlayBuilder;

  const PremiumImageFrame({
    super.key,
    required this.image,
    required this.radius,
    this.height,
    this.width,
    this.overlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            image,
            if (overlayBuilder != null)
              Positioned.fill(child: overlayBuilder!(context)),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder sized by the parent (StackFit.expand context).
Widget premiumPlaceholder(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => ShimmerBox(
        width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
        height: constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity,
        radius: BorderRadius.zero,
      ),
    );

/// Branded fallback: ink gradient + monogram, never a broken-image icon.
Widget premiumFallback(BuildContext context) => Container(
      decoration: const BoxDecoration(gradient: Lux.inkGradient),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_bus_filled_rounded,
        color: Lux.gold.withValues(alpha: 0.5),
        size: 42,
      ),
    );
