
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'SF Pro Display',
      ),
      home: const AdminDashboardScreen(),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _crimeStats = {};
  Map<String, dynamic> _reportStats = {};
  Map<String, dynamic> _activityStats = {};
  List<Map<String, dynamic>> _hotspotData = [];
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDashboardData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      curve: Curves.easeOutCubic,
    ));

    _chartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _chartController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _loadUserStats(),
        _loadCrimeStats(),
        _loadReportStats(),
        _loadActivityStats(),
        _loadHotspotData(),
      ]);
      
      // Start animations after data loads
      _fadeController.forward();
      _slideController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _chartController.forward();
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final genderResponse = await Supabase.instance.client
          .from('users')
          .select('gender')
          .not('gender', 'is', null);

      final roleResponse = await Supabase.instance.client
          .from('users')
          .select('role');

      Map<String, int> genderCounts = {};
      Map<String, int> roleCounts = {};

      for (var user in genderResponse) {
        String gender = user['gender'] ?? 'Not specified';
        genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
      }

      for (var user in roleResponse) {
        String role = user['role'] ?? 'user';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      setState(() {
        _userStats = {
          'gender': genderCounts,
          'role': roleCounts,
          'total': roleResponse.length,
        };
      });
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  Future<void> _loadCrimeStats() async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));

      final crimeResponse = await Supabase.instance.client
          .from('hotspot')
          .select('type_id, crime_type(name, level, category)')
          .gte('created_at', startDateStr)
          .lt('created_at', endDateStr);

      Map<String, int> crimeCounts = {};
      Map<String, int> levelCounts = {};
      Map<String, int> categoryCounts = {};

      for (var crime in crimeResponse) {
        if (crime['crime_type'] != null) {
          String name = crime['crime_type']['name'];
          String level = crime['crime_type']['level'];
          String category = crime['crime_type']['category'] ?? 'Other';

          crimeCounts[name] = (crimeCounts[name] ?? 0) + 1;
          levelCounts[level] = (levelCounts[level] ?? 0) + 1;
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
      }

      setState(() {
        _crimeStats = {
          'types': crimeCounts,
          'levels': levelCounts,
          'categories': categoryCounts,
          'total': crimeResponse.length,
        };
      });
    } catch (e) {
      print('Error loading crime stats: $e');
    }
  }

  Future<void> _loadHotspotData() async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));

      final hotspotResponse = await Supabase.instance.client
          .from('hotspot')
          .select('created_at, crime_type(name)')
          .gte('created_at', startDateStr)
          .lt('created_at', endDateStr)
          .eq('status', 'approved')
          .order('created_at');

      Map<String, int> dailyCounts = {};

      for (var hotspot in hotspotResponse) {
        String date = DateFormat('yyyy-MM-dd').format(
          DateTime.parse(hotspot['created_at'])
        );
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      List<Map<String, dynamic>> chartData = [];
      for (var entry in dailyCounts.entries) {
        chartData.add({
          'date': entry.key,
          'count': entry.value,
        });
      }

      chartData.sort((a, b) => a['date'].compareTo(b['date']));

      setState(() {
        _hotspotData = chartData;
      });
    } catch (e) {
      print('Error loading hotspot data: $e');
    }
  }

  Future<void> _loadReportStats() async {
    try {
      final reportResponse = await Supabase.instance.client
          .from('hotspot')
          .select('status')
          .gte('created_at', DateFormat('yyyy-MM-dd').format(_startDate))
          .lt('created_at', DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1))));

      Map<String, int> statusCounts = {
        'approved': 0,
        'pending': 0,
        'rejected': 0,
      };

      for (var report in reportResponse) {
        String status = report['status'] ?? 'pending';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      setState(() {
        _reportStats = {
          'status': statusCounts,
          'total': reportResponse.length,
        };
      });
    } catch (e) {
      print('Error loading report stats: $e');
    }
  }

  Future<void> _loadActivityStats() async {
    try {
      final activityResponse = await Supabase.instance.client
          .from('hotspot')
          .select('active_status')
          .gte('created_at', DateFormat('yyyy-MM-dd').format(_startDate))
          .lt('created_at', DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1))));

      Map<String, int> activityCounts = {
        'active': 0,
        'inactive': 0,
      };

      for (var activity in activityResponse) {
        String status = activity['active_status'] ?? 'active';
        activityCounts[status] = (activityCounts[status] ?? 0) + 1;
      }

      setState(() {
        _activityStats = {
          'status': activityCounts,
          'total': activityResponse.length,
        };
      });
    } catch (e) {
      print('Error loading activity stats: $e');
    }
  }

  Future<void> _selectDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Start date must be before end date'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      // Reset animations
      _fadeController.reset();
      _slideController.reset();
      _chartController.reset();
      
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 220, 234, 248), // Almost white with hint of blue
              Color.fromARGB(255, 190, 198, 207), // Light slate gray
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildDashboardContent(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Crime Analytics & Reports',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _fadeController.reset();
                _slideController.reset();
                _chartController.reset();
                _loadDashboardData();
              },
              tooltip: 'Refresh Data',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          SizedBox(height: 20),
          Text(
            'Loading dashboard data...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeCard(),
          const SizedBox(height: 24),
          _buildOverviewCards(),
          const SizedBox(height: 32),
          // Use LayoutBuilder for responsive design
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              return Column(
                children: [
                  _buildUserChartsSection(isWide: isWide),
                  const SizedBox(height: 32),
                  _buildCrimeChartsSection(isWide: isWide),
                  const SizedBox(height: 32),
                  _buildStatusChartsSection(isWide: isWide),
                  const SizedBox(height: 32),
                  _buildHotspotTrendSection(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Data Range',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            label: const Text('Change Range'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6366F1),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isTablet = constraints.maxWidth > 600;
        return isTablet
            ? Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      title: 'Total Users',
                      value: '${_userStats['total'] ?? 0}',
                      icon: Icons.people_alt_outlined,
                      gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                      delay: 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatsCard(
                      title: 'Total Reports',
                      value: '${_crimeStats['total'] ?? 0}',
                      icon: Icons.report_outlined,
                      gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
                      delay: 100,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatsCard(
                      title: 'Approved',
                      value: '${_reportStats['status']?['approved'] ?? 0}',
                      icon: Icons.check_circle_outline,
                      gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                      delay: 200,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatsCard(
                      title: 'Pending',
                      value: '${_reportStats['status']?['pending'] ?? 0}',
                      icon: Icons.pending_outlined,
                      gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      delay: 300,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Total Users',
                          value: '${_userStats['total'] ?? 0}',
                          icon: Icons.people_alt_outlined,
                          gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                          delay: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Total Reports',
                          value: '${_crimeStats['total'] ?? 0}',
                          icon: Icons.report_outlined,
                          gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
                          delay: 100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Approved',
                          value: '${_reportStats['status']?['approved'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                          delay: 200,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatsCard(
                          title: 'Pending',
                          value: '${_reportStats['status']?['pending'] ?? 0}',
                          icon: Icons.pending_outlined,
                          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                          delay: 300,
                        ),
                      ),
                    ],
                  ),
                ],
              );
      },
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required int delay,
  }) {
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_chartAnimation.value * 0.2),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    final animatedValue = (int.parse(value) * _chartAnimation.value).toInt();
                    return Text(
                      '$animatedValue',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserChartsSection({bool isWide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Statistics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        isWide 
            ? Row(
                children: [
                  Expanded(flex: 2, child: _buildGenderChartCards()),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildRoleChart()),
                ],
              )
            : Column(
                children: [
                  _buildGenderChartCards(),
                  const SizedBox(height: 20),
                  _buildRoleChart(),
                ],
              ),
      ],
    );
  }

  Widget _buildCrimeChartsSection({bool isWide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crime Statistics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        isWide
            ? Row(
                children: [
                  Expanded(child: _buildCrimeLevelsChart()),
                  const SizedBox(width: 20),
                  Expanded(child: _buildCrimeCategoriesChart()),
                ],
              )
            : Column(
                children: [
                  _buildCrimeLevelsChart(),
                  const SizedBox(height: 20),
                  _buildCrimeCategoriesChart(),
                ],
              ),
      ],
    );
  }

  Widget _buildStatusChartsSection({bool isWide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Analytics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        isWide
            ? Row(
                children: [
                  Expanded(child: _buildReportStatusChart()),
                  const SizedBox(width: 20),
                  Expanded(child: _buildActivityStatusChart()),
                ],
              )
            : Column(
                children: [
                  _buildReportStatusChart(),
                  const SizedBox(height: 20),
                  _buildActivityStatusChart(),
                ],
              ),
      ],
    );
  }

