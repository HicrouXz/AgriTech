// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking.dart'; 
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:intl/intl.dart'; 

// --- Helper Functions ---

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.amber.shade700;
    case 'confirmed':
      return Colors.green.shade600;
    case 'cancelled': 
      return Colors.red.shade700; 
    case 'completed':
      return const Color.fromARGB(255, 7, 161, 166);
    default:
      return Colors.grey.shade500;
  }
}

IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Icons.pending_actions_rounded;
    case 'confirmed':
      return Icons.check_circle_outline_rounded;
    case 'cancelled': 
      return Icons.cancel_rounded; 
    case 'in_delivery':
      return Icons.local_shipping_rounded;
    case 'delivered':
      return Icons.check_circle_rounded;
    case 'completed': 
      return Icons.task_alt_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String _formatDateTime(String? dateString) {
  if (dateString == null || dateString.isEmpty) return "N/A";
  try {
    return DateFormat('MMM d, h:mm a').format(DateTime.parse(dateString).toLocal());
  } catch (e) {
    return dateString;
  }
}

String _getRelativeTime(String dateString) {
  try {
    final dateTime = DateTime.parse(dateString).toLocal();
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} mins ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    
    return DateFormat('MMM d, yyyy').format(dateTime); 
    
  } catch (e) {
    return 'N/A';
  }
}

// ------------------------------------------

class NotificationsPage extends StatefulWidget {
  final String currentUserId;
  
