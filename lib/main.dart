import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/home.dart';
import 'screens/map.dart';
import 'screens/add.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userId = prefs.getString('userId') ?? '';

  runApp(AgriTechApp(
    isLoggedIn: isLoggedIn,
    userId: userId,
  ));
}

class AgriTechApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userId;

  const AgriTechApp({super.key, required this.isLoggedIn, required this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriTech',
      theme: ThemeData(primarySwatch: Colors.green),

      home: isLoggedIn
          ? Home(currentUserId: userId, onLogout: () {})
          : const Welcome(),

      // using MaterialPageRoute to ensure the correct userId is passed.
      routes: {
        // Routes that do not depend on a logged-in user can stay.
        '/welcome': (context) => const Welcome(),
        '/login': (context) => Login(onLoginSuccess: (String newUserId) async {
          // After login, navigate directly to Home with the NEW user ID
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Home(currentUserId: newUserId, onLogout: () {}),
            ),
          );
        }),
        '/signup': (context) => SignUp(),
        '/map': (context) => MapPage(),
        '/add': (context) => Add(),
      },
    );
  }
}
    