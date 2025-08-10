import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AdminDashboardScreen(),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _crimeStats = {};
  Map<String, dynamic> _reportStats = {};
  Map<String, dynamic> _activityStats = {};
  List<Map<String, dynamic>> _hotspotData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
    // Format dates properly for Supabase query
    String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1))); // Add 1 day to include the end date

    final crimeResponse = await Supabase.instance.client
        .from('hotspot')
        .select('type_id, crime_type(name, level, category)')
        .gte('created_at', startDateStr)
        .lt('created_at', endDateStr); // Use lt instead of lte with the adjusted end date
   

    // Rest of the method remains the same...
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
    // Format dates properly for Supabase query
    String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1))); // Add 1 day to include the end date

    final hotspotResponse = await Supabase.instance.client
        .from('hotspot')
        .select('created_at, crime_type(name)')
        .gte('created_at', startDateStr)
        .lt('created_at', endDateStr) // Use lt instead of lte with the adjusted end date
        .eq('status', 'approved')
        .order('created_at');

    // Rest of the method remains the same...
    Map<String, int> dailyCounts = {};

    for (var hotspot in hotspotResponse) {
      String date = DateFormat('yyyy-MM-dd').format(
        DateTime.parse(hotspot['created_at'])
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    List<Map<String, dynamic>> chartData = [];
    dailyCounts.entries.forEach((entry) {
      chartData.add({
        'date': entry.key,
        'count': entry.value,
      });
    });

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
  );
  
  if (picked != null) {
    // Ensure start date is before end date
    if (picked.start.isAfter(picked.end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date must be before end date')),
      );
      return;
    }
    
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _loadDashboardData();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildDateRangeCard()),
                  const SizedBox(height: 16),
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildUserChartsSection(),
                  const SizedBox(height: 24),
                  _buildCrimeChartsSection(),
                  const SizedBox(height: 24),
                  _buildReportStatusSection(),
                  const SizedBox(height: 24),
                  _buildActivityStatusSection(),
                  const SizedBox(height: 24),
                  _buildHotspotTrendSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Data Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range),
              label: const Text('Change Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            color: Colors.blue.shade50,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.people, size: 32, color: Colors.blue.shade800),
                  const SizedBox(height: 8),
                  Text(
                    '${_userStats['total'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Users'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            color: Colors.red.shade50,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 32, color: Colors.red.shade800),
                  const SizedBox(height: 8),
                  Text(
                    '${_crimeStats['total'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Reports'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

Widget _buildUserChartsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'User Statistics',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Column( // ⬅ replaced Row with Column
        children: [
          _buildGenderChart(),
          const SizedBox(height: 16),
          _buildRoleChart(),
        ],
      ),
    ],
  );
}


  Widget _buildGenderChart() {
    Map<String, int> genderData = _userStats['gender'] ?? {};

    if (genderData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No gender data available')),
        ),
      );
    }

    List<Color> colors = [
      Colors.blue,
      Colors.pink,
      Colors.purple,
      Colors.orange,
      Colors.green,
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Users by Gender',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: genderData.entries.map((entry) {
                    int index = genderData.keys.toList().indexOf(entry.key);
                    double percentage = (entry.value / (_userStats['total'] ?? 1)) * 100;
                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: genderData.entries.map((entry) {
                int index = genderData.keys.toList().indexOf(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ${entry.value}'),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChart() {
    Map<String, int> roleData = _userStats['role'] ?? {};

    if (roleData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No role data available')),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Users by Role',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: roleData.values.isEmpty ? 10 : roleData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barGroups: roleData.entries.map((entry) {
                    int index = roleData.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: entry.key == 'admin' ? Colors.blue : Colors.green,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
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
                                style: const TextStyle(fontSize: 10),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrimeChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crime Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildCrimeLevelsChart(),
        const SizedBox(height: 16),
        _buildCrimeCategoriesChart(),
      ],
    );
  }

  Widget _buildCrimeLevelsChart() {
    Map<String, int> levelData = _crimeStats['levels'] ?? {};

    if (levelData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No crime level data available')),
        ),
      );
    }

    Map<String, Color> levelColors = {
      'critical': Colors.red.shade700,
      'high': Colors.orange.shade600,
      'medium': Colors.yellow.shade600,
      'low': Colors.green.shade600,
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Crimes by Severity Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: levelData.entries.map((entry) {
                    double percentage = (entry.value / (_crimeStats['total'] ?? 1)) * 100;
                    return PieChartSectionData(
                      color: levelColors[entry.key] ?? Colors.grey,
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
Wrap(
  spacing: 8.0,
  runSpacing: 4.0,
  children: levelData.entries.map((entry) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: levelColors[entry.key] ?? Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          '${entry.key.toUpperCase()}: ${entry.value}',
          style: const TextStyle(fontSize: 10), // ⬅ smaller text
        ),
      ],
    );
  }).toList(),
),
          ],
        ),
      ),
    );
  }

  Widget _buildCrimeCategoriesChart() {
    Map<String, int> categoryData = _crimeStats['categories'] ?? {};

    if (categoryData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No crime category data available')),
        ),
      );
    }

    List<Color> colors = [
      Colors.red.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.purple.shade400,
      Colors.orange.shade400,
      Colors.teal.shade400,
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Crimes by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: categoryData.values.isEmpty ? 10 : categoryData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barGroups: categoryData.entries.map((entry) {
                    int index = categoryData.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: colors[index % colors.length],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          List<String> keys = categoryData.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < keys.length) {
                            String text = keys[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotspotTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crime Hotspot Trends',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildHotspotLineChart(),
      ],
    );
  }

Widget _buildReportStatusSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Crime Status',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
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
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      _buildActivityStatusChart(),
    ],
  );
}


