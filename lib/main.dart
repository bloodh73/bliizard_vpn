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
          primary: const Color(0xFF007BFF), // یک آبی جذاب برای Primary
          onPrimary: Colors.white,
          secondary: const Color(
            0xFF03DAC6,
          ), // یک فیروزه‌ای روشن برای Secondary
          onSecondary: Colors.black,
          surface: Colors.white, // رنگ پس‌زمینه کارت‌ها و سطوح
          onSurface: Colors.black87,
          background: const Color(0xFFF0F2F5), // رنگ پس‌زمینه کلی برنامه
          onBackground: Colors.black87,
          error: Colors.redAccent,
          onError: Colors.white,
          // اضافه کردن رنگ‌های اضافی برای وضعیت‌ها
          tertiary: const Color(0xFF28A745), // رنگ سبز برای موفقیت
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFFC107), // رنگ زرد برای هشدار
          onTertiaryContainer: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(
          0xFFF0F2F5,
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
          elevation: 4, // افزایش سایه کارت‌ها
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // گوشه‌های گردتر
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white, // رنگ پس‌زمینه کارت
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          buttonColor: const Color(0xFF007BFF),
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(
              double.infinity,
              50,
            ), // دکمه‌های با ارتفاع بیشتر و تمام عرض
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            elevation: 5,
            textStyle: const TextStyle(
              fontFamily: 'SM',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF007BFF),
            textStyle: const TextStyle(fontFamily: 'SM', fontSize: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // حذف BorderSide پیش‌فرض
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(
                0xFFE0E0E0,
              ), // یک رنگ خاکستری روشن برای border غیرفعال
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF007BFF), // رنگ Primary برای border فعال
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: TextStyle(fontFamily: 'SM', color: Colors.grey[700]),
          hintStyle: TextStyle(fontFamily: 'SM', color: Colors.grey[500]),
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
