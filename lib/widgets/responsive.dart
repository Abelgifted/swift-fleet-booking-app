import 'package:flutter/material.dart';

import '../config/premium_theme.dart';

/// Width classes used to adapt layouts across phone, tablet and desktop.
abstract final class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1024;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => width(context) < tablet;

  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) => width(context) >= desktop;

  /// True when a mouse is likely present — enables hover affordances.
  static bool hasPointer(BuildContext context) =>
      MediaQuery.maybeOf(context)?.navigationMode ==
          NavigationMode.traditional ||
      !isPhone(context);
}

/// Picks a layout for the current width class.
///
/// Falls back gracefully: a missing `desktop` reuses `tablet`, a missing
/// `tablet` reuses `phone`.
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final w = Breakpoints.width(context);
    if (w >= Breakpoints.desktop) {
      return desktop ?? tablet ?? phone;
    }
    if (w >= Breakpoints.tablet) {
      return tablet ?? desktop ?? phone;
    }
    return phone;
  }
}

/// Constrains and centres content so long-form pages stay readable on
/// desktop widths instead of stretching edge to edge.
class ContentShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ContentShell({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.all(Lux.gap),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Adds a subtle lift, gold halo and pointer cursor on hover — the
/// desktop/web affordance that makes cards feel interactive.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double lift;
  final bool enabled;

  const HoverLift({
    super.key,
    required this.child,
    this.lift = 6,
    this.enabled = true,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: _hovered ? Offset(0, -widget.lift / 100) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          scale: _hovered ? 1.012 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A gentle fade + rise used to stagger content on first paint.
class EntranceFade extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double offsetY;

  const EntranceFade({
    super.key,
    required this.child,
    required this.animation,
    this.offsetY = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, offsetY),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
