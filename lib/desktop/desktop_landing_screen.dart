import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/screens/map_screen.dart';

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
  late PageController _pageController;
  int _currentPage = 0;

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

    _scrollController = ScrollController();
    
    _pageController = PageController(
      viewportFraction: 0.35,
      initialPage: 0,
    );
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });

    // Start animations
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
    super.dispose();
  }

  
List<Map<String, dynamic>> _crimeData = [];

Future<void> _loadCrimeData() async {
  try {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, now.day);

    final response = await Supabase.instance.client
        .from('hotspot')
        .select('created_at')
        .eq('status', 'approved')
        .gte('created_at', lastMonth.toIso8601String())
        .lte('created_at', now.toIso8601String());

    Map<String, int> dailyCounts = {};

    for (var item in response) {
      final date = DateTime.parse(item['created_at']);
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
    }

    final chartData = dailyCounts.entries.map((e) {
      return {
        'date': e.key,   // now daily
        'count': e.value,
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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
        'description': 'Interactive map displaying only police-verified crime incidents and safe spots in Zamboanga City.',
        'color': Colors.blue,
        'gradient': [Colors.blue.shade400, Colors.blue.shade600],
      },
      {
        'icon': Icons.report_rounded,
        'title': 'AI-Assisted Reporting',
        'description': 'Submit geo-located crime reports easily via mobile app, with automatic categorization by type and severity.',
        'color': Colors.purple,
        'gradient': [Colors.purple.shade400, Colors.purple.shade600],
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Police Verification',
        'description': 'Secure dashboard for officers to review, categorize, and verify reports before public display.',
        'color': Colors.green,
        'gradient': [Colors.green.shade400, Colors.green.shade600],
      },
      {
        'icon': Icons.route_rounded,
        'title': 'Safe Route Recommendations',
        'description': 'Algorithm suggests safer paths avoiding verified hotspots and prioritizing user-marked safe locations.',
        'color': Colors.orange,
        'gradient': [Colors.orange.shade400, Colors.orange.shade600],
      },
      {
        'icon': Icons.notification_important_rounded,
        'title': 'Real-Time Alerts',
        'description': 'Automatic notifications for verified incidents near your location to keep you informed.',
        'color': Colors.teal,
        'gradient': [Colors.teal.shade400, Colors.teal.shade600],
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Pattern Detection',
        'description': 'AI identifies duplicate reports and emerging crime trends to aid faster responses.',
        'color': Colors.indigo,
        'gradient': [Colors.indigo.shade400, Colors.indigo.shade600],
      },
    ];
  }

  List<Map<String, dynamic>> _getBenefits() {
    return [
      {
        'title': 'For Law Enforcement',
        'description': 'Reduces manual processing time by 30-40%, organizes reports, and identifies patterns for quicker responses.',
        'icon': Icons.local_police_rounded,
      },
      {
        'title': 'For Citizens',
        'description': 'Easy reporting with precise locations, access to verified safety info, and community participation in safe spot marking.',
        'icon': Icons.people_rounded,
      },
      {
        'title': 'For Community',
        'description': 'Fosters collaboration through transparent, police-verified data sharing and data-driven safety planning.',
        'icon': Icons.safety_divider_rounded,
      },
    ];
  }

  final List<Map<String, dynamic>> _hotlines = [

    {
      'category': 'Emergency Ciudad Medical',
      'numbers': [
        {'name': 'EMS', 'number': '926-1849'},
      ]
    },

    {
      'category': 'ZC Mobile Force Company',
      'numbers': [
        {'name': '1ST ZCMFC', 'number': '0995-279-1449'},
        {'name': '2ND ZCMFC', 'number': '0905-886-0405'},
      ]
    },
    {
      'category': 'ZC Police Office (ZCPO)',
      'numbers': [
        {'name': 'ZCPO', 'number': '0977-855-8138'},
      ]
    },
    {
      'category': 'Join Task Force Zamboanga',
      'numbers': [
        {'name': 'JTFZ', 'number': '0917-710-2326'},
        {'name': 'JTFZ', 'number': '0916-535-8106'},
        {'name': 'JTFZ', 'number': '0928-396-9926'},
      ]
    },

    {
      'category': 'CDRRMO',
      'numbers': [
        {'name': 'CDRRMO', 'number': '0917-711-3536'},
        {'name': 'CDRRMO', 'number': '0918-933-7858'},
        {'name': 'CDRRMO', 'number': '926-9274'},
      ]
    },

    {
      'category': 'ZCDRRMO',
      'numbers': [
        {'name': 'ZCDRRMO', 'number': '986-1171'},
        {'name': 'ZCDRRMO', 'number': '826-1848'},
        {'name': 'ZCDRRMO', 'number': '955-9801'},
        {'name': 'ZCDRRMO', 'number': '955-3850'},
        {'name': 'ZCDRRMO', 'number': '956-1871'},
        {'name': 'Emergency Operations Center', 'number': '0966-731-6242'},
        {'name': 'Emergency Operations Center', 'number': '0955-604-3882'},
        {'name': 'Emergency Operations Center', 'number': '0925-502-3829'},
        {'name': 'Technical Rescue/Fire Auxiliary', 'number': '0926-091-2492'},
        {'name': 'Services/Emergency Medical', 'number': '926-1848'},
      ]
    },





    {
      'category': 'Police Stations',
      'stations': [
        {
          'name': 'PS1-Vitali',
          'numbers': [
            '0935-604-9139',
            '0988-967-3923',
          ]
        },
        {
          'name': 'PS2-Curuan',
          'numbers': [
            '0935-457-3483',
            '0918-230-7135',
          ]
        },
        {
          'name': 'PS3-Sangali',
          'numbers': [
            '0917-146-2400',
            '939-930-7144',
            '955-0156',
          ]
        },
        {
          'name': 'PS4-Culianan',
          'numbers': [
            '0975-333-9826',
            '0935-562-7161',
            '955-0255',
          ]
        },
        {
          'name': 'PS5-Divisoria',
          'numbers': [
            '0917-837-8907',
            '0998-967-3927',
            '955-6887',
          ]
        },
        {
          'name': 'PS6-Tetuan',
          'numbers': [
            '0997-746-6666',
            '0926-174-0151',
            '901-0678',
          ]
        },
        {
          'name': 'PS7-Sta. Maria',
          'numbers': [
            '0917-397-8098',
            '0998-967-3929',
            '985-9001',
          ]
        },
        {
          'name': 'PS8-Sininuc',
          'numbers': [
            '0906-853-9806',
            '0988-967-3930',
            '985-9001',
          ]
        },
        {
          'name': 'PS9-Ayala',
          'numbers': [
            '0998-967-3931',
            '0917-864-8553',
            '983-0001',
          ]
        },
        {
          'name': 'PS10-Labuan',
          'numbers': [
            '0917-309-3887',
            '0935-993-8033',
          ]
        },
        {
          'name': 'PS11-Central',
          'numbers': [
            '0917-701-4340',
            '0998-967-3934',
            '310-2030',
          ]
        },
      ]
    },

    {
      'category': 'Fire Department',
      'numbers': [
        {'name': 'Zamboanga City Fire District', 'number': '991-3255'},
        {'name': 'Zamboanga City Fire District', 'number': '0955-781-6063'},
      ],
      'stations': [
        {
          'name': 'Putik Fire Sub-Station',
          'numbers': [
            '310-9797',
          ]
        },
        {
          'name': 'Lunzuran Fire Sub-Station',
          'numbers': [
            '310-7212',
            '0935-454-5366',
          ]
        },
        {
          'name': 'Guiwan Fire Sub-Station',
          'numbers': [
            '957-4372',
            '0916-135-2436',
          ]
        },
        {
          'name': 'Tumaga Fire Sub-Station',
          'numbers': [
            '991-5809',
          ]
        },
        {
          'name': 'Sta. Maria Fire Sub-Station',
          'numbers': [
            '985-0520',
          ]
        },
        {
          'name': 'Tetuan Fire Sub-Station',
          'numbers': [
            '992-0620',
            '0906-441-1416',
          ]
        },
        {
          'name': 'Sta Catalina Fire Sub-Station',
          'numbers': [
            '957-3160',
            '0995-071-7746',
          ]
        },
        {
          'name': 'Mahaman Fire Sub-Station',
          'numbers': [
            '0975-074-1376',
          ]
        },
        {
          'name': 'Boalan Fire Sub-Station',
          'numbers': [
            '957-6217',
            '0997-703-1365',
          ]
        },
        {
          'name': 'Manicahan Fire Sub-Station',
          'numbers': [
            '0975-031-1372',
          ]
        },
        {
          'name': 'Quiniput Fire Sub-Station',
          'numbers': [
            '0975-197-3009',
          ]
        },
        {
          'name': 'Culianan Fire Sub-Station',
          'numbers': [
            '310-0313',
            '0975-255-3899',
          ]
        },
        {
          'name': 'Vitalli Fire Sub-Station',
          'numbers': [
            '0965-185-7746',
            '0999-518-4848',
          ]
        },
        {
          'name': 'San Jose Guling Fire Sub-Station',
          'numbers': [
            '0914-701-0209',
          ]
        },
        {
          'name': 'Calarian Fire Sub-Station',
          'numbers': [
            '0917-106-2785',
            '957-4440',
          ]
        },
        {
          'name': 'Recodo Fire Sub-Station',
          'numbers': [
            '957-3729',
            '0936-256-7071',
          ]
        },
        {
          'name': 'Talisayan Fire Sub-Station',
          'numbers': [
            '0936-462-2070',
          ]
        },
        {
          'name': 'Ayala Fire Sub-Station',
          'numbers': [
            '957-6209',
            '0953-149-9756',
          ]
        },
        {
          'name': 'Labuan Fire Sub-Station',
          'numbers': [
            '0927-493-5473',
          ]
        },
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50.withOpacity(0.3),
                  Colors.transparent,
                  Colors.blue.shade50.withOpacity(0.2),
                ],
              ),
            ),
          ),
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
                  _buildFeaturesSection(screenWidth),
                  SizedBox(height: screenHeight * 0.08),
                  // Benefits Section
                  _buildBenefitsSection(screenWidth),
                  SizedBox(height: screenHeight * 0.08),
                  // Hotlines Section
                  _buildHotlinesSection(screenWidth),
                  SizedBox(height: screenHeight * 0.08),
                  // Call to Action
                  _buildCallToAction(screenWidth),
                  SizedBox(height: screenHeight * 0.05),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Zecure',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Navigation
          Row(
            children: [
              TextButton(
                onPressed: () => _scrollToSection('features'),
                child: Text(
                  'Features',
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => _scrollToSection('benefits'),
                child: Text(
                  'Benefits',
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => _scrollToSection('hotlines'),
                child: Text(
                  'Hotlines',
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                ),
              ),
              const SizedBox(width: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Get Started',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.purple.shade100],
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
                        _buildTrustBadge(Icons.verified_user_rounded, 'Police Verified'),
                        const SizedBox(width: 24),
                        _buildTrustBadge(Icons.update_rounded, 'Real-Time Updates'),
                        const SizedBox(width: 24),
                        _buildTrustBadge(Icons.groups_rounded, 'Community Driven'),
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
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                backgroundColor: isHovered ? Colors.transparent : Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
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
              foregroundColor: isHovered ? Colors.blue.shade700 : Colors.blue.shade600,
              side: BorderSide(
                color: isHovered ? Colors.blue.shade700 : Colors.blue.shade600,
                width: 2,
              ),
              backgroundColor: isHovered ? Colors.blue.shade50 : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
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
        child: Icon(
          icon,
          size: 16,
          color: Colors.blue.shade600,
        ),
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
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
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
        // Section Header with Icon
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
          child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
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
        const SizedBox(height: 60),
        
        // Features Grid with Staggered Animation
        Wrap(
          spacing: 30,
          runSpacing: 30,
          children: features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: SizedBox(
                      width: (screenWidth - 220) / 3 - 30,
                      child: _buildFeatureCard(feature),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
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
            ..translate(0.0, isHovered ? -12.0 : 0.0)
            ..rotateZ(isHovered ? -0.01 : 0.0),
          child: Container(
            height: 320,
            padding: const EdgeInsets.all(28),
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
                // Icon with animated background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  transform: Matrix4.identity()
                    ..scale(isHovered ? 1.15 : 1.0)
                    ..rotateZ(isHovered ? 0.1 : 0.0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: feature['gradient'],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: feature['color'].withOpacity(0.4),
                          blurRadius: isHovered ? 25 : 15,
                          offset: Offset(0, isHovered ? 10 : 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      feature['icon'],
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title with gradient on hover
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isHovered ? feature['color'] : Colors.grey.shade900,
                    height: 1.3,
                  ),
                  child: Text(feature['title']),
                ),
                const SizedBox(height: 14),
                
                // Description
                Expanded(
                  child: Text(
                    feature['description'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          Colors.blue.shade50.withOpacity(0.3),
        ],
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
  
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: HoverBuilder(
      builder: (isHovered) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 700 + (index * 150)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, animValue, child) {
            return Transform.scale(
              scale: animValue,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                transform: Matrix4.identity()
                  ..translate(0.0, isHovered ? -10.0 : 0.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isHovered ? colors[index] : [Colors.white, Colors.white],
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
                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isHovered 
                            ? Colors.white.withOpacity(0.2)
                            : colors[index][0].withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        transform: Matrix4.identity()
                          ..scale(isHovered ? 1.2 : 1.0),
                        child: Icon(
                          benefit['icon'],
                          size: 48,
                          color: isHovered ? Colors.white : colors[index][0],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Title
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
                    
                    // Description
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
                    
                    const SizedBox(height: 24),
                    

                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

// REVAMPED HOTLINES SECTION
Widget _buildHotlinesSection(double screenWidth) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.red.shade50.withOpacity(0.3),
          Colors.orange.shade50.withOpacity(0.2),
        ],
      ),
    ),
    child: Column(
      children: [
        // Animated Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade500, Colors.orange.shade600],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Hotlines',
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Available 24/7 • Quick Response',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 60),
        
        // Hotlines Grid
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: _hotlines.asMap().entries.map((entry) {
            final index = entry.key;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 500 + (index * 80)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: SizedBox(
                      width: (screenWidth - 220) / 4 - 20,
                      child: _buildHotlineCard(entry.value),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    ),
  );
}

Widget _buildHotlineCard(Map<String, dynamic> hotline) {
  final categoryIcon = _getIconForCategory(hotline['category']);
  final categoryColor = _getColorForCategory(hotline['category']);
  
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: HoverBuilder(
      builder: (isHovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.identity()
            ..translate(0.0, isHovered ? -6.0 : 0.0)
            ..scale(isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHovered 
                  ? categoryColor.withOpacity(0.6)
                  : Colors.grey.shade200,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered 
                    ? categoryColor.withOpacity(0.25)
                    : Colors.black.withOpacity(0.06),
                blurRadius: isHovered ? 30 : 15,
                offset: Offset(0, isHovered ? 15 : 8),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: categoryColor.withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(20),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                leading: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.identity()
                    ..scale(isHovered ? 1.15 : 1.0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [categoryColor, categoryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.4),
                        blurRadius: isHovered ? 15 : 8,
                        offset: Offset(0, isHovered ? 6 : 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    categoryIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  hotline['category'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isHovered ? categoryColor : Colors.grey.shade900,
                  ),
                ),
                trailing: AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: isHovered ? 0.5 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                ),
                children: [
                  if (hotline['numbers'] != null)
                    ...hotline['numbers'].map<Widget>((n) => _buildPhoneNumber(n, categoryColor)),
                  if (hotline['stations'] != null)
                    ...hotline['stations'].map<Widget>((s) => _buildStation(s, categoryColor)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildPhoneNumber(Map<String, dynamic> number, Color color) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: HoverBuilder(
      builder: (isHovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHovered
                  ? [color.withOpacity(0.08), color.withOpacity(0.12)]
                  : [Colors.grey.shade50, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovered ? color.withOpacity(0.4) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phone_rounded, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      number['number'],
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isHovered)
                Icon(Icons.content_copy_rounded, size: 16, color: color),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildStation(Map<String, dynamic> station, Color color) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.location_on_rounded, size: 18, color: color),
        ),
        title: Text(
          station['name'],
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        children: station['numbers'].map<Widget>((num) => 
          _buildPhoneNumber({'name': station['name'], 'number': num}, color)
        ).toList(),
      ),
    ),
  );
}

IconData _getIconForCategory(String category) {
  if (category.contains('CDRRMO') || category.contains('ZCDRRMO')) {
    return Icons.shield_rounded;
  } else if (category.contains('Medical') || category.contains('EMS')) {
    return Icons.medical_services_rounded;
  } else if (category.contains('Task Force') || category.contains('JTFZ')) {
    return Icons.security_rounded;
  } else if (category.contains('Police Office') && category.contains('ZCPO')) {
    return Icons.local_police_rounded;
  } else if (category.contains('Police Stations')) {
    return Icons.store_rounded;
  } else if (category.contains('Mobile Force')) {
    return Icons.directions_car_rounded;
  } else if (category.contains('Fire')) {
    return Icons.local_fire_department_rounded;
  }
  return Icons.phone_in_talk_rounded; // default
}

Color _getColorForCategory(String category) {
  // Column 1: Green spectrum
  if (category.contains('Medical') || category.contains('EMS')) {
    return Colors.lightGreen.shade700;
  } 
  else if (category.contains('CDRRMO') && !category.contains('ZCDRRMO')) {
    return Colors.green.shade700; // Greenish-orange
  } 
  // Column 2: Teal/Cyan spectrum
  else if (category.contains('Mobile Force')) {
    return Colors.amber.shade600;
  } 
  else if (category.contains('ZCDRRMO')) {
    return Colors.yellow.shade800; // Warm teal-orange
  } 
  // Column 3: Blue spectrum
  else if (category.contains('Police Office') && category.contains('ZCPO')) {
    return Colors.lightBlue.shade600;
  } 
  else if (category.contains('Police Stations')) {
    return Colors.blue.shade500; // Lighter blue
  } 
  // Column 4: Purple to Red spectrum
  else if (category.contains('Task Force') || category.contains('JTFZ')) {
    return Colors.pink.shade300;
  } 
  else if (category.contains('Fire')) {
    return Colors.red.shade600; // Pinkish-red
  }

  return Colors.red.shade600; // default
}



// REVAMPED CALL TO ACTION SECTION
Widget _buildCallToAction(double screenWidth) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue.shade700,
          Colors.blue.shade600,
          Colors.purple.shade600,
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
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
              side: BorderSide(
                color: Colors.white,
                width: isHovered ? 3 : 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
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

// REVAMPED FOOTER
Widget _buildFooter() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade900,
          Colors.grey.shade800,
        ],
      ),
    ),
    child: Column(
      children: [
        // Top section with logo and description
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo and tagline
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/images/zecure.png',
                          height: 50,
                          width: 50,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Zecure',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Making Zamboanga City safer through community-powered crime monitoring and real-time safety alerts.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 60),
            
            // Quick Links
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Links',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFooterLink('Features'),
                  _buildFooterLink('Benefits'),
                  _buildFooterLink('Hotlines'),
                  _buildFooterLink('Get Started'),
                ],
              ),
            ),
            
            // Contact Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get in Touch',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactInfo(Icons.location_on_outlined, 'Zamboanga City, Philippines'),
                  _buildContactInfo(Icons.email_outlined, 'info@zecure.ph'),
                  _buildContactInfo(Icons.phone_outlined, 'Emergency: 911'),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 50),
        
        // Divider
        Container(
          height: 1,
          color: Colors.grey.shade800,
        ),
        
        const SizedBox(height: 30),
        
        // Bottom section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Copyright
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '© 2025 Zecure. All rights reserved.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Salido, Sardani, Solis',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  'Western Mindanao State University - College of Computing Studies',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            
            // Social links (placeholder)
            Row(
              children: [
                _buildSocialIcon(Icons.facebook_rounded),
                const SizedBox(width: 12),
                _buildSocialIcon(Icons.verified_rounded),
                const SizedBox(width: 12),
                _buildSocialIcon(Icons.info_outline_rounded),
              ],
            ),
          ],
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
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isHovered ? Colors.blue.shade400 : Colors.grey.shade400,
              ),
              child: Text(text),
            ),
          ),
        );
      },
    ),
  );
}

void _scrollToSection(String section) {
  double offset;
  
  switch (section) {
    case 'features':
      offset = 800;
      break;
    case 'benefits':
      offset = 1500;
      break;
    case 'hotlines':
      offset = 2200;
      break;
    case 'get started':
      offset = 2900; // Scroll to CTA section
      break;
    default:
      offset = 0;
  }
  
  _scrollController.animateTo(
    offset,
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeInOut,
  );
}

Widget _buildContactInfo(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSocialIcon(IconData icon) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: HoverBuilder(
      builder: (isHovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered ? Colors.blue.shade600 : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        );
      },
    ),
  );
}

// REVAMPED CRIME LINE CHART
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
        ],
      ),
    );
  }

  final maxValue = _crimeData
      .map((e) => e['count'] as int)
      .reduce((a, b) => a > b ? a : b);

  final avgValue = _crimeData.fold<int>(0, (sum, item) => sum + (item['count'] as int)) /
      _crimeData.length;

  final totalReports = _crimeData.fold<int>(0, (sum, item) => sum + (item['count'] as int));

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
              horizontalInterval: (maxValue / 5).ceilToDouble().clamp(1, double.infinity),
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.15),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.1),
                strokeWidth: 1,
              ),
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
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  colors: [
                    Colors.blue.shade600,
                    Colors.purple.shade600,
                  ],
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
                    
                    if (!isLast && !isPeak) return FlDotCirclePainter(radius: 0);
                    
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.white,
                      strokeWidth: 3,
                      strokeColor: isPeak ? Colors.red.shade600 : Colors.blue.shade600,
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

Widget _buildStatBadge(String label, String value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
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

  const HoverBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

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