import 'package:fleet_booking/models/booking.dart';
import 'package:fleet_booking/models/transaction.dart';
import 'package:fleet_booking/utils/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 3);

  WalletTransaction txn(String date, double amount) =>
      WalletTransaction(
        id: 't-$date-$amount',
        type: amount < 0 ? 'debit' : 'credit',
        amount: amount.abs(),
        description: 'test',
        date: date,
        status: 'completed',
      );

  Booking booking(String bookedAt) => Booking(
        bookingId: 'b-$bookedAt',
        masterId: 'm1',
        seatNumber: '1',
        paymentReference: 'p',
        bookedAt: bookedAt,
      );

  group('AnalyticsService', () {
    test('monthlySpend buckets debits by month', () {
      final spend = AnalyticsService.monthlySpend(
        transactions: [
          txn('2026-09-01T10:00:00', -5000),
          txn('2026-08-15T10:00:00', -3000),
          txn('2026-09-02T10:00:00', 10000), // credit ignored
        ],
        bookings: const [],
        farePerBooking: 5000,
        months: 2,
        now: now,
      );
      expect(spend, [3000, 5000]); // Aug, Sep
    });

    test('monthlySpend falls back to fares when ledger is empty', () {
      final spend = AnalyticsService.monthlySpend(
        transactions: const [],
        bookings: [booking('2026-09-01T10:00:00')],
        farePerBooking: 4500,
        months: 1,
        now: now,
      );
      expect(spend, [4500]);
    });

    test('monthlyBookings counts per month', () {
      final counts = AnalyticsService.monthlyBookings(
        bookings: [
          booking('2026-09-01T10:00:00'),
          booking('2026-09-02T10:00:00'),
          booking('2026-07-01T10:00:00'),
        ],
        months: 3,
        now: now,
      );
      expect(counts, [1, 0, 2]); // Jul, Aug, Sep
    });

    test('totals and averages', () {
      expect(AnalyticsService.totalSpend([100, 200]), 300);
      expect(AnalyticsService.average([100, 200]), 150);
      expect(AnalyticsService.average([]), 0);
    });
  });
}
