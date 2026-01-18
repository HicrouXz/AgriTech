// lib/screens/booking.dart

// ignore_for_file: unused_element, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Enum for filter options
enum _TimePeriod { all, today, thisWeek, thisMonth, thisYear }

class Booking extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onBookingUpdate;

  const Booking({super.key, required this.currentUserId, this.onBookingUpdate});

  @override
  State<Booking> createState() => _BookingState();
}

class _BookingState extends State<Booking> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  List<Map<String, dynamic>> _allBookings = []; // Holds the unfiltered, fetched list
  
  // State variables for sorting and filtering
  bool _sortAscending = false;
  _TimePeriod _selectedPeriod = _TimePeriod.all;

  // --- TAB CONTROLLER AND LABELS ---
  late final TabController _tabController; 
  final List<String> _tabLabels = [
    "Confirmed",
    "Completed",
    "Cancelled",
  ];
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookingsAndSort();
    // Initialize TabController here, as it requires 'vsync: this'
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


// --- DATA LOADING & SORTING ---

  // Unified loading and sorting logic
  Future<List<Map<String, dynamic>>> _loadBookingsAndSort() async {
    final list = await fetchBookings();
    setState(() {
      _allBookings = list;
      _sortBookings(_allBookings); // Sort the fetched list initially
    });
    return _allBookings;
  }
  
  /**
   * Sorts the provided list of bookings based on the start date/time.
   */
  void _sortBookings(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return;

    list.sort((a, b) {
      final dateA = DateTime.tryParse(a["start_time"]?.toString() ?? '1970-01-01T00:00:00Z') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b["start_time"]?.toString() ?? '1970-01-01T00:00:00Z') ?? DateTime(1970);
      final comparison = dateA.compareTo(dateB);
      return _sortAscending ? comparison : -comparison;
    });
  }

  /**
   * Toggles the sort order and refreshes the UI.
   */
  void _toggleSortOrder() {
    setState(() {
      _sortAscending = !_sortAscending;
      _sortBookings(_allBookings);
    });
  }

  /**
   * Filters the master list (_allBookings) based on the selected time period.
   */
  List<Map<String, dynamic>> _getFilteredBookings() {
    if (_selectedPeriod == _TimePeriod.all) {
      return _allBookings;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime startTime;

    switch (_selectedPeriod) {
      case _TimePeriod.today:
        startTime = today;
        break;
      case _TimePeriod.thisWeek:
        startTime = today.subtract(Duration(days: today.weekday - 1));
        break;
      case _TimePeriod.thisMonth:
        startTime = DateTime(now.year, now.month, 1);
        break;
      case _TimePeriod.thisYear:
        startTime = DateTime(now.year, 1, 1);
        break;
      default:
        return _allBookings;
    }

    return _allBookings.where((booking) {
      final bookingTime = DateTime.tryParse(booking["start_time"]?.toString() ?? '') ?? DateTime(1970);
      
      if (bookingTime.isBefore(startTime)) {
        return false;
      }

      if (_selectedPeriod == _TimePeriod.today) {
        final tomorrow = today.add(const Duration(days: 1));
        return bookingTime.isBefore(tomorrow);
      }
      
      return true;
    }).toList();
  }


  Future<List<Map<String, dynamic>>> fetchBookings() async {
    try {
      final url = Uri.parse(
          "https://agriease.helioho.st/public_html/agri_web/get_bookings.php?renter_id=${widget.currentUserId}&timestamp=${DateTime.now().millisecondsSinceEpoch}");

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          if (data.isNotEmpty && data[0] is Map && data[0].containsKey('error')) {
            throw data[0]['error'];
          }
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('error')) {
          throw data['error'];
        }
        return [];
      } else {
        throw Exception('Failed to load bookings. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading bookings: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

// --- UI HELPER METHODS ---

  String _formatDateTime(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus.contains('cancel')) {
      return Colors.red.shade400; // RED for cancelled status
    }

    switch (normalizedStatus) {
      case 'pending':
        return const Color.fromARGB(255, 255, 153, 0); // Orange/Yellow
      case 'confirmed':
        return const Color.fromARGB(255, 0, 189, 44); // Green
      case 'completed':
      case 'returned':
        return const Color.fromARGB(255, 6, 214, 221); // Cyan
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _getStatusIcon(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    if (normalizedStatus.contains('cancel')) {
      return Icons.cancel_rounded; // Cancel icon
    }

    switch (normalizedStatus) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'completed':
      case 'returned':
        return Icons.task_alt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // Utility to convert enum to display string
  String _periodToString(_TimePeriod period) {
    switch (period) {
      case _TimePeriod.all: return "All Time";
      case _TimePeriod.today: return "Today";
      case _TimePeriod.thisWeek: return "This Week";
      case _TimePeriod.thisMonth: return "This Month";
      case _TimePeriod.thisYear: return "This Year";
    }
  }
  
  // Helper function to map tab label to filter string
  String _getStatusFilterForTab(String tabLabel) {
    switch (tabLabel) {
      case "Confirmed":
        return "confirmed";
      case "Completed":
        return "completed";
      case "Cancelled":
        // Using '|' to indicate an OR condition in the filter logic
        return "cancel|returned";
      default:
        return "";
    }
  }


// --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              // Using the same dark green color from the Browse header
              colors: [Color(0xFF4B5320), Color(0xFF4B5320)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text("Booking History"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _bookingsFuture = _loadBookingsAndSort();
              });
            },
          ),
        ],
        // --- TabBar Implementation with Custom Indicator ---
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
          isScrollable: true,
          
          labelColor: Colors.white, // Changed to white for dark AppBar background
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white70,

          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Colors.white, // Changed indicator color to white
              width: 2.0,
            ),
            insets: EdgeInsets.symmetric(horizontal: 16.0),
          ),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      // MODIFIED: Set background to light cream color
      backgroundColor: const Color.fromARGB(255, 250, 248, 239),
      // --- TabBarView to display content for each tab ---
      body: TabBarView(
        controller: _tabController,
        children: _tabLabels.map((label) {
          return _buildTabContent(label); // Content for each tab
        }).toList(),
      ),
    );
  }


  /**
   * Builds the content for a specific tab, including the filter/sort controls
   * and the booking list, filtered by the tab's status and time period.
   */
  Widget _buildTabContent(String tabLabel) {
    final String statusFilter = _getStatusFilterForTab(tabLabel);

    // Filter the master list (_allBookings, already filtered by time period)
    // using the combined time and status filter.
    final filteredBookings = _getFilteredBookings().where((booking) {
      final status = booking["booking_status"]?.toString().toLowerCase().trim() ?? "pending";
      
      // Handle combined status filter (e.g., "cancel|returned")
      if (statusFilter.contains('|')) {
        final parts = statusFilter.split('|');
        return parts.any((part) => status.contains(part));
      }
      // Handle single status filter (e.g., "confirmed", "completed")
      else if (statusFilter.isNotEmpty) {
        // Use exact match for clarity on core statuses
        return status.contains(statusFilter);
      }
        
      return false; // Bookings without a defined status/filter are excluded from tabs
    }).toList();
    
    // UI variables for the controls
    final IconData sortIcon = _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final String sortLabel = _sortAscending ? "Oldest First" : "Newest First";

    return Column(
      children: [
        // --- FILTER & SORT CONTROLS ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. FILTER DROPDOWN
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_TimePeriod>(
                      value: _selectedPeriod,
                      icon: const Icon(Icons.filter_list, color: Colors.black, size: 20),
                      dropdownColor: Colors.white, // Changed dropdown color to white
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      onChanged: (_TimePeriod? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedPeriod = newValue;
                          });
                        }
                      },
                      items: _TimePeriod.values.map((_TimePeriod period) {
                        return DropdownMenuItem<_TimePeriod>(
                          value: period,
                          child: Text(
                            _periodToString(period),
                            style: const TextStyle(color: Colors.black87), // Ensure dropdown item text is dark
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 2. SORT BUTTON
              Tooltip(
                message: "Sort by Start Date: $sortLabel",
                child: ElevatedButton.icon(
                  onPressed: _allBookings.isNotEmpty ? _toggleSortOrder : null,
                  icon: Icon(sortIcon, size: 18, color: const Color(0xFF4B5320)), // Icon color set to dark green
                  label: Text(sortLabel, style: const TextStyle(fontSize: 14, color: Colors.black)), // Label color set to black
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // Button background set to white
                    elevation: 0, // Ensure no elevation
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      // REMOVED THE BORDER SIDE (OUTLINE)
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // --- BOOKINGS LIST ---
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _bookingsFuture, // Check if initial data load is complete
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!)));
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text("Error Loading Bookings", style: TextStyle(color: Colors.black87, fontSize: 18)), // Changed text color
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _bookingsFuture = _loadBookingsAndSort();
                          });
                        },
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                );
              } else if (_allBookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text("No Bookings Found", style: TextStyle(color: Colors.black87, fontSize: 18)), // Changed text color
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _bookingsFuture = _loadBookingsAndSort();
                          });
                        },
                        child: const Text("Refresh"),
                      ),
                    ],
                  ),
                );
              } else if (filteredBookings.isEmpty) {
                // Empty list after filtering by tab and period
                return Center(
                  child: Text(
                    "No $tabLabel Bookings for ${_periodToString(_selectedPeriod)}",
                    style: const TextStyle(color: Colors.black87, fontSize: 18), // Changed text color
                    textAlign: TextAlign.center,
                  ),
                );
              } else {
                // Display the filtered and sorted list
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _bookingsFuture = _loadBookingsAndSort();
                    });
                    await _bookingsFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(filteredBookings[index]);
                    },
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }


  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final String status = booking["booking_status"]?.toString() ?? "pending";
    // ignore: unused_local_variable
    final bool isCompleted = status.toLowerCase() == 'completed' || status.toLowerCase() == 'returned';
    
    final Color statusColor = _getStatusColor(status);
    final IconData statusIcon = _getStatusIcon(status);

    final String equipmentDisplayName = booking["equipment_name"]?.toString() ?? booking["equipment_type"]?.toString() ?? "Unknown Equipment";

    return Card(
      color: Colors.white, // MODIFIED: Card background set to white
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black12, width: 0.5), // Added subtle border
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipmentDisplayName,
                        style: const TextStyle(
                          color: Colors.black, // MODIFIED: Text color set to black
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "ID: ${booking["booking_id"]?.toString() ?? "N/A"}",
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 14), // MODIFIED: Text color set to black54
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Start", _formatDateTime(booking["start_time"]?.toString())),
                _buildDetailRow("End", _formatDateTime(booking["end_time"]?.toString())),
                _buildDetailRow("Quantity", "${booking["quantity"]?.toString() ?? "N/A"} Units"),
                _buildDetailRow("Total", "₱${booking["total_price"]?.toString() ?? "0"}"),
                _buildDetailRow("Address", booking["delivery_address"]?.toString() ?? "N/A"),
                const SizedBox(height: 16),

                // --- ACTION BUTTONS ROW ---
                Row(
                  children: [
                    // 1. DETAILS Button
                    ElevatedButton.icon(
                      onPressed: () {
                        _showBookingDetails(booking);
                      },
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text("Details"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200], // MODIFIED: Button background set to light gray
                        foregroundColor: Colors.black87, // MODIFIED: Button foreground set to dark gray
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.black12, width: 0.5),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 14), // MODIFIED: Text color set to dark
            ),
          ),
          const Text(": ", style: TextStyle(color: Colors.black54)), // MODIFIED: Text color set to dark
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600), // MODIFIED: Text color set to black
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // MODIFIED: Dialog background set to white
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Booking Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), // MODIFIED: Text color set to black
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Equipment",
                  booking["equipment_name"]?.toString() ?? "N/A"),
              _buildDetailRow("Type",
                  booking["equipment_type"]?.toString() ?? "N/A"),
              _buildDetailRow("Quantity", "${booking["quantity"]?.toString() ?? "N/A"} Units"),
              _buildDetailRow(
                  "Status", booking["booking_status"]?.toString() ?? "N/A"),
              _buildDetailRow("Total", "₱${booking["total_price"]?.toString() ?? "0"}"),
              _buildDetailRow("Start Date", _formatDateTime(booking["start_time"]?.toString())),
              _buildDetailRow("End Date", _formatDateTime(booking["end_time"]?.toString())),
              _buildDetailRow("Booking ID", booking["booking_id"]?.toString() ?? "N/A"),
              _buildDetailRow("Created", _formatDateTime(booking["created_at"]?.toString())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialogPlaceholder(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // MODIFIED: Dialog background set to white
        title: const Text("Rate Your Experience", style: TextStyle(color: Colors.black)), // MODIFIED: Text color set to black
        content: Text(
          "Ready to rate your booking for '${booking["equipment_name"]}' (ID: ${booking["booking_id"]})!",
          style: const TextStyle(color: Colors.black54), // MODIFIED: Text color set to dark
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement actual rating logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Rating feature coming soon!"), backgroundColor: Colors.green),
              );
            },
            child: const Text("Start Rating"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }
}