import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';

/// Elevated surface with hairline border + layered soft shadow.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? color;
  final Border? border;
  final BorderRadius? radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Lux.gap),
    this.margin,
    this.gradient,
    this.color,
    this.border,
    this.radius,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = radius ?? BorderRadius.circular(Lux.rLg);
    final effective = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (isDark ? Lux.darkCard : Lux.cardLight))
            : null,
        gradient: gradient,
        borderRadius: shape,
        border: border ??
            Border.all(
              color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
              width: 1,
            ),
        boxShadow: shadows ?? Lux.soft,
      ),
      // A transparent Material sits between this DecoratedBox and the child so
      // that any ListTile/SwitchListTile inside a PremiumCard can still paint
      // its background and ink splashes on a Material ancestor (otherwise
      // Flutter raises "ListTile background color or ink splashes may be
      // invisible" in debug builds).
      child: Material(
        type: MaterialType.transparency,
        textStyle: DefaultTextStyle.of(context).style,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return effective;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: shape,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: effective,
      ),
    );
  }
}

/// Frosted-glass surface (backdrop blur) for overlays on imagery.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final double blur;
  final Color? fill;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Lux.gap),
    this.radius = const BorderRadius.all(Radius.circular(Lux.rLg)),
    this.blur = 18,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill ??
                (isDark
                    ? Lux.darkSurface.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.78)),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Uppercase gold eyebrow label (luxury section marker).
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: color ?? (Theme.of(context).brightness == Brightness.dark
            ? Lux.goldBright
            : Lux.goldDeep),
      ),
    );
  }
}

/// Serif section title with optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrowText;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrowText,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrowText != null) ...[
                Eyebrow(eyebrowText!),
                const SizedBox(height: 6),
              ],
              Text(title,
                  style: Lux.headline(context, size: 22)),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Compact pill badge for statuses (Confirmed, VIP, Cancelled…).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin gold divider with optional center ornament.
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Lux.gold,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
