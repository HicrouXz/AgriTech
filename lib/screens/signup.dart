import 'dart:async'; // Import for Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  bool isLoading = false;
  bool isCodeSent = false;
  bool _isPasswordVisible = false;

  // --- Timer Variables Updated for 5 Minutes (300 seconds) ---
  Timer? _timer;
  int _resendCountdown = 0; 
  final int _resendDurationSeconds = 300; // <<< Changed to 300 seconds (5 minutes)
  // -----------------------------------------------------------

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // --- New Timer Method ---
  void startTimer() {
    // Stop any existing timer
    _timer?.cancel();
    // Reset countdown and start from the full duration
    _resendCountdown = _resendDurationSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown < 1) {
        timer.cancel();
        if (mounted) {
          setState(() {}); // Trigger rebuild to enable the Resend button
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
        }
      }
    });
  }
  // ---------------------------

  Future<void> signUp() async {
    // ... [Security Validation code remains the same]
    String password = passController.text.trim();
    String username = userController.text.trim();
    String email = emailController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address (e.g., name@email.com)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 8 characters long."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must contain at least one special character (e.g., ! @ # \$ &)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    // ---------------------------------------------------------

    setState(() => isLoading = true);

    try {
      final url = Uri.parse("https://agriease.helioho.st/public_html/signup.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": username,
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ??
                  "Registration successful! Check your email for the verification code.")),
        );
        setState(() {
          isCodeSent = true;
          isLoading = false;
        });
        startTimer(); // <<< START THE TIMER ON SUCCESSFUL SIGNUP
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Signup failed")),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // --- Resend Code Function ---
  Future<void> resendCode() async {
    if (_resendCountdown > 0 || isLoading) return; // Prevent spamming/while loading

    setState(() => isLoading = true);

    try {
      final url = Uri.parse("https://agriease.helioho.st/public_html/resend_code.php"); // <<< NEW PHP ENDPOINT
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? "New verification code sent!")),
        );
        startTimer(); // <<< START THE TIMER AGAIN ON SUCCESS
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed to resend code.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Resend Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  // ------------------------------------

  Future<void> verifyCode() async {
    setState(() => isLoading = true);

    if (codeController.text.trim().length != 6) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit code.")),
      );
      return;
    }

    try {
      final verificationUrl =
          Uri.parse("https://agriease.helioho.st/public_html/verify_email.php");

      final response = await http.post(
        verificationUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "code": codeController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? "Email verified successfully!")),
        );
        _timer?.cancel(); // Stop timer on successful verification
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(data['message'] ?? "Verification failed. Invalid code.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSignUpForm() {
    // ... [Unchanged _buildSignUpForm code]
    return Column(
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
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.eco,
                  color: Colors.green,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Sign Up",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: userController,
          decoration: InputDecoration(
            hintText: "Username",
            prefixIcon:
                const Icon(Icons.person_outline, color: Color(0xFF1B5E20)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: "Email",
            prefixIcon:
                const Icon(Icons.email_outlined, color: Color(0xFF1B5E20)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: "Password",
            prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFF1B5E20)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: const Color(0xFF1B5E20),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : signUp,
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
                    "Sign Up",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Already have an account?",
              style: TextStyle(color: Colors.black54),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text(
                "Login",
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerificationForm() {
    final String rawEmail = emailController.text.trim();
    String displayEmail = rawEmail;

    if (rawEmail.contains('@')) {
      final parts = rawEmail.split('@');
      final localPart = parts[0];
      final domainPart = parts[1];
      final int visibleLength = 3;
      final int showLength = visibleLength > localPart.length ? localPart.length : visibleLength;
      final String maskedLocalPart = localPart.substring(0, showLength) + "***";
      displayEmail = "$maskedLocalPart@$domainPart";
    }

    // Format countdown time (e.g., 04:59)
    String minutes = (_resendCountdown ~/ 60).toString().padLeft(2, '0');
    String seconds = (_resendCountdown % 60).toString().padLeft(2, '0');
    String countdownText = '$minutes:$seconds';

    bool isResendEnabled = _resendCountdown <= 0 && !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.mark_email_read_outlined,
            size: 80, color: Color(0xFF388E3C)),
        const SizedBox(height: 24),
        const Text(
          "Verify Email",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 32,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "We sent a 6-digit code to $displayEmail. Please check your inbox.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 36),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "000000",
            counterText: "",
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : verifyCode,
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
                    "Verify Code",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // --- Countdown and Resend Button ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Resend code in:",
              style: TextStyle(
                color: Colors.black54,
                fontWeight: isResendEnabled ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: isResendEnabled ? resendCode : null,
              child: Text(
                isResendEnabled ? "Resend Now" : countdownText,
                style: TextStyle(
                  color: isResendEnabled
                      ? const Color(0xFF1B5E20) // Enabled color
                      : Colors.red.shade400, // Disabled countdown color
                  fontWeight: FontWeight.bold,
                  decoration: isResendEnabled ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
        // ------------------------------------
        const SizedBox(height: 10),
        TextButton(
          onPressed: isLoading
              ? null
              : () {
                  setState(() => isCodeSent = false);
                },
          child: Text(
            "Back to Registration",
            style: TextStyle(
              color: isLoading ? Colors.black38 : const Color(0xFF1B5E20),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAEF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: isCodeSent ? _buildVerificationForm() : _buildSignUpForm(),
          ),
        ),
      ),
    );
  }
}