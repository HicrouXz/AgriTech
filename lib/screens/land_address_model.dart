import 'dart:math';

/// MODEL: Land Address
/// This class represents the structure of a land address object.
/// It is separate from the UI to keep the data logic clean.
class LandAddress {
  final String id;
  final String ownerName;
  final String address;
  final double area;
  final String unit;

  LandAddress({
    required this.id,
    required this.ownerName,
    required this.address,
    required this.area,
    required this.unit,
  });

  /// Converts the area to square meters, regardless of the original unit.
  double get areaInSqm {
    switch (unit.toLowerCase()) {
      case "hectare":
        return area * 10000;
      case "acre":
        return area * 4046.86;
      default: // Assumes 'sqm' or any other unit is already in square meters.
        return area;
    }
  }
  
  /// A factory constructor to create a LandAddress instance from a JSON map.
  /// This is useful for parsing data from an API response.
  factory LandAddress.fromJson(Map<String, dynamic> json) {
    return LandAddress(
      id: json['id'].toString(),
      ownerName: json['owner_name'] ?? '',
      address: json['address'] ?? '',
      area: double.tryParse(json['area'].toString()) ?? 0.0,
      unit: json['unit'] ?? 'sqm',
    );
  }

  /// Converts the LandAddress instance into a JSON map.
  /// This is useful for sending data to an API (e.g., when updating).
  Map<String, dynamic> toJson() => {
        "id": id,
        "owner_name": ownerName,
        "address": address,
        "area": area,
        "unit": unit,
      };

  // --- Utility Functions that could be part of the model ---

  /// Calculates the distance in kilometers between two geographic points.
  static double calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // in kilometers
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Helper function to convert degrees to radians.
  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Computes the booking cost based on a fixed rate per hectare.
  /// This could be made more complex if needed.
  double computeBookingCost() {
    const ratePerHectare = 16000.0;
    return area * ratePerHectare;
  }
}
