// ignore_for_file: unused_local_variable, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// Import your other pages
import 'equipment_sub_browse_page.dart';
import 'checkout_page.dart';

class Browse extends StatefulWidget {
  final String currentUserId;

  const Browse({super.key, required this.currentUserId});

  @override
  State<Browse> createState() => _BrowseState();
}

class _BrowseState extends State<Browse> {
  bool isCardView = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool showSuggestions = false;

  List<Map<String, dynamic>> allEquipment = [];
  List<Map<String, dynamic>> filteredEquipment = [];
  late Future<void> _fetchEquipmentFuture;
  List<String> suggestionList = [];

  @override
  void initState() {
    super.initState();
    _fetchEquipmentFuture = _fetchEquipment();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) setState(() => showSuggestions = false);
    });
  }

  // FETCHER: Returns Future<void> so RefreshIndicator works
  Future<void> _fetchEquipment() async {
    const String url =
        "https://agriease.helioho.st/public_html/browse_equipment.php";
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final Map<String, Map<String, dynamic>> groupedItems = {};
        for (var equip in data) {
          final String categoryName = equip['name']; // This is the Category (e.g. Tractors)
          
          if (!groupedItems.containsKey(categoryName)) {
            groupedItems[categoryName] = {
              "name": categoryName,
              "types": [],
              "color": _getColorForCategory(categoryName),
              "icon": _getIconForCategory(categoryName),
            };
          }
          groupedItems[categoryName]!['types'].add(equip);
        }

        if (mounted) {
          setState(() {
            allEquipment = groupedItems.values.toList();
            
            // If the user is currently searching, re-run the filter on the new data
            if (_searchController.text.isNotEmpty) {
              _filterItems(_searchController.text);
            } else {
              filteredEquipment = List.from(allEquipment);
            }
          });
        }
      } else {
        throw Exception('Failed to load equipment: HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar("Request timed out.", isError: true);
      }
    } catch (e) {
      debugPrint('Error fetching equipment: $e');
      if (mounted) {
        _showSnackBar("Failed to load equipment data.", isError: true);
      }
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case "Tractors": return Colors.teal[200]!;
      case "Plows": return Colors.pink[200]!;
      case "Sprayers": return Colors.green[300]!;
      case "Sickles": return Colors.brown[200]!;
      case "Trucks": return Colors.red[200]!;
      case "Cultivators": return Colors.blueGrey[200]!;
      default: return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case "Tractors": return Icons.agriculture;
      case "Plows": return Icons.construction;
      case "Sprayers": return Icons.local_drink;
      case "Sickles": return Icons.grass;
      case "Trucks": return Icons.local_shipping;
      case "Cultivators": return Icons.grass;
      default: return Icons.category;
    }
  }

  // SEARCH LOGIC: Now checks specific 'equip_name' inside the types list
  void _filterItems(String query) {
    final lower = query.toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        filteredEquipment = List.from(allEquipment);
        suggestionList = [];
        showSuggestions = false;
        return;
      }

      filteredEquipment = allEquipment.where((item) {
        // 1. Check if Category Name matches (e.g. "Tractors")
        final categoryName = item['name'].toString().toLowerCase();
        
        // 2. Check if any Item inside this category matches (e.g. "Kubota")
        final hasMatchingType = (item['types'] as List).any((t) {
          final type = t['type'].toString().toLowerCase(); // e.g. "Mini Tractor"
          final equipName = (t['equip_name'] ?? '').toString().toLowerCase(); // e.g. "Kubota L5018"
          
          return type.contains(lower) || equipName.contains(lower);
        });

        return categoryName.contains(lower) || hasMatchingType;
      }).toList();

      // SUGGESTIONS: Flatten the list to show specific names in dropdown
      suggestionList = allEquipment
          .expand((item) => [
                item['name'] as String, // Add Category Name
                ...(item['types'] as List).expand((t) {
                  return [
                    t['type'] as String, // Add Type
                    if (t['equip_name'] != null) t['equip_name'] as String // Add Specific Name
                  ];
                })
              ])
          .toSet() // Remove duplicates
          .where((k) => k.toLowerCase().contains(lower))
          .take(6)
          .toList();
          
      showSuggestions = suggestionList.isNotEmpty;
    });
  }

  void _selectSuggestion(String text) async {
    _searchController.text = text;
    _filterItems(text);
    setState(() => showSuggestions = false);
    FocusScope.of(context).unfocus();

    final lowerText = text.toLowerCase();
    
    // 1. Try to find a matching Category
    final category = allEquipment.firstWhere(
      (item) => item['name'].toString().toLowerCase() == lowerText,
      orElse: () => {},
    );

    if (category.isNotEmpty) {
      _navigateToSubBrowse(category);
      return;
    }

    // 2. Try to find a matching Specific Item
    for (var item in allEquipment) {
      final types = List<Map<String, dynamic>>.from(item['types']);
      
      final match = types.firstWhere(
        (t) => 
          t['type'].toString().toLowerCase() == lowerText || 
          (t['equip_name'] ?? '').toString().toLowerCase() == lowerText,
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        _navigateToCheckout(item, match);
        return;
      }
    }
  }

  Future<void> _navigateToSubBrowse(Map<String, dynamic> category) async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EquipmentSubBrowsePage(
            title: category['name'],
            types: List<Map<String, dynamic>>.from(category['types']),
            color: category['color'],
            icon: category['icon'],
            currentUserId: widget.currentUserId,
          ),
        ),
      );
      if (result == true) {
        _showRefreshSnackbar();
        _fetchEquipment();
      }
  }

  Future<void> _navigateToCheckout(Map<String, dynamic> category, Map<String, dynamic> item) async {
      final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPage(
              key: ValueKey(widget.currentUserId),
              equipmentName: item['equip_name'] ?? item['type'],
              equipmentType: category['name'],
              equipmentDescription: item['description'],
              equipmentId: item['equipment_id'].toString(),
              pricePerHectare:
                  double.tryParse(item['price_per_hectare'] ?? '0.0') ?? 0.0,
              color: category['color'],
              icon: category['icon'],
              currentUserId: widget.currentUserId,
              imageUrl: item['image_url'],
            ),
          ),
        );
        if (result == true) {
          _showRefreshSnackbar();
          _fetchEquipment();
        }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  void _showRefreshSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ New booking placed. Check your bookings tab!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 241, 221),
      body: SafeArea(
        child: FutureBuilder(
          future: _fetchEquipmentFuture,
          builder: (context, snapshot) {
            // Only show loading if we have NO data yet
            if (snapshot.connectionState == ConnectionState.waiting && allEquipment.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError && allEquipment.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 80, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      "Failed to load equipment data.",
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _fetchEquipmentFuture = _fetchEquipment();
                        });
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
            } else {
              return Stack(
                children: [
                  Column(
                    children: [
                      // --- HEADER SECTION ---
                      Container(
                        height: 150,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B5320),
                          image: const DecorationImage(
                            image: NetworkImage(
                                "https://agriease.helioho.st/public_html/agri_images/dashboard.png"),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            opacity: 0.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  height: 50,
                                  child: Image.network(
                                    "https://agriease.helioho.st/public_html/agri_images/logo.jpg",
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.error,
                                            color: Colors.red, size: 32),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                "Browse Equipment",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      
                      // --- SEARCH BAR ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _filterItems,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Search (e.g. Kubota, Tractor)...',
                            hintStyle: const TextStyle(color: Colors.black45),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF4B5320)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // --- VIEW TOGGLE ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => isCardView = true),
                              child: Text(
                                "Card View",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isCardView
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCardView ? const Color(0xFF4B5320) : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => isCardView = false),
                              child: Text(
                                "List View",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: !isCardView
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: !isCardView ? const Color(0xFF4B5320) : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- LIST CONTENT (With Refresh) ---
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchEquipment,
                          color: const Color(0xFF4B5320),
                          child: isCardView
                              ? buildCardView(filteredEquipment)
                              : buildListView(filteredEquipment),
                        ),
                      ),
                    ],
                  ),

                  // --- SUGGESTIONS DROPDOWN ---
                  if (showSuggestions && suggestionList.isNotEmpty)
                    Positioned(
                      top: 220, // Position relative to Search Bar
                      left: 16,
                      right: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: suggestionList.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.black12, height: 1),
                            itemBuilder: (context, i) {
                              final s = suggestionList[i];
                              return ListTile(
                                dense: true,
                                title: Text(s,
                                    style:
                                        const TextStyle(color: Colors.black87)),
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // Helper widget for Card View
  Widget buildCardView(List<Map<String, dynamic>> list) {
    // Wrapped in ListView to ensure Pull-to-Refresh always works
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final category = list[index];
            return InkWell(
              onTap: () => _navigateToSubBrowse(category),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: category["color"],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(category["icon"], size: 40, color: Colors.black),
                    const SizedBox(height: 10),
                    Text(
                      category["name"],
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Helper widget for List View
  Widget buildListView(List<Map<String, dynamic>> list) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final category = list[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(category["icon"], color: const Color(0xFF4B5320), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          category["name"].toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                (category["types"] as List).length,
                (i) => GestureDetector(
                  onTap: () => _navigateToCheckout(category, category["types"][i]),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                        children: [
                          Icon(category["icon"], size: 18, color: const Color(0xFF4B5320)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${category["types"][i]['equip_name'] ?? category["types"][i]['type']}",
                              style:
                                  const TextStyle(fontSize: 16, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "₱${category["types"][i]['price_per_hectare']}/ha",
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}