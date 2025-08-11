import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40.0 : 16.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  // Hero Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildHeroSection(isWeb, screenWidth),
                    ),
                  ),
                  
                  SizedBox(height: isWeb ? 40 : 24),
                  
                  // Features Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildFeaturesSection(isWeb, screenWidth),
                  ),
                  
                  SizedBox(height: isWeb ? 40 : 24),
                  
                  // Call to Action
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCallToAction(isWeb, screenWidth),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isWeb, double screenWidth) {
    // Expanded width for hero content
    final double maxWidth = isWeb ? 700 : screenWidth * 0.95;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isWeb ? 24 : 12),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              // Logo without shadow
              Image.asset(
                'assets/images/zecure.png',
                height: isWeb ? 120 : 100,
                width: isWeb ? 120 : 100,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: isWeb ? 120 : 100,
                  width: isWeb ? 120 : 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: isWeb ? 70 : 60,
                    color: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(height: isWeb ? 20 : 12),
              
              // Main Title
              Text(
                'Welcome to Zecure',
                style: GoogleFonts.poppins(
                  fontSize: isWeb ? 38 : 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Your Safety Companion for Zamboanga City',
                style: GoogleFonts.poppins(
                  fontSize: isWeb ? 18 : 15,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isWeb ? 16 : 10),
              
              // Description
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Stay safe with live crime updates, smart route suggestions, and community safety reports. Built to help protect Zamboanga City families through community cooperation.',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 16 : 14,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(bool isWeb, double screenWidth) {
    final features = [
      {
        'icon': Icons.map_rounded,
        'title': 'Live Safety Map',
        'description': 'See current unsafe areas and safe zones in your neighborhood on an easy-to-read map'
      },
      {
        'icon': Icons.psychology_rounded,
        'title': 'Smart Safety Alerts',
        'description': 'Get helpful warnings about areas to avoid based on recent incidents and reports'
      },
      {
        'icon': Icons.route_rounded,
        'title': 'Safe Route Finder',
        'description': 'Find the safest paths to your destination using current safety information'
      },
      {
        'icon': Icons.notification_important_rounded,
        'title': 'Instant Safety Alerts',
        'description': 'Get quick notifications about safety concerns happening near you'
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Community Reports',
        'description': 'Share safety information and mark safe places to help your neighbors'
      },
      {
        'icon': Icons.shield_rounded,
        'title': 'For Everyone',
        'description': 'Made for all Zamboanga families, police officers, and local government'
      },
    ];

    // Expanded width for features section
    final double maxWidth = isWeb ? 1000 : screenWidth * 0.95;

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Text(
                'How Zecure Keeps You Safe',
                style: GoogleFonts.poppins(
                  fontSize: isWeb ? 26 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isWeb ? 32 : 24),
              
              if (isWeb)
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: features
                      .map((feature) => _buildFeatureCard(feature, isWeb, screenWidth))
                      .toList(),
                )
              else
                Column(
                  children: features
                      .map((feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildFeatureCard(feature, isWeb, screenWidth),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, bool isWeb, double screenWidth) {
    // Expanded width for feature cards
    final double cardWidth = isWeb ? 300 : screenWidth * 0.92;
    
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature['icon'],
              color: Colors.blue.shade600,
              size: 26,
            ),
          ),
          
          const SizedBox(height: 14),
          
          Text(
            feature['title'],
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 6),
          
          Text(
            feature['description'],
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallToAction(bool isWeb, double screenWidth) {
    // Expanded width for call to action section
    final double maxWidth = isWeb ? 600 : screenWidth * 0.95;
    
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Text(
                'Ready to Make Zamboanga Safer?',
                style: GoogleFonts.poppins(
                  fontSize: isWeb ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Join our community of safety-conscious citizens and help create a safer Zamboanga City.',
                style: GoogleFonts.poppins(
                  fontSize: isWeb ? 16 : 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isWeb ? 28 : 20),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'Get Started - Login',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Guest Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.explore_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'Explore as Guest',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}