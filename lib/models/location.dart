/// Pickup / drop-off location (park / terminal).
class Location {
  final String id;
  final String name;
  final String code;

  const Location({required this.id, required this.name, required this.code});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: '${json['Id'] ?? json['id'] ?? ''}',
      name: '${json['Name'] ?? json['name'] ?? ''}',
      code: '${json['Code'] ?? json['code'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name, 'Code': code};

  @override
  String toString() => name;
}
