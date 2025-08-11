import 'dart:math' as math;

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

  // [Keep all the original data loading methods - _loadUserStats, _loadCrimeStats, etc.]
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
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF334155), // Dark slate blue
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
                  color: Color(0xFF1E293B), // Dark slate
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Crime Analytics & Reports',
                style: TextStyle(
                  color: Color(0xFF475569), // Medium slate
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF334155), // Dark slate blue
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
    return Container(
      margin: const EdgeInsets.all(16), // Reduced margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Center(
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
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16), // Expanded margins
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // Expanded padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeCard(),
            const SizedBox(height: 24),
            _buildOverviewCards(),
            const SizedBox(height: 32),
            _buildUserChartsSection(),
            const SizedBox(height: 32),
            _buildCrimeChartsSection(),
            const SizedBox(height: 32),
            _buildReportStatusSection(),
            const SizedBox(height: 32),
            _buildActivityStatusSection(),
            const SizedBox(height: 32),
            _buildHotspotTrendSection(),
          ],
        ),
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
    return Row(
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
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserChartsSection() {
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
        Column(
          children: [
            _buildGenderChartCards(),
            const SizedBox(height: 20),
            _buildRoleChart(),
          ],
        ),
      ],
    );
  }

Widget _buildGenderChartCards() {
  Map<String, int> genderData = _userStats['gender'] ?? {};

  if (genderData.isEmpty) {
    return _buildEmptyCard('No gender data available');
  }

  List<Color> colors = [
    const Color.fromARGB(255, 99, 137, 241),
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
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
                    int index = genderData.keys.toList().indexOf(entry.key);
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
        // Grid layout for better organization
        GridView.count(
          crossAxisCount: genderData.length > 2 ? 2 : genderData.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: genderData.entries.map((entry) {
            int index = genderData.keys.toList().indexOf(entry.key);
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
      width: double.infinity, // Expand to full width
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
                        return FlLine(
                          color: const Color(0xFFE5E7EB),
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

  // Add similar modern styling to other chart methods...
  Widget _buildCrimeChartsSection() {
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
        _buildCrimeLevelsChart(),
        const SizedBox(height: 20),
        _buildCrimeCategoriesChart(),
      ],
    );
  }

  Widget _buildCrimeLevelsChart() {
    Map<String, int> levelData = _crimeStats['levels'] ?? {};

    if (levelData.isEmpty) {
      return _buildEmptyCard('No crime level data available');
    }

    Map<String, Color> levelColors = {
      'critical': const Color(0xFFDC2626),
      'high': const Color(0xFFEA580C),
      'medium': const Color.fromARGB(255, 217, 161, 6),
      'low': const Color(0xFF059669),
    };

    return Container(
      width: double.infinity, // Expand to full width
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
          // Responsive legend for crime levels with smaller text
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: levelData.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6.0), // Reduced margin
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12, // Smaller indicator
                        height: 12,
                        decoration: BoxDecoration(
                          color: levelColors[entry.key] ?? Colors.grey,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4), // Reduced spacing
                      Text(
                        '${entry.key.toUpperCase()}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 10, // Smaller font size
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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

  return Container(
    width: double.infinity, // Expand to full width
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
          'Crimes by Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250, // Increased height for better spacing
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: categoryData.values.isEmpty ? 10 : categoryData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barGroups: categoryData.entries.map((entry) {
                    int index = categoryData.keys.toList().indexOf(entry.key);
                    double animatedHeight = entry.value.toDouble() * _chartAnimation.value;
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: animatedHeight,
                          color: colors[index % colors.length],
                          width: 28, // Slightly reduced bar width to make more room
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            colors: [
                              colors[index % colors.length],
                              colors[index % colors.length].withOpacity(0.7),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, 
                        reservedSize: 30, // Reduced from 40 to 30
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10, // Reduced font size
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40, // Increased space for bottom labels
                        getTitlesWidget: (value, meta) {
                          List<String> keys = categoryData.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < keys.length) {
                            String text = keys[value.toInt()];
                            // Better text handling - show full text if short, abbreviate if long
                            String displayText;
                            if (text.length <= 10) {
                              displayText = text;
                            } else if (text.contains(' ')) {
                              // If there's a space, show first word and abbreviate
                              List<String> words = text.split(' ');
                              displayText = words.length > 1 
                                  ? '${words[0]}\n${words[1].substring(0, math.min(words[1].length, 4))}...'
                                  : '${text.substring(0, 8)}...';
                            } else {
                              displayText = '${text.substring(0, 8)}...';
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                displayText,
                                style: const TextStyle(
                                  fontSize: 9, // Slightly smaller for better fit
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  height: 1.2, // Better line height for multi-line text
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2, // Allow 2 lines for better readability
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
                      return FlLine(
                        color: const Color(0xFFE5E7EB),
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

  Widget _buildReportStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Status',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        _buildReportStatusChart(),
      ],
    );
  }

  Widget _buildActivityStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Status',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
        _buildActivityStatusChart(),
      ],
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
      width: double.infinity, // Expand to full width
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
                      double animatedValue = entry.value.toDouble() * _chartAnimation.value;
                      
                      return PieChartSectionData(
                        color: _getStatusColor(entry.key),
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
          // Responsive legend for report status with smaller text
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: statusData.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6.0), // Reduced margin
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12, // Smaller indicator
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(entry.key),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4), // Reduced spacing
                      Text(
                        '${entry.key.toUpperCase()}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 10, // Smaller font size
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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
      width: double.infinity, // Expand to full width
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
                        return FlLine(
                          color: const Color(0xFFE5E7EB),
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

    return Container(
      width: double.infinity, // Expand to full width
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
            'Daily Crime Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFFE5E7EB),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < _hotspotData.length) {
                              String date = _hotspotData[index]['date'];
                              DateTime dateTime = DateTime.parse(date);
                              return Text(
                                DateFormat('M/d').format(dateTime),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
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
                    borderData: FlBorderData(show: false),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        barWidth: 4,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1).withOpacity(0.3),
                              const Color(0xFF8B5CF6).withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: const Color(0xFF6366F1),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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