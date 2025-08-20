import 'package:flutter/material.dart';

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
    this.isSidebarVisible = true,
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
      // Return empty container - mobile bottom nav is handled separately
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
    this.isVisible = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isVisible ? 280 : 0,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: isVisible ? _buildSidebarContent() : null,
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
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  subtitle: 'Alerts & updates',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                  badge: unreadNotificationCount > 0 ? unreadNotificationCount : null,
                ),
                const SizedBox(height: 4),
                _buildModernNavItem(
                  index: 2,
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  subtitle: 'Account settings',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
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

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 92, 118, 165), 
            Color.fromARGB(255, 61, 91, 131)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          
          // Version info
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
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
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
      left: isSidebarVisible ? 296 : 16,
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