import 'package:intl/intl.dart';
import 'constants.dart';

/// Formatting helpers for currency, dates, times, and durations.
class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2);

  static final NumberFormat _currencyNoDecimals =
      NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 0);

  /// Formats [amount] as currency, e.g. ₦5,000.00
  static String currency(dynamic amount, {bool withDecimals = true}) {
    final value = _toDouble(amount);
    return withDecimals
        ? _currencyFormat.format(value)
        : _currencyNoDecimals.format(value);
  }

  /// Formats an ISO date string (yyyy-MM-dd) as "Mon, 12 May 2026".
  static String date(String? isoDate, {String fallback = '—'}) {
    if (isoDate == null || isoDate.isEmpty) return fallback;
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  /// Formats a time string ("HH:mm" or "HH:mm:ss") as "h:mm a".
  static String time(String? raw, {String fallback = '—'}) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      DateTime dt;
      if (raw.contains('T')) {
        dt = DateTime.parse(raw);
      } else {
        final parts = raw.split(':');
        dt = DateTime(2000, 1, 1, int.parse(parts[0]),
            parts.length > 1 ? int.parse(parts[1]) : 0);
      }
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  /// Combines date + time strings for trip display.
  static String dateTime(String? date, String? time) =>
      '${Formatters.date(date)} • ${Formatters.time(time)}';

  /// Formats an estimated duration in minutes as "2h 30m".
  static String duration(dynamic minutesRaw) {
    final minutes = _toInt(minutesRaw);
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Masks a phone number, e.g. 0803****123.
  static String maskPhone(String? phone) {
    if (phone == null || phone.length < 7) return phone ?? '—';
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}';
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
