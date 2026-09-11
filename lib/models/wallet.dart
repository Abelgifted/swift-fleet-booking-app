/// Customer wallet balance.
class Wallet {
  final String customerId;
  final String customerName;
  final double balance;
  final double totalCredit;
  final String currency;
  final String lastUpdated;

  const Wallet({
    required this.customerId,
    required this.customerName,
    required this.balance,
    required this.totalCredit,
    required this.currency,
    required this.lastUpdated,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      customerId: '${json['CustomerId'] ?? json['customerId'] ?? ''}',
      customerName:
          '${json['CustomerName'] ?? json['customerName'] ?? ''}',
      balance: _toDouble(json['Balance'] ?? json['balance']),
      totalCredit: _toDouble(json['TotalCredit'] ?? json['totalCredit']),
      currency: '${json['Currency'] ?? json['currency'] ?? 'NGN'}',
      lastUpdated:
          '${json['LastUpdated'] ?? json['lastUpdated'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'CustomerId': customerId,
        'CustomerName': customerName,
        'Balance': balance,
        'TotalCredit': totalCredit,
        'Currency': currency,
        'LastUpdated': lastUpdated,
      };

  /// True when [amount] can be covered by the current balance.
  bool canCover(double amount) => balance >= amount;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}
