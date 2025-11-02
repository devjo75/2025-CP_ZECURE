import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/services/firebase_service.dart';
import 'package:zecure/screens/landing_screen.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/desktop/desktop_landing_screen.dart';

// Global flag to detect logout
bool isLoggingOut = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // For web builds, use dart-define values directly
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  // Fallback to .env for development
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    await dotenv.load(fileName: ".env");
  }

  // ✅ Initialize Firebase (skip on web - notifications not supported)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      print('✅ Firebase initialized successfully');
      
      // ✅ Initialize Firebase Service (notifications) - mobile only
      await FirebaseService().initialize();
      print('✅ Firebase Service initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
    }
  } else {
    print('⚠️ Running on web - Firebase push notifications disabled');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl.isNotEmpty ? supabaseUrl : dotenv.env['SUPABASE_URL']!,
    anonKey: supabaseAnonKey.isNotEmpty ? supabaseAnonKey : dotenv.env['SUPABASE_ANON_KEY']!,
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
        // Add route generation for web navigation
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  // Handle web routes
  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/map':
        return MaterialPageRoute(builder: (_) => const MapScreen());
      case '/confirm':
        return MaterialPageRoute(builder: (_) => const EmailConfirmationScreen());
      case '/landing':
        return MaterialPageRoute(builder: (_) => const ResponsiveLandingScreen());
      default:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
    }
  }
}

/// ✅ New Responsive Landing wrapper
class ResponsiveLandingScreen extends StatelessWidget {
  const ResponsiveLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return const DesktopLandingScreen();
    } else {
      return const LandingScreen();
    }
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeUrlHandling();
    
    // ✅ Only setup auth listener on mobile (Firebase not available on web)
    if (!kIsWeb) {
      _setupAuthListener();
    }
  }

  Future<void> _initializeUrlHandling() async {
    // Temporarily disabled URL handling for mobile compatibility
    // await UrlHandler.handleUrlOnAppStart();
    
    setState(() {
      _isInitialized = true;
    });
  }

  // ✅ Setup auth listener to handle FCM token on login/logout (mobile only)
  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      
      if (session != null) {
        // User logged in - save FCM token
        _saveFCMToken();
      } else {
        // User logged out - clear FCM token
        _clearFCMToken();
      }
    });
  }

  // ✅ Save FCM token when user logs in (mobile only)
  Future<void> _saveFCMToken() async {
    if (kIsWeb) return; // Skip on web
    
    try {
      final token = FirebaseService().fcmToken;
      if (token != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('users')
              .update({
                'fcm_token': token,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('email', user.email!);
          
          print('✅ FCM token saved for user: ${user.email}');
        }
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // ✅ Clear FCM token when user logs out (mobile only)
  Future<void> _clearFCMToken() async {
    if (kIsWeb) return; // Skip on web
    
    try {
      await FirebaseService().clearToken();
      print('✅ FCM token cleared on logout');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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

        // ✅ Default: not logged in → use Responsive Landing
        return const ResponsiveLandingScreen();
      },
    );
  }
}

// Email confirmation screen (simplified without URL handler)
class EmailConfirmationScreen extends StatefulWidget {
  const EmailConfirmationScreen({super.key});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _isProcessing = true;
  bool _isSuccess = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _processConfirmation();
  }

  Future<void> _processConfirmation() async {
    try {
      // Give time for auth state to update
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to refresh the session to pick up any auth changes
      await Supabase.instance.client.auth.refreshSession();
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        setState(() {
          _isSuccess = true;
          _message = 'Email confirmed successfully! Welcome to Zecure!';
          _isProcessing = false;
        });
        
        // Show success message then redirect to map
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          }
        });
      } else {
        setState(() {
          _isSuccess = false;
          _message = 'Email confirmation failed or link has expired.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = 'An error occurred during confirmation. Please try again.';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LIGHT.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.3),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(40),
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/zecure.png',
                    height: 80,
                    width: 80,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (_isProcessing) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    const Text(
                      'Confirming your email...',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we verify your account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Icon(
                      _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 80,
                      color: _isSuccess ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSuccess ? 'Email Confirmed!' : 'Confirmation Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    if (!_isSuccess) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Go to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LandingScreen()),
                          );
                        },
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        'Redirecting to your dashboard...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}