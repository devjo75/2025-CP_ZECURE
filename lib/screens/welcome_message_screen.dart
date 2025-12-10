// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zecure/desktop/hotlines_desktop.dart';
import 'package:zecure/screens/hotlines_screen.dart';
import 'package:zecure/screens/admin_dashboard.dart';

enum UserType { guest, user, admin, officer, tanod }

class WelcomeMessageModal extends StatefulWidget {
  final UserType userType;
  final String? userName;
  final VoidCallback onClose;
  final VoidCallback? onCreateAccount;
  final bool isSidebarVisible; // Add sidebar visibility
  final double sidebarWidth; // Add sidebar width

  const WelcomeMessageModal({
    super.key,
    required this.userType,
    this.userName,
    required this.onClose,
    this.onCreateAccount,
    this.isSidebarVisible = true, // Default value
    this.sidebarWidth = 280, // Default value, adjust to match your app
  });

  @override
  State<WelcomeMessageModal> createState() => _WelcomeMessageModalState();
}

class _WelcomeMessageModalState extends State<WelcomeMessageModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: isWeb
                      ? (screenWidth * 0.4).clamp(400.0, 500.0)
                      : screenWidth * 0.9,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: isWeb ? 500 : double.infinity,
                  ),
                  margin: EdgeInsets.all(isWeb ? 20 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 3,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(isWeb),
                          _buildContent(isWeb),
                          _buildActions(isWeb),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isWeb) {
    Color headerColor;
    IconData headerIcon;
    String title;

    switch (widget.userType) {
      case UserType.guest:
        headerColor = Colors.blue.shade600;
        headerIcon = Icons.explore_rounded;
        title = 'Welcome to Zecure!';
        break;
      case UserType.user:
        headerColor = Colors.green.shade600;
        headerIcon = Icons.person_rounded;
        title =
            'Welcome Back${widget.userName != null ? ', ${widget.userName}' : ''}!';
        break;
      case UserType.admin:
        headerColor = Color.fromARGB(255, 61, 91, 131);
        headerIcon = Icons.admin_panel_settings_rounded;
        title = "Welcome back, Admin!";
        break;
      case UserType.officer:
        headerColor = Colors.indigo.shade600;
        headerIcon = Icons.local_police_rounded;
        title = "Welcome, Officer\n${widget.userName ?? ''}!";
        break;
      case UserType.tanod:
        headerColor = Colors.teal.shade600;
        headerIcon = Icons.shield_rounded;
        title = "Welcome, Tanod\n${widget.userName ?? ''}!";
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [headerColor, headerColor.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: _handleClose,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(headerIcon, color: Colors.white, size: isWeb ? 40 : 35),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 22 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_getContentForUserType(isWeb)],
      ),
    );
  }

  Widget _getContentForUserType(bool isWeb) {
    switch (widget.userType) {
      case UserType.guest:
        return _buildGuestContent(isWeb);
      case UserType.user:
        return _buildUserContent(isWeb);
      case UserType.officer:
        return _buildOfficerContent(isWeb);
      case UserType.admin:
        return _buildAdminContent(isWeb);
      case UserType.tanod: // Add this
        return _buildTanodContent(isWeb);
    }
  }

  Widget _buildGuestContent(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thanks for exploring Zecure!',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          "As a guest, you can explore the safety map to view safe areas and crime hotspots in Zamboanga City. However, some features are limited:",
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 14 : 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        _buildFeatureList(isWeb, [
          {
            'icon': Icons.visibility_rounded,
            'text': 'Check safe areas and nearby crime areas',
            'available': true,
          },
          {
            'icon': Icons.map_rounded,
            'text': 'Browse the interactive safety map',
            'available': true,
          },
          {
            'icon': Icons.report_problem_rounded,
            'text': 'Report safety incidents',
            'available': false,
          },
          {
            'icon': Icons.add_location_alt_rounded,
            'text': 'Mark safe locations',
            'available': false,
          },
          {
            'icon': Icons.notifications_rounded,
            'text': 'Receive safety alerts',
            'available': false,
          },
        ]),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Want to report incidents or get personalized safety features? Create a free account to unlock all features!',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.blue.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Emergency Hotlines Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.blueGrey.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Hotlines Available',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 13 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                    Text(
                      'Access emergency contacts anytime',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 12 : 11,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (isWeb) {
                    FocusScope.of(
                      context,
                    ).unfocus(); // Remove focus before opening modal
                    showHotlinesModal(
                      context,
                      isSidebarVisible: widget.isSidebarVisible,
                      sidebarWidth: widget.sidebarWidth,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HotlinesScreen(),
                      ),
                    );
                  }
                },
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserContent(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Great to see you again!',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'You now have full access to all Zecure safety features. Here\'s what you can do:',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 14 : 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        _buildFeatureList(isWeb, [
          {
            'icon': Icons.report_rounded,
            'text': 'Report safety incidents in your area',
            'available': true,
          },
          {
            'icon': Icons.add_location_alt_rounded,
            'text': 'Mark safe locations for the community map',
            'available': true,
          },
          {
            'icon': Icons.notifications_active_rounded,
            'text': 'Receive real-time safety alerts',
            'available': true,
          },
          {
            'icon': Icons.people_rounded,
            'text': 'Contribute to community safety data',
            'available': true,
          },
          {
            'icon': Icons.forum_rounded,
            'text': 'Join discussions on reported incidents',
            'available': true,
          },
        ]),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your reports help make Zamboanga City safer for everyone. Thank you for being part of our community!',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.green.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.blueGrey.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quick access to emergency hotlines is always available for your safety.',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.blueGrey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (isWeb) {
                    FocusScope.of(
                      context,
                    ).unfocus(); // Remove focus before opening modal
                    showHotlinesModal(
                      context,
                      isSidebarVisible: widget.isSidebarVisible,
                      sidebarWidth: widget.sidebarWidth,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HotlinesScreen(),
                      ),
                    );
                  }
                },
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminContent(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Dashboard Access',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'You have administrative privileges for managing Zecure\'s safety data and user reports:',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 14 : 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        _buildFeatureList(isWeb, [
          {
            'icon': Icons.verified_rounded,
            'text': 'Review and approve incident reports',
            'available': true,
          },
          {
            'icon': Icons.add_location_rounded,
            'text': 'Approve and verify community safe spots',
            'available': true,
          },
          {
            'icon': Icons.analytics_rounded,
            'text': 'Access safety analytics and trends',
            'available': true,
          },
          {
            'icon': Icons.dashboard_rounded,
            'text': 'Access comprehensive crime analytics dashboard',
            'available': true,
          },
          {
            'icon': Icons.heat_pump_rounded,
            'text': 'Manage crime hotspot zones and boundaries',
            'available': true,
          },
        ]),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Colors.purple.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please handle all data responsibly and ensure the privacy and safety of our community members.',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.purple.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficerContent(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Officer Dashboard Access',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'You have officer privileges for managing safety reports and community data:',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 14 : 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        _buildFeatureList(isWeb, [
          {
            'icon': Icons.verified_rounded,
            'text': 'Review and verify incident reports',
            'available': true,
          },
          {
            'icon': Icons.add_location_rounded,
            'text': 'Approve and verify community safe spots',
            'available': true,
          },
          {
            'icon': Icons.dashboard_rounded,
            'text': 'View crime analytics and safety trends',
            'available': true,
          },
          {
            'icon': Icons.rate_review_rounded,
            'text': 'Respond to community feedback and queries',
            'available': true,
          },
          {
            'icon': Icons.add_circle_outline_rounded,
            'text': 'Manage crime hotspot zones and boundaries',
            'available': true,
          },
        ]),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: Colors.indigo.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your role is crucial in maintaining community safety. Thank you for your service to Zamboanga City.',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.indigo.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList(bool isWeb, List<Map<String, dynamic>> features) {
    return Column(
      children: features.map((feature) {
        final bool isAvailable = feature['available'] ?? true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'],
                  size: 18,
                  color: isAvailable
                      ? Colors.green.shade600
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature['text'],
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: isAvailable
                        ? Colors.grey.shade700
                        : Colors.grey.shade500,
                    decoration: isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
              if (!isAvailable)
                Icon(Icons.lock_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 20),
      child: Column(
        children: [
          if (widget.userType == UserType.guest &&
              widget.onCreateAccount != null) ...[
            // Create Account Button for guests
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _animationController.reverse().then((_) {
                    if (mounted) {
                      Navigator.of(context).pop(); // Close modal first
                      widget.onCreateAccount?.call();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Create Free Account',
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
          ],

          if (widget.userType == UserType.admin) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _animationController.reverse().then((_) {
                    if (mounted) {
                      Navigator.of(context).pop(); // Close modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboardScreen(),
                        ),
                      );
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(
                    255,
                    61,
                    91,
                    131,
                  ), // Matches admin header color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dashboard_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Go to Dashboard',
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
          ],

          // Add this right after the admin dashboard button section in your WelcomeMessageModal
          if (widget.userType == UserType.officer) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _animationController.reverse().then((_) {
                    if (mounted) {
                      Navigator.of(context).pop(); // Close modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboardScreen(),
                        ),
                      );
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600, // Officer color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dashboard_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Check Out Dashboard',
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
          ],

          // Continue Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _handleClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                widget.userType == UserType.guest
                    ? 'Continue Exploring'
                    : 'Continue to App',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanodContent(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barangay Safety Officer Access',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'You have barangay-level authority to manage safety in your community:',
          style: GoogleFonts.poppins(
            fontSize: isWeb ? 14 : 13,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        _buildFeatureList(isWeb, [
          {
            'icon': Icons.verified_rounded,
            'text': 'Verify low and medium-level incident reports',
            'available': true,
          },
          {
            'icon': Icons.add_location_rounded,
            'text': 'Mark and verify safe locations in your barangay',
            'available': true,
          },
          {
            'icon': Icons.forum_rounded,
            'text': 'Join discussions on reported incidents',
            'available': true,
          },
          {
            'icon': Icons.map_rounded,
            'text': 'Monitor safety patterns in your assigned area',
            'available': true,
          },
          {
            'icon': Icons.campaign_rounded,
            'text': 'Alert residents about local safety concerns',
            'available': true,
          },
        ]),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.people_rounded, color: Colors.teal.shade600, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'As a Barangay Tanod, you are the first line of defense for your community. Thank you for keeping your neighborhood safe!',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.teal.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.blueGrey.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quick access to emergency hotlines is always available.',
                  style: GoogleFonts.poppins(
                    fontSize: isWeb ? 13 : 12,
                    color: Colors.blueGrey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (isWeb) {
                    FocusScope.of(context).unfocus();
                    showHotlinesModal(
                      context,
                      isSidebarVisible: widget.isSidebarVisible,
                      sidebarWidth: widget.sidebarWidth,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HotlinesScreen(),
                      ),
                    );
                  }
                },
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Helper function to show the welcome modal
void showWelcomeModal(
  BuildContext context, {
  required UserType userType,
  String? userName,
  VoidCallback? onCreateAccount,
  bool isSidebarVisible = true, // Add sidebar visibility
  double sidebarWidth = 280, // Add sidebar width
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WelcomeMessageModal(
        userType: userType,
        userName: userName,
        onClose: () => Navigator.of(context).pop(),
        onCreateAccount: onCreateAccount,
        isSidebarVisible: isSidebarVisible,
        sidebarWidth: sidebarWidth,
      );
    },
  );
}
