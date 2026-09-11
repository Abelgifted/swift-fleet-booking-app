import '../utils/json_safe.dart';

/// Authenticated customer / app user.
class User {
  final String customerId;
  final String customerName;
  final String email;
  final String phone;
  final String token;
  final double balance;

  const User({
    required this.customerId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.token,
    required this.balance,
  });

  factory User.fromJson(Map<String, dynamic> rawJson) {
    // Tolerate wrapper payloads: {Data: {…}}, {User: {…}}, {Customer: {…}}.
    final json = JsonSafe.unwrap(rawJson);
    // Some backends return the token beside the profile object — lift it in.
    final token = JsonSafe.asString(json['Token'] ?? json['token'] ??
        rawJson['Token'] ?? rawJson['token']);
    return User(
      customerId: JsonSafe.asString(
          json['CustomerId'] ?? json['customerId'] ?? json['Id'] ?? json['id']),
      customerName: JsonSafe.asString(
          json['CustomerName'] ?? json['customerName'] ?? json['Name'] ?? json['name']),
      email: JsonSafe.asString(json['Email'] ?? json['email']),
      phone: JsonSafe.asString(json['Phone'] ?? json['phone']),
      token: token,
      balance: JsonSafe.toDouble(json['Balance'] ?? json['balance']),
    );
  }

  Map<String, dynamic> toJson() => {
        'CustomerId': customerId,
        'CustomerName': customerName,
        'Email': email,
        'Phone': phone,
        'Token': token,
        'Balance': balance,
      };

  /// Copy with optional overrides (e.g. refresh balance after funding).
  User copyWith({
    String? customerId,
    String? customerName,
    String? email,
    String? phone,
    String? token,
    double? balance,
  }) {
    return User(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      token: token ?? this.token,
      balance: balance ?? this.balance,
    );
  }
}