  const NotificationsPage({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _notificationItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndPrepareNotifications();
  }

  // --- DATA LOADING ---

  Future<void> _loadAndPrepareNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
          "https://agriease.helioho.st/public_html/agri_web/get_bookings.php?renter_id=${widget.currentUserId}&_=$timestamp");
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bookings = json.decode(response.body);
        if (bookings is List) {
          _allBookings = List<Map<String, dynamic>>.from(bookings);
          await _createNotificationList();
        }
      }
    } catch (e) {
      debugPrint("Error loading/fetching notifications: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC CHANGE: Show ALL Un-Dismissed Items ---
  
  Future<void> _createNotificationList() async {
    final List<Map<String, dynamic>> updates = [];
    final prefs = await SharedPreferences.getInstance();

    // 1. Get the list of specific IDs the user has swiped away
    final String dismissKey = 'dismissed_ids_${widget.currentUserId}';
    final List<String> dismissedIds = prefs.getStringList(dismissKey) ?? [];

    // 2. Loop through ALL bookings to find relevant alerts
    for (var booking in _allBookings) {
      final status = booking['booking_status']?.toString().toLowerCase() ?? '';
      final id = booking['booking_id']?.toString() ?? '0';
      
      // Skip if user already dismissed this specific ID
      if (dismissedIds.contains(id)) continue;

      // Check Statuses we care about
      if (status.contains('confirmed')) {
        updates.add(Map.from(booking)..['message'] = 'Booking was CONFIRMED');
      } 
      else if (status.contains('completed')) {
        updates.add(Map.from(booking)..['message'] = 'Booking was COMPLETED');
      } 
      else if (status.contains('cancel')) { // Matches 'cancelled' or 'canceled'
        updates.add(Map.from(booking)..['message'] = 'Booking was CANCELLED');
      }
    }
    
    // --- 3. Collect Imminent Returns (non-dismissible) ---
    final imminentReturnsCount = _allBookings.where((b) {
      final status = b['booking_status']?.toString().toLowerCase() ?? '';
      final endTimeString = b['end_time']?.toString();
      if (status == 'confirmed' && endTimeString != null) {
        try {
          final now = DateTime.now();
          final tomorrow = now.add(const Duration(days: 1));
          final endTime = DateTime.parse(endTimeString);
          return endTime.isAfter(now) && endTime.isBefore(tomorrow.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }
      return false;
    }).length;

    if (imminentReturnsCount > 0) {
      updates.add({
        'booking_status': 'reminder',
        'booking_id': '0', // ID 0 means it's a system reminder
        'equip_name': 'Imminent Return Reminder',
        'message': 'You have $imminentReturnsCount returns due soon!',
        'isDismissible': false,
        'created_at': DateTime.now().toIso8601String(),
        'total_price': 'N/A',
        'quantity': imminentReturnsCount.toString(),
        'start_time': 'N/A', 
        'end_time': 'N/A', 
      });
    }

    // Sort by date (newest first)
    updates.sort((a, b) {
      final dateA = DateTime.tryParse(a["created_at"]?.toString() ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b["created_at"]?.toString() ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _notificationItems = updates;
      });
    }
  }

  // --- ACTION 1: UI UPDATE (Immediate) ---
  void _clearNotification(String status, String bookingId) {
    if (mounted) {
      setState(() {
        _notificationItems.removeWhere((item) => 
          item['booking_status']?.toString().toLowerCase() == status.toLowerCase() && 
          item['booking_id'].toString() == bookingId
        );
      });
    }
    _saveDismissalToPreferences(bookingId);
  }

  // --- ACTION 2: BACKGROUND SAVE (List Based) ---
  Future<void> _saveDismissalToPreferences(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String dismissKey = 'dismissed_ids_${widget.currentUserId}';
      
      // Get current list, add new ID, save back
      List<String> dismissedIds = prefs.getStringList(dismissKey) ?? [];
      
      if (!dismissedIds.contains(bookingId)) {
        dismissedIds.add(bookingId);
        await prefs.setStringList(dismissKey, dismissedIds);
      }
    } catch (e) {
      debugPrint("Error saving dismissal: $e");
    }
  }

  Future<void> _clearAllDismissibleNotifications() async {
    // 1. Identify items to clear
    final itemsToClear = _notificationItems.where((item) => item['isDismissible'] ?? true).toList();
    if (itemsToClear.isEmpty) return;

    // 2. Clear UI Immediately
    if (mounted) {
        setState(() {
            _notificationItems.removeWhere((item) => item['isDismissible'] ?? true);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Cleared ${itemsToClear.length} alert(s).")),
        );
    }

    // 3. Process persistence in background
    for (var item in itemsToClear) {
        final id = item['booking_id']?.toString() ?? '0';
        if (id != '0') {
            _saveDismissalToPreferences(id);
        }
    }
  }

  // Renders the list of notifications using Dismissible
  Widget _buildNotificationList() {
    if (_notificationItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            "No recent alerts.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: _notificationItems.length,
      itemBuilder: (context, index) {
        final item = _notificationItems[index];
        final status = item['booking_status']?.toString().toLowerCase() ?? 'unknown';
        final isDismissible = item['isDismissible'] ?? true;
        
        // --- FIX: ADDED INDEX TO KEY TO PREVENT DUPLICATE KEY CRASHES IN APK ---
        final uniqueKey = Key("${status}_${item['booking_id']}_$index"); 
        
        final itemColor = _getStatusColor(status);
        final itemIcon = _getStatusIcon(status);

        // --- Expanded Content Details Builder ---
        Widget buildDetailRow(String label, String value, {Color valueColor = Colors.black87}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54))),
                const Text(": ", style: TextStyle(color: Colors.black54)),
                Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor))),
              ],
            ),
          );
        }

        // Non-dismissible reminder item
        if (!isDismissible) {
          return Card(
            color: const Color(0xFFFAF9F6),
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: Icon(itemIcon, color: itemColor),
              title: Text(
                item['message'] ?? 'Reminder', // Added null safety
                style: TextStyle(fontWeight: FontWeight.bold, color: itemColor, fontSize: 14),
              ),
              subtitle: Text(
                "Tap for details",
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                  child: Column(
                    children: [
                      buildDetailRow("Alert Type", item['equipment'] ?? 'Reminder', valueColor: itemColor),
                      buildDetailRow("Quantity", "${item['quantity']} Units"),
                      buildDetailRow("Alert Date", _getRelativeTime(item['created_at'])),
                      const SizedBox(height: 8),
                      const Text("This alert is not dismissible. See Booking History.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          );
        }

        // Dismissible status update items
        return Dismissible(
          key: uniqueKey,
          direction: DismissDirection.startToEnd,
          background: Container(
            color: itemColor.withOpacity(0.5),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            // Safe Sync Removal
            _clearNotification(status, item['booking_id'].toString()); 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${item['message'] ?? 'Alert'} cleared.")),
            );
          },
          child: Card(
            color: const Color(0xFFFAF9F6), 
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            child: ExpansionTile(
              leading: Icon(itemIcon, color: itemColor),
              title: Text(
                "${item['equip_name'] ?? item['equipment'] ?? 'Equipment'}", 
                style: TextStyle(fontWeight: FontWeight.bold, color: itemColor, fontSize: 14),
              ),
              subtitle: Text(
                "${item['message'] ?? 'Update'} (ID: ${item['booking_id']})", 
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                  child: Column(
                    children: [
                      buildDetailRow("Status", status.toUpperCase(), valueColor: itemColor),
                      buildDetailRow("Booking ID", item['booking_id'].toString()),
                      buildDetailRow("Quantity", "${item['quantity']?.toString() ?? 'N/A'} Units"),
                      buildDetailRow("Total Price", "₱${item['total_price']?.toString() ?? '0.00'}"),
                      buildDetailRow("Start", _formatDateTime(item['start_time']?.toString())),
                      buildDetailRow("End", _formatDateTime(item['end_time']?.toString())),
                      buildDetailRow("Alert Sent", _getRelativeTime(item['created_at'])),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF4), 
      appBar: AppBar(
        title: const Text(
          "Notifications", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF4B5320), 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4B5320)))
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "All Alerts and Updates",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      // Clear All Button
                      if (_notificationItems.any((item) => item['isDismissible'] ?? true))
                          TextButton(
                            onPressed: _clearAllDismissibleNotifications,
                            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
                          ),
                    ],
                  ),
                  const Divider(),
                  
                  _buildNotificationList(),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Booking(currentUserId: widget.currentUserId, onBookingUpdate: () {}),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, color: Color(0xFF4B5320)),
                    label: const Text("View Booking History"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD2B48C), 
                      foregroundColor: const Color(0xFF4B5320),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(color: Color(0xFF4B5320), fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}