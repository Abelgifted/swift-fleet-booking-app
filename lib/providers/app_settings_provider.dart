import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Accessibility + display preferences (font scale, high contrast).
///
/// Consumed in [MaterialApp.builder] to apply a [MediaQuery] text scaler,
/// and by the theme getters for high-contrast adjustments.
class AppSettingsProvider extends ChangeNotifier {
  double _fontScale = 1.0;
  bool _highContrast = false;

  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;

  /// Restores saved settings (called once at startup).
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontScale =
          (prefs.getDouble(AppConstants.keyFontScale) ?? 1.0).clamp(0.85, 1.3);
      _highContrast = prefs.getBool(AppConstants.keyHighContrast) ?? false;
    } catch (_) {
      // Defaults stand.
    }
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.85, 1.3);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(AppConstants.keyFontScale, _fontScale);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyHighContrast, v);
    } catch (_) {
      // Best-effort.
    }
  }
}
