import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/premium_theme.dart';
import 'premium_image_shared.dart';

/// Native build: disk-cached network image with fade-in + shimmer.
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
      image: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 350),
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => LayoutBuilder(
          builder: (context, constraints) => Container(color: Lux.cream),
        ),
        errorWidget: (_, _, _) => premiumFallback(context),
      ),
    );
  }
}
