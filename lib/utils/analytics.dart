import '../models/booking.dart';
import '../models/transaction.dart';

/// Pure analytics helpers: monthly spend, booking counts, totals.
///
/// All functions are side-effect free so they can be unit-tested and
/// reused by the dashboard, analytics screen, and widgets.
class AnalyticsService {
  AnalyticsService._();

  /// Last [months] calendar months as DateTime(month start), oldest first.
  static List<DateTime> lastMonths(int months, {DateTime? now}) {
    final base = now ?? DateTime.now();
    return List.generate(
      months,
      (i) => DateTime(base.year, base.month - months + 1 + i),
    );
  }

  /// Spend per month from wallet debits (falls back to booking fares when
  /// the ledger is empty so charts are never blank after a booking).
  static List<double> monthlySpend({
    required List<WalletTransaction> transactions,
    required List<Booking> bookings,
    required double farePerBooking,
    int months = 6,
    DateTime? now,
  }) {
    final keys = lastMonths(months, now: now);
    final spend = List<double>.filled(months, 0);
    var hasLedger = false;
    for (final t in transactions) {
      if (t.isCredit) continue;
      final dt = DateTime.tryParse(t.date);
      if (dt == null) continue;
      final idx = keys.indexWhere(
          (k) => k.year == dt.year && k.month == dt.month);
      if (idx >= 0) {
        spend[idx] += t.amount;
        hasLedger = true;
      }
    }
    if (!hasLedger && bookings.isNotEmpty) {
      for (final b in bookings) {
        final dt = DateTime.tryParse(b.bookedAt) ?? DateTime.now();
        final idx = keys.indexWhere(
            (k) => k.year == dt.year && k.month == dt.month);
        if (idx >= 0) spend[idx] += farePerBooking;
      }
    }
    return spend;
  }

  /// Booking counts per month (bookedAt, falling back to trip date).
  static List<int> monthlyBookings({
    required List<Booking> bookings,
    int months = 6,
    DateTime? now,
  }) {
    final keys = lastMonths(months, now: now);
    final counts = List<int>.filled(months, 0);
    for (final b in bookings) {
      final dt = DateTime.tryParse(b.bookedAt) ??
          DateTime.tryParse(b.tripDetails?.departureDate ?? '');
      if (dt == null) continue;
      final idx = keys.indexWhere(
          (k) => k.year == dt.year && k.month == dt.month);
      if (idx >= 0) counts[idx] += 1;
    }
    return counts;
  }

  static double totalSpend(List<double> monthly) =>
      monthly.fold(0, (a, b) => a + b);

  static double average(List<double> monthly) =>
      monthly.isEmpty ? 0 : totalSpend(monthly) / monthly.length;
}
