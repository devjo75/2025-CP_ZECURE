import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/screens/landing_screen.dart';
import 'package:zecure/screens/auth/login_screen.dart';

// Global flag to detect logout
bool isLoggingOut = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ZecureApp());
}

class ZecureApp extends StatelessWidget {
  const ZecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HotspotFilterService(),
      child: MaterialApp(
        title: 'Zecure',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // Logged in → MapScreen
          return const MapScreen();
        }

        if (isLoggingOut) {
          // If just logged out → go to LoginScreen instead of Landing
          isLoggingOut = false; // Reset for next time
          return const LoginScreen();
        }

        // Default: not logged in → LandingScreen
        return const LandingScreen();
      },
    );
  }
}