Widget _buildReportStatusChart() {
  final totalReports = _reportStats['total'] ?? 0;
  Map<String, int> statusData = _reportStats['status'] ?? {};
  statusData.removeWhere((key, value) => value == 0);

  final isEmpty = totalReports == 0;

  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    elevation: isEmpty ? 1 : 4, // Reduced elevation when empty
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: isEmpty
          ? const Center(
              child: Text(
                'No report status data available',
                style: TextStyle(color: Colors.black),
              ),
            )
          : Column(
              children: [
                const Text(
                  'Reports by Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: statusData.entries.map((entry) {
                        double percentage = (entry.value / totalReports) * 100;
                        return PieChartSectionData(
                          color: _getStatusColor(entry.key),
                          value: entry.value.toDouble(),
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
Wrap(
  spacing: 8.0,
  runSpacing: 4.0,
  children: statusData.entries.map((entry) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: _getStatusColor(entry.key),
        ),
        const SizedBox(width: 4),
        Text(
          '${entry.key.toUpperCase()}: ${entry.value}',
          style: const TextStyle(fontSize: 10), // ⬅ smaller text
        ),
      ],
    );
  }).toList(),
),

              ],
            ),
    ),
  );
}

Widget _buildActivityStatusChart() {
  final totalActivities = _activityStats['total'] ?? 0;
  Map<String, int> activityData = _activityStats['status'] ?? {};
  activityData.removeWhere((key, value) => value == 0);

  final isEmpty = totalActivities == 0;

  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    elevation: isEmpty ? 1 : 4, // Reduced elevation when empty
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: isEmpty
          ? const Center(
              child: Text(
                'No activity status data available',
                style: TextStyle(color: Colors.black),
              ),
            )
          : Column(
              children: [
                const Text(
                  'Reports by Activity Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: activityData.values.isEmpty 
                          ? 10 
                          : activityData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                      barGroups: activityData.entries.map((entry) {
                        int index = activityData.keys.toList().indexOf(entry.key);
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: _getActivityColor(entry.key),
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
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
                                    style: const TextStyle(fontSize: 10),
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
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: activityData.entries.map((entry) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: _getActivityColor(entry.key),
                        ),
                        const SizedBox(width: 4),
                        Text('${entry.key.toUpperCase()}: ${entry.value}'),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    ),
  );
}

// Helper methods for consistent colors
Color _getStatusColor(String status) {
  switch (status) {
    case 'approved':
      return Colors.green.shade600;
    case 'pending':
      return Colors.orange.shade600;
    case 'rejected':
      return Colors.red.shade600;
    default:
      return Colors.grey;
  }
}

Color _getActivityColor(String status) {
  switch (status) {
    case 'active':
      return Colors.green.shade600;
    case 'inactive':
      return Colors.red.shade600;
    default:
      return Colors.grey;
  }
}


  

  Widget _buildHotspotLineChart() {
    if (_hotspotData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No hotspot trend data available')),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Daily Crime Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
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
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _hotspotData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value['count'].toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
