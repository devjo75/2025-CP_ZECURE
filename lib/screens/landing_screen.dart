// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zecure/auth/login_screen.dart';
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
  bool _showDevelopersModal = false;
  PageController? _modalPageController; // ADD THIS
  int _currentDeveloperIndex = 0; // ADD THIS
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _featureScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _featureController, curve: Curves.elasticOut),
    );

    // Initialize carousel
    _pageController = PageController(viewportFraction: 0.85);

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Delayed feature animation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _featureController.forward();
    });
    _modalPageController = PageController();
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
    _modalPageController?.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFeatures() {
    return [
      {
        'icon': Icons.map_rounded,
        'title': 'Live Safety Map',
        'description':
            'See current unsafe areas and safe zones in your neighborhood on an easy-to-read map',
        'color': Colors.blue,
        'gradient': [Colors.blue.shade400, Colors.blue.shade600],
      },
      {
        'icon': Icons.forum_rounded,
        'title': 'Report Discussions',
        'description':
            'Share additional details and context on verified incidents through discussion threads',
        'color': Colors.purple,
        'gradient': [Colors.purple.shade400, Colors.purple.shade600],
      },
      {
        'icon': Icons.route_rounded,
        'title': 'Safe Route Finder',
        'description':
            'Find the safest paths to your destination avoiding high-crime areas',
        'color': Colors.green,
        'gradient': [Colors.green.shade400, Colors.green.shade600],
      },
      {
        'icon': Icons.notification_important_rounded,
        'title': 'Instant Safety Alerts',
        'description':
            'Get quick notifications about verified safety concerns happening near you',
        'color': Colors.orange,
        'gradient': [Colors.orange.shade400, Colors.orange.shade600],
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Community Reports',
        'description':
            'Share safety information and mark safe places to help your neighbors',
        'color': Colors.teal,
        'gradient': [Colors.teal.shade400, Colors.teal.shade600],
      },
      {
        'icon': Icons.shield_rounded,
        'title': 'Police Verified',
        'description':
            'All reports are checked and verified by police officers before being shown',
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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/LIGHT.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.2),
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
                            child: _buildEnhancedFeaturesSection(
                              isWeb,
                              screenWidth,
                            ),
                          ),
                        ),
                        SizedBox(height: isWeb ? 60 : 40),
                        // Call to Action
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildCallToAction(isWeb, screenWidth),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(height: isWeb ? 60 : 50),
                        _buildFooter(isWeb, screenWidth, this),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Developers Modal
          if (_showDevelopersModal) _buildDevelopersModal(isWeb),
        ],
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
                "Your Guide to a Safer Zamboanga",
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

          // Carousel Section with responsive width
          Center(
            child: SizedBox(
              width: isWeb ? math.min(screenWidth * 0.7, 800) : double.infinity,
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
                          child: _buildEnhancedFeatureCard(
                            features[index],
                            isWeb,
                            screenWidth,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
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
                  _autoPlayTimer?.isActive == true
                      ? Icons.pause
                      : Icons.play_arrow,
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

  Widget _buildEnhancedFeatureCard(
    Map<String, dynamic> feature,
    bool isWeb,
    double screenWidth,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isWeb ? 8 : 6,
        vertical: isWeb
            ? 12
            : 8, // <-- Added top & bottom margin for breathing space
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
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
                      gradient: LinearGradient(colors: feature['gradient']),
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
                        // ignore: deprecated_member_use
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
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (Route<dynamic> route) =>
                            false, // Remove all previous routes
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
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                      (Route<dynamic> route) =>
                          false, // Remove all previous routes
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

  Widget _buildDevelopersModal(bool isWeb) {
    final developers = [
      {
        'name': 'Venard Jhon C. Salido',
        'role': 'Full Stack Developer',
        'image': 'assets/images/venard.jpg',
        'portfolio': 'https://venardjhoncsalido.free.nf/',
      },
      {
        'name': 'Alekxiz T. Solis',
        'role': 'Frontend Developer & Documentation',
        'image': 'assets/images/alekxiz.jpg',
        'portfolio': 'https://alekxizsolis.netlify.app/',
      },
      {
        'name': 'Jo Louis B. Sardani',
        'role': 'Frontend Developer & Documentation',
        'image': 'assets/images/jo.jpg',
        'portfolio': 'https://jolouis-portfolio.netlify.app/',
      },
    ];

    // Initialize a fresh controller if needed
    if (_modalPageController == null) {
      _modalPageController = PageController(initialPage: 0);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showDevelopersModal = false;
          _currentDeveloperIndex = 0;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isWeb ? 60 : 20,
                vertical: 20, // Add vertical margin
              ),
              constraints: BoxConstraints(
                maxWidth: isWeb ? 500 : double.infinity,
                maxHeight:
                    MediaQuery.of(context).size.height *
                    0.85, // Limit to 85% of screen height
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isWeb ? 20 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.purple.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isWeb ? 10 : 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.code_rounded,
                            color: Colors.white,
                            size: isWeb ? 24 : 20,
                          ),
                        ),
                        SizedBox(width: isWeb ? 12 : 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meet the Developers',
                                style: GoogleFonts.poppins(
                                  fontSize: isWeb ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: isWeb ? 2 : 1),
                              Text(
                                '${_currentDeveloperIndex + 1} of ${developers.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: isWeb ? 12 : 11,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showDevelopersModal = false;
                              _currentDeveloperIndex = 0;
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          iconSize: isWeb ? 24 : 22,
                        ),
                      ],
                    ),
                  ),

                  // Developer Card with PageView - Make it flexible
                  Flexible(
                    fit: FlexFit.loose,
                    child: PageView.builder(
                      controller: _modalPageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentDeveloperIndex = index;
                        });
                      },
                      itemCount: developers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.all(isWeb ? 20 : 16),
                          child: _buildDeveloperCard(developers[index], isWeb),
                        );
                      },
                    ),
                  ),

                  // Navigation Controls
                  Padding(
                    padding: EdgeInsets.only(
                      left: isWeb ? 20 : 16,
                      right: isWeb ? 20 : 16,
                      bottom: isWeb ? 20 : 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous Button
                        IconButton(
                          onPressed: _currentDeveloperIndex > 0
                              ? () {
                                  if (_modalPageController != null &&
                                      _modalPageController!.hasClients) {
                                    _modalPageController!.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: _currentDeveloperIndex > 0
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                          ),
                          iconSize: 32,
                        ),

                        // Page Indicators
                        Row(
                          children: List.generate(developers.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentDeveloperIndex == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentDeveloperIndex == index
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        // Next Button
                        IconButton(
                          onPressed:
                              _currentDeveloperIndex < developers.length - 1
                              ? () {
                                  if (_modalPageController != null &&
                                      _modalPageController!.hasClients) {
                                    _modalPageController!.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color:
                                _currentDeveloperIndex < developers.length - 1
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                          ),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(Map<String, dynamic> developer, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive image height based on available space
        final availableHeight = constraints.maxHeight;
        final imageHeight = (availableHeight * 0.7).clamp(
          250.0,
          450.0,
        ); // Increased from 0.65 to 0.7

        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Add this
              children: [
                // Photo
                Container(
                  height: imageHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: Image.asset(
                      developer['image'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: isWeb ? 70 : 60,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),

                // Info
                Padding(
                  padding: EdgeInsets.all(isWeb ? 18 : 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Add this
                    children: [
                      Text(
                        developer['name'],
                        style: GoogleFonts.poppins(
                          fontSize: isWeb ? 15 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isWeb ? 6 : 4),
                      Text(
                        developer['role'],
                        style: GoogleFonts.poppins(
                          fontSize: isWeb ? 12 : 11,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isWeb ? 14 : 10),

                      // Portfolio Button - Full width on mobile
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade500,
                                Colors.purple.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final uri = Uri.parse(developer['portfolio']);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWeb ? 20 : 16,
                                  vertical: isWeb ? 10 : 9,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.language_rounded,
                                      color: Colors.white,
                                      size: isWeb ? 16 : 15,
                                    ),
                                    SizedBox(width: isWeb ? 8 : 6),
                                    Text(
                                      'View Portfolio',
                                      style: GoogleFonts.poppins(
                                        fontSize: isWeb ? 13 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildFooter(bool isWeb, double screenWidth, _LandingScreenState state) {
  final double maxWidth = isWeb ? 600 : screenWidth * 0.95;

  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      vertical: isWeb ? 30 : 20,
      horizontal: isWeb ? 40 : 16,
    ),
    decoration: BoxDecoration(
      color: Colors.transparent, // Changed from Colors.grey.shade100
      border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
    ),
    child: Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            // Copyright
            Text(
              '© 2025 Zecure. All rights reserved.',
              style: GoogleFonts.poppins(
                fontSize: isWeb ? 14 : 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Team info
            GestureDetector(
              onTap: () {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  state._showDevelopersModal = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Salido, Sardani, Solis',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 13 : 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Western Mindanao State University',
              style: GoogleFonts.poppins(
                fontSize: isWeb ? 12 : 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'College of Computing Studies',
              style: GoogleFonts.poppins(
                fontSize: isWeb ? 12 : 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Social icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialIcon(
                  FontAwesomeIcons.facebookF,
                  'https://www.facebook.com/venard.jhon.c.salido',
                  hoverColor: const Color(0xFF1877F2),
                ),
                const SizedBox(width: 14),
                _buildSocialIcon(
                  FontAwesomeIcons.instagram,
                  'https://www.instagram.com/venplaystrings/',
                  hoverColor: const Color(0xFFE1306C),
                ),
                const SizedBox(width: 14),
                _buildSocialIcon(
                  FontAwesomeIcons.linkedinIn,
                  'https://www.linkedin.com/in/venard-jhon-cabahug-salido-08041434b/',
                  hoverColor: const Color.fromARGB(255, 58, 137, 190),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildSocialIcon(
  IconData icon,
  String url, {
  required Color hoverColor,
}) {
  return InkWell(
    onTap: () async {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    },
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: FaIcon(icon, size: 18, color: Colors.grey.shade700),
    ),
  );
}
