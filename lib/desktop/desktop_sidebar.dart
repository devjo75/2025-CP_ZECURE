import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';



// Responsive navigation wrapper that switches between sidebar and bottom nav

class ResponsiveNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadNotificationCount;
  final bool isSidebarVisible;
  final VoidCallback? onToggle;
  final bool isUserLoggedIn;



  const ResponsiveNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.unreadNotificationCount,
    this.isSidebarVisible = false, // Changed default to false (mini sidebar)
    this.onToggle,
    required this.isUserLoggedIn,
  });



  @override

  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;



    if (isDesktop && isUserLoggedIn) {
      // Show sidebar on desktop for logged-in users

      return DesktopSidebar(
        currentIndex: currentIndex,
        onTap: onTap,
        unreadNotificationCount: unreadNotificationCount,
        isVisible: isSidebarVisible,
        onToggle: onToggle,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}



class DesktopSidebar extends StatelessWidget {

  final int currentIndex;

  final Function(int) onTap;

  final int unreadNotificationCount;

  final bool isVisible;

  final VoidCallback? onToggle;



  const DesktopSidebar({

    super.key,

    required this.currentIndex,

    required this.onTap,

    required this.unreadNotificationCount,

    this.isVisible = false, // Changed default to false (mini sidebar)

    this.onToggle,

  });



  @override

  Widget build(BuildContext context) {

    return AnimatedContainer(

      duration: const Duration(milliseconds: 300),

      curve: Curves.easeInOut,

      width: isVisible ? 280 : 64, // Full sidebar: 280, Mini sidebar: 64

      height: double.infinity,

      decoration: BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.08),

            blurRadius: 12,

            offset: const Offset(2, 0),

          ),

        ],

      ),

      child: isVisible ? _buildSidebarContent() : _buildMiniSidebarContent(context),

    );

  }



  Widget _buildSidebarContent() {

    return Column(

      children: [

        // Logo section with gradient header

        _buildGradientHeader(),

        

        // Navigation items - Scrollable middle section

        Expanded(

          child: SingleChildScrollView(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),

            child: Column(

              children: [

                const SizedBox(height: 8),

                

                // Navigation Items

                _buildModernNavItem(

                  index: 0,

                  icon: Icons.map_rounded,

                  title: 'Map',

                  subtitle: 'View locations',

                  isActive: currentIndex == 0,

                  onTap: () => onTap(0),

                ),

                const SizedBox(height: 4),

                _buildModernNavItem(

                  index: 1,

                  icon: Icons.directions,

                  title: 'Quick Access',

                  subtitle: 'Safety features',

                  isActive: currentIndex == 1,

                  onTap: () => onTap(1),

                ),



                const SizedBox(height: 4),

              // Add Save Points navigation item

              _buildModernNavItem(

                index: 4,

                icon: Icons.bookmark_rounded,

                title: 'Save Points',

                subtitle: 'Saved locations',

                isActive: currentIndex == 4,

                onTap: () => onTap(4),

              ),

                const SizedBox(height: 4),

                _buildModernNavItem(

                  index: 2,

                  icon: Icons.notifications_rounded,

                  title: 'Notifications',

                  subtitle: 'Alerts & updates',

                  isActive: currentIndex == 2,

                  onTap: () => onTap(2),

                  badge: unreadNotificationCount > 0 ? unreadNotificationCount : null,

                ),

                const SizedBox(height: 4),

                _buildModernNavItem(

                  index: 3,

                  icon: Icons.person_rounded,

                  title: 'Profile',

                  subtitle: 'Account settings',

                  isActive: currentIndex == 3,

                  onTap: () => onTap(3),

                ),

                

                // Extra space for scrolling

                const SizedBox(height: 100),

              ],

            ),

          ),

        ),

        

        // Fixed bottom section

        _buildBottomSection(),

      ],

    );

  }



  Widget _buildMiniSidebarContent(BuildContext context) {

    return Column(

      children: [

        // Top padding

        SizedBox(height: MediaQuery.of(context).padding.top + 20),

        

        // Mini logo at top

        _buildMiniLogo(),

        

        const SizedBox(height: 24),

        

        // Mini navigation items

        _buildMiniNavItem(

          index: 0,

          icon: Icons.map_rounded,

          title: 'Map',

          isActive: currentIndex == 0,

          onTap: () => onTap(0),

        ),

        const SizedBox(height: 8),

        _buildMiniNavItem(

          index: 1,

          icon: Icons.directions,

          title: 'Navigation',

          isActive: currentIndex == 1,

          onTap: () => onTap(1),

        ),



      const SizedBox(height: 8),

      // Add Save Points mini navigation item

      _buildMiniNavItem(

        index: 4,

        icon: Icons.bookmark_rounded,

        title: 'Save Points',

        isActive: currentIndex == 4,

        onTap: () => onTap(4),

      ),

      

        const SizedBox(height: 8),

        _buildMiniNavItem(

          index: 2,

          icon: Icons.notifications_rounded,

          title: 'Notifications',

          isActive: currentIndex == 2,

          onTap: () => onTap(2),

          badge: unreadNotificationCount > 0 ? unreadNotificationCount : null,

        ),

        const SizedBox(height: 8),

        _buildMiniNavItem(

          index: 3,

          icon: Icons.person_rounded,

          title: 'Profile',

          isActive: currentIndex == 3,

          onTap: () => onTap(3),

        ),

        

        // Spacer to fill remaining space

        const Spacer(),

        

        const SizedBox(height: 20),

      ],

    );

  }



  Widget _buildMiniLogo() {

    return Container(

      width: 48,

      height: 48,

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.08),

            blurRadius: 8,

            offset: const Offset(0, 2),

            spreadRadius: 0,

          ),

        ],

        border: Border.all(

          color: const Color(0xFFE5E7EB),

          width: 1,

        ),

      ),

      child: ClipRRect(

        borderRadius: BorderRadius.circular(12),

        child: Image.asset(

          'assets/images/zecure.png',

          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {

            return const Icon(

              Icons.security_rounded,

              color: Color(0xFF4F8EF7),

              size: 28,

            );

          },

        ),

      ),

    );

  }



  Widget _buildMiniNavItem({

    required int index,

    required IconData icon,

    required String title,

    required bool isActive,

    required VoidCallback onTap,

    int? badge,

  }) {

    return Tooltip(

      message: title,

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          borderRadius: BorderRadius.circular(12),

          onTap: onTap,

          child: Container(

            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(

              color: isActive 

                  ? const Color(0xFF4F8EF7).withOpacity(0.1)

                  : Colors.transparent,

              borderRadius: BorderRadius.circular(12),

            ),

            child: Stack(

              clipBehavior: Clip.none,

              children: [

                Icon(

                  icon,

                  color: isActive 

                      ? const Color(0xFF4F8EF7) 

                      : const Color(0xFF6B7280),

                  size: 24,

                ),

                if (badge != null)

                  Positioned(

                    right: -8,

                    top: -8,

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),

                      decoration: BoxDecoration(

                        color: Colors.red,

                        borderRadius: BorderRadius.circular(10),

                        border: Border.all(color: Colors.white, width: 2),

                      ),

                      constraints: const BoxConstraints(

                        minWidth: 20,

                        minHeight: 20,

                      ),

                      child: Text(

                        badge > 99 ? '99+' : '$badge',

                        style: const TextStyle(

                          color: Colors.white,

                          fontSize: 11,

                          fontWeight: FontWeight.bold,

                        ),

                        textAlign: TextAlign.center,

                      ),

                    ),

                  ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _buildGradientHeader() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),

        decoration: BoxDecoration(

          image: DecorationImage(

            image: AssetImage('assets/images/DARK.jpg'),

            fit: BoxFit.cover,

          ),

        ),

      child: Column(

        children: [

          // Logo container with improved styling

          Container(

            width: 70,

            height: 70,

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(20),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.08),

                  blurRadius: 12,

                  offset: const Offset(0, 4),

                  spreadRadius: 0,

                ),

              ],

            ),

            child: ClipRRect(

              borderRadius: BorderRadius.circular(20),

              child: Image.asset(

                'assets/images/zecure.png',

                fit: BoxFit.cover,

                errorBuilder: (context, error, stackTrace) {

                  return const Icon(

                    Icons.security_rounded,

                    color: Color(0xFF4F8EF7),

                    size: 35,

                  );

                },

              ),

            ),

          ),

          const SizedBox(height: 16),

          const Text(

            'ZECURE',

            style: TextStyle(

              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.bold,

              letterSpacing: 1.2,

            ),

          ),

          const SizedBox(height: 4),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),

            decoration: BoxDecoration(

              color: Colors.white.withOpacity(0.2),

              borderRadius: BorderRadius.circular(12),

            ),

            child: const Text(

              'Your Safety Companion',

              style: TextStyle(

                color: Colors.white,

                fontSize: 12,

                fontWeight: FontWeight.w500,

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildModernNavItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive 
                  ? const Color(0xFF4F8EF7).withOpacity(0.1) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isActive 
                  ? Border.all(
                      color: const Color(0xFF4F8EF7).withOpacity(0.2), 
                      width: 1
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Icon container with badge support
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive 
                            ? const Color(0xFF4F8EF7).withOpacity(0.15)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: !isActive 
                            ? Border.all(
                                color: const Color(0xFFE5E7EB), 
                                width: 1
                              )
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isActive 
                            ? const Color(0xFF4F8EF7) 
                            : const Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                    // Notification badge
                    if (badge != null)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5, 
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive 
                              ? const Color(0xFF374151) 
                              : const Color(0xFF6B7280),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isActive 
                              ? const Color(0xFF6B7280) 
                              : const Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active indicator
                if (isActive)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F8EF7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }



Widget _buildBottomSection() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Divider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          height: 1,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        // Version info (moved up)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '2025 Zecure Security',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '© Salido Sardani Solis',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'WMSU - CCS',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF), // Darker grey for better visibility
                  fontWeight: FontWeight.w600,
                ),
              ),

              

              // New social media section (moved below WMSU-CCS)
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SocialIconWidget(
                    icon: FontAwesomeIcons.facebookF,
                    url: 'https://www.facebook.com/venard.jhon.c.salido',
                    hoverColor: const Color(0xFF1877F2), // Facebook Blue
                  ),
                  const SizedBox(width: 12),
                  SocialIconWidget(
                    icon: FontAwesomeIcons.instagram,
                    url: 'https://www.instagram.com/venplaystrings/',
                    hoverColor: const Color(0xFFC13584), // Instagram Purple/Pink
                  ),
                  const SizedBox(width: 12),
                  SocialIconWidget(
                    icon: FontAwesomeIcons.linkedinIn,
                    url: 'https://www.linkedin.com/in/venard-jhon-cabahug-salido-08041434b/',
                    hoverColor: const Color(0xFF0A66C2), // LinkedIn Blue
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

}





