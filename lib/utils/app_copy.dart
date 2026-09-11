/// In-app legal + product copy.
class AppCopy {
  AppCopy._();

  static const String version = '1.0.0+1';

  static const String about =
      'Fleet Booking helps you find trips, pick seats, and pay in seconds. '
      'Phase 6 adds analytics, e-tickets with QR codes, offline-friendly caching, '
      'and accessibility options. Built with Flutter + Material 3.';

  static const String terms = '''
1. Tickets are issued per seat and are non-transferable without support approval.
2. Arrive at least 30 minutes before departure with your ticket reference or QR code.
3. Cancellations made from My Bookings release the seat; refunds follow the operator's policy.
4. Fares shown at search time are final at payment. Wallet top-ups are non-refundable credit.
5. Operators may reschedule trips; affected passengers are notified in-app.
''';

  static const String privacy = '''
• We store your name, email, phone, bookings, and wallet ledger to operate the service.
• Payment card details are processed by Paystack and never stored on our servers.
• Session tokens stay on your device (SharedPreferences) and can be cleared via Log out.
• Analytics are computed on-device from your own bookings and transactions.
• Contact support to request data export or deletion.
''';
}
