import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';
import 'premium_card.dart';
import 'premium_image.dart';
import 'responsive.dart';

/// Split-screen auth layout.
///
/// • tablet / desktop — editorial hero image on the left, form on the
///   right against a clean surface.
/// • phone — the same hero fills the screen behind a frosted glass card
///   holding the form.
class AuthShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String quote;
  final Widget form;
  final Widget? footer;

  const AuthShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.form,
    required this.quote,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    // The split only earns its keep once both panes have room to breathe;
    // below that the full-bleed hero + glass card reads better anyway.
    final wide = Breakpoints.width(context) >= 900;
    return Scaffold(
      body: wide ? _split(context) : _phone(context),
    );
  }

  // ── Phone: full-bleed hero + glass card ─────────────────────────
  Widget _phone(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PremiumImage(
          url: imageUrl,
          fit: BoxFit.cover,
          overlayBuilder: (_) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xCC0A1628), Color(0xF20A1628)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.1, 0.75],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Lux.gap,
              vertical: Lux.gap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const _Wordmark(compact: true),
                const SizedBox(height: 28),
                GlassCard(
                  blur: 22,
                  padding: const EdgeInsets.all(Lux.gap),
                  child: _formBlock(context, dark: true),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 18),
                  Center(child: footer!),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tablet / desktop: image left, form right ────────────────────
  Widget _split(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(flex: 5, child: _heroPanel()),
        Expanded(
          flex: 4,
          child: Container(
            color: isDark ? Lux.darkBg : Lux.ivory,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 36,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Wordmark(compact: false),
                        const SizedBox(height: 36),
                        _formBlock(context, dark: isDark),
                        if (footer != null) ...[
                          const SizedBox(height: 22),
                          Center(child: footer!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PremiumImage(
          url: imageUrl,
          fit: BoxFit.cover,
          overlayBuilder: (_) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xB30A1628), Color(0xF20A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const _GoldRule(),
              const SizedBox(height: 20),
              Text(
                quote,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 30,
                  height: 1.28,
                  fontWeight: FontWeight.w500,
                  color: Lux.ivory,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'SWIFT FLEET — PRIVATE COACH TRAVEL',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.6,
                  color: Lux.gold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formBlock(BuildContext context, {required bool dark}) {
    final headingColor = dark ? Lux.ivory : Lux.ink;
    final subColor = dark
        ? Lux.textOnDarkMuted
        : Lux.ink.withValues(alpha: 0.62);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: Lux.gold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: headingColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            height: 1.5,
            color: subColor,
          ),
        ),
        const SizedBox(height: 26),
        form,
      ],
    );
  }
}

/// Compact brand lockup used at the top of auth panels.
class _Wordmark extends StatelessWidget {
  final bool compact;

  const _Wordmark({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 42,
          height: compact ? 38 : 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: Lux.goldGradient,
          ),
          child: Icon(
            Icons.directions_bus_filled_rounded,
            size: compact ? 20 : 22,
            color: Lux.ink,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SWIFT FLEET',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Lux.ivory
                      : Lux.ink,
                ),
              ),
              Text(
                'Private coach travel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Lux.textOnDarkMuted
                      : Lux.ink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoldRule extends StatelessWidget {
  const _GoldRule();

  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 2,
        decoration: const BoxDecoration(gradient: Lux.goldGradient),
      );
}

/// "or continue with" separator.
class OrDivider extends StatelessWidget {
  final String label;

  const OrDivider({super.key, this.label = 'or continue with'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Lux.hairlineDark
        : Lux.ink.withValues(alpha: 0.12);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              letterSpacing: 0.8,
              color: isDark
                  ? Lux.textOnDarkMuted
                  : Lux.ink.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

/// Google + Apple provider buttons. Presentation only — the backing
/// OAuth flow is not wired yet, so they report that honestly.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _SocialTile(
            label: 'Google',
            icon: Icons.g_mobiledata_rounded,
            isDark: isDark,
            onTap: () => _notWired(context, 'Google'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialTile(
            label: 'Apple',
            icon: Icons.apple_rounded,
            isDark: isDark,
            onTap: () => _notWired(context, 'Apple'),
          ),
        ),
      ],
    );
  }

  void _notWired(BuildContext context, String provider) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-in is coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialTile({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      lift: 3,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Lux.rSm + 2),
          onTap: onTap,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lux.rSm + 2),
              border: Border.all(
                color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
              ),
              color: isDark
                  ? Lux.darkCard
                  : Colors.white.withValues(alpha: 0.7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isDark ? Lux.textOnDark : Lux.ink,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Lux.textOnDark : Lux.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
