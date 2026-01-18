// lib/screens/checkout_page.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import 'land_address_model.dart';
import 'profile.dart';

class CheckoutPage extends StatefulWidget {
  final String equipmentName;
  final String equipmentType;
  final String equipmentId;
  final double pricePerHectare; // This is the Base Price (e.g. 16000)
  final Color? color;
  final IconData? icon;
  final String currentUserId;
  final String? equipmentDescription;
  final String? imageUrl; 

  const CheckoutPage({
    Key? key,
    required this.equipmentName,
    required this.equipmentType,
    required this.equipmentId,
    required this.pricePerHectare,
    this.color,
    this.icon,
    required this.currentUserId,
    this.equipmentDescription,
    this.imageUrl, 
  }) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isLoading = true;
  List<LandAddress> _savedAddresses = [];
  LandAddress? _selectedAddress;
  bool _isPlacingOrder = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Equipment Quantity defaults to 1 and is independent of address
  int _equipmentQuantity = 1; 
  final int _minQuantity = 1; 
  final int _quantityStep = 1; 

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void didUpdateWidget(covariant CheckoutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUserId != oldWidget.currentUserId) {
      _loadAddresses();
    }
  }

  Future<void> _loadAddresses() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          "https://agriease.helioho.st/public_html/fetch_addresses.php?user_id=${widget.currentUserId}");
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (mounted && response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = json.decode(response.body) as List;
        setState(() {
          _savedAddresses = decoded.map((data) => LandAddress.fromJson(data)).toList();
          // Select the first address by default, but do NOT update quantity automatically
          _selectedAddress = _savedAddresses.isNotEmpty ? _savedAddresses.first : null;
        });
      }
    } catch (e) {
      debugPrint("Error loading addresses: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error fetching addresses."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _incrementQuantity() {
    setState(() {
      _equipmentQuantity = _equipmentQuantity + _quantityStep;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_equipmentQuantity > _minQuantity) {
        _equipmentQuantity = _equipmentQuantity - _quantityStep;
      }
    });
  }

  Future<void> _navigateToProfileAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Profile(
          currentUserId: widget.currentUserId,
          onLogout: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
    _loadAddresses();
  }

  Future<DateTime?> _pickDateTime({required DateTime initialDate, required bool isStartDate}) async {
    final now = DateTime.now();
    final minimumStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
    final DateTime firstSelectableDate = isStartDate ? minimumStart : (_startDate ?? minimumStart).add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstSelectableDate) ? firstSelectableDate : initialDate,
      firstDate: firstSelectableDate, 
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate.isBefore(firstSelectableDate) ? firstSelectableDate : initialDate);

    final time = await showTimePicker(
      context: context, 
      initialTime: initialTime,
    );
    if (time == null) return null;
    
    final selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (isStartDate && selectedDateTime.isBefore(minimumStart)) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ Start date must be at least 2 days from today."), backgroundColor: Colors.red),
            );
        }
        return null;
    }
    
    return selectedDateTime;
  }

  Future<void> placeOrder() async {
    final selectedQuantity = _equipmentQuantity; 
    
    if (_selectedAddress == null || selectedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Please select a valid address and quantity."), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Please select a start and end date."), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!.add(const Duration(days: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ End date cannot be the same day or before the start date."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final url = Uri.parse("https://agriease.helioho.st/public_html/agri_web/book_equipments.php");
      
      // --- CALCULATION LOGIC ---
      // Formula: Hectares * Quantity * Price
      double areaInHectares = _selectedAddress!.area;
      double pricePerUnit = widget.pricePerHectare;
      
      final totalCost = areaInHectares * selectedQuantity * pricePerUnit; 

      final now = DateTime.now();
      final minimumStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));

      if (_startDate!.isBefore(minimumStart)) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("❌ Start date must be at least 2 days from today."), backgroundColor: Colors.red),
           );
           setState(() => _isPlacingOrder = false);
           return;
      }
      
      final response = await http.post(url, body: {
        "equipment_id": widget.equipmentId,
        "equipment_name": widget.equipmentName,
        "equipment_type": widget.equipmentType,
        "renter_id": widget.currentUserId,
        
        "quantity": selectedQuantity.toString(), 
        "area_in_hectares": _selectedAddress!.area.toString(), 
        "price_per_hectare": widget.pricePerHectare.toString(),
        
        // This is the multiplied total (Area * Qty * Price)
        "total_price": totalCost.toStringAsFixed(2), 
        
        "booking_date": DateTime.now().toIso8601String(),
        "start_time": _startDate!.toIso8601String(),
        "end_time": _endDate!.toIso8601String(),
        "delivery_address": _selectedAddress!.address,
        "payment_method": "cod",
      }).timeout(const Duration(seconds: 30));

      final result = json.decode(response.body);
      if (result["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Order Placed Successfully! Message: ${result["message"]}"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ ${result["message"] ?? "Order failed"}"), backgroundColor: Colors.red),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ The request timed out."), backgroundColor: Colors.red),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Invalid response from server."), backgroundColor: Colors.red),
      );
    } catch (e) {
      debugPrint("Exception placing order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ An error occurred."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
  
  Widget _buildEquipmentQuantityAdder() {
    final Color primaryGreen = Colors.green.shade600;
    final Color buttonBackground = Colors.white; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Equipment Quantity (Units):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuantityButton(
                icon: Icons.remove,
                onPressed: _equipmentQuantity > _minQuantity ? _decrementQuantity : null, 
                backgroundColor: _equipmentQuantity > _minQuantity ? buttonBackground : Colors.grey.shade300, 
                iconColor: _equipmentQuantity > _minQuantity ? primaryGreen : Colors.black54,
                size: 48,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _equipmentQuantity.toString(), 
                  style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              _buildQuantityButton(
                icon: Icons.add,
                onPressed: _incrementQuantity,
                backgroundColor: primaryGreen, 
                iconColor: Colors.white,
                size: 48,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon, 
    required VoidCallback? onPressed, 
    required Color backgroundColor,
    required Color iconColor,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          if (onPressed != null && icon == Icons.add)
            BoxShadow(
              color: backgroundColor.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 1. Get current values
    final selectedQuantity = _equipmentQuantity; 
    
    // Default to 0 if no address selected so math doesn't crash, but Logic ensures address is selected before order.
    final double area = _selectedAddress?.area ?? 0.0;
    
    // 2. MATH: Hectares * Quantity * Price
    final totalCost = area * selectedQuantity * widget.pricePerHectare; 
    
    final formatter = DateFormat('MMM d, yyyy h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text("Rent ${widget.equipmentName}"),
        backgroundColor: widget.color ?? Colors.green,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color.fromARGB(255, 250, 248, 239),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black87))
          : RefreshIndicator(
              onRefresh: _loadAddresses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                      Center(
                        child: Image.network(
                          "https://agriease.helioho.st${widget.imageUrl!.startsWith('/') ? widget.imageUrl : '/${widget.imageUrl}'}", 
                          fit: BoxFit.contain,
                          height: 150,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(widget.icon ?? Icons.agriculture, size: 80, color: widget.color ?? Colors.green),
                        ),
                      )
                    else
                      Center(child: Icon(widget.icon ?? Icons.agriculture, size: 80, color: widget.color ?? Colors.green)),
                    const SizedBox(height: 16),
                    if (widget.equipmentDescription != null && widget.equipmentDescription!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          widget.equipmentDescription!,
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ),
                    
                    // --- DELIVERY ADDRESS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Delivery Address:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_location_alt, size: 18),
                          label: const Text("Manage"),
                          onPressed: _navigateToProfileAndRefresh,
                          style: TextButton.styleFrom(foregroundColor: Colors.green), 
                        ),
                      ],
                    ),
                    if (_savedAddresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                            "No saved addresses found.\nUse the 'Manage' button to add one.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _savedAddresses.map((addr) => RadioListTile<LandAddress>(
                          activeColor: Colors.green,
                          value: addr,
                          groupValue: _selectedAddress,
                          
                          // When user clicks address, we ONLY update the address.
                          // The 'Total' below will automatically update because 'area' changes.
                          // The quantity number remains whatever the user set it to.
                          onChanged: (LandAddress? value) {
                            setState(() {
                              _selectedAddress = value;
                            });
                          },
                          
                          title: Text("${addr.ownerName} - ${addr.address}", style: const TextStyle(color: Colors.black87)),
                          subtitle: Text("Area: ${addr.area} ${addr.unit}", style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        )).toList(),
                      ),
                    
                    const SizedBox(height: 16),

                    // --- RENTAL PERIOD ---
                    const Text("Rental Period:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, color: Colors.black),
                            label: Text(_startDate == null ? 'Select Start Date' : formatter.format(_startDate!)),
                            onPressed: () async {
                              final now = DateTime.now();
                              final initialDate = _startDate ?? DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
                              final pickedDate = await _pickDateTime(initialDate: initialDate, isStartDate: true);
                              if (pickedDate != null) setState(() => _startDate = pickedDate);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, color: Colors.black),
                            label: Text(_endDate == null ? 'Select End Date' : formatter.format(_endDate!)),
                            onPressed: _startDate == null ? null : () async {
                              final pickedDate = await _pickDateTime(initialDate: _endDate ?? _startDate!, isStartDate: false);
                              if (pickedDate != null) setState(() => _endDate = pickedDate);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: _startDate == null ? Colors.grey[300] : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    
                    // --- PAYMENT METHOD ---
                    const Text("Payment Method:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const ListTile(
                      leading: Icon(Icons.payments, color: Colors.orange),
                      title: Text("Cash on Delivery (COD)", style: const TextStyle(color: Colors.black87)),
                    ),
                    const SizedBox(height: 16),

                    // --- QUANTITY ADDER ---
                    _buildEquipmentQuantityAdder(),
                    const SizedBox(height: 24),

                    // --- ORDER SUMMARY ---
                    const Text("Order Summary:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text("Equipment: ${widget.equipmentName}", style: const TextStyle(color: Colors.black87)),
                    Text("Type: ${widget.equipmentType}", style: const TextStyle(color: Colors.black87)),
                    
                    const SizedBox(height: 8),
                    // Display the Breakdown so user understands the price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Land Area:", style: TextStyle(color: Colors.black54)),
                        Text("$area Hectares", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Quantity:", style: TextStyle(color: Colors.black54)),
                        Text("$selectedQuantity Units", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Price:", style: TextStyle(color: Colors.black54)),
                        Text("₱${widget.pricePerHectare.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    
                    const Divider(thickness: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          Text(
                            "₱${totalCost.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: (_isPlacingOrder || _selectedAddress == null || _startDate == null || _endDate == null || selectedQuantity <= 0) ? null : placeOrder,
                        icon: _isPlacingOrder
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle),
                        label: Text(_isPlacingOrder ? "Placing Order..." : "Place Order"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}