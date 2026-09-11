import 'dart:math';

import 'package:flutter/material.dart';

import '../config/premium_theme.dart';
import '../utils/formatters.dart';

/// Full-screen celebratory confetti burst (gold + ivory particles).
/// Pure CustomPainter — no external assets, works on every platform.
class ConfettiBurst extends StatefulWidget {
  final Duration duration;
  final Widget? child;

  const ConfettiBurst({super.key, this.duration = const Duration(seconds: 3), this.child});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Particle> _particles = _generate();

  List<_Particle> _generate() {
    final rng = Random(7);
    final palette = [
      Lux.goldBright,
      Lux.gold,
      Lux.goldDeep,
      Lux.ivory,
      Lux.success,
    ];
    return List.generate(120, (i) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 0.45 + rng.nextDouble() * 0.55;
      return _Particle(
        x: rng.nextDouble(),
        y: -rng.nextDouble() * 0.35,
        vx: cos(angle) * 0.05 * speed,
        vy: (0.28 + rng.nextDouble() * 0.5) * speed,
        size: 4 + rng.nextDouble() * 7,
        color: palette[rng.nextInt(palette.length)],
        spin: rng.nextDouble() * 2 * pi,
        spinRate: (rng.nextDouble() - 0.5) * 12,
        rect: rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.child != null) widget.child!,
        // IgnorePointer so celebration never blocks interaction.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(_particles, _c.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  final double x, y, vx, vy, size, spin, spinRate;
  final Color color;
  final bool rect;
  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.spin,
    required this.spinRate,
    required this.rect,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (final p in particles) {
      // Gravity-like fall with slight horizontal drift, easing out.
      final progress = Curves.easeOutQuad.transform(t.clamp(0, 1));
      final dx = (p.x + p.vx * progress * 4) * size.width;
      final dy = (p.y + p.vy * progress * 1.6) * size.height;
      if (dy > size.height + 20) continue;
      final angle = p.spin + p.spinRate * t;
      paint.color = p.color.withValues(
          alpha: (1 - t).clamp(0, 1) * 0.9 + 0.1);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle);
      if (p.rect) {
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * 0.55),
            paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// Golden success mark: drawing circle + check, then a soft glow.
class AnimatedSuccessMark extends StatefulWidget {
  final double size;

  const AnimatedSuccessMark({super.key, this.size = 110});

  @override
  State<AnimatedSuccessMark> createState() => _AnimatedSuccessMarkState();
}

class _AnimatedSuccessMarkState extends State<AnimatedSuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _SuccessMarkPainter(_c.value),
      ),
    );
  }
}

class _SuccessMarkPainter extends CustomPainter {
  final double t;
  _SuccessMarkPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.42;

    // Ring draws itself.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.055
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Lux.goldBright, Lux.goldDeep],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * Curves.easeOutCubic.transform(t.clamp(0.0, 0.65) / 0.65),
      false,
      ringPaint,
    );

    // Check mark draws after the ring.
    final checkT = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    if (checkT > 0) {
      final checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Lux.success;

      final start = Offset(center.dx - radius * 0.45, center.dy + radius * 0.02);
      final p1 = Offset(center.dx - radius * 0.12, center.dy + radius * 0.34);
      final p2 = Offset(center.dx + radius * 0.5, center.dy - radius * 0.3);

      final path = Path()..moveTo(start.dx, start.dy);
      if (checkT <= 0.5) {
        // First segment: short down-stroke.
        final end =
            Offset.lerp(start, p1, Curves.easeOut.transform(checkT / 0.5))!;
        path.lineTo(end.dx, end.dy);
      } else {
        // Second segment: long up-stroke.
        path.lineTo(p1.dx, p1.dy);
        final end = Offset.lerp(
            p1, p2, Curves.easeOut.transform((checkT - 0.5) / 0.5))!;
        path.lineTo(end.dx, end.dy);
      }
      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_SuccessMarkPainter oldDelegate) => oldDelegate.t != t;
}

/// Wallet balance counter: animates value changes with eased tween.
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        Formatters.currency(v, withDecimals: false),
        style: style,
      ),
    );
  }
}