Widget _buildGenderChartCards() {
  // Define all possible genders you want to display
  List<String> allGenders = ['Male', 'Female', 'Others', 'LGBTQ+'];

  // Initialize genderData with actual data or an empty map
  Map<String, int> genderData = _userStats['gender'] ?? {};

  // Ensure all genders are present in genderData with a default value of 0
  for (var gender in allGenders) {
    genderData.putIfAbsent(gender, () => 0);
  }

  List<Color> colors = [
    const Color.fromARGB(255, 99, 137, 241),
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
  ];

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Users by Gender',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  sections: genderData.entries.map((entry) {
                    int index = allGenders.indexOf(entry.key);
                    double percentage = (entry.value / (_userStats['total'] ?? 1)) * 100;
                    double animatedValue = entry.value.toDouble() * _chartAnimation.value;

                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: 60 + (10 * _chartAnimation.value),
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: allGenders.length > 2 ? 2 : allGenders.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: allGenders.map((gender) {
            int index = allGenders.indexOf(gender);
            int value = genderData[gender] ?? 0;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors[index % colors.length].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors[index % colors.length].withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gender.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          value == 0 ? 'None' : '$value',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors[index % colors.length],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}


  Widget _buildRoleChart() {
    Map<String, int> roleData = _userStats['role'] ?? {};

    if (roleData.isEmpty) {
      return _buildEmptyCard('No role data available');
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Users by Role',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: roleData.values.isEmpty ? 10 : roleData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                    barGroups: roleData.entries.map((entry) {
                      int index = roleData.keys.toList().indexOf(entry.key);
                      double animatedHeight = entry.value.toDouble() * _chartAnimation.value;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: animatedHeight,
                            color: entry.key == 'admin' ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                            width: 32,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            gradient: LinearGradient(
                              colors: entry.key == 'admin' 
                                  ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                  : [const Color(0xFF10B981), const Color(0xFF059669)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            List<String> keys = roleData.keys.toList();
                            if (value.toInt() >= 0 && value.toInt() < keys.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  keys[value.toInt()].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Color(0xFFE5E7EB),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


Widget _buildCrimeLevelsChart() {
  // Define all possible crime severity levels
  List<String> allLevels = ['critical', 'high', 'medium', 'low'];

  // Initialize levelData with all levels and default value of 0
  Map<String, int> levelData = {for (var level in allLevels) level: 0};

  // Update levelData with actual data if it exists
  if (_crimeStats['levels'] != null) {
    _crimeStats['levels'].forEach((key, value) {
      if (levelData.containsKey(key)) {
        levelData[key] = value;
      }
    });
  }

  Map<String, Color> levelColors = {
    'critical': const Color.fromARGB(255, 247, 26, 10),
    'high': const Color.fromARGB(255, 223, 106, 11),
    'medium': const Color.fromARGB(155, 202, 130, 49),
    'low': const Color.fromARGB(255, 216, 187, 23),
  };

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Crimes by Severity Level',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  sections: levelData.entries.map((entry) {
                    double percentage = (entry.value / (_crimeStats['total'] ?? 1)) * 100;
                    double animatedValue = entry.value.toDouble() * _chartAnimation.value;
                    return PieChartSectionData(
                      color: levelColors[entry.key] ?? Colors.grey,
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: 60 + (10 * _chartAnimation.value),
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: allLevels.length > 2 ? 2 : allLevels.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: allLevels.map((level) {
            final color = levelColors[level] ?? Colors.grey;
            final value = levelData[level] ?? 0;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          value == 0 ? 'None' : '$value',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}


Widget _buildCrimeCategoriesChart() {
  Map<String, int> categoryData = _crimeStats['categories'] ?? {};

  if (categoryData.isEmpty) {
    return _buildEmptyCard('No crime category data available');
  }

  List<Color> colors = [
    const Color(0xFFDC2626),
    const Color(0xFF2563EB),
    const Color(0xFF059669),
    const Color(0xFF7C3AED),
    const Color(0xFFEA580C),
    const Color(0xFF0891B2),
  ];

  // Get max value for scaling
  int maxValue = categoryData.values.isEmpty ? 1 : categoryData.values.reduce((a, b) => a > b ? a : b);
  
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crimes by Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _chartAnimation,
          builder: (context, child) {
            return Column(
              children: categoryData.entries.map((entry) {
                int index = categoryData.keys.toList().indexOf(entry.key);
                Color barColor = colors[index % colors.length];
                double progress = (entry.value / maxValue) * _chartAnimation.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            entry.value.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: constraints.maxWidth * progress,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: LinearGradient(
                                      colors: [
                                        barColor.withOpacity(0.8),
                                        barColor,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: barColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildReportStatusChart() {
  final totalReports = _reportStats['total'] ?? 0;
  Map<String, int> statusData = _reportStats['status'] ?? {};
  statusData.removeWhere((key, value) => value == 0);

  if (totalReports == 0) {
    return _buildEmptyCard('No report status data available');
  }

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Reports by Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  sections: statusData.entries.map((entry) {
                    double percentage = (entry.value / totalReports) * 100;
                    double animatedValue =
                        entry.value.toDouble() * _chartAnimation.value;

                    return PieChartSectionData(
                      color: _getStatusColor(entry.key),
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8
                          ? '${percentage.toStringAsFixed(1)}%'
                          : '',
                      radius: 60 + (10 * _chartAnimation.value),
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // NEW Row of mini cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: statusData.entries.map((entry) {
            final color = _getStatusColor(entry.key);
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}


  Widget _buildActivityStatusChart() {
    final totalActivities = _activityStats['total'] ?? 0;
    Map<String, int> activityData = _activityStats['status'] ?? {};
    activityData.removeWhere((key, value) => value == 0);

    if (totalActivities == 0) {
      return _buildEmptyCard('No activity status data available');
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Reports by Activity Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: activityData.values.isEmpty 
                        ? 10 
                        : activityData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                    barGroups: activityData.entries.map((entry) {
                      int index = activityData.keys.toList().indexOf(entry.key);
                      double animatedHeight = entry.value.toDouble() * _chartAnimation.value;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: animatedHeight,
                            color: _getActivityColor(entry.key),
                            width: 40,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            gradient: LinearGradient(
                              colors: [
                                _getActivityColor(entry.key),
                                _getActivityColor(entry.key).withOpacity(0.7),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            List<String> keys = activityData.keys.toList();
                            if (value.toInt() >= 0 && value.toInt() < keys.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  keys[value.toInt()].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Color(0xFFE5E7EB),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: activityData.entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getActivityColor(entry.key),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.key.toUpperCase()}: ${entry.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

 Widget _buildHotspotTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crime Hotspot Trends',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        _buildHotspotLineChart(),
      ],
    );
  }

Widget _buildHotspotLineChart() {
  if (_hotspotData.isEmpty) {
    return _buildEmptyCard('No hotspot trend data available');
  }

  // Calculate chart dimensions based on screen size
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 600;
      final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
      
      // Responsive dimensions
      final chartHeight = isSmallScreen ? 220.0 : isMediumScreen ? 280.0 : 320.0;
      final leftReservedSize = isSmallScreen ? 32.0 : 40.0;
      final bottomReservedSize = isSmallScreen ? 25.0 : 35.0;
      final fontSize = isSmallScreen ? 9.0 : 11.0;
      
      // Calculate max Y value with proper padding
      final maxValue = _hotspotData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
      final maxY = (maxValue * 1.3).toDouble(); // 30% padding above max value
      
      // Calculate interval for better grid lines
      final interval = maxY > 20 ? (maxY / 8).ceil().toDouble() : 
                      maxY > 10 ? 2.0 : 1.0;

      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8.0 : 16.0,
        ),
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with responsive title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Crime Reports',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Trends over selected period',
                        style: TextStyle(
                          fontSize: fontSize,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Summary stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Total: ${_hotspotData.fold(0, (sum, item) => sum + (item['count'] as int))}',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            // Chart container with proper constraints
            SizedBox(
              height: chartHeight,
              child: AnimatedBuilder(
                animation: _chartAnimation,
                builder: (context, child) {
                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        drawHorizontalLine: true,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Color(0xFFE5E7EB),
                            strokeWidth: 0.8,
                            dashArray: [5, 5],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: leftReservedSize,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value % interval == 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF6B7280),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: bottomReservedSize,
                            interval: _calculateBottomInterval(_hotspotData.length, screenWidth),
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _hotspotData.length) {
                                // Show fewer labels on small screens
                                final showInterval = _calculateBottomInterval(_hotspotData.length, screenWidth);
                                if (index % showInterval.toInt() != 0 && 
                                    index != _hotspotData.length - 1) {
                                  return const Text('');
                                }
                                
                                String date = _hotspotData[index]['date'];
                                DateTime dateTime = DateTime.parse(date);
                                
                                // Responsive date format
                                String formattedDate = isSmallScreen 
                                  ? DateFormat('M/d').format(dateTime)
                                  : DateFormat('MMM d').format(dateTime);
                                
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      minX: 0,
                      maxX: (_hotspotData.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => const Color(0xFF1F2937).withOpacity(0.9),
                          tooltipBorder: const BorderSide(color: Color(0xFF374151), width: 1),
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final index = barSpot.x.toInt();
                              if (index >= 0 && index < _hotspotData.length) {
                                final date = _hotspotData[index]['date'];
                                final count = _hotspotData[index]['count'];
                                final dateTime = DateTime.parse(date);
                                
                                return LineTooltipItem(
                                  '${DateFormat('MMM d, yyyy').format(dateTime)}\n$count reports',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                        touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                          // Optional: Add haptic feedback on touch
                          if (event is FlTapUpEvent && touchResponse != null) {
                            // HapticFeedback.lightImpact();
                          }
                        },
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: const Color(0xFF6366F1).withOpacity(0.5),
                                strokeWidth: 2,
                                dashArray: [3, 3],
                              ),
                              FlDotData(
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: const Color(0xFF6366F1),
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _hotspotData.asMap().entries.map((entry) {
                            double animatedY = entry.value['count'].toDouble() * _chartAnimation.value;
                            return FlSpot(
                              entry.key.toDouble(),
                              animatedY,
                            );
                          }).toList(),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          preventCurveOverShooting: true,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          barWidth: isSmallScreen ? 3.0 : 4.0,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1).withOpacity(0.2),
                                const Color(0xFF8B5CF6).withOpacity(0.05),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            cutOffY: 0,
                            applyCutOffY: true,
                          ),
                          dotData: FlDotData(
                            show: !isSmallScreen, // Hide dots on small screens for cleaner look
                            getDotPainter: (spot, percent, barData, index) {
                              // Highlight peak values with larger dots
                              final isHighValue = spot.y > maxValue * 0.8;
                              return FlDotCirclePainter(
                                radius: isHighValue ? 5 : 4,
                                color: Colors.white,
                                strokeWidth: isHighValue ? 3 : 2,
                                strokeColor: isHighValue 
                                  ? const Color(0xFFDC2626) 
                                  : const Color(0xFF6366F1),
                              );
                            },
                          ),
                        ),
                      ],
                      // Add subtle animation curves
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          // Average line
                          if (_hotspotData.isNotEmpty)
                            HorizontalLine(
                              y: _hotspotData.fold(0, (sum, item) => sum + (item['count'] as int)) / _hotspotData.length,
                              color: const Color(0xFFF59E0B).withOpacity(0.6),
                              strokeWidth: 1.5,
                              dashArray: [8, 4],
                              label: HorizontalLineLabel(
                                show: !isSmallScreen,
                                labelResolver: (line) => 'Avg',
                                style: TextStyle(
                                  color: const Color(0xFFF59E0B),
                                  fontSize: fontSize - 1,
                                  fontWeight: FontWeight.w600,
                                ),
                                alignment: Alignment.topRight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Legend and stats (responsive layout)
            if (!isSmallScreen) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Peak', maxValue.toString(), const Color(0xFFDC2626)),
                  _buildStatItem(
                    'Average', 
                    (_hotspotData.fold(0, (sum, item) => sum + (item['count'] as int)) / _hotspotData.length).toStringAsFixed(1),
                    const Color(0xFFF59E0B),
                  ),
                  _buildStatItem('Days', _hotspotData.length.toString(), const Color(0xFF6366F1)),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

// Helper method to calculate bottom axis interval
double _calculateBottomInterval(int dataLength, double screenWidth) {
  if (screenWidth < 400) {
    return dataLength > 15 ? (dataLength / 4).ceil().toDouble() : 
           dataLength > 10 ? 3.0 : 2.0;
  } else if (screenWidth < 600) {
    return dataLength > 20 ? (dataLength / 6).ceil().toDouble() : 
           dataLength > 15 ? 3.0 : 2.0;
  } else {
    return dataLength > 30 ? (dataLength / 10).ceil().toDouble() : 
           dataLength > 20 ? 3.0 : 2.0;
  }
}

// Helper method to build stat items
Widget _buildStatItem(String label, String value, Color color) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B7280),
        ),
      ),
    ],
  );
}

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF059669);
      case 'pending':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getActivityColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF059669);
      case 'inactive':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }
}