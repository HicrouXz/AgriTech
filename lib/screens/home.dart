// lib/screens/home.dart

// ignore_for_file: unused_local_variable, unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Import the dart:async library for Timer

import 'Profile.dart';
import 'booking.dart';
import 'browse.dart';
import 'notifications_page.dart'; // Added import for notifications_page

class Home extends StatefulWidget {
  final String currentUserId;
  // REMOVED: final void Function() onLogout;

  const Home({Key? key, required this.currentUserId, required Null Function() onLogout}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String username = "Loading...";
  String? profilePictureUrl;
  bool isLoggedIn = false;
  
  int notificationCount = 0; 
  int imminentReturnsCount = 0;
  
  // --- NEW PERSISTENCE FIELDS FOR 3 STATUSES ---
  bool _hasUnseenCancellation = false; 
  bool _hasUnseenConfirmation = false;
  bool _hasUnseenCompletion = false;
  
  // Latest IDs found by server
  int _latestCancelledBookingId = 0; 
  int _latestConfirmedBookingId = 0; 
  int _latestCompletedBookingId = 0; 

  // Last IDs user dismissed
  int _lastSeenCancelledBookingId = 0; 
  int _lastSeenConfirmedBookingId = 0;
  int _lastSeenCompletedBookingId = 0;

  // The notifications panel is now removed, _isNotificationsOpen state is unused.
  // bool _isNotificationsOpen = false;
  
  // Initialize the Timer to prevent LateInitializationError
  Timer _pollingTimer = Timer(Duration.zero, () {}); 

  late Future<void> _loadInitialDataFuture;
  List<dynamic> activeBookings = [];

  @override
  void initState() {
    super.initState();
    // Use Future.wait to load data concurrently, making the screen appear faster.
    _loadInitialDataFuture = _loadInitialData();
    
    // Start polling every 5 seconds for a "live" feel
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Use _fetchAndForceUpdate to ensure setState runs correctly on the timer thread
      _fetchAndForceUpdate(isPolling: true);
    });
  }
  
  @override
  void dispose() {
    _pollingTimer.cancel(); // Now guaranteed to be a valid object
    super.dispose();
  }

  // --- PERSISTENCE HELPERS ---
  
  // Combined load function for all statuses
  Future<void> _loadLastSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenCancelledBookingId = prefs.getInt('lastSeenCancelledId_${widget.currentUserId}') ?? 0;
    _lastSeenConfirmedBookingId = prefs.getInt('lastSeenConfirmedId_${widget.currentUserId}') ?? 0;
    _lastSeenCompletedBookingId = prefs.getInt('lastSeenCompletedId_${widget.currentUserId}') ?? 0;
    
    await _loadUnseenFlags(); 
  }

  // Sets the last seen ID for a specific status and clears the corresponding flag
  Future<void> _setLastSeenId(String status, int bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final keyId = 'lastSeen${status}Id_${widget.currentUserId}';
    final keyFlag = 'unseen${status}_${widget.currentUserId}';

    await prefs.setInt(keyId, bookingId);
    
    // Update local variables immediately
    if (status == 'Cancelled') _lastSeenCancelledBookingId = bookingId;
    if (status == 'Confirmed') _lastSeenConfirmedBookingId = bookingId;
    if (status == 'Completed') _lastSeenCompletedBookingId = bookingId;

    await _setUnseenFlag(keyFlag, false);
  }

  // Combined load function for all flags
  Future<void> _loadUnseenFlags() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _hasUnseenCancellation = prefs.getBool('unseenCancelled_${widget.currentUserId}') ?? false;
      _hasUnseenConfirmation = prefs.getBool('unseenConfirmed_${widget.currentUserId}') ?? false;
      _hasUnseenCompletion = prefs.getBool('unseenCompleted_${widget.currentUserId}') ?? false;
      _recalculateNotificationCount();
    }
  }

  // General setter for the unseen flag
  Future<void> _setUnseenFlag(String keyFlag, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFlag, value);
    if (mounted) {
      setState(() {
        if (keyFlag.contains('Cancelled')) _hasUnseenCancellation = value;
        if (keyFlag.contains('Confirmed')) _hasUnseenConfirmation = value;
        if (keyFlag.contains('Completed')) _hasUnseenCompletion = value;
        _recalculateNotificationCount();
      });
    }
  }
  
  // Recalculates the total badge count based on active notifications
  void _recalculateNotificationCount() {
    if (mounted) {
        setState(() {
          int statusBadges = 0;
          
          if (_hasUnseenCancellation && _latestCancelledBookingId > 0) statusBadges++;
          if (_hasUnseenConfirmation && _latestConfirmedBookingId > 0) statusBadges++;
          if (_hasUnseenCompletion && _latestCompletedBookingId > 0) statusBadges++;
          
          // The count represents all unique notification flags (status updates + imminent returns)
          notificationCount = imminentReturnsCount + statusBadges; 
        });
    }
  }

  // Wrapper function to handle polling and state updates
  Future<void> _fetchAndForceUpdate({bool isPolling = false}) async {
    await _loadLastSeenIds(); 
    await _fetchActiveBookingsAndNotifications(isPolling: isPolling);
    
    if (mounted) {
      // Small delay to ensure setState is called after the async data fetch completes
      Future.delayed(Duration.zero, () {
        if (mounted) {
            _recalculateNotificationCount();
            setState(() {});
        }
      });
    }
  }
  // --- END PERSISTENCE HELPERS ---

  // --- PARALLEL LOADING IMPLEMENTATION ---
  Future<void> _loadInitialData() async {
    // 1. Load local profile image synchronously first (very fast)
    await _loadLocalProfileImage();

    // 2. Run all other heavy/async operations in parallel
    await Future.wait([
      _fetchUserDetails(),
      _checkLoginStatus(),
      _loadLastSeenIds(), // Use combined load
      _fetchActiveBookingsAndNotifications(),
    ]);
  }
  // --- END PARALLEL LOADING ---

  Future<void> _loadLocalProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('profileImageUrl_${widget.currentUserId}');
    if (savedUrl != null && savedUrl.isNotEmpty && mounted) {
      setState(() => profilePictureUrl = savedUrl);
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    });
  }
  
  // Helper to format DateTime for display
  String _formatDateTime(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString);
      // Use intl package for formatting
      return DateFormat('MMM d, h:mm a').format(dateTime); 
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse(
          "https://agriease.helioho.st/public_html/get_user.php?user_id=${widget.currentUserId}&_=$timestamp"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["success"] == true && data["user"] != null && mounted) {
          
          String? fetchedUrl; 
          final profilePicName = data["user"]["profile_picture"];

          if (profilePicName != null && profilePicName.toString().isNotEmpty) {
            fetchedUrl =
                "https://agriease.helioho.st/public_html/agri_images_profile/${profilePicName}?v=$timestamp";
          } 

          setState(() {
            username = data["user"]["name"] ?? "Unknown User";
            
            if (fetchedUrl != null) {
              profilePictureUrl = fetchedUrl;
            } else if (profilePictureUrl == null) {
              profilePictureUrl = null; 
            }
          });

          final prefs = await SharedPreferences.getInstance();
          if (fetchedUrl != null) {
            await prefs.setString('profileImageUrl_${widget.currentUserId}', fetchedUrl);
          }
          
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => username = "Network error");
      }
    }
  }
  
  Future<void> _fetchActiveBookingsAndNotifications({bool isPolling = false}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse(
          "https://agriease.helioho.st/public_html/agri_web/get_bookings.php?renter_id=${widget.currentUserId}&_=$timestamp"));

      if (response.statusCode == 200) {
        final bookings = json.decode(response.body);
        if (bookings is List && mounted) {
          final now = DateTime.now();
          final tomorrow = now.add(const Duration(days: 1));
          
          int newImminentReturnsCount = 0;
          
          // Reset highest found IDs before processing
          int highestCancelledId = 0;
          int highestConfirmedId = 0;
          int highestCompletedId = 0;
          
          final updatedActiveBookings = [];
          
          for (final booking in bookings) {
            final status = booking['booking_status']?.toString().toLowerCase() ?? '';
            final endTimeString = booking['end_time']?.toString();
            final bookingId = int.tryParse(booking['booking_id']?.toString() ?? '0') ?? 0;
            
            // a) Check for imminent returns
            if (status == 'confirmed' && endTimeString != null) {
              try {
                final endTime = DateTime.parse(endTimeString);
                final bool isDueToday = endTime.year == now.year &&
                    endTime.month == now.month &&
                    endTime.day == now.day;
                final bool isDueTomorrow = endTime.year == tomorrow.year &&
                    endTime.month == tomorrow.month &&
                    endTime.day == tomorrow.day;
                if (isDueToday || isDueTomorrow) {
                  newImminentReturnsCount++;
                }
              } catch (e) {
                // Ignore parsing errors
              }
            }
            
            // b) Find the highest ID for all three statuses
            if (status.contains('cancelled') && bookingId > highestCancelledId) {
                highestCancelledId = bookingId;
            } else if (status.contains('confirmed') && bookingId > highestConfirmedId) {
                highestConfirmedId = bookingId;
            } else if (status.contains('completed') && bookingId > highestCompletedId) {
                highestCompletedId = bookingId;
            }

            // c) Determine which bookings are truly active for the list view
            if (status != 'completed' && status != 'cancelled') {
              updatedActiveBookings.add(booking);
            }
          }
          
          setState(() {
            imminentReturnsCount = newImminentReturnsCount;
            activeBookings = updatedActiveBookings;
            _latestCancelledBookingId = highestCancelledId; 
            _latestConfirmedBookingId = highestConfirmedId;
            _latestCompletedBookingId = highestCompletedId;
          });
          
          // --- 3. Manage Persistent Status Flags ---
          if (isPolling) {
              // Notify only for NEWER IDs found than the last seen ID
              if (highestCancelledId > _lastSeenCancelledBookingId) {
                  await _setUnseenFlag('unseenCancelled_${widget.currentUserId}', true);
              }
              if (highestConfirmedId > _lastSeenConfirmedBookingId) {
                  await _setUnseenFlag('unseenConfirmed_${widget.currentUserId}', true);
              }
              if (highestCompletedId > _lastSeenCompletedBookingId) {
                  await _setUnseenFlag('unseenCompleted_${widget.currentUserId}', true);
              }
          }
          
          _recalculateNotificationCount();
        }
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
    }
  }

  // REFRESH FIX: This sequence ensures the image is loaded from local cache immediately
  Future<void> _refreshData() async {
    // Stop the timer briefly during refresh to prevent conflict
    _pollingTimer.cancel(); 
    await _loadLocalProfileImage(); 
    await _fetchActiveBookingsAndNotifications();
    await _fetchUserDetails();
    // Restart the timer
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchAndForceUpdate(isPolling: true);
    });
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      final url = Uri.parse(
          "https://agriease.helioho.st/public_html/agri_web/update_booking_status.php");
      final response = await http.post(
        url,
        body: {
          "booking_id": bookingId,
          "status": "cancelled",
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result["success"] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Booking cancelled successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }
          final cancelledId = int.tryParse(bookingId) ?? 0;
          if (cancelledId > 0) {
            // Dismiss locally initiated cancellation notification immediately
            await _setLastSeenId('Cancelled', cancelledId);
          }
          await _fetchAndForceUpdate(isPolling: false); 
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result["message"] ?? "Cancel failed"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error cancelling booking: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error cancelling booking"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (isLoggedIn) {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return false;
    }
    return true;
  }

  // UPDATED FUNCTION
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber.shade700;
      case 'confirmed':
        return Colors.green.shade600;
      case 'cancelled': 
        return Colors.red.shade700; 
      case 'completed':
        return const Color(0xFF4B5320); // Primary Green
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
      case 'completed': // Added specific completed icon
        return Icons.task_alt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // Helper to build a notification row for any status
  Widget _buildStatusNotificationRow({
    required String status,
    required bool hasUnseen,
    required int latestId,
    required Color color,
    required IconData icon,
    required String message,
  }) {
    if (!hasUnseen) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 2),
            child: Icon(icon, color: color, size: 18),
          ),
          Expanded(
            child: Text(
              '$message (ID: $latestId).',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Dismiss the specific notification
              _setLastSeenId(status, latestId);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen height here to constrain the notification panel
    final screenHeight = MediaQuery.of(context).size.height;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFBF4), // Off-White Background
        body: SafeArea(
          child: FutureBuilder(
            future: _loadInitialDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4B5320)), // Primary Green
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        "Failed to load data. Please try again.",
                        style: TextStyle(color: Colors.red[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loadInitialDataFuture = _loadInitialData();
                          });
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              } else {
                return RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFF4B5320), // Primary Green
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Stack(
                      children: [
                        // --- 1. HEADER IMAGE AND BUTTONS (BOTTOM LAYER) ---
                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  "https://agriease.helioho.st/public_html/agri_images/dashboard.png",
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: Colors.grey[300]);
                                  },
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Image.network(
                                    "https://agriease.helioho.st/public_html/agri_images/logo.jpg",
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
                                          onPressed: () {
                                            // MODIFIED: Navigate directly to NotificationsPage on bell press
                                            // FIX: Dismiss ALL persistent status notifications before navigating
                                            if (_hasUnseenCancellation) _setLastSeenId('Cancelled', _latestCancelledBookingId);
                                            if (_hasUnseenConfirmation) _setLastSeenId('Confirmed', _latestConfirmedBookingId);
                                            if (_hasUnseenCompletion) _setLastSeenId('Completed', _latestCompletedBookingId);

                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NotificationsPage(currentUserId: widget.currentUserId),
                                                ),
                                            );
                                          },
                                        ),
                                        if (notificationCount > 0)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                              child: const Text(
                                                '!',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Profile(currentUserId: widget.currentUserId, onLogout: () {  },), 
                                          ),
                                        );
                                        // This correctly forces refresh on return
                                        await _refreshData();
                                      },
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.white,
                                        // Uses the profilePictureUrl state variable
                                        backgroundImage: profilePictureUrl != null ? NetworkImage(profilePictureUrl!) : null,
                                        child: profilePictureUrl == null ? const Icon(Icons.person, color: Color(0xFF4B5320), size: 24) : null, // Primary Green
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 50,
                                left: 16,
                                right: 16,
                                child: Text(
                                  "Welcome, $username!",
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [Shadow(blurRadius: 2.0, color: Colors.black45)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // --- 2. MAIN CONTENT WRAPPER (MIDDLE LAYER) ---
                        Padding(
                          padding: const EdgeInsets.only(top: 190.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFFCFBF4), // Off-White Background
                              borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Browse(currentUserId: widget.currentUserId))),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD2B48C), // Button Tan
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                          ),
                                          child: const Text("Browse Equipment", style: TextStyle(color: Color(0xFF4B5320), fontWeight: FontWeight.bold, fontSize: 16)), // Primary Green Text
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await Navigator.push(context, MaterialPageRoute(builder: (_) => Booking(currentUserId: widget.currentUserId, onBookingUpdate: _refreshData)));
                                            _refreshData();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD2B48C), // Button Tan
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                          ),
                                          child: const Text("Booking History", style: TextStyle(color: Color(0xFF4B5320), fontWeight: FontWeight.bold, fontSize: 16)), // Primary Green Text
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text("Active Bookings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4B5320))), // Primary Green
                                  ),
                                  if (activeBookings.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text("No active bookings found.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: activeBookings.length,
                                      itemBuilder: (context, index) {
                                        final booking = activeBookings[index];
                                        final status = booking['booking_status']?.toString().toLowerCase() ?? '';

                                        // Retrieve Quantity using the new 'quantity' key
                                        final quantity = booking['quantity']?.toString() ?? 'N/A';
                                        
                                        return Card(
                                          color: const Color(0xFFFAF9F6), // Light Cream Card
                                          margin: const EdgeInsets.only(bottom: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ExpansionTile(
                                            leading: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 30),
                                            title: Text(
                                              booking['equip_name']?.toString() ?? 'Unknown Name',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                            ),
                                            subtitle: Text(
                                              "Status: ${status.replaceAll('_', ' ')}",
                                              style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  children: [
                                                    _buildDetailRow("Booking ID", booking['booking_id'].toString()),
                                                    _buildDetailRow("Start", _formatDateTime(booking['start_time'].toString())), // Use helper function
                                                    _buildDetailRow("End", _formatDateTime(booking['end_time'].toString())),  // Use helper function
                                                    // Display the Quantity here
                                                    _buildDetailRow("Quantity", "$quantity Units"),
                                                    _buildDetailRow("Total", "₱${booking['total_price'].toString()}"),
                                                    _buildDetailRow("Address", booking['delivery_address']?.toString() ?? "N/A"),
                                                    if (status == 'pending') ...[
                                                      const SizedBox(height: 8),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton.icon(
                                                          onPressed: () => _cancelBooking(booking['booking_id'].toString()),
                                                          icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                                                          label: const Text("Cancel Booking", style: TextStyle(color: Colors.white)),
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), // Deep Red
                                                        ),
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // --- 3. NOTIFICATION PANEL (TOP LAYER - REMOVED, LOGIC FORMERLY HERE) ---
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54))),
          const Text(": ", style: TextStyle(color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
        ],
      ),
    );
  }
}