import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';

/// Elegant text field: floating label, icon prefix, gold focus border.
///
/// Wraps Material's InputDecoration from the active [Lux] theme so the
/// same field style serves auth forms, passenger details and search.
class PremiumTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final int maxLines;

  const PremiumTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: isDark ? Lux.textOnDark : Lux.ink,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.suffix,
      ),
    );
  }
}
