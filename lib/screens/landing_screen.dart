import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';
import 'dart:async';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _featureController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _featureScaleAnimation;
  
  // Carousel controllers
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    
    // Initialize existing animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _featureController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _featureScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _featureController,
      curve: Curves.elasticOut,
    ));

    // Initialize carousel
    _pageController = PageController(viewportFraction: 0.85);
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Delayed feature animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _featureController.forward();
    });
    
    // Start auto-play
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && mounted) {
        final nextPage = (_currentPage + 1) % _getFeatures().length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _featureController.dispose();
    _pageController.dispose();
    _stopAutoPlay();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFeatures() {
    return [
      {
        'icon': Icons.map_rounded,
        'title': 'Live Safety Map',
        'description': 'See current unsafe areas and safe zones in your neighborhood on an easy-to-read map',
        'color': Colors.blue,
        'gradient': [Colors.blue.shade400, Colors.blue.shade600],
      },
      {
        'icon': Icons.psychology_rounded,
        'title': 'Smart Safety Alerts',
        'description': 'Get helpful warnings about areas to avoid based on recent incidents and reports',
        'color': Colors.purple,
        'gradient': [Colors.purple.shade400, Colors.purple.shade600],
      },
      {
        'icon': Icons.route_rounded,
        'title': 'Safe Route Finder',
        'description': 'Find the safest paths to your destination using current safety information',
        'color': Colors.green,
        'gradient': [Colors.green.shade400, Colors.green.shade600],
      },
      {
        'icon': Icons.notification_important_rounded,
        'title': 'Instant Safety Alerts',
        'description': 'Get quick notifications about safety concerns happening near you',
        'color': Colors.orange,
        'gradient': [Colors.orange.shade400, Colors.orange.shade600],
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Community Reports',
        'description': 'Share safety information and mark safe places to help your neighbors',
        'color': Colors.teal,
        'gradient': [Colors.teal.shade400, Colors.teal.shade600],
      },
      {
        'icon': Icons.shield_rounded,
        'title': 'For Everyone',
        'description': 'Made for all Zamboanga families, police officers, and local government',
        'color': Colors.indigo,
        'gradient': [Colors.indigo.shade400, Colors.indigo.shade600],
      },
    ];
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
                  
                  SizedBox(height: isWeb ? 60 : 40),
                  
                  // Enhanced Features Section with Carousel
                  ScaleTransition(
                    scale: _featureScaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildEnhancedFeaturesSection(isWeb, screenWidth),
                    ),
                  ),
                  
                  SizedBox(height: isWeb ? 60 : 40),
                  
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
    final double maxWidth = isWeb ? 700 : screenWidth * 0.95;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isWeb ? 24 : 12),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              // Logo without shadow and expanded size
              Image.asset(
                'assets/images/zecure.png',
                height: isWeb ? 150 : 130,
                width: isWeb ? 150 : 130,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: isWeb ? 150 : 130,
                  width: isWeb ? 150 : 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(75),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: isWeb ? 90 : 80,
                    color: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(height: isWeb ? 20 : 12),
              
              // Main Title with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ).createShader(bounds),
                child: Text(
                  'Welcome to Zecure',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 38 : 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
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

  Widget _buildEnhancedFeaturesSection(bool isWeb, double screenWidth) {
    final features = _getFeatures();
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: isWeb ? 30 : 20),
      child: Column(
        children: [
          // Section Title
          Text(
            'How Zecure Keeps You Safe',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Discover powerful features designed for your safety',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 16 : 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isWeb ? 30 : 25),
          
          // Carousel Section with expanded width
          SizedBox(
            width: double.infinity,
            height: isWeb ? 280 : 220,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: features.length,
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 0;
                    if (_pageController.position.haveDimensions) {
                      value = index.toDouble() - (_pageController.page ?? 0);
                      value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                    } else {
                      value = index == 0 ? 1.0 : 0.7;
                    }
                    
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: _buildEnhancedFeatureCard(features[index], isWeb, screenWidth),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 18),
          
          // Pagination Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(features.length, (index) {
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index 
                      ? Colors.blue.shade600 
                      : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 15),
          
          // Auto-play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  _stopAutoPlay();
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: Icon(Icons.chevron_left, color: Colors.blue.shade600),
              ),
              IconButton(
                onPressed: () {
                  if (_autoPlayTimer?.isActive == true) {
                    _stopAutoPlay();
                  } else {
                    _startAutoPlay();
                  }
                  setState(() {});
                },
                icon: Icon(
                  _autoPlayTimer?.isActive == true ? Icons.pause : Icons.play_arrow,
                  color: Colors.blue.shade600,
                ),
              ),
              IconButton(
                onPressed: () {
                  _stopAutoPlay();
                  if (_currentPage < features.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: Icon(Icons.chevron_right, color: Colors.blue.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildEnhancedFeatureCard(Map<String, dynamic> feature, bool isWeb, double screenWidth) {
  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: isWeb ? 8 : 6,
      vertical: isWeb ? 12 : 8, // <-- Added top & bottom margin for breathing space
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Colors.grey.shade50,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: feature['color'].withOpacity(0.08),
          blurRadius: 15,
          spreadRadius: -8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    feature['color'].withOpacity(0.08),
                    feature['color'].withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: feature['gradient'],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: feature['color'].withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    feature['icon'],
                    color: Colors.white,
                    size: isWeb ? 28 : 24,
                  ),
                ),
                SizedBox(height: isWeb ? 20 : 16),
                Text(
                  feature['title'],
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: isWeb ? 10 : 8),
                Text(
                  feature['description'],
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildCallToAction(bool isWeb, double screenWidth) {
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
              
              // Login Button with enhanced design
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
onPressed: () {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
    (Route<dynamic> route) => false, // Remove all previous routes
  );
},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
              ),
              
              const SizedBox(height: 12),
              
              // Guest Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
onPressed: () {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const MapScreen()),
    (Route<dynamic> route) => false, // Remove all previous routes
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