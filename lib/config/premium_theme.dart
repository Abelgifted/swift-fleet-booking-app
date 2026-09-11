import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────────
///  PREMIUM DESIGN SYSTEM — "Swift Fleet Noir"
///
///  A luxury travel language: deep navy ink, champagne gold, ivory
///  surfaces, editorial serif headlines (Playfair Display) over a
///  precise geometric sans (Inter).
/// ─────────────────────────────────────────────────────────────────
abstract final class Lux {
  // ── Ink (brand navy) ────────────────────────────────────────────
  static const Color ink = Color(0xFF0A1628);
  static const Color inkElevated = Color(0xFF12203A);
  static const Color inkSoft = Color(0xFF1C2E4A);

  // ── Champagne gold ──────────────────────────────────────────────
  static const Color gold = Color(0xFFC9A96E);
  static const Color goldBright = Color(0xFFE5C88A);
  static const Color goldDeep = Color(0xFFA8874B);

  // ── Ivory / cream surfaces ──────────────────────────────────────
  static const Color ivory = Color(0xFFFAF8F3);
  static const Color cream = Color(0xFFF5F1E8);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color hairlineLight = Color(0xFFE7E0D2);

  // ── Premium dark palette ────────────────────────────────────────
  static const Color darkBg = Color(0xFF0A0F1A);
  static const Color darkSurface = Color(0xFF101828);
  static const Color darkCard = Color(0xFF16202F);
  static const Color hairlineDark = Color(0xFF24314A);

  // ── Semantics ───────────────────────────────────────────────────
  static const Color success = Color(0xFF2D6A4F);
  static const Color successSoft = Color(0xFFE7F2EC);
  static const Color error = Color(0xFFC1121F);
  static const Color errorSoft = Color(0xFFFBEBEC);
  static const Color warning = Color(0xFFB7791F);

  // ── Text ────────────────────────────────────────────────────────
  static const Color textOnDark = Color(0xFFF5F1E8);
  static const Color textOnDarkMuted = Color(0xFF9AA7BD);

  // ── Seat map ────────────────────────────────────────────────────
  static const Color seatAvailable = Color(0xFFFBF7EE);
  static const Color seatSelected = gold;
  static const Color seatBooked = Color(0xFFB4AFA3);
  static const Color seatHeld = Color(0xFFE8D9B5);
  static const Color driverSeat = Color(0xFFE7E2D6);

