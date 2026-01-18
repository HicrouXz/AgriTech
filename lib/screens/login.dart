// ignore_for_file: unused_catch_clause
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'home.dart'; // Assuming you have a home.dart file

// ----------------------
// 🚨 FORGOT PASSWORD URL
// ----------------------
const String forgotPasswordUrl = 
    "http://agriease.helioho.st/public_html/forgot_password.php"; 

class Login extends StatefulWidget {
  // onLoginSuccess is kept but currently unused for the primary navigation path
  final Future<void> Function(String userId) onLoginSuccess; 
  const Login({super.key, required this.onLoginSuccess});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isLoading = false;
  bool isForgotLoading = false;
  
  // --- ADDED THIS LINE ---
  bool _isPasswordVisible = false; 

  @override
  void initState() {
    super.initState();
  }

  // --- LOGIN FUNCTION ---
  Future<void> login() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse("http://agriease.helioho.st/public_html/login.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passController.text.trim(),
        }),
      );

      // Check for non-200 status or empty body before decoding
      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        throw Exception("Server Error (Status ${response.statusCode}) or Empty Response.");
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final user = data['user'];
        final userId = user['id'].toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', userId);
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Home(
                currentUserId: userId,
                onLogout: () {}, // Replace with actual logout logic
              )),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Login failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Error: $e")),
      );
    } finally {
      if(mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- FORGOT PASSWORD FUNCTION (with FormatException fix) ---
  Future<void> handleForgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address above to reset your password.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => isForgotLoading = true);

    try {
      final url = Uri.parse(forgotPasswordUrl);
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      // Check for non-200 status codes (e.g., 500, 404)
      if (response.statusCode != 200) {
         throw Exception("Server Error (Status ${response.statusCode}). Check PHP environment/logs.");
      }

      // 🚨 CRITICAL: jsonDecode will throw a FormatException if it sees the "<br />" or other non-JSON output.
      final data = jsonDecode(response.body); 

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? "Failed to process request."),
          backgroundColor: data['status'] == 'success' ? Colors.green : Colors.red,
        ),
      );
      
    } on FormatException catch (e) {
      if (!mounted) return;
      // Specific error message for the JSON decoding failure
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Server sent corrupted data. Check PHP script for stray characters/whitespace."),
              backgroundColor: Colors.red,
          ),
      );
      
    } catch (e) {
      if (!mounted) return;
      // Generic catch-all for network errors, timeouts, and other exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reset Request Error: ${e.toString()}")),
      );
    } finally {
      if(mounted) {
        setState(() => isForgotLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FAEF),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.network(
                          "https://agriease.helioho.st/public_html/agri_images/logo.jpg",
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.eco,
                              color: Colors.green,
                              size: 48,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Login",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF1B5E20)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- MODIFIED PASSWORD TEXTFIELD ---
                  TextField(
                    controller: passController,
                    obscureText: !_isPasswordVisible, // <-- CHANGED
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Color(0xFF1B5E20)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      // --- ADDED THIS SUFFIXICON ---
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Color(0xFF1B5E20),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  // FORGOT PASSWORD LINK with loading indicator
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isForgotLoading ? null : handleForgotPassword,
                      child: isForgotLoading
                          ? const SizedBox(
                              width: 20, 
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)))
                          : const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Login",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an Account? ",
                        style: TextStyle(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/signup'),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}