import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';

/// Horizontal progress rail for the four-step booking flow:
/// Seats → Details → Payment → Confirmed.
class BookingSteps extends StatelessWidget {
  /// Zero-based index of the active step.
  final int current;

  static const List<String> _labels = [
    'Seats',
    'Details',
    'Payment',
    'Confirmed',
  ];

  const BookingSteps({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _node(context, i, isDark),
            if (i < _labels.length - 1)
              Expanded(
                child: Container(
                  height: 1.6,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: i < current
                        ? Lux.gold
                        : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _node(BuildContext context, int index, bool isDark) {
    final done = index < current;
    final active = index == current;
    final color = done || active
        ? Lux.gold
        : (isDark ? Lux.hairlineDark : Lux.hairlineLight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: active ? 26 : 22,
          height: active ? 26 : 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done || active ? Lux.goldGradient : null,
            color: done || active ? null : Colors.transparent,
            border: Border.all(color: color, width: 1.6),
            boxShadow: active ? Lux.goldGlow : null,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 13, color: Lux.ink)
                : Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? Lux.ink
                          : (isDark ? Lux.textOnDarkMuted : Lux.ink)
                              .withValues(alpha: 0.55),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _labels[index].toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: active
                ? Lux.goldDeep
                : (isDark ? Lux.textOnDarkMuted : Lux.ink)
                    .withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
