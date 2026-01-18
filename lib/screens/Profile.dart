// lib/screens/profile.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'land_address_model.dart'; // Import the model
import 'address_dialogs.dart'; // Import the dialogs
import 'login.dart';

/// PROFILE PAGE
class Profile extends StatefulWidget {
  final String currentUserId;

  const Profile(
      {Key? key, required this.currentUserId, required Null Function() onLogout})
      : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with WidgetsBindingObserver {
  final List<LandAddress> _addresses = [];
  String userName = "Username";
  String userEmail = "user@example.com";
  String? profileImageUrl;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalProfileImage();
    _fetchData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  Future<void> _loadLocalProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('profileImageUrl_${widget.currentUserId}');
    if (savedUrl != null && savedUrl.isNotEmpty && mounted) {
      setState(() => profileImageUrl = savedUrl);
    }
  }

  Future<void> _saveProfileImageUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImageUrl_${widget.currentUserId}', url);
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;
    await _loadUserInfo();
    await _loadAddresses();
    _isFetching = false;
  }

  Future<void> _loadUserInfo() async {
    try {
      final url = Uri.parse(
          "https://agriease.helioho.st/public_html/get_user.php?user_id=${widget.currentUserId}&t=${DateTime.now().millisecondsSinceEpoch}");
      final response = await http.get(url);

      if (mounted && response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            userName = data['user']['name'] ?? userName;
            userEmail = data['user']['email'] ?? userEmail;
            final pic = data['user']['profile_picture'];
            if (pic != null && pic.toString().isNotEmpty) {
              profileImageUrl =
                  "https://agriease.helioho.st/public_html/agri_images_profile/${pic.toString()}?v=${DateTime.now().millisecondsSinceEpoch}";
              _saveProfileImageUrl(profileImageUrl!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user info: $e");
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final url = Uri.parse(
          "http://agriease.helioho.st/public_html/fetch_addresses.php?user_id=${widget.currentUserId}");
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          setState(() {
            _addresses.clear();
            _addresses.addAll(decoded.map((e) => LandAddress.fromJson(e)));
          });
        } else if (decoded is Map && decoded['addresses'] is List) {
          setState(() {
            _addresses.clear();
            _addresses.addAll(
                (decoded['addresses'] as List).map((e) => LandAddress.fromJson(e)));
          });
        } else {
          setState(() => _addresses.clear());
        }
      } else {
        setState(() => _addresses.clear());
      }
    } catch (e) {
      debugPrint("Error fetching addresses: $e");
      if (mounted) {
        setState(() => _addresses.clear());
      }
    }
  }

  // EDIT USER INFO
  Future<void> _editUserInfo() async {
    TextEditingController nameController = TextEditingController(text: userName);
    TextEditingController emailController =
        TextEditingController(text: userEmail);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: "Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                  labelText: "Email", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final url = Uri.parse(
                  "http://agriease.helioho.st/public_html/update_user.php");
              try {
                final response = await http.post(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({
                    "user_id": widget.currentUserId,
                    "name": nameController.text,
                    "email": emailController.text,
                  }),
                );
                final data = json.decode(response.body);
                if (!context.mounted) return;
                if (data['success'] == true) {
                  setState(() {
                    userName = nameController.text;
                    userEmail = emailController.text;
                  });
                  Navigator.pop(context);
                  await _loadUserInfo();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile updated")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(data['message'] ?? "Failed to update profile"),
                  ));
                }
              } catch (e) {
                debugPrint("Update user error: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Failed to update profile")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // LOGOUT
  Future<void> _logout() async {
    try {
      final url =
          Uri.parse("http://agriease.helioho.st/public_html/logout.php");
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('isLoggedIn');
          await prefs.remove('userId');

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) =>
                      Login(onLoginSuccess: (String userId) async {})),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? "Logout failed")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Logout error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Logout failed")));
      }
    }
  }

  void _chooseImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 85);

      if (image != null) {
        await _uploadProfileImage(File(image.path));
        await _loadUserInfo();
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to pick image")),
        );
      }
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse(
            "http://agriease.helioho.st/public_html/upload_profile_picture.php"),
      );

      request.fields['user_id'] = widget.currentUserId;
      request.files.add(await http.MultipartFile.fromPath(
        'profile_picture',
        imageFile.path,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        final data = json.decode(respStr);

        if (data['success'] == true && data['file'] != null) {
          final newUrl =
              "http://agriease.helioho.st/public_html/${data['file']}?v=${DateTime.now().millisecondsSinceEpoch}";
          if (mounted) {
            setState(() {
              profileImageUrl = newUrl;
            });
          }
          await _saveProfileImageUrl(newUrl);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile picture updated")));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['message'] ?? "Failed to upload picture")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Upload failed")));
        }
      }
    } catch (e) {
      debugPrint("Error uploading profile image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Error uploading image")));
      }
    }
  }

  // DELETE ADDRESS
  Future<void> _removeAddress(String id) async {
    try {
      final url =
          Uri.parse("http://agriease.helioho.st/public_html/delete_address.php");
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: json.encode({"id": id}));

      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _loadAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Address removed")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? "Failed to delete")));
        }
      }
    } catch (e) {
      debugPrint("Delete address error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete address")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DESIGN: Use a lighter, cleaner color scheme
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 107, 153, 132),
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // DESIGN: Use a white card for a clean look
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              profileImageUrl != null && profileImageUrl!.isNotEmpty
                                  ? NetworkImage(profileImageUrl!)
                                  : null,
                          child: profileImageUrl == null || profileImageUrl!.isEmpty
                              ? Icon(Icons.person,
                                  color: Colors.grey.shade400, size: 30)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _chooseImageSource,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            // DESIGN: Bolder text for name
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            // DESIGN: Subtler color for email
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DESIGN: Simplified edit and logout buttons
                    IconButton(
                      icon: Icon(Icons.edit_note, color: Colors.blue.shade700),
                      onPressed: _editUserInfo,
                      tooltip: 'Edit Profile',
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.red.shade700),
                      onPressed: _logout,
                      tooltip: 'Log Out',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Saved Addresses Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("Saved Addresses",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                            onPressed: () => showAddAddressDialog(
                                  context: context,
                                  currentUserId: widget.currentUserId,
                                  onAddressAdded: _loadAddresses,
                                ),
                            icon: Icon(Icons.add_circle,
                                color: Colors.blue.shade700, size: 28)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _addresses.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(child: Text("No addresses saved yet.", style: TextStyle(color: Colors.grey))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _addresses.length,
                            itemBuilder: (context, index) {
                              final land = _addresses[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(land.ownerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    "${land.address}\nArea: ${land.area} ${land.unit} (${land.areaInSqm.toStringAsFixed(0)} sqm)"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => showEditAddressDialog(
                                        context: context,
                                        land: land,
                                        onAddressUpdated: _loadAddresses,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeAddress(land.id),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(context, land.toJson());
                                },
                              );
                            },
                            separatorBuilder: (context, index) => const Divider(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}