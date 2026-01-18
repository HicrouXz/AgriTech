// lib/widgets/address_dialogs.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'land_address_model.dart'; // Import the model

// ADD ADDRESS DIALOG (HECTARES ONLY)
Future<void> showAddAddressDialog({
  required BuildContext context,
  required String currentUserId,
  required VoidCallback onAddressAdded,
}) async {
  final ownerController = TextEditingController();
  final addressController = TextEditingController();
  final areaController = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Add Land Address"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                  labelText: "Owner Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                  labelText: "Address", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Area (Hectares)", border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (ownerController.text.isEmpty ||
                addressController.text.isEmpty ||
                areaController.text.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill required fields")),
                );
              }
              return;
            }

            final newLand = {
              "user_id": currentUserId,
              "owner_name": ownerController.text,
              "address": addressController.text,
              "area": double.tryParse(areaController.text) ?? 0.0,
              "unit": "hectare",
            };

            try {
              final url = Uri.parse(
                  "http://agriease.helioho.st/public_html/add_address.php");
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: json.encode(newLand),
              );

              final data = json.decode(response.body);
              if (!context.mounted) return;

              if (data['success'] == true) {
                onAddressAdded(); // Use the callback to refresh the list
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Address added")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(data['message'] ?? "Failed to add address")),
                );
              }
            } catch (e) {
              debugPrint("Add address error: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to add address")),
                );
              }
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

// EDIT ADDRESS DIALOG (HECTARES ONLY)
Future<void> showEditAddressDialog({
  required BuildContext context,
  required LandAddress land,
  required VoidCallback onAddressUpdated,
}) async {
  final ownerController = TextEditingController(text: land.ownerName);
  final addressController = TextEditingController(text: land.address);
  final areaController = TextEditingController(text: land.area.toString());

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Land Address"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                  labelText: "Owner Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                  labelText: "Address", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Area (Hectares)", border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            final updatedLand = {
              "id": land.id,
              "owner_name": ownerController.text,
              "address": addressController.text,
              "area": double.tryParse(areaController.text) ?? 0.0,
              "unit": "hectare",
            };

            try {
              final url = Uri.parse(
                  "http://agriease.helioho.st/public_html/update_address.php");
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: json.encode(updatedLand),
              );

              final data = json.decode(response.body);
              if (!context.mounted) return;

              if (data['success'] == true) {
                onAddressUpdated(); // Use the callback to refresh
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Address updated")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(data['message'] ?? "Failed to update address")),
                );
              }
            } catch (e) {
              debugPrint("Edit address error: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to update address")),
                );
              }
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}