  // ── Gradients ───────────────────────────────────────────────────
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldBright, gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient inkGradient = LinearGradient(
    colors: [ink, inkSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlay = LinearGradient(
    colors: [Colors.transparent, Colors.black54, Color(0xE6000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 0.7, 1.0],
  );

  /// Scrim for heroes that carry text at the **top** as well as the bottom.
  ///
  /// [heroOverlay] is fully transparent for its first 35%, which leaves a
  /// greeting rendered straight onto the photograph. This variant keeps a
  /// dense band across the top (where the greeting sits), opens up through
  /// the middle so the imagery still reads, and closes down again at the
  /// bottom for the footer row.
  static const LinearGradient heroScrim = LinearGradient(
    colors: [
      Color(0xD9000000), // 85% — greeting band
      Color(0xA6000000), // 65%
      Color(0x40000000), // 25% — let the photo breathe
      Color(0xCC000000), // 80% — footer band
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.30, 0.58, 1.0],
  );

  /// Soft halo that keeps light type legible over any photograph, even the
  /// bright patch of a sky. Layered so it reads as depth, not as a box.
  static const List<Shadow> heroTextShadow = [
    Shadow(color: Color(0xB3000000), blurRadius: 20, offset: Offset(0, 2)),
    Shadow(color: Color(0x8C000000), blurRadius: 8, offset: Offset(0, 1)),
    Shadow(color: Color(0x59000000), blurRadius: 3),
  ];

  /// Metallic sheen used on wallet / membership cards.
  static const LinearGradient metallic = LinearGradient(
    colors: [
      Color(0xFF14263F),
      Color(0xFF0A1628),
      Color(0xFF3A2F1E),
      Color(0xFFC9A96E),
      Color(0xFF0A1628),
    ],
    stops: [0.0, 0.35, 0.55, 0.8, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Radii ───────────────────────────────────────────────────────
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 24;
  static const double rXl = 32;

  // ── Spacing ─────────────────────────────────────────────────────
  static const double gap = 24;

  // ── Shadows ─────────────────────────────────────────────────────
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: ink.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: ink.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get goldGlow => [
        BoxShadow(
          color: gold.withValues(alpha: 0.35),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
          color: ink.withValues(alpha: 0.16),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  // ── Typography ──────────────────────────────────────────────────
  /// Editorial serif for display headlines.
  static TextStyle display(BuildContext context, {double size = 40}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.1,
        color: _onSurface(context),
      );

  static TextStyle headline(BuildContext context, {double size = 24}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
        color: _onSurface(context),
      );

  static TextStyle title(BuildContext context, {double size = 17}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: _onSurface(context),
      );

  static TextStyle body(BuildContext context, {double size = 14}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: _onSurface(context).withValues(alpha: 0.85),
      );

  static TextStyle caption(BuildContext context, {double size = 12}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: _onSurface(context).withValues(alpha: 0.6),
      );

  /// Small uppercase label with wide tracking (luxury detail).
  static TextStyle eyebrow(BuildContext context,
      {Color? color, double size = 11}) {
    final base = GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.2,
    );
    return base.copyWith(color: color ?? gold);
  }

  static Color _onSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textOnDark : ink;

  // ── Theme assembly ──────────────────────────────────────────────
  static ThemeData light() => _base(Brightness.light).copyWith(
        scaffoldBackgroundColor: ivory,
        cardTheme: _card(cardLight, hairlineLight),
        appBarTheme: AppBarTheme(
          backgroundColor: ivory,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        inputDecorationTheme: _input(
          fill: Colors.white,
          border: hairlineLight,
          focused: gold,
        ),
      );

  static ThemeData dark() => _base(Brightness.dark).copyWith(
        scaffoldBackgroundColor: darkBg,
        cardTheme: _card(darkCard, hairlineDark),
        appBarTheme: AppBarTheme(
          backgroundColor: darkBg,
          foregroundColor: textOnDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textOnDark,
          ),
        ),
        inputDecorationTheme: _input(
          fill: darkCard,
          border: hairlineDark,
          focused: gold,
        ),
      );

  /// High-contrast pass layered on top of [light] / [dark] when the
  /// accessibility setting is on: pure backgrounds, hairline borders and
  /// maximum-legibility text.
  static ThemeData highContrast(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final onSurface = dark ? Colors.white : Colors.black;
    return theme.copyWith(
      scaffoldBackgroundColor: dark ? Colors.black : Colors.white,
      cardTheme: theme.cardTheme.copyWith(
        color: dark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
          side: BorderSide(color: onSurface, width: 1.5),
        ),
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      dividerTheme: theme.dividerTheme.copyWith(color: onSurface),
    );
  }

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? goldBright : gold,
      secondary: isDark ? gold : goldDeep,
      surface: isDark ? darkSurface : cardLight,
      error: error,
      outline: isDark ? hairlineDark : hairlineLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkBg : ivory,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, isDark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? goldBright : ink,
          foregroundColor: isDark ? ink : textOnDark,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm + 2),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: isDark ? ink : Colors.white,
          disabledBackgroundColor: (isDark ? hairlineDark : hairlineLight)
              .withValues(alpha: 0.6),
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm + 2),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? goldBright : ink,
          side: BorderSide(
              color: isDark ? gold : ink, width: 1.2),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm + 2),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? goldBright : goldDeep,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
              color: isDark ? hairlineDark : hairlineLight),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : Colors.white,
        indicatorColor: (isDark ? goldBright : gold).withValues(alpha: 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: isDark ? textOnDark : ink,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? (isDark ? goldBright : goldDeep)
                  : (isDark ? textOnDarkMuted : ink.withValues(alpha: 0.45)),
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? textOnDark : ink,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: isDark ? textOnDark.withValues(alpha: 0.85) : ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkCard : Colors.white,
        modalBackgroundColor: isDark ? darkCard : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rLg)),
        ),
        showDragHandle: true,
        dragHandleColor: isDark ? hairlineDark : hairlineLight,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkCard : ink,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13.5,
          color: textOnDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? hairlineDark : hairlineLight,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? goldBright : goldDeep,
        linearTrackColor: (isDark ? hairlineDark : hairlineLight)
            .withValues(alpha: 0.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (isDark ? goldBright : gold)
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (isDark ? gold.withValues(alpha: 0.35) : goldDeep.withValues(alpha: 0.4))
              : null,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughBuilder(),
          TargetPlatform.iOS: _FadeThroughBuilder(),
          TargetPlatform.windows: _FadeThroughBuilder(),
          TargetPlatform.macOS: _FadeThroughBuilder(),
          TargetPlatform.linux: _FadeThroughBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, bool isDark) {
    final onSurface =
        isDark ? textOnDark : ink;
    return base.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 44, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w600, color: onSurface),
      titleLarge: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          height: 1.55,
          color: onSurface.withValues(alpha: 0.9)),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: onSurface.withValues(alpha: 0.85)),
      bodySmall: GoogleFonts.inter(
          fontSize: 12.5,
          height: 1.45,
          color: onSurface.withValues(alpha: 0.6)),
      labelLarge: GoogleFonts.inter(
          fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: onSurface.withValues(alpha: 0.6)),
    );
  }

  static CardThemeData _card(Color color, Color hairline) => CardThemeData(
        color: color,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
          side: BorderSide(color: hairline, width: 1),
        ),
      );

  static InputDecorationTheme _input({
    required Color fill,
    required Color border,
    required Color focused,
  }) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: border,
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: border),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: focused,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? focused : border,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm + 2),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm + 2),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm + 2),
          borderSide: BorderSide(color: focused, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm + 2),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm + 2),
          borderSide: const BorderSide(color: error, width: 1.6),
        ),
      );
}

/// Fade-through route transition (shared-axis feel, no slide).
class _FadeThroughBuilder extends PageTransitionsBuilder {
  const _FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    // Outgoing route eases back slightly for depth.
    final scale = Tween<double>(begin: 0.985, end: 1)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
    return FadeTransition(
      opacity: fadeIn,
      child: ScaleTransition(scale: scale, child: child),
    );
  }
}
