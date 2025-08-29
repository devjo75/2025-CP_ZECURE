import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FirstTimeWelcomeModal extends StatefulWidget {
  final String? userName;
  final VoidCallback onClose;

  const FirstTimeWelcomeModal({
    super.key,
    this.userName,
    required this.onClose,
  });

  @override
  State<FirstTimeWelcomeModal> createState() => _FirstTimeWelcomeModalState();
}

class _FirstTimeWelcomeModalState extends State<FirstTimeWelcomeModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
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
            color: Colors.black.withOpacity(0.6 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Confetti Effect
                ..._buildConfettiParticles(),
                
                // Main Modal
                Center(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: isWeb 
                          ? (screenWidth * 0.4).clamp(400.0, 520.0)
                          : screenWidth * 0.92,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                        maxWidth: isWeb ? 520 : double.infinity,
                      ),
                      margin: EdgeInsets.all(isWeb ? 20 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
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
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildConfettiParticles() {
    return List.generate(15, (index) {
      return AnimatedBuilder(
        animation: _confettiAnimation,
        builder: (context, child) {
          final double progress = _confettiAnimation.value;
          final double delay = index * 0.1;
          final double adjustedProgress = (progress - delay).clamp(0.0, 1.0);
          
          return Positioned(
            left: MediaQuery.of(context).size.width * (0.1 + (index % 5) * 0.2),
            top: MediaQuery.of(context).size.height * 0.1 + 
                 adjustedProgress * MediaQuery.of(context).size.height * 0.8,
            child: Transform.rotate(
              angle: adjustedProgress * 6.28 * 2, // 2 full rotations
              child: Opacity(
                opacity: (1 - adjustedProgress).clamp(0.0, 1.0),
                child: Container(
                  width: 8 + (index % 3) * 4,
                  height: 8 + (index % 3) * 4,
                  decoration: BoxDecoration(
                    color: [
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.purple,
                      Colors.pink,
                    ][index % 5],
                    shape: index % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: index % 2 == 1 ? BorderRadius.circular(2) : null,
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildHeader(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWeb ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade600,
            Colors.green.shade500,
            Colors.blue.shade600,
          ],
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Celebration Icon with pulse effect
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_confettiAnimation.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration_rounded,
                    color: Colors.white,
                    size: isWeb ? 50 : 45,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Welcome Message
          Text(
            '🎉 Welcome to Zecure!',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            widget.userName != null 
                ? 'Hi ${widget.userName}! Your account is ready to go.'
                : 'Your account has been created successfully!',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 16 : 15,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Created Successfully!',
                        style: GoogleFonts.poppins(
                          fontSize: isWeb ? 16 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can now access all Zecure safety features.',
                        style: GoogleFonts.poppins(
                          fontSize: isWeb ? 13 : 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'What you can do now:',
            style: GoogleFonts.poppins(
              fontSize: isWeb ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildFeatureList(isWeb, [
            {
              'icon': Icons.report_rounded, 
              'title': 'Report Safety Incidents',
              'description': 'Help your community by reporting safety concerns in your area.',
              'color': Colors.red.shade600,
            },
            {
              'icon': Icons.route_rounded, 
              'title': 'Get Safe Routes',
              'description': 'Receive personalized route suggestions based on current safety data.',
              'color': Colors.blue.shade600,
            },
            {
              'icon': Icons.notifications_active_rounded, 
              'title': 'Real-time Alerts',
              'description': 'Stay informed with instant safety alerts in your vicinity.',
              'color': Colors.orange.shade600,
            },
            {
              'icon': Icons.analytics_rounded, 
              'title': 'Safety Analytics',
              'description': 'View detailed safety statistics and trends for Zamboanga City.',
              'color': Colors.purple.shade600,
            },
          ]),
          
          const SizedBox(height: 20),
          
          // Getting Started Tips
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Quick Start Tips',
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTip('📍 Explore the map to see safety hotspots in your area'),
                _buildTip('🔔 Enable notifications for real-time safety updates'),
                _buildTip('👥 Your reports help make the community safer for everyone'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.blue.shade700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildFeatureList(bool isWeb, List<Map<String, dynamic>> features) {
    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (feature['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature['icon'],
                  size: 20,
                  color: feature['color'],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'],
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['description'],
                      style: GoogleFonts.poppins(
                        fontSize: isWeb ? 12 : 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 24),
      child: Column(
        children: [
          // Start Exploring Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: Colors.green.shade200,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Start Exploring Zecure',
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
    );
  }
}

// Helper function to show the first-time welcome modal
void showFirstTimeWelcomeModal(
  BuildContext context, {
  String? userName,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return FirstTimeWelcomeModal(
        userName: userName,
        onClose: () => Navigator.of(context).pop(),
      );
    },
  );
}