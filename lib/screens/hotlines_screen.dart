import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:zecure/services/hotline_service.dart';
import 'package:zecure/screens/hotlines_admin_screen.dart';


class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key});

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  final HotlineService _hotlineService = HotlineService();
  final AuthService _authService = AuthService(Supabase.instance.client); // Add this
  List<Map<String, dynamic>> hotlines = [];
  bool isLoading = true;
  String? errorMessage;
  bool isAdmin = false; // Add this

  @override
  void initState() {
    super.initState();
    _loadHotlines();
    _checkAdminStatus();
  }

Future<void> _loadHotlines() async {
  try {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Pass forceRefresh = false to use cache
    final data = await _hotlineService.fetchHotlineData(forceRefresh: false);

    setState(() {
      hotlines = data;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      errorMessage = 'Failed to load hotlines: $e';
      isLoading = false;
    });
  }
}

  Future<void> _checkAdminStatus() async {
  try {
    final adminStatus = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        isAdmin = adminStatus;
      });
    }
  } catch (e) {
    print('Error checking admin status: $e');
    if (mounted) {
      setState(() {
        isAdmin = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LIGHT.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC).withOpacity(0.2),
          ),
          child: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  pinned: false,
                  floating: false,
                  expandedHeight: 0,
                  flexibleSpace: Container(),
                  title: const Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.8,
                      color: Color(0xFF1A1D29),
                    ),
                  ),
                  foregroundColor: const Color(0xFF1A1D29),
                  centerTitle: false,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    // Add admin button if user is admin
                    if (isAdmin)
IconButton(
  icon: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey.shade200,
        width: 1,
      ),
    ),
    child: Icon(
      Icons.edit_rounded,
      color: Colors.grey.shade600,
      size: 18,
    ),
  ),
  onPressed: () async {
    // Navigate and wait for return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HotlinesAdminScreen(),
      ),
    );
    
    // Refresh from cache (instant, no database call)
    if (mounted) {
      final cachedData = await _hotlineService.fetchHotlineData(forceRefresh: false);
      setState(() {
        hotlines = cachedData;
      });
    }
  },
  tooltip: 'Manage Hotlines',
),

                      //REFRESH BUTTON
                   // IconButton(
                   //   icon: const Icon(Icons.refresh_rounded),
                   //   onPressed: _loadHotlines,
                   //   tooltip: 'Refresh',
                  //  ),
],
                ),
              ];
            },
            body: isLoading
                ? _buildLoadingState()
                : errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading hotlines...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHotlines,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (hotlines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_disabled_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hotlines available',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 20),
                _build911Button(),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final category = hotlines[index];
              return _buildCategoryCard(category);
            },
            childCount: hotlines.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 92, 118, 165),
            Color.fromARGB(255, 61, 91, 131),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.phone_in_talk,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tap to call or send SMS instantly',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hotline Services',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBadge(Icons.access_time_rounded, '24/7 Available'),
              const SizedBox(width: 12),
              _buildBadge(Icons.verified_rounded, 'Verified'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build911Button() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _makePhoneCall('911'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '911',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Emergency Hotline',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          iconColor: Colors.grey[400],
          collapsedIconColor: Colors.grey[400],
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCategoryColorFromString(category['color']).withOpacity(0.1),
                      _getCategoryColorFromString(category['color']).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _getCategoryColorFromString(category['color']).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _getIconFromString(category['icon']),
                  color: _getCategoryColorFromString(category['color']),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['category'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (category['description'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        category['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          children: _buildCategoryContent(category),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryContent(Map<String, dynamic> category) {
    List<Widget> children = [];

    if (category.containsKey('numbers')) {
      children.addAll(
        (category['numbers'] as List).map(
          (hotline) => _buildHotlineItem(
            hotline['name'],
            hotline['number'],
          ),
        ),
      );
    }

    if (category.containsKey('stations')) {
      children.addAll(_buildStations(category['stations']));
    }

    return children;
  }

  List<Widget> _buildStations(List stations) {
    return stations.map<Widget>((station) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              station['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),
          ...(station['numbers'] as List).map<Widget>(
            (number) => _buildHotlineItem(station['name'], number),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildHotlineItem(String name, String number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.call_rounded,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  onPressed: () => _makePhoneCall(number),
                  tooltip: 'Call',
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.message_rounded,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  onPressed: () => _sendSMS(number),
                  tooltip: 'SMS',
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    final icons = {
      'warning_rounded': Icons.warning_rounded,
      'local_hospital_rounded': Icons.local_hospital_rounded,
      'security_rounded': Icons.security_rounded,
      'local_police_rounded': Icons.local_police_rounded,
      'local_fire_department_rounded': Icons.local_fire_department_rounded,
      'shield_rounded': Icons.shield_rounded,
      'contact_phone_rounded': Icons.contact_phone_rounded,
    };
    return icons[iconName] ?? Icons.contact_phone_rounded;
  }

  Color _getCategoryColorFromString(String colorName) {
    final colors = {
      'orange_600': Colors.orange.shade600,
      'pink_600': Colors.pink.shade600,
      'indigo_600': Colors.indigo.shade600,
      'blue_600': Colors.blue.shade600,
      'deepOrange_600': Colors.deepOrange.shade600,
      'purple_600': Colors.purple.shade600,
      'grey_600': Colors.grey.shade600,
    };
    return colors[colorName] ?? Colors.grey.shade600;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }
}