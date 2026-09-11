import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/imagery.dart';
import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/premium_image.dart';

/// Opening moment: full-bleed luxury coach imagery under an ink scrim,
/// a gold monogram that draws itself, then a determinate progress rule
/// while the cached session is restored.
///
/// Routes to the dashboard when a session exists, otherwise to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Minimum time the brand moment stays on screen.
  static const Duration _hold = Duration(milliseconds: 2200);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _hold);
    _controller.forward();
    // Defer session restore until after the first frame so the provider
    // never notifies during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      auth.initialize(),
      Future<void>.delayed(_hold),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      auth.isLoggedIn ? AppConstants.routeHome : AppConstants.routeLogin,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Staggered entrance: mark, then wordmark, then footer.
    final mark = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    final word = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
    );
    final foot = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: Lux.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-bleed hero ──────────────────────────────────────
          PremiumImage(
            url: Imagery.luxuryBus,
            fit: BoxFit.cover,
            overlayBuilder: (_) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE60A1628),
                    Color(0x990A1628),
                    Color(0xF20A1628),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Lux.gap),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // ── Gold monogram ────────────────────────────────
                  FadeTransition(
                    opacity: mark,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1).animate(mark),
                      child: const _BrandMark(),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // ── Wordmark ─────────────────────────────────────
                  FadeTransition(
                    opacity: word,
                    child: Column(
                      children: [
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 38,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            height: 1.1,
                            color: Lux.ivory,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _GoldRule(),
                        const SizedBox(height: 12),
                        Text(
                          'TRAVEL IN LUXURY',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.4,
                            color: Lux.goldBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  // ── Determinate progress rule ────────────────────
                  FadeTransition(
                    opacity: foot,
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _controller.value,
                              minHeight: 3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.16),
                              valueColor: const AlwaysStoppedAnimation(
                                Lux.goldBright,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Preparing your journey',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: Lux.textOnDarkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold-gradient rounded monogram with a slow sheen sweep.
class _BrandMark extends StatefulWidget {
  const _BrandMark();

  @override
  State<_BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<_BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: Lux.goldGradient,
        boxShadow: [
          BoxShadow(
            color: Lux.gold.withValues(alpha: 0.42),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.directions_bus_filled_rounded,
              size: 52,
              color: Lux.ink,
            ),
            // Travelling highlight.
            AnimatedBuilder(
              animation: _sheen,
              builder: (context, _) => Align(
                alignment: Alignment(-2.4 + _sheen.value * 4.8, 0),
                child: Transform.rotate(
                  angle: 0.42,
                  child: Container(
                    width: 26,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin gold rule with a centre diamond ornament.
class _GoldRule extends StatelessWidget {
  const _GoldRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 1,
          color: Lux.gold.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398,
          child: Container(width: 6, height: 6, color: Lux.gold),
        ),
        const SizedBox(width: 10),
        Container(
          width: 42,
          height: 1,
          color: Lux.gold.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}
