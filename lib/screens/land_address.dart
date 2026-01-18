import 'dart:math';
import 'package:flutter/material.dart';

/// MODEL: Land Address
class LandAddress {
  final String id; // unique ID for each land address
  final String ownerName;
  final String address;
  final double latitude;
  final double longitude;
  final double area;
  final String unit; // "sqm", "hectare", "acre"

  LandAddress({
    required this.id,
    required this.ownerName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.unit,
  });

  /// Convert area to sqm for uniform calculation
  double get areaInSqm {
    switch (unit.toLowerCase()) {
      case "hectare":
        return area * 10000;
      case "acre":
        return area * 4046.86;
      default:
        return area;
    }
  }

  /// Calculate distance between two points (Haversine formula)
  static double calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
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

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Compute booking cost (distance + area pricing)
  double computeBookingCost({
    required double baseRatePerKm,
    required double ratePerSqm,
    required double serviceLat,
    required double serviceLon,
  }) {
    double distance =
        calculateDistanceKm(serviceLat, serviceLon, latitude, longitude);
    double travelCost = distance * baseRatePerKm;
    double areaCost = areaInSqm * ratePerSqm;
    return travelCost + areaCost;
  }
}

/// MANAGER: Saved Land Addresses
class LandAddressBook {
  final List<LandAddress> _addresses = [];

  List<LandAddress> get addresses => List.unmodifiable(_addresses);

  void addAddress(LandAddress address) {
    _addresses.add(address);
  }

  void removeAddress(String id) {
    _addresses.removeWhere((a) => a.id == id);
  }

  void updateAddress(LandAddress updated) {
    final index = _addresses.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      _addresses[index] = updated;
    }
  }

  LandAddress? getAddressById(String id) {
    try {
      return _addresses.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// UI PAGE: Manage Saved Land Addresses
class ManageAddressesPage extends StatefulWidget {
  const ManageAddressesPage({Key? key}) : super(key: key);

  @override
  State<ManageAddressesPage> createState() => _ManageAddressesPageState();
}

class _ManageAddressesPageState extends State<ManageAddressesPage> {
  final LandAddressBook _addressBook = LandAddressBook();

  void _addNewAddress() {
    final newAddress = LandAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // simple ID
      ownerName: "Juan Dela Cruz",
      address: "Barangay 123, Quezon City",
      latitude: 14.6760,
      longitude: 121.0437,
      area: 2.5,
      unit: "hectare",
    );

    setState(() {
      _addressBook.addAddress(newAddress);
    });
  }

  void _removeAddress(String id) {
    setState(() {
      _addressBook.removeAddress(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Land Addresses")),
      body: _addressBook.addresses.isEmpty
          ? const Center(child: Text("No saved land addresses."))
          : ListView.builder(
              itemCount: _addressBook.addresses.length,
              itemBuilder: (context, index) {
                final land = _addressBook.addresses[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: ListTile(
                    title: Text("${land.ownerName} - ${land.address}"),
                    subtitle: Text(
                        "Area: ${land.area} ${land.unit} (${land.areaInSqm.toStringAsFixed(0)} sqm)"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeAddress(land.id),
                    ),
                    onTap: () {
                      // Example: compute booking cost when tapped
                      final cost = land.computeBookingCost(
                        baseRatePerKm: 50,
                        ratePerSqm: 2,
                        serviceLat: 14.5995,
                        serviceLon: 120.9842,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Booking Cost for ${land.labelText}: ₱${cost.toStringAsFixed(2)}"),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAddress,
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension on LandAddress {
  String get labelText => ownerName.isNotEmpty ? ownerName : id;
}
