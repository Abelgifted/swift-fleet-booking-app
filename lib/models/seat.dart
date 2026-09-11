/// A single seat within a trip's vehicle layout.
class Seat {
  final String seatId;
  final String seatNumber;
  final bool isAvailable;
  final bool isBooked;
  final bool isHeld;
  final bool isDriverSeat;
  final String seatType;

  const Seat({
    required this.seatId,
    required this.seatNumber,
    required this.isAvailable,
    required this.isBooked,
    required this.isHeld,
    required this.isDriverSeat,
    required this.seatType,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      seatId: '${json['SeatId'] ?? json['seatId'] ?? ''}',
      seatNumber: '${json['SeatNumber'] ?? json['seatNumber'] ?? ''}',
      isAvailable: _toBool(json['IsAvailable'] ?? json['isAvailable']),
      isBooked: _toBool(json['IsBooked'] ?? json['isBooked']),
      isHeld: _toBool(json['IsHeld'] ?? json['isHeld']),
      isDriverSeat:
          _toBool(json['IsDriverSeat'] ?? json['isDriverSeat']),
      seatType: '${json['SeatType'] ?? json['seatType'] ?? 'Standard'}',
    );
  }

  Map<String, dynamic> toJson() => {
        'SeatId': seatId,
        'SeatNumber': seatNumber,
        'IsAvailable': isAvailable,
        'IsBooked': isBooked,
        'IsHeld': isHeld,
        'IsDriverSeat': isDriverSeat,
        'SeatType': seatType,
      };

  /// Selectable = available, not booked/held, not the driver seat.
  bool get isSelectable =>
      isAvailable && !isBooked && !isHeld && !isDriverSeat;

  /// Occupied (shown disabled in the seat map).
  bool get isOccupied => isBooked || isHeld || !isAvailable;

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }
}
