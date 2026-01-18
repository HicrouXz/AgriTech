import 'package:flutter/material.dart';

import 'checkout_page.dart';

// This widget is for the sub-browse page, displaying types within a category.
class EquipmentSubBrowsePage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> types;
  final Color? color;
  final IconData? icon;
  final String currentUserId;

  const EquipmentSubBrowsePage({
    Key? key,
    required this.title,
    required this.types,
    this.color,
    this.icon,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define the color to be used from the category color, with a green fallback.
    final Color categoryColor = color ?? Colors.green.shade600;

    return Scaffold(
      // MODIFIED: Changed background color from dark charcoal to light cream color
      backgroundColor: const Color.fromARGB(255, 250, 248, 239),
      appBar: AppBar(
        title: Text(title),
        // MODIFIED: AppBar background color uses the category color
        backgroundColor: categoryColor,
        // The title and icon color should be white for contrast against the dynamic background color.
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white), // Back button color
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              // MODIFIED: Icon color uses the dark green base color for consistency with Browse List View
              Icon(icon, color: const Color(0xFF4B5320)),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  // MODIFIED: Changed text color to dark gray/black
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              types.length,
              (i) => GestureDetector(
                onTap: () async {
                  final item = types[i];
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutPage(
                        key: ValueKey(currentUserId),
                        equipmentName: item['equip_name'] ?? item['type'],
                        equipmentType: title,
                        equipmentDescription: item['description'],
                        equipmentId: item['equipment_id'].toString(),
                        pricePerHectare: double.tryParse(
                                item['price_per_hectare'] ?? '0.0') ??
                            0.0,
                        color: color, // Passed to CheckoutPage
                        icon: icon,
                        currentUserId: currentUserId,
                        imageUrl: item['image_url'],
                      ),
                    ),
                  );
                  // If a booking was placed on the CheckoutPage, pop this page
                  // and return true to the Browse page to trigger a refresh.
                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // MODIFIED: Icon color uses the dark green base color
                      Icon(icon, size: 18, color: const Color(0xFF4B5320)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${types[i]['equip_name'] ?? types[i]['type']}",
                          style:
                              // MODIFIED: Changed text color to dark gray/black
                              const TextStyle(fontSize: 16, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₱${types[i]['price_per_hectare']}/ha",
                        style: const TextStyle(
                          fontSize: 16,
                          // MODIFIED: Changed text color to dark gray/black
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}