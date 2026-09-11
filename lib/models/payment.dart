/// Payment verification result for a booking.
class Payment {
  final String paymentReference;
  final String status;
  final bool isCompleted;
  final String bookingReference;
  final String masterId;
  final double amount;

  const Payment({
    required this.paymentReference,
    required this.status,
    required this.isCompleted,
    required this.bookingReference,
    required this.masterId,
    required this.amount,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final status = '${json['Status'] ?? json['status'] ?? ''}';
    return Payment(
      paymentReference:
          '${json['PaymentReference'] ?? json['paymentReference'] ?? ''}',
      status: status,
      isCompleted: _toBool(json['IsCompleted'] ?? json['isCompleted']) ||
          status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'success',
      bookingReference:
          '${json['BookingReference'] ?? json['bookingReference'] ?? ''}',
      masterId: '${json['MasterId'] ?? json['masterId'] ?? ''}',
      amount: _toDouble(json['Amount'] ?? json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'PaymentReference': paymentReference,
        'Status': status,
        'IsCompleted': isCompleted,
        'BookingReference': bookingReference,
        'MasterId': masterId,
        'Amount': amount,
      };

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'completed' || s == 'success';
    }
    return false;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}
