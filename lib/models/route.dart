/// A travel route between a source and destination location.
class RouteModel {
  final String id;
  final String name;
  final String sourceId;
  final String sourceName;
  final String destinationId;
  final String destinationName;
  final double fare;
  final int estimatedDuration; // in minutes

  const RouteModel({
    required this.id,
    required this.name,
    required this.sourceId,
    required this.sourceName,
    required this.destinationId,
    required this.destinationName,
    required this.fare,
    required this.estimatedDuration,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: '${json['Id'] ?? json['id'] ?? ''}',
      name: '${json['Name'] ?? json['name'] ?? ''}',
      sourceId: '${json['SourceId'] ?? json['sourceId'] ?? ''}',
      sourceName: '${json['SourceName'] ?? json['sourceName'] ?? ''}',
      destinationId:
          '${json['DestinationId'] ?? json['destinationId'] ?? ''}',
      destinationName:
          '${json['DestinationName'] ?? json['destinationName'] ?? ''}',
      fare: _toDouble(json['Fare'] ?? json['fare']),
      estimatedDuration:
          _toInt(json['EstimatedDuration'] ?? json['estimatedDuration']),
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'SourceId': sourceId,
        'SourceName': sourceName,
        'DestinationId': destinationId,
        'DestinationName': destinationName,
        'Fare': fare,
        'EstimatedDuration': estimatedDuration,
      };

  /// Human label: "Lagos → Abuja".
  String get label => '$sourceName → $destinationName';

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
