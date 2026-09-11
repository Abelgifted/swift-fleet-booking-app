import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';
import 'premium_image.dart';

/// Full-bleed dashboard hero that carries text over photography.
///
/// Contrast is guaranteed by three cooperating layers rather than by luck:
///   1. [Lux.heroScrim] — a dense band across the top where the greeting
///      sits, opening up mid-frame so the imagery still reads.
///   2. [Lux.heroTextShadow] — a layered halo on the type itself, so a
///      bright patch of sky can never wash the text out.
///   3. A near-opaque ivory on the primary line, with the secondary line
///      held at 92% instead of the 72% it used to be.
class PremiumHeroHeader extends StatelessWidget {
  /// Primary line, e.g. "Hello, Jane".
  final String greeting;

  /// Supporting line under the greeting.
  final String subtitle;

  /// Small gold label pinned to the bottom of the hero.
  final String eyebrow;

  /// Hero photograph. When null a navy gradient is used instead.
  final String? imageUrl;

  /// Optional leading widget (avatar).
  final Widget? leading;

  /// Optional trailing widget (notifications).
  final Widget? trailing;

  /// Expanded height of the app bar.
  final double height;

  /// Extra bottom padding, e.g. to clear a floating element.
  final double bottomPadding;

  const PremiumHeroHeader({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.eyebrow,
    this.imageUrl,
    this.leading,
    this.trailing,
    this.height = 244,
    this.bottomPadding = 20,
  });

  /// Playfair greeting, sized for a hero rather than a list row.
  static TextStyle greetingStyle({double size = 28}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: 0.2,
        color: Colors.white,
        shadows: Lux.heroTextShadow,
      );

  static TextStyle subtitleStyle() => GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: Colors.white.withValues(alpha: 0.92),
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 1)),
        ],
      );

  static TextStyle eyebrowStyle() => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.6,
        color: Lux.goldBright,
        shadows: const [
          Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 1)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: height,
      floating: true,
      pinned: false,
      stretch: true,
      backgroundColor: Lux.ink,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: Lux.inkGradient),
              )
            else
              PremiumImage(
                url: imageUrl!,
                fit: BoxFit.cover,
                overlayBuilder: (_) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: Lux.heroScrim),
                ),
              ),
            // Belt-and-braces: even if the image layer changes, the text
            // band keeps its own scrim.
            if (imageUrl != null)
              const Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xB3000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 13),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: greetingStyle(),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle(),
                              ),
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    const Spacer(),
                    Text(eyebrow, style: eyebrowStyle()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
