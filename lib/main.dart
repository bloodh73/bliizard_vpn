import 'package:blizzard_vpn/screens/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:blizzard_vpn/screens/home_page.dart';
import 'package:blizzard_vpn/screens/login_page.dart';
import 'package:blizzard_vpn/screens/server_selection_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'V2Ray Client',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(
            0xFF6200EE,
          ), // Deep purple for primary actions/branding
          onPrimary: Colors.white,
          secondary: const Color(
            0xFF03DAC6,
          ), // Teal for accents and secondary actions
          onSecondary: Colors.black,
          error: Colors.redAccent, // For error states
          onError: Colors.white,
          background: const Color(0xFF121212), // Dark background
          onBackground: Colors.white,
          surface: const Color(
            0xFF1E1E1E,
          ), // Slightly lighter surface for cards, dialogs
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: Color(
          0xFF121212,
        ), // Consistent with background
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E), // AppBar matches surface
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0, // Flat app bar for modern look
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(
              0xFF6200EE,
            ), // Primary color for elevated buttons
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Rounded buttons
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(
              0xFF03DAC6,
            ), // Secondary color for text buttons
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // No border by default
          ),
          filled: true,
          fillColor: const Color(0xFF2C2C2C), // Fill color for input fields
          labelStyle: TextStyle(color: Colors.grey[400]),
          hintStyle: TextStyle(color: Colors.grey[600]),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
        // Add more specific themes for other widgets as needed
        listTileTheme: ListTileThemeData(
          iconColor: Colors.white70,
          textColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: const Color(0xFF03DAC6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) {
          final session = Supabase.instance.client.auth.currentSession;
          return session == null ? const LoginPage() : const HomePage();
        },
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/server_selection': (context) => const ServerSelectionPage(),
        '/admin': (context) => const AdminPage(),
      },
    );
  }
}
