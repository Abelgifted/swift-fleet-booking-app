/// A wallet ledger entry (credit = money in, debit = money out).
class WalletTransaction {
  final String id;
  final String type; // 'credit' | 'debit'
  final double amount;
  final String description;
  final String date; // ISO string
  final String status; // 'completed' | 'pending' | 'failed'

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.status,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final rawType =
        '${json['Type'] ?? json['type'] ?? json['TransactionType'] ?? ''}'
            .toLowerCase();
    final amount = _toDouble(json['Amount'] ?? json['amount']);
    return WalletTransaction(
      id: '${json['Id'] ?? json['id'] ?? json['Reference'] ?? ''}',
      type: rawType.contains('debit') || amount < 0 ? 'debit' : 'credit',
      amount: amount.abs(),
      description:
          '${json['Description'] ?? json['description'] ?? json['Narration'] ?? 'Wallet transaction'}',
      date: '${json['Date'] ?? json['date'] ?? json['CreatedAt'] ?? ''}',
      status:
          '${json['Status'] ?? json['status'] ?? 'completed'}'.toLowerCase(),
    );
  }

  bool get isCredit => type == 'credit';
  bool get isCompleted => status == 'completed' || status == 'success';

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}
