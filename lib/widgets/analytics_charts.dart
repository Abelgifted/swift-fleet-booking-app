import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/premium_theme.dart';
import '../utils/analytics.dart';
import '../utils/formatters.dart';

/// Monthly spending bars — hand-rolled, gold-gradient, no extra deps.
class SpendChart extends StatelessWidget {
  final List<double> monthly;
  final List<DateTime> months;

  const SpendChart({
    super.key,
    required this.monthly,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final max = monthly.fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 176,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < monthly.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (monthly[i] > 0)
                          Text(
                            Formatters.currency(monthly[i], withDecimals: false),
                            style: Lux.caption(context, size: 8.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          height: max <= 0 ? 8 : 10 + 118 * (monthly[i] / max),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: LinearGradient(
                              colors: monthly[i] > 0
                                  ? [Lux.goldBright, Lux.goldDeep]
                                  : [
                                      Lux.hairlineLight,
                                      Lux.hairlineLight,
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            boxShadow: monthly[i] > 0
                                ? [
                                    BoxShadow(
                                      color: Lux.gold.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM').format(months[i]),
                          style: Lux.caption(context, size: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: Theme.of(context).dividerColor, height: 1),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat(
              context,
              'Total spend',
              Formatters.currency(AnalyticsService.totalSpend(monthly),
                  withDecimals: false),
              isDark,
            ),
            Container(
              width: 1,
              height: 30,
              color: Theme.of(context).dividerColor,
            ),
            _stat(
              context,
              'Monthly average',
              Formatters.currency(AnalyticsService.average(monthly),
                  withDecimals: false),
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: Lux.caption(context, size: 10.5)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Lux.goldBright : Lux.ink,
          ),
        ),
      ],
    );
  }
}

/// Booking-count trend line (smooth curve + gold nodes).
class BookingTrendChart extends StatelessWidget {
  final List<int> monthly;
  final List<DateTime> months;

  const BookingTrendChart({
    super.key,
    required this.monthly,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final max = monthly.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 158,
      child: CustomPaint(
        painter: _TrendPainter(
          values: monthly,
          max: max <= 0 ? 1 : max,
          line: Lux.gold,
          dot: Lux.goldBright,
          labelColor: Lux.caption(context).color ?? Lux.goldDeep,
          fillTop: Lux.gold.withValues(alpha: 0.22),
          fillBottom: Lux.gold.withValues(alpha: 0.0),
        ),
        child: Row(
          children: [
            for (var i = 0; i < monthly.length; i++)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      DateFormat('MMM').format(months[i]),
                      style: Lux.caption(context, size: 10.5),
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

class _TrendPainter extends CustomPainter {
  final List<int> values;
  final int max;
  final Color line;
  final Color dot;
  final Color labelColor;
  final Color fillTop;
  final Color fillBottom;

  _TrendPainter({
    required this.values,
    required this.max,
    required this.line,
    required this.dot,
    required this.labelColor,
    required this.fillTop,
    required this.fillBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padTop = 20.0;
    const padBottom = 26.0;
    final h = size.height - padTop - padBottom;

    Offset point(int i) {
      final x =
          size.width * (values.length == 1 ? 0.5 : i / (values.length - 1));
      final y = padTop + h * (1 - values[i] / max);
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prev = point(i - 1);
        path.cubicTo(
          (prev.dx + p.dx) / 2, prev.dy,
          (prev.dx + p.dx) / 2, p.dy,
          p.dx, p.dy,
        );
      }
    }

    // Soft area fill under the curve.
    final area = Path.from(path)
      ..lineTo(size.width, size.height - padBottom)
      ..lineTo(0, size.height - padBottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [fillTop, fillBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      canvas.drawCircle(p, 5.5, Paint()..color = dot);
      canvas.drawCircle(p, 2.4, Paint()..color = Lux.ink);
      textPainter.text = TextSpan(
        text: '${values[i]}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: labelColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, p + const Offset(-4, -22));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.line != line || old.dot != dot;
}
