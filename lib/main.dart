// main.dart
import 'package:blizzard_vpn/screens/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', 'IR'), // فارسی
      ],
      locale: const Locale('fa', 'IR'),
      debugShowCheckedModeBanner: false,
      title: 'Blizzard VPN',
      theme: ThemeData(
        fontFamily: 'SM', // استفاده از فونت سفارشی
        brightness: Brightness.light,
        // تعریف ColorScheme جدید
        colorScheme: ColorScheme.light(
          primary: const Color(
            0xFF007BFF,
          ), // Keep a strong blue for primary actions
          onPrimary: Colors.white,
          secondary: const Color(
            0xFF00C896,
          ), // A slightly softer, more harmonious green/turquoise
          onSecondary: Colors.white,
          surface: Colors.white, // For cards, dialogs, etc.
          onSurface: Colors.black87,
          background: const Color(
            0xFFF8F9FA,
          ), // A very light grey for main backgrounds
          onBackground: Colors.black87,
          error: Colors.redAccent,
          onError: Colors.white,
          // Custom colors for success and warning
          tertiary: const Color(0xFF28A745), // Success (Green)
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFFC107), // Warning (Yellow)
          onTertiaryContainer: Colors.black87,
        ),
        scaffoldBackgroundColor: const Color(
          0xFFF8F9FA,
        ), // رنگ پس‌زمینه Scaffold
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF007BFF),
          foregroundColor: Colors.white,
          elevation: 0, // حذف سایه زیر AppBar
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'SM',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              12,
            ), // Consistent with input fields
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Start with no visible border
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ), // Subtle border
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ), // Highlight on focus
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          hintStyle: TextStyle(color: Colors.grey[500], fontFamily: 'SM'),
          labelStyle: TextStyle(color: Colors.grey[700], fontFamily: 'SM'),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: const Color(0xFF007BFF), // آیکون‌ها به رنگ Primary
          textColor: Colors.black87,
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
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontFamily: 'SM',
          ),
          actionTextColor: const Color(0xFF03DAC6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF007BFF),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontFamily: 'SM',
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontFamily: 'SM'),
          elevation: 8,
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
