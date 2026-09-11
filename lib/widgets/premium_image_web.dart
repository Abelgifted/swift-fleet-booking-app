import 'package:flutter/material.dart';

import 'premium_image_shared.dart';

/// Web build: browser-cached network image with fade-in + shimmer.
class PremiumImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius radius;
  final PremiumImageOverlayBuilder? overlayBuilder;

  const PremiumImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.radius = BorderRadius.zero,
    this.overlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumImageFrame(
      height: height,
      width: width,
      radius: radius,
      overlayBuilder: overlayBuilder,
      image: Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress != null &&
              progress.expectedTotalBytes != null &&
              progress.cumulativeBytesLoaded ==
                  progress.expectedTotalBytes) {
            return child;
          }
          return premiumPlaceholder(context);
        },
        errorBuilder: (context, error, stack) => premiumFallback(context),
      ),
    );
  }
}
