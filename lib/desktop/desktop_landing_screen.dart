import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';
import 'package:zecure/services/hotline_service.dart';

class DesktopLandingScreen extends StatefulWidget {
  const DesktopLandingScreen({super.key});

  @override
  State<DesktopLandingScreen> createState() => _DesktopLandingScreenState();
}

class _DesktopLandingScreenState extends State<DesktopLandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;
  late AnimationController _carouselController;
  late PageController _pageController;
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _benefitsKey = GlobalKey();
  final GlobalKey _ctaKey = GlobalKey();

  List<Map<String, dynamic>> _hotlines = [];
  bool _isLoadingHotlines = false;
  final HotlineService _hotlineService = HotlineService();

  int _currentPage = 0;
  Timer? _autoPlayTimer; // Add this
  bool _isAutoPlaying = false; // Add this
  double _carouselOffset = 0.0;

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

    // Add carousel animation controller
    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _scrollController = ScrollController();

    _fadeController.forward();
    _slideController.forward();
    _loadCrimeData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _animateToPage(int newPage) {
    final features = _getFeatures();
    final normalizedNew = newPage % features.length;
    final normalizedCurrent = _currentPage % features.length;

    // Calculate direction and offset
    int direction = normalizedNew - normalizedCurrent;
    if (direction.abs() > features.length ~/ 2) {
      direction = direction > 0
          ? direction - features.length
          : direction + features.length;
    }

    final startOffset = _carouselOffset;
    final endOffset = _carouselOffset + direction;

    final animation = Tween<double>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(
        parent: _carouselController,
        curve: Curves.easeInOutCubic,
      ),
    );

    animation.addListener(() {
      setState(() {
        _carouselOffset = animation.value;
      });
    });

    _carouselController.forward(from: 0).then((_) {
      setState(() {
        _currentPage = normalizedNew;
        _carouselOffset = 0;
      });
    });
  }

  void _startAutoPlay() {
    setState(() => _isAutoPlaying = true);
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _animateToPage(_currentPage + 1);
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    setState(() => _isAutoPlaying = false);
  }

  List<Map<String, dynamic>> _getInfiniteFeatures() {
    final features = _getFeatures();
    // Create [last2, last1, ...features, first1, first2] for seamless wrapping
    return [
      features[features.length - 2],
      features[features.length - 1],
      ...features,
      features[0],
      features[1],
    ];
  }

  List<Map<String, dynamic>> _crimeData = [];

  Future<void> _loadCrimeData() async {
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, now.day);

      final response = await Supabase.instance.client
          .from('hotspot')
          .select('time') // Changed from 'created_at' to 'time'
          .eq('status', 'approved')
          .gte(
            'time',
            lastMonth.toIso8601String(),
          ) // Changed from 'created_at' to 'time'
          .lte(
            'time',
            now.toIso8601String(),
          ); // Changed from 'created_at' to 'time'

      Map<String, int> dailyCounts = {};

      for (var item in response) {
        final date = DateTime.parse(
          item['time'],
        ); // Changed from 'created_at' to 'time'
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      }

      final chartData =
          dailyCounts.entries.map((e) {
            return {'date': e.key, 'count': e.value};
          }).toList()..sort(
            (a, b) => (a['date'] as String).compareTo(b['date'] as String),
          );

      setState(() {
        _crimeData = chartData;
      });
    } catch (e) {
      print("Error loading crime data: $e");
    }
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
            'Share additional details and context on verified incidents through structured discussion threads',
        'color': Colors.purple,
        'gradient': [Colors.purple.shade400, Colors.purple.shade600],
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Police Verification',
        'description':
            'All reports are reviewed and verified by police officers before appearing on the public map',
        'color': Colors.green,
        'gradient': [Colors.green.shade400, Colors.green.shade600],
      },
      {
        'icon': Icons.route_rounded,
        'title': 'Safe Route Finder',
        'description':
            'Find the safest paths to your destination avoiding high-crime areas and active incidents',
        'color': Colors.orange,
        'gradient': [Colors.orange.shade400, Colors.orange.shade600],
      },
      {
        'icon': Icons.notification_important_rounded,
        'title': 'Instant Safety Alerts',
        'description':
            'Get quick notifications about verified safety concerns happening near your location',
        'color': Colors.teal,
        'gradient': [Colors.teal.shade400, Colors.teal.shade600],
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Community Safety',
        'description':
            'Report incidents with precise locations and mark safe spots to help your community',
        'color': Colors.indigo,
        'gradient': [Colors.indigo.shade400, Colors.indigo.shade600],
      },
    ];
  }

  List<Map<String, dynamic>> _getBenefits() {
    return [
      {
        'title': 'For Law Enforcement',
        'description':
            'Reduces manual processing time by 30-40%, organizes reports, and identifies patterns for quicker responses.',
        'icon': Icons.local_police_rounded,
      },
      {
        'title': 'For Citizens',
        'description':
            'Easy reporting with precise locations, access to verified safety info, and community participation in safe spot marking.',
        'icon': Icons.people_rounded,
      },
      {
        'title': 'For Community',
        'description':
            'Fosters collaboration through transparent, police-verified data sharing and data-driven safety planning.',
        'icon': Icons.safety_divider_rounded,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: _buildHotlinesFAB(),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/LIGHT.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Subtle overlay

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  SizedBox(height: screenHeight * 0.05),
                  // Hero Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildHeroSection(screenWidth, screenHeight),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.08),
                  // Features Section
                  Container(
                    key: _featuresKey,
                    child: _buildFeaturesSection(screenWidth),
                  ),
                  Container(
                    key: _benefitsKey,
                    child: _buildBenefitsSection(screenWidth),
                  ),

                  // Call to Action
                  _buildCallToAction(screenWidth),

                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotlinesFAB() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0)
              ..scale(isHovered ? 1.05 : 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isHovered
                      ? [const Color(0xFF1e3a8a), const Color(0xFF3b82f6)]
                      : [const Color(0xFF2563eb), const Color(0xFF3b82f6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF3b82f6,
                    ).withOpacity(isHovered ? 0.4 : 0.25),
                    blurRadius: isHovered ? 20 : 12,
                    offset: Offset(0, isHovered ? 6 : 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showHotlinesModal,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Hotlines',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // IMPROVED HEADER
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/zecure.png',
            height: 75,
            width: 75,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Zecure',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),

          // Navigation with tighter spacing
          _buildNavItem('Features', () => _scrollToSection('features')),
          const SizedBox(width: 28),
          _buildNavItem('Benefits', () => _scrollToSection('benefits')),
          const SizedBox(width: 32),

          // Compact CTA Button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: HoverBuilder(
              builder: (isHovered) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  transform: Matrix4.translationValues(
                    0,
                    isHovered ? -3 : 0,
                    0,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered ? Colors.white : Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade600, width: 2),
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ), // 🔹 Reduced width
                      minimumSize: const Size(0, 0), // prevent extra width
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isHovered
                                ? Colors.blue.shade600
                                : Colors.white,
                          ),
                          child: const Text('Get Started'),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: isHovered
                              ? Colors.blue.shade600
                              : Colors.white,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String text, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.poppins(
                    color: isHovered ? Colors.blue.shade600 : Colors.black87,
                    fontSize: 16,
                    fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(text),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: isHovered ? 40 : 0,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // REVAMPED HERO SECTION
  Widget _buildHeroSection(double screenWidth, double screenHeight) {
    return Container(
      height: screenHeight * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Content
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated badge
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade100,
                              Colors.purple.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Community-Powered Safety Platform',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Main headline with gradient
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.grey.shade900,
                              Colors.blue.shade700,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Welcome to Zecure',
                            style: GoogleFonts.poppins(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Subheading
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Text(
                          'Your Guide to a Safer Zamboanga City',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Description
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1400),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 550),
                          child: Text(
                            'Stay safe with live crime updates, smart route suggestions, and community safety reports. '
                            'Built to help protect Zamboanga City families through community cooperation.',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey.shade700,
                              height: 1.7,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // CTA Buttons
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Row(
                          children: [
                            _buildHeroPrimaryButton(),
                            const SizedBox(width: 16),
                            _buildHeroSecondaryButton(),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Trust indicators
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Row(
                        children: [
                          _buildTrustBadge(
                            Icons.verified_user_rounded,
                            'Police Verified',
                          ),
                          const SizedBox(width: 24),
                          _buildTrustBadge(
                            Icons.update_rounded,
                            'Real-Time Updates',
                          ),
                          const SizedBox(width: 24),
                          _buildTrustBadge(
                            Icons.groups_rounded,
                            'Community Driven',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 80),

          // Right side: Enhanced chart
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1400),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(50 * (1 - value), 0),
                    child: Container(
                      height: 480,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _buildCrimeLineChart(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPrimaryButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -3.0 : 0.0)
              ..scale(isHovered ? 1.03 : 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isHovered
                    ? LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                      )
                    : null,
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.blue.shade400.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  'Login to Zecure',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHovered
                      ? Colors.transparent
                      : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSecondaryButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -3.0 : 0.0)
              ..scale(isHovered ? 1.03 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: Text(
                'View Map as Guest',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isHovered
                    ? Colors.blue.shade700
                    : Colors.blue.shade600,
                side: BorderSide(
                  color: isHovered
                      ? Colors.blue.shade700
                      : Colors.blue.shade600,
                  width: 2,
                ),
                backgroundColor: isHovered
                    ? Colors.blue.shade50
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.blue.shade600),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // REVAMPED FEATURES SECTION
  Widget _buildFeaturesSection(double screenWidth) {
    final features = _getFeatures();
    final infiniteFeatures = _getInfiniteFeatures();
    final centerIndex = _currentPage + 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50.withOpacity(0.3),
            Colors.purple.shade50.withOpacity(0.2),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'How Zecure Keeps You Safe',
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Discover powerful features designed for your safety',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 100), // Increased from 60
          // Carousel with adjusted positioning
          Center(
            child: SizedBox(
              height: 420, // Reduced from 480 to move cards up
              width: 1200,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: _buildStackedCards(infiniteFeatures, centerIndex),
              ),
            ),
          ),

          const SizedBox(height: 60), // Increased from 40
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCarouselButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => _animateToPage(_currentPage - 1),
              ),
              const SizedBox(width: 20),
              _buildPlayButton(),
              const SizedBox(width: 20),
              _buildCarouselButton(
                icon: Icons.chevron_right_rounded,
                onPressed: () => _animateToPage(_currentPage + 1),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              features.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.blue.shade600
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method to build properly stacked cards
  List<Widget> _buildStackedCards(
    List<Map<String, dynamic>> infiniteFeatures,
    int centerIndex,
  ) {
    final cards = <MapEntry<double, Widget>>[];

    for (int i = -2; i <= 2; i++) {
      final offset = i.toDouble() - _carouselOffset;
      final featureIndex = (centerIndex + i) % infiniteFeatures.length;
      final absOffset = offset.abs();

      cards.add(
        MapEntry(
          absOffset,
          _buildCarouselCard(
            feature: infiniteFeatures[featureIndex],
            offset: offset,
            isCurrent: i == 0 && _carouselOffset.abs() < 0.5,
            containerWidth: 1200,
          ),
        ),
      );
    }

    // Sort by absolute offset (descending) so furthest cards render first
    cards.sort((a, b) => b.key.compareTo(a.key));

    return cards.map((e) => e.value).toList();
  }

  Widget _buildCarouselCard({
    required Map<String, dynamic> feature,
    required double offset,
    required bool isCurrent,
    required double containerWidth,
  }) {
    final absOffset = offset.abs();
    final horizontalOffset = offset * 220.0;
    final scale = 1.0 - (absOffset * 0.2);
    final opacity = (1.0 - (absOffset * 0.3)).clamp(0.3, 1.0);
    final verticalOffset = absOffset * 25.0; // Reduced from 30.0

    final cardWidth = 320.0;
    final centerPosition = (containerWidth / 2) - (cardWidth / 2);

    return Positioned(
      left: centerPosition + horizontalOffset,
      top:
          30 + verticalOffset, // Added base offset of 30 to push all cards down
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..scale(scale)
          ..rotateY(offset * 0.1),
        alignment: Alignment.center,
        child: Opacity(
          opacity: opacity,
          child: SizedBox(width: cardWidth, child: _buildFeatureCard(feature)),
        ),
      ),
    );
  }

  Widget _buildCarouselButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHovered ? Colors.blue.shade600 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.shade600, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: isHovered ? Colors.white : Colors.blue.shade600,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
            child: InkWell(
              onTap: () {
                if (_isAutoPlaying) {
                  _stopAutoPlay();
                } else {
                  _startAutoPlay();
                }
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isAutoPlaying
                        ? [Colors.orange.shade500, Colors.red.shade500]
                        : [Colors.blue.shade600, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isAutoPlaying ? Colors.orange : Colors.blue)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isAutoPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -8.0 : 0.0),
            child: Container(
              height: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isHovered
                      ? feature['color'].withOpacity(0.6)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? feature['color'].withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: isHovered ? 30 : 15,
                    spreadRadius: isHovered ? 2 : 0,
                    offset: Offset(0, isHovered ? 15 : 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keep your existing card content
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    transform: Matrix4.identity()
                      ..scale(isHovered ? 1.15 : 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: feature['gradient'],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: feature['color'].withOpacity(0.4),
                            blurRadius: isHovered ? 20 : 12,
                            offset: Offset(0, isHovered ? 8 : 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        feature['icon'],
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isHovered
                          ? feature['color']
                          : Colors.grey.shade900,
                      height: 1.3,
                    ),
                    child: Text(feature['title']),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      feature['description'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // REVAMPED BENEFITS SECTION
  Widget _buildBenefitsSection(double screenWidth) {
    final benefits = _getBenefits();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.blue.shade50],
        ),
      ),
      child: Column(
        children: [
          // Header
          Text(
            'Built For Everyone',
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              'Zecure brings together law enforcement, citizens, and communities with purpose-built tools for each stakeholder',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 60),

          // Benefits Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: benefits.asMap().entries.map((entry) {
              final index = entry.key;
              final benefit = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 15,
                    right: index == benefits.length - 1 ? 0 : 15,
                  ),
                  child: _buildBenefitCard(benefit, index),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(Map<String, dynamic> benefit, int index) {
    final colors = [
      [Colors.blue.shade600, Colors.blue.shade400],
      [Colors.purple.shade600, Colors.purple.shade400],
      [Colors.teal.shade600, Colors.teal.shade400],
    ];

    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        // Calculate parallax offset based on scroll position
        final scrollOffset = _scrollController.hasClients
            ? _scrollController.offset
            : 0;
        final parallaxOffset =
            (scrollOffset - 1500) *
            0.05 *
            (index - 1); // Different speed per card

        return Transform.translate(
          offset: Offset(0, parallaxOffset.clamp(-30.0, 30.0)),
          child: child,
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: HoverBuilder(
          builder: (isHovered) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              transform: Matrix4.identity()
                ..translate(0.0, isHovered ? -10.0 : 0.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isHovered
                      ? colors[index]
                      : [Colors.white, Colors.white],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isHovered ? Colors.transparent : Colors.grey.shade200,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? colors[index][0].withOpacity(0.4)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: isHovered ? 35 : 20,
                    offset: Offset(0, isHovered ? 20 : 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(36),
              child: Column(
                children: [
                  // Icon with animated glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? Colors.white.withOpacity(0.2)
                          : colors[index][0].withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: colors[index][0].withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ]
                          : [],
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      transform: Matrix4.identity()
                        ..scale(isHovered ? 1.2 : 1.0)
                        ..rotateZ(isHovered ? 0.1 : 0.0), // Add slight rotation
                      child: Icon(
                        benefit['icon'],
                        size: 48,
                        color: isHovered ? Colors.white : colors[index][0],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    benefit['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isHovered ? Colors.white : Colors.grey.shade900,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    benefit['description'],
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isHovered
                          ? Colors.white.withOpacity(0.95)
                          : Colors.grey.shade600,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showHotlinesModal() {
    // Show dialog immediately
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(
          // 👈 Add this wrapper
          builder: (dialogContext, setDialogState) {
            // 👈 Use setDialogState
            // Start loading on first build
            if (_hotlines.isEmpty && !_isLoadingHotlines) {
              Future.microtask(() async {
                setDialogState(() => _isLoadingHotlines = true);
                try {
                  final data = await _hotlineService.fetchHotlineData();
                  setDialogState(() {
                    _hotlines = data;
                    _isLoadingHotlines = false;
                  });
                } catch (e) {
                  print("Error loading hotline data: $e");
                  setDialogState(() => _isLoadingHotlines = false);
                }
              });
            }

            return Container(
              width: 500,
              height: 850,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Modern Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B5876).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: Color(0xFF2B5876),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Contacts',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1a1a1a),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Quick access to emergency services',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade700,
                          ),
                          iconSize: 24,
                        ),
                      ],
                    ),
                  ),

                  // Scrollable list with loading state
                  Expanded(
                    child: _isLoadingHotlines
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading hotlines...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _hotlines.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_disabled_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hotlines available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              // 911 Emergency
                              _buildEmergencyCard(),
                              const SizedBox(height: 16),

                              // All other hotlines
                              ..._hotlines.map(
                                (hotline) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHotlineListItem(hotline),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3b82f6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '911',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Emergency Hotline',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineListItem(Map<String, dynamic> hotline) {
    final categoryIcon = _getIconForCategory(hotline['category']);
    final categoryColor = _getColorForCategory(hotline['category']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.grey.shade100,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, color: categoryColor, size: 22),
          ),
          title: Text(
            hotline['category'],
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1a1a1a),
            ),
          ),
          subtitle: Text(
            _getSubtitleForCategory(hotline['category']),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          trailing: Icon(
            Icons.expand_more_rounded,
            color: Colors.grey.shade600,
            size: 22,
          ),
          children: [
            if (hotline['numbers'] != null)
              ...hotline['numbers'].map<Widget>(
                (n) => _buildPhoneNumberListItem(n),
              ),
            if (hotline['stations'] != null)
              ...hotline['stations'].map<Widget>(
                (s) => _buildStationListItem(s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberListItem(Map<String, dynamic> number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  number['number'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF1a1a1a),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationListItem(Map<String, dynamic> station) {
    final categoryColor = _getColorForCategory(station['category'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Icon(
            Icons.location_on_rounded,
            color: categoryColor,
            size: 20,
          ),
          title: Text(
            station['name'],
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1a1a1a),
            ),
          ),
          trailing: Icon(
            Icons.expand_more_rounded,
            color: Colors.grey.shade600,
            size: 20,
          ),
          children: station['numbers']
              .map<Widget>(
                (num) => _buildPhoneNumberListItem({
                  'name': station['name'],
                  'number': num,
                }),
              )
              .toList(),
        ),
      ),
    );
  }

  String _getSubtitleForCategory(String category) {
    if (category.contains('Medical') || category.contains('EMS')) {
      return 'Medical emergencies';
    } else if (category.contains('CDRRMO') || category.contains('ZCDRRMO')) {
      return 'Disaster risk management';
    } else if (category.contains('Task Force') || category.contains('JTFZ')) {
      return 'Joint security operations';
    } else if (category.contains('Police')) {
      return 'Law enforcement';
    } else if (category.contains('Fire')) {
      return 'Fire emergencies';
    }
    return 'Emergency services';
  }

  IconData _getIconForCategory(String category) {
    if (category.contains('CDRRMO') || category.contains('ZCDRRMO')) {
      return Icons.shield_rounded;
    } else if (category.contains('Medical') || category.contains('EMS')) {
      return Icons.medical_services_rounded;
    } else if (category.contains('Task Force') || category.contains('JTFZ')) {
      return Icons.security_rounded;
    } else if (category.contains('Police Office') &&
        category.contains('ZCPO')) {
      return Icons.local_police_rounded;
    } else if (category.contains('Police Stations')) {
      return Icons.store_rounded;
    } else if (category.contains('Mobile Force')) {
      return Icons.directions_car_rounded;
    } else if (category.contains('Fire')) {
      return Icons.local_fire_department_rounded;
    }
    return Icons.phone_in_talk_rounded;
  }

  Color _getColorForCategory(String category) {
    // Column 1: Green spectrum
    if (category.contains('Medical') || category.contains('EMS')) {
      return Colors.lightGreen.shade700;
    } else if (category.contains('CDRRMO') && !category.contains('ZCDRRMO')) {
      return Colors.green.shade700;
    }
    // Column 2: Teal/Cyan spectrum
    else if (category.contains('Mobile Force')) {
      return Colors.amber.shade600;
    } else if (category.contains('ZCDRRMO')) {
      return Colors.yellow.shade800;
    }
    // Column 3: Blue spectrum
    else if (category.contains('Police Office') && category.contains('ZCPO')) {
      return Colors.lightBlue.shade600;
    } else if (category.contains('Police Stations')) {
      return Colors.blue.shade500;
    }
    // Column 4: Purple to Red spectrum
    else if (category.contains('Task Force') || category.contains('JTFZ')) {
      return Colors.pink.shade300;
    } else if (category.contains('Fire')) {
      return Colors.red.shade600;
    }

    return Colors.red.shade600;
  }

  // REVAMPED CALL TO ACTION SECTION
  Widget _buildCallToAction(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        80,
        100,
        80,
        0,
      ), // Changed: removed bottom padding
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/VERYDARK.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          // Animated badge
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trusted by Zamboanga Community',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Main headline
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Column(
                    children: [
                      Text(
                        'Ready to Enhance Public Safety?',
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Text(
                          'Be part of a community-driven platform that makes Zamboanga City safer through verified data, real-time alerts, and collaborative action.',
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            color: Colors.white.withOpacity(0.95),
                            height: 1.7,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          // Stats row
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem('24/7', 'Monitoring', value * 1.0),
                    const SizedBox(width: 60),
                    _buildStatItem('Real-time', 'Updates', value * 1.0),
                    const SizedBox(width: 60),
                    _buildStatItem('Verified', 'Data Only', value * 1.0),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 50),

          // CTA Buttons
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1400),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPrimaryCTAButton(),
                      const SizedBox(width: 20),
                      _buildSecondaryCTAButton(),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(
            height: 100,
          ), // Added bottom spacing within the container
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, double animValue) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCTAButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0)
              ..scale(isHovered ? 1.05 : 1.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 22),
              label: Text(
                'Get Started Now',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 22,
                ),
                elevation: isHovered ? 12 : 6,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondaryCTAButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0)
              ..scale(isHovered ? 1.05 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
              icon: const Icon(Icons.explore_rounded, size: 22),
              label: Text(
                'Explore Map',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white, width: isHovered ? 3 : 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 22,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // IMPROVED FOOTER
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
        ),
      ),
      child: Column(
        children: [
          // Main footer content
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand section
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/zecure.png',
                              height: 52,
                              width: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 52,
                                    width: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.security_rounded,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Zecure',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Making Zamboanga City safer through community-powered crime monitoring and real-time safety alerts.',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade300,
                          height: 1.7,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Social icons
                      Row(
                        children: [
                          _buildSocialIcon(
                            FontAwesomeIcons.facebookF,
                            'https://www.facebook.com/venard.jhon.c.salido',
                            hoverColor: const Color(
                              0xFF1877F2,
                            ), // Facebook blue
                          ),
                          const SizedBox(width: 14),
                          _buildSocialIcon(
                            FontAwesomeIcons.instagram,
                            'https://www.instagram.com/venplaystrings/',
                            hoverColor: const Color(
                              0xFFE1306C,
                            ), // Instagram pink/red tone
                          ),
                          const SizedBox(width: 14),
                          _buildSocialIcon(
                            FontAwesomeIcons.linkedinIn,
                            'https://www.linkedin.com/in/venard-jhon-cabahug-salido-08041434b/',
                            hoverColor: const Color.fromARGB(
                              255,
                              58,
                              137,
                              190,
                            ), // LinkedIn blue
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 80),

                // Quick Links
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Links',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFooterLink('Features'),
                      _buildFooterLink('Benefits'),
                      _buildFooterLink('Get Started'),
                    ],
                  ),
                ),

                // Contact Info
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get in Touch',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildContactInfo(
                        Icons.location_on_outlined,
                        'Zamboanga City, Philippines',
                      ),
                      _buildContactInfo(
                        Icons.email_outlined,
                        'zecure.netlify.app',
                      ),
                      _buildContactInfo(Icons.phone_outlined, '09351363586'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 28),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '© 2025 Zecure. All rights reserved.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Salido, Sardani, Solis',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      'Western Mindanao State University - College of Computing Studies',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.shade500.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Community Trusted',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade300,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return InkWell(
            onTap: () {
              if (text.toLowerCase() == 'get started') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              } else {
                _scrollToSection(text.toLowerCase());
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isHovered ? 8 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (isHovered) const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isHovered
                          ? Colors.blue.shade400
                          : Colors.grey.shade300,
                      fontWeight: isHovered
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    child: Text(text),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade600.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.blue.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade300,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url, {Color? hoverColor}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverBuilder(
        builder: (isHovered) {
          return GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isHovered
                    ? (hoverColor ?? Colors.blue.shade600)
                    : Colors.white.withOpacity(0.1),

                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovered
                      ? Colors.blue.shade500
                      : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              transform: Matrix4.translationValues(0, isHovered ? -3 : 0, 0),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  void _scrollToSection(String section) {
    BuildContext? targetContext;

    switch (section) {
      case 'features':
        targetContext = _featuresKey.currentContext;
        break;
      case 'benefits':
        targetContext = _benefitsKey.currentContext;
        break;
      case 'get started':
        targetContext = _ctaKey.currentContext;
        break;
      default:
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        return;
    }

    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0, // 0 aligns top of section with top of viewport
      );
    }
  }

  Widget _buildCrimeLineChart() {
    if (_crimeData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No crime trend data available",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Data will appear here once reports are submitted",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Only crimes from the last 30 days are displayed.",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    final maxValue = _crimeData
        .map((e) => e['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    final avgValue =
        _crimeData.fold<int>(0, (sum, item) => sum + (item['count'] as int)) /
        _crimeData.length;

    final totalReports = _crimeData.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Crime Reports Trend",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last 30 Days Analysis",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Stats badges
            _buildStatBadge(
              'Total',
              totalReports.toString(),
              Colors.blue.shade600,
              Icons.description_rounded,
            ),
            const SizedBox(width: 12),
            _buildStatBadge(
              'Peak',
              maxValue.toString(),
              Colors.red.shade600,
              Icons.trending_up_rounded,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Chart
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: (maxValue / 5).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) =>
                    FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value % (maxValue / 5).ceilToDouble() != 0) {
                        return const SizedBox();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (_crimeData.length / 6).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _crimeData.length) {
                        return const SizedBox();
                      }

                      final date = DateTime.parse(_crimeData[index]['date']);
                      final formatted = DateFormat('MMM d').format(date);

                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          formatted,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  left: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              minX: 0,
              maxX: (_crimeData.length - 1).toDouble(),
              minY: 0,
              maxY: (maxValue * 1.3).toDouble(),

              // Average line
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: avgValue,
                    color: Colors.amber.shade600,
                    strokeWidth: 2,
                    dashArray: [8, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      labelResolver: (_) => 'Average',
                      style: GoogleFonts.poppins(
                        color: Colors.amber.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Line with gradient
              lineBarsData: [
                LineChartBarData(
                  spots: _crimeData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value['count'].toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.purple.shade600],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400.withOpacity(0.3),
                        Colors.purple.shade400.withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final isLast = index == _crimeData.length - 1;
                      final isPeak = spot.y == maxValue.toDouble();

                      if (!isLast && !isPeak) {
                        return FlDotCirclePainter(radius: 0);
                      }

                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: isPeak
                            ? Colors.red.shade600
                            : Colors.blue.shade600,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper widget for hover state management
class HoverBuilder extends StatefulWidget {
  final Widget Function(bool isHovered) builder;

  const HoverBuilder({super.key, required this.builder});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(_isHovered),
    );
  }
}
