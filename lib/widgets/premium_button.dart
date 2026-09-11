import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';

/// Gold-gradient primary CTA with press scale, haptics and an elegant
/// shimmer sweep while [loading].
class PremiumButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final Color? foreground;

  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.foreground,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _shine.repeat();
  }

  @override
  void didUpdateWidget(covariant PremiumButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !_shine.isAnimating) {
      _shine.repeat();
    } else if (!widget.loading) {
      _shine.stop();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !_enabled;
    final fg = widget.foreground ?? Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: disabled ? 0.55 : 1,
          child: Container(
            height: 56,
            width: widget.expanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lux.rSm + 2),
              gradient: Lux.goldGradient,
              boxShadow: disabled ? null : Lux.goldGlow,
            ),
            child: Stack(
              children: [
                // Moving sheen (always drifting slowly while visible).
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Lux.rSm + 2),
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (context, _) {
                        final t = _shine.isAnimating
                            ? _shine.value
                            : 0.25;
                        return Align(
                          alignment: Alignment(-2 + t * 4, 0),
                          child: Transform.rotate(
                            angle: 0.5,
                            child: Container(
                              width: 56,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.loading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: 10),
                      ],
                      // Flexible + ellipsis so a long label or a wider
                      // fallback font can never overflow the button.
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
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

/// Quiet, bordered secondary action.
class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? foreground;

  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = foreground ?? (isDark ? Lux.goldBright : Lux.ink);
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: fg),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed?.call();
        },
        icon: icon == null ? null : Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
