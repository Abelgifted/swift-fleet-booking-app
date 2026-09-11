import 'trip.dart';
import '../utils/json_safe.dart';

/// A confirmed (or pending) seat booking.
class Booking {
  final String bookingId;
  final String masterId;
  final String seatNumber;
  final String paymentReference;
  final String bookedAt;
  final Trip? tripDetails;

  const Booking({
    required this.bookingId,
    required this.masterId,
    required this.seatNumber,
    required this.paymentReference,
    required this.bookedAt,
    this.tripDetails,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    Trip? trip;
    final rawTrip = json['TripDetails'] ?? json['tripDetails'] ?? json['Trip'] ?? json['trip'];
    final tripMap = JsonSafe.asMap(rawTrip);
    if (tripMap != null) {
      trip = Trip.fromJson(tripMap);
    }
    return Booking(
      bookingId: JsonSafe.asString(
          json['BookingId'] ?? json['bookingId'] ?? json['Id'] ?? json['id']),
      masterId: JsonSafe.asString(json['MasterId'] ?? json['masterId']),
      seatNumber: JsonSafe.asString(json['SeatNumber'] ?? json['seatNumber']),
      paymentReference: JsonSafe.asString(
          json['PaymentReference'] ?? json['paymentReference'] ?? json['Reference'] ?? json['reference']),
      bookedAt: JsonSafe.asString(json['BookedAt'] ?? json['bookedAt'] ??
          json['CreatedAt'] ?? json['createdAt']),
      tripDetails: trip,
    );
  }

  Map<String, dynamic> toJson() => {
        'BookingId': bookingId,
        'MasterId': masterId,
        'SeatNumber': seatNumber,
        'PaymentReference': paymentReference,
        'BookedAt': bookedAt,
        'TripDetails': tripDetails?.toJson(),
      };
}
