import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  
  runApp(MainApp(hasToken: token != null && token.isNotEmpty));
}

class MainApp extends StatelessWidget {
  final bool hasToken;
  
  const MainApp({super.key, required this.hasToken});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tickets SSP',
      home: hasToken ? const MainScreen() : const LoginScreen(),
    );
  }
}

