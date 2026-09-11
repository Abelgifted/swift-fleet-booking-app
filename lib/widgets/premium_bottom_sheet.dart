import 'package:flutter/material.dart';

import '../config/premium_theme.dart';

/// Elegant slide-up sheet: rounded 24 top, drag handle, safe padding.
Future<T?> showPremiumBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    // Paint the sheet surface via the route itself rather than an extra
    // DecoratedBox, so descendants (ListTile, SwitchListTile…) keep the
    // sheet's Material as their nearest Material ancestor.
    backgroundColor: isDark ? Lux.darkCard : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Lux.rLg)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}

/// Standard padding + optional title block used inside premium sheets.
class SheetBody extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;

  const SheetBody({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(Lux.gap, 0, Lux.gap, Lux.gap),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Lux.headline(context, size: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: Lux.body(context)),
              ],
              const SizedBox(height: Lux.gap),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