// New Stateful Widget for the Social Icons with hover glow effect

class SocialIconWidget extends StatefulWidget {
  final IconData icon;
  final String url;
  final Color hoverColor;
  const SocialIconWidget({
    super.key,
    required this.icon,
    required this.url,
    required this.hoverColor,
  });

  @override
  State<SocialIconWidget> createState() => _SocialIconWidgetState();
}



class _SocialIconWidgetState extends State<SocialIconWidget> {
  bool _isHovering = false;
  // Function to launch the URL
  void _launchURL() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }



  @override

  Widget build(BuildContext context) {
    // Define the color variables based on hover state
    final Color glowColor = _isHovering ? widget.hoverColor : const Color(0xFFE5E7EB);
    final Color iconColor = _isHovering ? widget.hoverColor : const Color(0xFF6B7280);
    final double blurRadius = _isHovering ? 8.0 : 0.0;
    final double borderWidth = _isHovering ? 2.0 : 1.0;
    final Color borderColor = _isHovering ? widget.hoverColor.withOpacity(0.5) : const Color(0xFFE5E7EB);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _launchURL,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white, // Background color remains white
            borderRadius: BorderRadius.circular(18), // Half of width/height for full circle
            border: Border.all(
              color: borderColor, // Border glows
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(_isHovering ? 0.6 : 0.0), // Glow effect
                blurRadius: blurRadius,
                spreadRadius: 0.0,
                offset: const Offset(0, 0),
              ),
              // Optional subtle static shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),

          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.icon,
                color: iconColor, // Icon glows
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Responsive toggle button that shows/hides based on screen size and login status
class ResponsiveSidebarToggle extends StatelessWidget {
  final bool isSidebarVisible;
  final VoidCallback onToggle;
  final bool isUserLoggedIn;
  final int currentTab; // To only show on map screen

  const ResponsiveSidebarToggle({
    super.key,
    required this.isSidebarVisible,
    required this.onToggle,
    required this.isUserLoggedIn,
    required this.currentTab,
  });
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    // Only show toggle button on desktop, when user is logged in, and on map screen (index 0)
    if (!isDesktop || !isUserLoggedIn || currentTab != 0) {
      return const SizedBox.shrink();
    }



    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: isSidebarVisible ? 296 : 80, // Adjusted position for mini sidebar
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            icon: Icon(
              isSidebarVisible ? Icons.menu_open : Icons.menu,
              color: Colors.grey.shade700,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}