import '../utils/json_safe.dart';

/// A scheduled trip (a vehicle departure on a route).
class Trip {
  final String masterId;
  final String routeId;
  final String assetName;
  final String source;
  final String destination;
  final String departureTime;
  final String departureDate;
  final double fare;
  final int totalSeats;
  final int bookedSeats;
  final int heldSeats;
  final int availableSeats;
  final String driverName;
  final String vehicleRegNo;

  const Trip({
    required this.masterId,
    required this.routeId,
    required this.assetName,
    required this.source,
    required this.destination,
    required this.departureTime,
    required this.departureDate,
    required this.fare,
    required this.totalSeats,
    required this.bookedSeats,
    required this.heldSeats,
    required this.availableSeats,
    required this.driverName,
    required this.vehicleRegNo,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    int total = JsonSafe.toInt(json['TotalSeats'] ?? json['totalSeats']);
    int booked = JsonSafe.toInt(json['BookedSeats'] ?? json['bookedSeats']);
    int held = JsonSafe.toInt(json['HeldSeats'] ?? json['heldSeats']);
    int available =
        JsonSafe.toInt(json['AvailableSeats'] ?? json['availableSeats']);
    // Derive available seats when the API omits it.
    if (available == 0 && total > 0) {
      available = total - booked - held;
    }
    return Trip(
      masterId:
          JsonSafe.asString(json['MasterId'] ?? json['masterId'] ?? json['Id'] ?? json['id']),
      routeId: JsonSafe.asString(json['RouteId'] ?? json['routeId']),
      assetName: JsonSafe.asString(json['AssetName'] ?? json['assetName'] ??
          json['VehicleName'] ?? json['vehicleName']),
      source: JsonSafe.asString(json['Source'] ?? json['source']),
      destination:
          JsonSafe.asString(json['Destination'] ?? json['destination']),
      departureTime: JsonSafe.asString(
          json['DepartureTime'] ?? json['departureTime'] ?? json['DepartureDateTime'] ?? json['departureDateTime']),
      departureDate: JsonSafe.asString(
          json['DepartureDate'] ?? json['departureDate'] ?? json['DepartureDateTime'] ?? json['departureDateTime']),
      fare: JsonSafe.toDouble(json['Fare'] ?? json['fare'] ?? json['Price'] ?? json['price']),
      totalSeats: total,
      bookedSeats: booked,
      heldSeats: held,
      availableSeats: available,
      driverName: JsonSafe.asString(
          json['DriverName'] ?? json['driverName']),
      vehicleRegNo: JsonSafe.asString(
          json['VehicleRegNo'] ?? json['vehicleRegNo'] ?? json['RegNumber'] ?? json['regNumber']),
    );
  }

  Map<String, dynamic> toJson() => {
        'MasterId': masterId,
        'RouteId': routeId,
        'AssetName': assetName,
        'Source': source,
        'Destination': destination,
        'DepartureTime': departureTime,
        'DepartureDate': departureDate,
        'Fare': fare,
        'TotalSeats': totalSeats,
        'BookedSeats': bookedSeats,
        'HeldSeats': heldSeats,
        'AvailableSeats': availableSeats,
        'DriverName': driverName,
        'VehicleRegNo': vehicleRegNo,
      };

  /// True when no seats remain.
  bool get isSoldOut => availableSeats <= 0;
}
