import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/search_filter_service.dart';

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
  // Initialize _startDate to the first day of the previous month
  // Initialize _endDate to the current date
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
  DateTime _endDate = DateTime.now();
  
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _crimeStats = {};
  Map<String, dynamic> _reportStats = {};
  Map<String, dynamic> _activityStats = {};
  List<Map<String, dynamic>> _hotspotData = [];
  List<Map<String, dynamic>> _usersData = [];
  List<Map<String, dynamic>> _reportsData = [];
  bool _isLoading = true;
  

// OFFICER CONTROLLER
final TextEditingController _officerSearchController = TextEditingController();
String _selectedOfficerGender = 'All Genders';
String _officerSortBy = 'date_joined';
bool _officerSortAscending = false;
List<Map<String, dynamic>> _officersData = [];
List<Map<String, dynamic>> _filteredOfficersData = [];
List<String> _availableOfficerGenders = ['All Genders'];

final Set<String> _expandedOfficerCards = <String>{};
List<String> _availablePoliceRanks = ['All Ranks'];
List<String> _availablePoliceStations = ['All Stations'];
String _selectedOfficerRank = 'All Ranks';
String _selectedOfficerStation = 'All Stations';


  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _chartAnimation;

  // Add these new variables to your _AdminDashboardScreenState class
  bool _isSidebarOpen = false;
  bool _showFilters = false;
  String _currentPage = 'dashboard';
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;

  // NEW VARIABLES FOR SEARCH AND FILTERING

// User page search and filter variables
final TextEditingController _userSearchController = TextEditingController();
String _selectedUserRole = 'All Roles';
String _selectedUserGender = 'All Genders';
String _userSortBy = 'date_joined';
bool _userSortAscending = false;
List<Map<String, dynamic>> _filteredUsersData = [];

// Report page search and filter variables
final TextEditingController _reportSearchController = TextEditingController();
String _selectedReportStatus = 'All Status';
String _selectedReportLevel = 'All Levels';
String _selectedReportCategory = 'All Categories';
String _selectedActivityStatus = 'All Activity';
String _reportSortBy = 'date';
bool _reportSortAscending = false;
List<Map<String, dynamic>> _filteredReportsData = [];

//AUTHORIZATION
bool _isAdmin = false;

// Dynamic filter options
List<String> _availableRoles = ['All Roles'];
List<String> _availableGenders = ['All Genders'];
List<String> _availableStatuses = ['All Status'];
List<String> _availableLevels = ['All Levels'];
List<String> _availableCategories = ['All Categories'];
List<String> _availableActivityStatuses = ['All Activity'];

// SafeSpot page search and filter variables
final TextEditingController _safeSpotSearchController = TextEditingController();
String _selectedSafeSpotStatus = 'All Status';
String _selectedSafeSpotType = 'All Types';
String _selectedSafeSpotVerified = 'All Verification';
String _safeSpotSortBy = 'created_at';
bool _safeSpotSortAscending = false;
List<Map<String, dynamic>> _safeSpotsData = [];
List<Map<String, dynamic>> _filteredSafeSpotsData = [];
List<String> _availableSafeSpotStatuses = ['All Status'];
List<String> _availableSafeSpotTypes = ['All Types'];
List<String> _availableSafeSpotVerified = ['All Verification'];
// ignore: unused_field
Map<String, dynamic> _safeSpotStats = {};



@override
  void initState() {
    super.initState();
    
    // Ensure dates are set to midnight local time to avoid time-based discrepancies
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    
    _initAnimations();
    _loadDashboardData();
    _loadCurrentUserProfile();
    
    // Add listeners for search controllers
    _userSearchController.addListener(_filterUsers);
    _reportSearchController.addListener(_filterReports);
    _safeSpotSearchController.addListener(_filterSafeSpots);
    _officerSearchController.addListener(_filterOfficers);
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

    _sidebarController = AnimationController(
  duration: const Duration(milliseconds: 300),
  vsync: this,
  );

  _sidebarAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _sidebarController,
    curve: Curves.easeInOut,
  ));
  }

@override
void dispose() {
  _fadeController.dispose();
  _slideController.dispose();
  _chartController.dispose();
  _sidebarController.dispose();
  _userSearchController.dispose();  
  _reportSearchController.dispose();  
  _safeSpotSearchController.dispose();
  _officerSearchController.dispose();

  super.dispose();
}




void _updateOfficerFilter(String filterType, String value) {
  setState(() {
    switch (filterType) {
      case 'gender':
        _selectedOfficerGender = value;
        break;
      case 'rank':
        _selectedOfficerRank = value;
        break;
      case 'station':
        _selectedOfficerStation = value;
        break;
      case 'sort':
        if (_officerSortBy == value) {
          _officerSortAscending = !_officerSortAscending;
        } else {
          _officerSortBy = value;
          _officerSortAscending = true;
        }
        break;
    }
  });
  _filterOfficers();
}

void _clearOfficerFilters() {
  setState(() {
    _officerSearchController.clear();
    _selectedOfficerGender = 'All Genders';
    _selectedOfficerRank = 'All Ranks';
    _selectedOfficerStation = 'All Stations';
    _officerSortBy = 'date_joined';
    _officerSortAscending = false;
  });
  _filterOfficers();
}


Future<void> _loadCurrentUserProfile() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('users')  // Changed from 'profiles' to 'users'
        .select()
        .eq('id', userId)
        .single();

    setState(() {
      _isAdmin = response['role']?.toString().toLowerCase() == 'admin';
    });
  } catch (e) {
    print('Error loading user profile: $e');
  }
}

Future<void> _loadOfficersData() async {
  try {
    print('Loading officers data...'); // Debug print
    
    // Updated query with proper joins to get rank and station data
    final response = await Supabase.instance.client
        .from('users')
        .select('''
          *,
          police_ranks:police_rank_id (
            id,
            old_rank,
            new_rank,
            rank_level
          ),
          police_stations:police_station_id (
            id,
            station_number,
            name
          )
        ''')
        .eq('role', 'officer')
        .order('created_at', ascending: false);
    
    print('Officers response: ${response.length} officers found'); // Debug print
    print('Sample officer data: ${response.isNotEmpty ? response[0] : 'No officers'}'); // Debug print
    
    setState(() {
      _officersData = List<Map<String, dynamic>>.from(response);
      
      // Update available filter options
      _availableOfficerGenders = ['All Genders', ...{..._officersData.map((o) => o['gender']?.toString() ?? '').where((g) => g.isNotEmpty)}];
      
      // Extract unique ranks and stations for filters
      _availablePoliceRanks = ['All Ranks'];
      _availablePoliceStations = ['All Stations'];
      
      for (var officer in _officersData) {
      // Add ranks
      final rank = officer['police_ranks']?['old_rank']?.toString();
      if (rank != null && rank.isNotEmpty && !_availablePoliceRanks.contains(rank)) {
        _availablePoliceRanks.add(rank);
      }
        
        // Add stations
        final station = officer['police_stations']?['name']?.toString();
        if (station != null && station.isNotEmpty && !_availablePoliceStations.contains(station)) {
          _availablePoliceStations.add(station);
        }
      }
      
      // Initialize filtered data
      _filteredOfficersData = List.from(_officersData);
    });
    
    _filterOfficers();
    print('Filtered officers: ${_filteredOfficersData.length}'); // Debug print
  } catch (e) {
    print('Error loading officers data: $e');
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading officers: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Also update your filter function to use the correct field names
void _filterOfficers() {
  setState(() {
    _filteredOfficersData = _officersData.where((officer) {
      // Search filter
      final searchQuery = _officerSearchController.text.toLowerCase();
      final fullName = '${officer['first_name'] ?? ''} ${officer['last_name'] ?? ''}'.toLowerCase();
      final email = (officer['email']?.toString() ?? '').toLowerCase();
      final username = (officer['username']?.toString() ?? '').toLowerCase();
      final rank = officer['police_ranks']?['old_rank']?.toString().toLowerCase() ?? '';
      final station = officer['police_stations']?['name']?.toString().toLowerCase() ?? '';
      
      final matchesSearch = searchQuery.isEmpty || 
          fullName.contains(searchQuery) ||
          email.contains(searchQuery) ||
          username.contains(searchQuery) ||
          rank.contains(searchQuery) ||
          station.contains(searchQuery);

      // Gender filter
      final matchesGender = _selectedOfficerGender == 'All Genders' || 
          (officer['gender']?.toString() ?? '') == _selectedOfficerGender;

// Rank filter - using old_rank field
final matchesRank = _selectedOfficerRank == 'All Ranks' || 
    (officer['police_ranks']?['old_rank']?.toString() ?? '') == _selectedOfficerRank;

      // Station filter
      final matchesStation = _selectedOfficerStation == 'All Stations' || 
          (officer['police_stations']?['name']?.toString() ?? '') == _selectedOfficerStation;

      return matchesSearch && matchesGender && matchesRank && matchesStation;
    }).toList();

    // Sorting
    _filteredOfficersData.sort((a, b) {
      dynamic aValue, bValue;

      switch (_officerSortBy) {
        case 'name':
          aValue = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim().toLowerCase();
          bValue = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.trim().toLowerCase();
          break;
        case 'email':
          aValue = (a['email']?.toString() ?? '').toLowerCase();
          bValue = (b['email']?.toString() ?? '').toLowerCase();
          break;
        case 'rank':
          aValue = (a['police_ranks']?['old_rank']?.toString() ?? '').toLowerCase();
          bValue = (b['police_ranks']?['old_rank']?.toString() ?? '').toLowerCase();
          break;
        case 'station':
          aValue = (a['police_stations']?['name']?.toString() ?? '').toLowerCase();
          bValue = (b['police_stations']?['name']?.toString() ?? '').toLowerCase();
          break;
        case 'date_joined':
          aValue = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime.now();
          bValue = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime.now();
          break;
        default:
          aValue = '';
          bValue = '';
      }

      if (aValue is DateTime && bValue is DateTime) {
        return _officerSortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      int comparison = aValue.toString().compareTo(bValue.toString());
      return _officerSortAscending ? comparison : -comparison;
    });
  });
}

// ADD THESE METHODS FOR SAFESPOT FILTERING

void _filterSafeSpots() {
  setState(() {
    _filteredSafeSpotsData = _safeSpotsData.where((safeSpot) {
      // Search filter
      final searchQuery = _safeSpotSearchController.text.toLowerCase();
      final matchesSearch = searchQuery.isEmpty || 
          (safeSpot['name']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
          (safeSpot['description']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
          (safeSpot['safe_spot_types']?['name']?.toString().toLowerCase().contains(searchQuery) ?? false);

      // Status filter
      final status = safeSpot['status']?.toString() ?? 'pending';
      final matchesStatus = _selectedSafeSpotStatus == 'All Status' || status == _selectedSafeSpotStatus;

      // Type filter
      final typeName = safeSpot['safe_spot_types']?['name']?.toString() ?? 'Unknown';
      final matchesType = _selectedSafeSpotType == 'All Types' || typeName == _selectedSafeSpotType;

      // Verification filter
      final verified = safeSpot['verified'] == true;
      final matchesVerified = _selectedSafeSpotVerified == 'All Verification' ||
          (_selectedSafeSpotVerified == 'Verified' && verified) ||
          (_selectedSafeSpotVerified == 'Unverified' && !verified);

      // Date range filter
      final createdAt = DateTime.tryParse(safeSpot['created_at'] ?? '');
      final matchesDateRange = createdAt == null ||
          (createdAt.isAfter(_startDate.subtract(const Duration(days: 1))) &&
           createdAt.isBefore(_endDate.add(const Duration(days: 1))));

      return matchesSearch && matchesStatus && matchesType && matchesVerified && matchesDateRange;
    }).toList();

    // Sorting
    _filteredSafeSpotsData.sort((a, b) {
      dynamic aValue = a[_safeSpotSortBy];
      dynamic bValue = b[_safeSpotSortBy];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _safeSpotSortAscending ? -1 : 1;
      if (bValue == null) return _safeSpotSortAscending ? 1 : -1;

      int comparison = 0;
      if (aValue is String && bValue is String) {
        comparison = aValue.compareTo(bValue);
      } else if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }

      return _safeSpotSortAscending ? comparison : -comparison;
    });
  });
}

void _updateSafeSpotFilter(String filterType, String value) {
  setState(() {
    switch (filterType) {
      case 'status':
        _selectedSafeSpotStatus = value;
        break;
      case 'type':
        _selectedSafeSpotType = value;
        break;
      case 'verified':
        _selectedSafeSpotVerified = value;
        break;
      case 'sort':
        if (_safeSpotSortBy == value) {
          _safeSpotSortAscending = !_safeSpotSortAscending;
        } else {
          _safeSpotSortBy = value;
          _safeSpotSortAscending = true;
        }
        break;
    }
  });
  _filterSafeSpots();
}

void _clearSafeSpotFilters() {
  setState(() {
    _safeSpotSearchController.clear();
    _selectedSafeSpotStatus = 'All Status';
    _selectedSafeSpotType = 'All Types';
    _selectedSafeSpotVerified = 'All Verification';
    _safeSpotSortBy = 'created_at';
    _safeSpotSortAscending = false;
  });
  _filterSafeSpots();
}

// ADD THIS METHOD TO LOAD SAFESPOT DATA
Future<void> _loadSafeSpotsData() async {
  try {
    final response = await Supabase.instance.client
        .from('safe_spots')
        .select('''
          *,
          safe_spot_types!inner(id, name, icon, description),
          users!safe_spots_created_by_fkey(first_name, last_name, email)
        ''')
        .order('created_at', ascending: false);

    setState(() {
      _safeSpotsData = List<Map<String, dynamic>>.from(response);
      
      // Update available filter options
      _availableSafeSpotStatuses = ['All Status', ...{..._safeSpotsData.map((s) => s['status']?.toString() ?? 'pending')}];
      _availableSafeSpotTypes = ['All Types', ...{..._safeSpotsData.map((s) => s['safe_spot_types']?['name']?.toString() ?? 'Unknown')}];
      _availableSafeSpotVerified = ['All Verification', 'Verified', 'Unverified'];
      
      // Initialize filtered data
      _filteredSafeSpotsData = List.from(_safeSpotsData);
    });
    
    _filterSafeSpots();
    _loadSafeSpotStats();
  } catch (e) {
    print('Error loading safe spots data: $e');
  }
}

// ADD METHOD TO LOAD SAFESPOT STATS
Future<void> _loadSafeSpotStats() async {
  try {
    String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));

    final response = await Supabase.instance.client
        .from('safe_spots')
        .select('status, verified, safe_spot_types!inner(name)')
        .gte('created_at', startDateStr)
        .lt('created_at', endDateStr);

    Map<String, int> statusCounts = {
      'pending': 0,
      'approved': 0,
      'rejected': 0,
    };

    Map<String, int> verificationCounts = {
      'verified': 0,
      'unverified': 0,
    };

    Map<String, int> typeCounts = {};

    for (var safeSpot in response) {
      String status = safeSpot['status'] ?? 'pending';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      bool verified = safeSpot['verified'] == true;
      verificationCounts[verified ? 'verified' : 'unverified'] = 
          (verificationCounts[verified ? 'verified' : 'unverified'] ?? 0) + 1;

      String type = safeSpot['safe_spot_types']?['name'] ?? 'Unknown';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    setState(() {
      _safeSpotStats = {
        'status': statusCounts,
        'verification': verificationCounts,
        'types': typeCounts,
        'total': response.length,
      };
    });
  } catch (e) {
    print('Error loading safe spot stats: $e');
  }
}

// Add these new methods for filtering:

  void _filterUsers() {
    setState(() {
      _filteredUsersData = SearchAndFilterService.filterUsers(
        users: _usersData,
        searchQuery: _userSearchController.text,
        roleFilter: _selectedUserRole,
        genderFilter: _selectedUserGender,
        sortBy: _userSortBy,
        ascending: _userSortAscending,
      );
    });
  }

  void _filterReports() {
    setState(() {
      _filteredReportsData = SearchAndFilterService.filterReports(
        reports: _reportsData,
        searchQuery: _reportSearchController.text,
        statusFilter: _selectedReportStatus,
        levelFilter: _selectedReportLevel,
        categoryFilter: _selectedReportCategory,
        activityFilter: _selectedActivityStatus,
        sortBy: _reportSortBy,
        ascending: _reportSortAscending,
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  void _updateUserFilter(String filterType, String value) {
    setState(() {
      switch (filterType) {
        case 'role':
          _selectedUserRole = value;
          break;
        case 'gender':
          _selectedUserGender = value;
          break;
        case 'sort':
          if (_userSortBy == value) {
            _userSortAscending = !_userSortAscending;
          } else {
            _userSortBy = value;
            _userSortAscending = true;
          }
          break;
      }
    });
    _filterUsers();
  }

  void _updateReportFilter(String filterType, String value) {
    setState(() {
      switch (filterType) {
        case 'status':
          _selectedReportStatus = value;
          break;
        case 'level':
          _selectedReportLevel = value;
          break;
        case 'category':
          _selectedReportCategory = value;
          break;
        case 'activity':
          _selectedActivityStatus = value;
          break;
        case 'sort':
          if (_reportSortBy == value) {
            _reportSortAscending = !_reportSortAscending;
          } else {
            _reportSortBy = value;
            _reportSortAscending = true;
          }
          break;
      }
    });
    _filterReports();
  }

  void _clearUserFilters() {
    setState(() {
      _userSearchController.clear();
      _selectedUserRole = 'All Roles';
      _selectedUserGender = 'All Genders';
      _userSortBy = 'date_joined';
      _userSortAscending = false;
    });
    _filterUsers();
  }

  void _clearReportFilters() {
    setState(() {
      _reportSearchController.clear();
      _selectedReportStatus = 'All Status';
      _selectedReportLevel = 'All Levels';
      _selectedReportCategory = 'All Categories';
      _selectedActivityStatus = 'All Activity';
      _reportSortBy = 'date';
      _reportSortAscending = false;
    });
    _filterReports();
  }

Future<void> _loadUserStats() async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));

      final response = await Supabase.instance.client
          .from('users')
          .select('gender, role, created_at')
          .gte('created_at', startDateStr)
          .lt('created_at', endDateStr);

      Map<String, int> genderCounts = {};
      Map<String, int> roleCounts = {};
      int officerCount = 0;

      for (var user in response) {
        String gender = user['gender'] ?? 'Not specified';
        genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;

        String role = user['role'] ?? 'user';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;

        if (role == 'officer') {
          officerCount++;
        }
      }

      print('Role counts: $roleCounts'); // Debug print
      print('Officer count: $officerCount'); // Debug print

      setState(() {
        _userStats = {
          'gender': genderCounts,
          'role': roleCounts,
          'total': response.length,
          'officers': officerCount,
        };
        // Removed setting _availableRoles and _availableGenders here to avoid potential overwrites from concurrent loads.
        // These are now only set in _loadUsersData for consistency.
      });

      _filterUsers();
    } catch (e) {
      print('Error loading user stats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user stats: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUsersData() async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));

      final response = await Supabase.instance.client
          .from('users')
          .select('*')
          .gte('created_at', startDateStr)
          .lt('created_at', endDateStr)
          .order('created_at', ascending: false);

      setState(() {
        _usersData = List<Map<String, dynamic>>.from(response);

        // Update available filter options (this ensures consistency and avoids race conditions from parallel loads)
        _availableRoles = SearchAndFilterService.getUniqueRoles(_usersData);
        _availableGenders = SearchAndFilterService.getUniqueGenders(_usersData);

        // Initialize filtered data
        _filteredUsersData = List.from(_usersData);
      });

      _filterUsers();
    } catch (e) {
      print('Error loading users data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _loadUserStats(),
        _loadCrimeStats(),
        _loadUsersData(),
        _loadReportStats(),
        _loadActivityStats(),
        _loadHotspotData(),
        _loadSafeSpotsData(),
        _loadOfficersData(),
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
  DateTime firstDate = DateTime(2020, 1, 1);
  DateTime lastDate = DateTime.now();

  DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    builder: (context, child) {
      final isDesktop = MediaQuery.of(context).size.width > 600;
      final size = MediaQuery.of(context).size;

      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
        ),
        child: isDesktop
            ? Center(
                child: IntrinsicHeight( // 👈 lets the picker shrink/expand naturally
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 470,          // fixed modal width
                      maxHeight: size.height * 0.9, // safety cap
                    ),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    ),
                  ),
                ),
              )
            : child!,
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
      _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });

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
            Color.fromARGB(255, 220, 234, 248),
            Color.fromARGB(255, 190, 198, 207),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Wrap main content with GestureDetector for swipe
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                // Detect left-to-right swipe
                if (details.delta.dx > 5 && !_isSidebarOpen) {
                  // Threshold to avoid accidental swipes (adjust as needed)
                  setState(() {
                    _isSidebarOpen = true;
                  });
                  _sidebarController.forward();
                }
              },
              child: Column(
                children: [
                  _buildModernAppBar(),
                  Expanded(
                    child: _buildCurrentPage(),
                  ),
                ],
              ),
            ),
            _buildSidebar(),
          ],
        ),
      ),
    ),
  );
}


String _getPageTitle() {
  switch (_currentPage) {
    case 'users':
      return 'User Management';
    case 'reports':
      return 'Crime Reports';
    case 'safespots': 
      return 'Safe Spots';
      case 'officers':
  return 'Officer Management';
    default:
      return 'System Dashboard';
  }
}


String _getPageSubtitle() {
  switch (_currentPage) {
    case 'users':
      return 'Manage system users';
    case 'reports':
      return 'Manage crime reports';
    case 'safespots': 
      return 'Manage safe spot reports';
    case 'officers':
    return 'Manage system officers';
    default:
      return 'Crime Analytics & Reports';
  }
}

// Fixed sidebar widget that handles keyboard properly
Widget _buildSidebar() {
  return AnimatedBuilder(
    animation: _sidebarAnimation,
    builder: (context, child) {
      return Stack(
        children: [
          // Backdrop
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSidebarOpen = false;
                });
                _sidebarController.reverse();
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.3 * _sidebarAnimation.value),
              ),
            ),
          // Sidebar with swipe-to-close
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx < -5 && _isSidebarOpen) {
                setState(() {
                  _isSidebarOpen = false;
                });
                _sidebarController.reverse();
              }
            },
            child: Transform.translate(
              offset: Offset(-320.0 + (320.0 * _sidebarAnimation.value), 0.0),
              child: Container(
                width: 320,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
       
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(4, 0),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                  // Logo section with new gradient
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color.fromARGB(255, 92, 118, 165), Color.fromARGB(255, 61, 91, 131)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
           
                    ),
                    child: GestureDetector(
                      onTap: () {
                        _navigateToPage('dashboard');
                      },
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
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Navigation items - Scrollable middle section
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          
                          // Navigation Items
                          _buildNavItem(
                            icon: Icons.dashboard_rounded,
                            title: 'Dashboard',
                            isActive: _currentPage == 'dashboard',
                            onTap: () => _navigateToPage('dashboard'),
                          ),
                          const SizedBox(height: 4),
                          _buildNavItem(
                            icon: Icons.people_rounded,
                            title: 'User Management',
                            isActive: _currentPage == 'users',
                            onTap: () => _navigateToPage('users'),
                          ),

                        const SizedBox(height: 4),
                        _buildNavItem(
                          icon:  Icons.local_police,
                          title: 'Officer Management',
                          isActive: _currentPage == 'officers',
                          onTap: () => _navigateToPage('officers'),
                        ),
                          const SizedBox(height: 4),
                          _buildNavItem(
                            icon: Icons.report_gmailerrorred_rounded,
                            title: 'Crime Reports',
                            isActive: _currentPage == 'reports',
                            onTap: () => _navigateToPage('reports'),
                          ),

                          _buildNavItem(
                          icon: Icons.place_rounded,
                          title: 'Safe Spots',
                          isActive: _currentPage == 'safespots',
                          onTap: () => _navigateToPage('safespots'),
                        ),


                          
                          // Extra space to push content up when scrolling
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  
                  // Fixed bottom section
                  Container(
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
                        
                        // Back to Profile Button
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _isSidebarOpen = false;
                                });
                                _sidebarController.reverse();
                                
                                // Simply go back to previous screen (ProfileScreen)
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF4F8EF7).withOpacity(0.1),
                                      const Color(0xFF6FA8F5).withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF4F8EF7).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F8EF7).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: Color(0xFF4F8EF7),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Back to Profile',
                                            style: TextStyle(
                                              color: Color(0xFF374151),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Return to main profile',
                                            style: TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF9CA3AF),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
        ],
      );
    },
  );
}

Widget _buildNavItem({
  required IconData icon,
  required String title,
  required bool isActive,
  required VoidCallback onTap,
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
                ? Border.all(color: const Color(0xFF4F8EF7).withOpacity(0.2), width: 1)
                : null,
          ),
          child: Row(
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
                      ? Border.all(color: const Color(0xFFE5E7EB), width: 1)
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive 
                        ? const Color(0xFF374151) 
                        : const Color(0xFF6B7280),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
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

void _navigateToPage(String page) {
  setState(() {
    _currentPage = page;
    _isSidebarOpen = false;
  });
  _sidebarController.reverse();
  
  // Load data based on page
  if (page == 'users') {
    _loadUsersData();
  } else if (page == 'reports') {
    _loadReportsData();
  } else if (page == 'safespots') { // ADD THIS
    _loadSafeSpotsData();
    } else if (page == 'officers') {
  _loadOfficersData();
  }
}

Widget _buildCurrentPage() {
  switch (_currentPage) {
    case 'users':
      return _buildUsersPage();
    case 'reports':
      return _buildReportsPage();
    case 'safespots': // ADD THIS CASE
      return _buildSafeSpotsPage();
    case 'officers':
    return _buildOfficersPage();
    default:
      return _isLoading
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildDashboardContent(),
              ),
            );
  }
}



  int? _calculateAge(String? bdayString) {
  if (bdayString == null) return null;
  
  try {
    final bday = DateTime.parse(bdayString);
    final today = DateTime.now();
    int age = today.year - bday.year;
    
    // Check if birthday hasn't occurred this year yet
    if (today.month < bday.month || 
        (today.month == bday.month && today.day < bday.day)) {
      age--;
    }
    
    return age;
  } catch (e) {
    return null;
  }
}

  Future<void> _loadReportsData() async {
    try {
      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
            *,
            crime_type(name, level, category),
            users!hotspot_created_by_fkey(first_name, last_name, email),
            reporter:users!hotspot_reported_by_fkey(first_name, last_name, email)
          ''')
          .order('created_at', ascending: false);
      
      setState(() {
        _reportsData = List<Map<String, dynamic>>.from(response);
        
        // Update available filter options
        _availableStatuses = SearchAndFilterService.getUniqueStatuses(_reportsData);
        _availableLevels = SearchAndFilterService.getUniqueLevels(_reportsData);
        _availableCategories = SearchAndFilterService.getUniqueCategories(_reportsData);
        _availableActivityStatuses = SearchAndFilterService.getUniqueActivityStatuses(_reportsData);
        
        // Initialize filtered data
        _filteredReportsData = List.from(_reportsData);
      });
      
      _filterReports();
    } catch (e) {
      print('Error loading reports data: $e');
    }
  }


void _showChangeRoleDialog(Map<String, dynamic> user) {
  String selectedRole = user['role'] ?? 'user';
  final availableRoles = ['user', 'admin', 'officer'];
  final currentRole = user['role'] ?? 'user';
  final hasPoliceData = user['police_rank_id'] != null || user['police_station_id'] != null;
  final isCurrentUser = user['id'] == Supabase.instance.client.auth.currentUser?.id;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final willLosePoliceData = currentRole == 'officer' && selectedRole != 'officer' && hasPoliceData;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text('Change User Role'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: ${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Email: ${user['email'] ?? 'No email'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (isCurrentUser) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[600], size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You cannot change your own role.',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Select new role:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedRole,
                      underline: const SizedBox(),
                      isExpanded: true,
                      items: availableRoles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                role == 'admin'
                                    ? Icons.admin_panel_settings
                                    : role == 'officer'
                                        ? Icons.local_police
                                        : Icons.person,
                                size: 18,
                                color: _getRoleColor(role),
                              ),
                              const SizedBox(width: 8),
                              Text(role.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                  ),
                  if (willLosePoliceData) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning, color: Colors.orange[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Warning: Police Data Will Be Removed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This user\'s police rank and station assignments will be permanently removed when changing from Officer role.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: isCurrentUser || selectedRole == user['role']
                    ? null // Disable if current user or no role change
                    : () {
                        Navigator.of(context).pop();
                        _changeUserRole(user['id'], selectedRole);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: willLosePoliceData ? Colors.orange[700] : Colors.blue[700],
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: willLosePoliceData
                        ? Colors.orange.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(willLosePoliceData ? 'Change Role & Remove Data' : 'Change Role'),
              ),
            ],
          );
        },
      );
    },
  );
}

// Updated _showDeleteUserDialog
void _showDeleteUserDialog(Map<String, dynamic> user) {
  final isCurrentUser = user['id'] == Supabase.instance.client.auth.currentUser?.id;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this user?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'User: ${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Email: ${user['email'] ?? 'No email'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.red[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCurrentUser
                          ? 'You cannot delete your own account.'
                          : 'This action cannot be undone.',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: isCurrentUser
                ? null // Disable if current user
                : () {
                    Navigator.of(context).pop();
                    _deleteUser(user['id']);
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[700],
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: Colors.red.withOpacity(0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete User'),
          ),
        ],
      );
    },
  );
}

// Method to change user role with notification cleanup
Future<void> _changeUserRole(String userId, String newRole) async {
  try {
    // Build update data
    final updateData = <String, dynamic>{'role': newRole};
    
    // If changing FROM officer to another role, clear police data
    if (newRole != 'officer') {
      updateData['police_rank_id'] = null;
      updateData['police_station_id'] = null;
    }
    
    // Update user role
    await Supabase.instance.client
        .from('users')
        .update(updateData)
        .eq('id', userId);

    // If changing TO 'user' role, clear admin/officer notifications
    if (newRole == 'user') {
      await _clearAdminOfficerNotifications(userId);
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('User role changed to $newRole successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Refresh the user data
    await _loadUserStats();
    _loadUsersData();
  } catch (e) {
    print('Error changing user role: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error changing user role: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Method to clear admin/officer specific notifications
Future<void> _clearAdminOfficerNotifications(String userId) async {
  try {
    print('Clearing admin/officer notifications for user: $userId');
    
    // Delete notifications that are only relevant to admins/officers
    await Supabase.instance.client
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .inFilter('type', [
          'report',                // Hotspot reports
          'safe_spot_report',     // Safe spot reports
          'hotspot_approval',     // Hotspot approvals (if any)
          'hotspot_rejection',    // Hotspot rejections (if any)
        ]);
    
    print('Admin/officer notifications cleared successfully');
  } catch (e) {
    print('Error clearing admin/officer notifications: $e');
    // Don't throw error here, just log it as it's not critical
  }
}

Future<void> _deleteUser(String userId) async {
  try {
    // Call the admin_delete_user stored procedure
    await Supabase.instance.client
        .rpc('admin_delete_user', params: {'target_user_id': userId});

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User deleted successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Refresh the user data
    await _loadUserStats();
    _loadUsersData();
  } catch (e) {
    print('Error deleting user: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting user: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// USER LIST MOBILE

Widget _buildUsersPage() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 768) {
        // Desktop view for screens wider than 768px
        return _buildUsersPageDesktop();
      } else {
  return Column(
    children: [
      // Search and Filter Bar (keeping your existing design)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Main Search Row
            Row(
              children: [
                // Expanded Search Bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _userSearchController,
                      onChanged: (value) {
                        _filterUsers();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search users by name, email, or username...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Filter Toggle Button
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      Icons.tune,
                      color: _showFilters ? Colors.white : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    tooltip: 'Toggle Filters',
                  ),
                ),
                
                // Clear Filters Button
                if (_userSearchController.text.isNotEmpty || 
                    _selectedUserRole != 'All Roles' || 
                    _selectedUserGender != 'All Genders')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _clearUserFilters,
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFFF87171),
                        size: 20,
                      ),
                      tooltip: 'Clear Filters',
                    ),
                  ),
              ],
            ),
            
            // Collapsible Filters Row
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 60 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFilters ? 1.0 : 0.0,
                child: _showFilters ? Container(
                  margin: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      // Role Filter Dropdown
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedUserRole,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: _availableRoles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateUserFilter('role', value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Gender Filter Dropdown
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedUserGender,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: _availableGenders.map((gender) {
                              return DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateUserFilter('gender', value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ) : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
      
      // Compact User List
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredUsersData.length,
            itemBuilder: (context, index) {
              final user = _filteredUsersData[index];
              return _buildUserCard(user);
                },
                ),
              ),
            ),
          ],
        );
      }
    },
  );
}

// Add this state variable to track expanded cards
Set<String> _expandedUserCards = <String>{};
Widget _buildUserCard(Map<String, dynamic> user) {
  final userId = user['id'] ?? 0;
  final isExpanded = _expandedUserCards.contains(userId);
  final isCurrentUser = user['id'] == Supabase.instance.client.auth.currentUser?.id;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedUserCards.remove(userId);
              } else {
                _expandedUserCards.add(userId);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getGenderColor(user['gender']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getGenderColor(user['gender']).withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'),
                      style: TextStyle(
                        color: _getGenderColor(user['gender']),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user['role']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getRoleColor(user['role']).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              (user['role'] ?? 'user').toUpperCase(),
                              style: TextStyle(
                                color: _getRoleColor(user['role']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? 'No email',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getGenderColor(user['gender']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getGenderColor(user['gender']).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              user['gender'] ?? 'N/A',
                              style: TextStyle(
                                color: _getGenderColor(user['gender']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user['created_at'] != null
                                ? _getTimeAgo(DateTime.parse(user['created_at']))
                                : 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Expanded Details Section
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: isExpanded ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildDetailItem(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: user['username'] ?? 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.cake,
                  label: 'Birthday',
                  value: user['bday'] != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(user['bday']))
                      : 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.person,
                  label: 'Age',
                  value: user['bday'] != null
                      ? '${_calculateAge(user['bday']) ?? 'Unknown'} years old'
                      : 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.phone,
                  label: 'Contact',
                  value: user['contact_number'] ?? 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.calendar_today,
                  label: 'Member Since',
                  value: user['created_at'] != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(user['created_at']))
                      : 'Unknown',
                ),
                
                // Action Buttons Section - Only visible to admins
                if (_isAdmin) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isCurrentUser)
                          const Text(
                            "You cannot change your own role or delete your own account.",
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF6B7280),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showChangeRoleDialog(user),
                                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                                  label: const Text('Change Role'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey[800],
                                    side: BorderSide(
                                      color: Colors.grey.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDeleteUserDialog(user),
                                  icon: const Icon(Icons.delete_outlined, size: 16),
                                  label: const Text('Delete User'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(
                                      color: Colors.red.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ) : const SizedBox(),
        ),
      ],
    ),
  );
}

Widget _buildDetailItem({
  required IconData icon,
  required String label,
  required String value, String? subtitle,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFF6366F1),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

//USER LIST DESKTOP
Widget _buildUsersPageDesktop() {
  return Column(
    children: [
      // Search and Filter Bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Expanded Search Bar (larger space)
            Expanded(
              flex: 3,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: TextField(
                  controller: _userSearchController,
                  onChanged: (value) {
                    _filterUsers();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search users by name, email, or username...',
                    hintStyle: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Role Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedUserRole,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableRoles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        role,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateUserFilter('role', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Gender Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedUserGender,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableGenders.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(
                        gender,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateUserFilter('gender', value);
                    }
                  },
                ),
              ),
            ),
            
            // Clear Filters Button
            if (_userSearchController.text.isNotEmpty || 
                _selectedUserRole != 'All Roles' || 
                _selectedUserGender != 'All Genders')
              Container(
                margin: const EdgeInsets.only(left: 16),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF87171)),
                ),
                child: IconButton(
                  onPressed: _clearUserFilters,
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: 'Clear Filters',
                ),
              ),
          ],
        ),
      ),
      
      // Data Table
    Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 56,
              dataRowHeight: 56,
              horizontalMargin: 24,
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
              columns: [
                const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Birthday', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Age', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Contact #', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                const DataColumn(label: Text('Member Since', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
                // Only show Actions column if user is admin
                if (_isAdmin)
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151), fontSize: 14))),
              ],
              rows: _filteredUsersData.map((user) {
                final isCurrentUser = user['id'] == Supabase.instance.client.auth.currentUser?.id;
                
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getGenderColor(user['gender']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'),
                                style: TextStyle(
                                  color: _getGenderColor(user['gender']),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(user['email'] ?? 'No email', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(user['role']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getRoleColor(user['role'])),
                        ),
                        child: Text(
                          (user['role'] ?? 'USER').toUpperCase(),
                          style: TextStyle(color: _getRoleColor(user['role']), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getGenderColor(user['gender']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getGenderColor(user['gender'])),
                        ),
                        child: Text(
                          user['gender'] ?? 'N/A',
                          style: TextStyle(color: _getGenderColor(user['gender']), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(Text(
                      user['bday'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(user['bday'])) : 'Not provided',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    )),
                    DataCell(Text(
                      user['bday'] != null ? '${_calculateAge(user['bday']) ?? 'Unknown'} years' : 'Not provided',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    )),
                    DataCell(Text(user['contact_number'] ?? 'Not provided', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)))),
                    DataCell(Text(
                      user['created_at'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(user['created_at'])) : 'Unknown',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    )),
                    // Only show Actions cell if user is admin
                    if (_isAdmin)
                      DataCell(
                        isCurrentUser
                            ? const Text('No actions available', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _showChangeRoleDialog(user),
                                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 20, color: Color(0xFF374151)),
                                    tooltip: 'Change Role',
                                  ),
                                  IconButton(
                                    onPressed: () => _showDeleteUserDialog(user),
                                    icon: const Icon(Icons.delete_outlined, size: 20, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete User',
                                  ),
                                ],
                              ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ],
  );
}


// REPORT PAGE MOBILE

Widget _buildReportsPage() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 768) {
        // Desktop view for screens wider than 768px
        return _buildReportsPageDesktop();
      } else {
  return Column(
    children: [
      // Search and Filter Bar (keeping your existing design)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Main Search Row
            Row(
              children: [
                // Expanded Search Bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _reportSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Search reports by crime type, level, or reporter...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Filter Toggle Button
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      Icons.tune,
                      color: _showFilters ? Colors.white : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    tooltip: 'Toggle Filters',
                  ),
                ),
                
                // Clear Filters Button
                if (_reportSearchController.text.isNotEmpty || 
                    _selectedReportStatus != 'All Status' || 
                    _selectedReportLevel != 'All Levels' ||
                    _selectedReportCategory != 'All Categories' ||
                    _selectedActivityStatus != 'All Activity')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _clearReportFilters,
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFFF87171),
                        size: 20,
                      ),
                      tooltip: 'Clear Filters',
                    ),
                  ),
              ],
            ),
            
            // Collapsible Filters Row
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 120 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFilters ? 1.0 : 0.0,
                child: _showFilters ? Container(
                  margin: const EdgeInsets.only(top: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // First row of filters
                        Row(
                          children: [
                            // Status Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedReportStatus,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableStatuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateReportFilter('status', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Crime Level Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedReportLevel,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableLevels.map((level) {
                                    return DropdownMenuItem(
                                      value: level,
                                      child: Text(
                                        level,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateReportFilter('level', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Second row of filters
                        Row(
                          children: [
                            // Category Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedReportCategory,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableCategories.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateReportFilter('category', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Activity Status Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedActivityStatus,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableActivityStatuses.map((activity) {
                                    return DropdownMenuItem(
                                      value: activity,
                                      child: Text(
                                        activity,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateReportFilter('activity', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ) : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
      
      // Compact Reports List
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredReportsData.length,
            itemBuilder: (context, index) {
              final report = _filteredReportsData[index];
              return _buildReportCard(report);
          },
                ),
              ),
            ),
          ],
        );
      }
    },
  );
}

// Add this state variable to track expanded report cards
Set<int> _expandedReportCards = <int>{};

Widget _buildReportCard(Map<String, dynamic> report) {
  final reportId = report['id'] ?? 0;
  final isExpanded = _expandedReportCards.contains(reportId);
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        // Main Card Content
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedReportCards.remove(reportId);
              } else {
                _expandedReportCards.add(reportId);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Priority Indicator
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getCrimeLevelColor(report['crime_type']?['level']),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Main Report Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Crime level badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCrimeLevelColor(report['crime_type']?['level']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getCrimeLevelColor(report['crime_type']?['level']).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              (report['crime_type']?['level'] ?? 'N/A').toUpperCase(),
                              style: TextStyle(
                                color: _getCrimeLevelColor(report['crime_type']?['level']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Activity status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getActivityColor(report['active_status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getActivityColor(report['active_status']).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              (report['active_status'] ?? 'active').toUpperCase(),
                              style: TextStyle(
                                color: _getActivityColor(report['active_status']),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Report status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(report['status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getStatusColor(report['status']).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              (report['status'] ?? 'pending').toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(report['status']),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report['crime_type']?['name'] ?? 'Unknown Crime',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report['crime_type']?['category'] ?? 'Unknown Category',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          
                          Text(
                            report['created_at'] != null
                                ? _getTimeAgo(DateTime.parse(report['created_at']))
                                : 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Expanded Details
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isExpanded ? null : 0,
          child: isExpanded ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Enhanced Reporter Details Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Reporter Info Row
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(report['reporter'] != null
                                    ? '${report['reporter']['first_name'] ?? ''} ${report['reporter']['last_name'] ?? ''}'
                                    : 'Admin'),
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reported by',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  report['reporter'] != null
                                      ? '${report['reporter']['first_name'] ?? ''} ${report['reporter']['last_name'] ?? ''}'.trim()
                                      : 'Administrator',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF111827),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (report['reporter'] != null && report['reporter']['email'] != null)
                                  Text(
                                    report['reporter']['email'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Additional Report Details
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildDetailItem(
                                  icon: Icons.access_time, 
                                  label: 'Time of Incident',
                                  value: report['time'] != null
                                      ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(report['time']))} at ${DateFormat('h:mm a').format(DateTime.parse(report['time']))}'
                                      : 'Unknown time',
                                ),
                                const SizedBox(height: 12),
                                _buildDetailItem(
                                  icon: Icons.event_note, // or Icons.send for reported
                                  label: 'Reported At',
                                  value: report['created_at'] != null
                                      ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))} at ${DateFormat('h:mm a').format(DateTime.parse(report['created_at']))}'
                                      : 'Unknown date',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ) : const SizedBox(),
        ),
      ],
    ),
  );
}

// REPORT PAGE DESKTOP

Widget _buildReportsPageDesktop() {
  return Column(
    children: [
      // Search and Filter Bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Expanded Search Bar (larger space)
            Expanded(
              flex: 3,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: TextField(
                  controller: _reportSearchController,
                  onChanged: (value) {
                    _filterReports();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search reports by crime type, level, or reporter...',
                    hintStyle: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Status Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedReportStatus,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateReportFilter('status', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Crime Level Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedReportLevel,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(
                        level,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateReportFilter('level', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Category Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedReportCategory,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateReportFilter('category', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Activity Status Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedActivityStatus,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableActivityStatuses.map((activity) {
                    return DropdownMenuItem(
                      value: activity,
                      child: Text(
                        activity,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateReportFilter('activity', value);
                    }
                  },
                ),
              ),
            ),
            
            // Clear Filters Button
            if (_reportSearchController.text.isNotEmpty || 
                _selectedReportStatus != 'All Status' || 
                _selectedReportLevel != 'All Levels' ||
                _selectedReportCategory != 'All Categories' ||
                _selectedActivityStatus != 'All Activity')
              Container(
                margin: const EdgeInsets.only(left: 16),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF87171)),
                ),
                child: IconButton(
                  onPressed: _clearReportFilters,
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: 'Clear Filters',
                ),
              ),
          ],
        ),
      ),
      
      // Data Table
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 56,
              dataRowHeight: 56,
              horizontalMargin: 24,
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
              columns: const [
                DataColumn(
                  label: Text(
                    'Crime Type',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Level',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Activity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Time of Incident',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reported At',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reporter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              rows: _filteredReportsData.map((report) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        report['crime_type']?['name'] ?? 'Unknown Crime',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        report['crime_type']?['category'] ?? 'Unknown Category',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCrimeLevelColor(report['crime_type']?['level']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getCrimeLevelColor(report['crime_type']?['level'])),
                        ),
                        child: Text(
                          (report['crime_type']?['level'] ?? 'N/A').toUpperCase(),
                          style: TextStyle(
                            color: _getCrimeLevelColor(report['crime_type']?['level']),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getStatusColor(report['status'])),
                        ),
                        child: Text(
                          (report['status'] ?? 'PENDING').toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(report['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getActivityColor(report['active_status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getActivityColor(report['active_status'])),
                        ),
                        child: Text(
                          (report['active_status'] ?? 'ACTIVE').toUpperCase(),
                          style: TextStyle(
                            color: _getActivityColor(report['active_status']),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        report['time'] != null
                            ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(report['time']))} at ${DateFormat('h:mm a').format(DateTime.parse(report['time']))}'
                            : 'Unknown time',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        report['created_at'] != null
                            ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))} at ${DateFormat('h:mm a').format(DateTime.parse(report['created_at']))}'
                            : 'Unknown date',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(report['reporter'] != null
                                    ? '${report['reporter']['first_name'] ?? ''} ${report['reporter']['last_name'] ?? ''}'
                                    : 'Admin'),
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report['reporter'] != null
                                ? '${report['reporter']['first_name'] ?? ''} ${report['reporter']['last_name'] ?? ''}'.trim()
                                : 'Administrator',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ],
  );
}


// SAFE SPOTS PAGE MOBILE
Widget _buildSafeSpotsPage() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 768) {
        // Desktop view for screens wider than 768px
        return _buildSafeSpotsPageDesktop();
      } else {
  return Column(
    children: [
      // Search and Filter Bar (matching Reports page design)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Main Search Row
            Row(
              children: [
                // Expanded Search Bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _safeSpotSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Search safe spots by name, type, or description...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Filter Toggle Button
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      Icons.tune,
                      color: _showFilters ? Colors.white : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    tooltip: 'Toggle Filters',
                  ),
                ),
                
                // Clear Filters Button
                if (_safeSpotSearchController.text.isNotEmpty || 
                    _selectedSafeSpotStatus != 'All Status' || 
                    _selectedSafeSpotType != 'All Types' ||
                    _selectedSafeSpotVerified != 'All Verification')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _clearSafeSpotFilters,
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFFF87171),
                        size: 20,
                      ),
                      tooltip: 'Clear Filters',
                    ),
                  ),
              ],
            ),
            
            // Collapsible Filters Row
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 60 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFilters ? 1.0 : 0.0,
                child: _showFilters ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // First row of filters
                        Row(
                          children: [
                            // Status Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedSafeSpotStatus,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableSafeSpotStatuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateSafeSpotFilter('status', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Type Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedSafeSpotType,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableSafeSpotTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateSafeSpotFilter('type', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Verification Filter
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedSafeSpotVerified,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _availableSafeSpotVerified.map((verified) {
                                    return DropdownMenuItem(
                                      value: verified,
                                      child: Text(
                                        verified,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updateSafeSpotFilter('verified', value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ) : const SizedBox(),
              ),
            ),
          ],
        ),
      ),
      
      // Safe Spots List
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: _filteredSafeSpotsData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place_outlined, size: 64, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 16),
                      Text(
                        'No safe spots found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or search terms',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSafeSpotsData.length,
                  itemBuilder: (context, index) {
                    return _buildSafeSpotCard(_filteredSafeSpotsData[index]);
              },
                      ),
              ),
            ),
          ],
        );
      }
    },
  );
}

// Add this state variable to track expanded safe spot cards

Set<String> _expandedSafeSpotCards = <String>{};

// UPDATED SAFESPOT CARD BUILDER
Widget _buildSafeSpotCard(Map<String, dynamic> safeSpot) {
  final safeSpotId = safeSpot['id'] ?? 0;
  final isExpanded = _expandedSafeSpotCards.contains(safeSpotId);
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        // Main Card Content
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSafeSpotCards.remove(safeSpotId);
              } else {
                _expandedSafeSpotCards.add(safeSpotId);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Safe Spot Type Icon with priority indicator
                Column(
                  children: [
                    // Priority/Status Indicator
                    Container(
                      width: 4,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getStatusColor(safeSpot['status']),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                
                // Main Safe Spot Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15), // Added padding here
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges Row
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(safeSpot['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getStatusColor(safeSpot['status']).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                (safeSpot['status'] ?? 'pending').toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(safeSpot['status']),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Verification badge
                            if (safeSpot['verified'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: const Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                      const SizedBox(height: 8),
                      // Safe Spot Name
                      Text(
                        safeSpot['name'] ?? 'Unnamed Safe Spot',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      // Safe Spot Type
                      Text(
                        safeSpot['safe_spot_types']?['name'] ?? 'Unknown Type',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      // Description (if available)
                      if (safeSpot['description'] != null && safeSpot['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            safeSpot['description'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Footer Info
                      Row(
                        children: [
                         
                          
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            safeSpot['created_at'] != null
                                ? _getTimeAgo(DateTime.parse(safeSpot['created_at']))
                                : 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                 ),
              ],
            ),
          ),
        ),
        
        // Expanded Details
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isExpanded ? null : 0,
          child: isExpanded ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Enhanced Creator Details Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Creator Info Row
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(safeSpot['users'] != null
                                    ? '${safeSpot['users']['first_name'] ?? ''} ${safeSpot['users']['last_name'] ?? ''}'
                                    : 'Admin'),
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Added by',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  safeSpot['users'] != null
                                      ? '${safeSpot['users']['first_name'] ?? ''} ${safeSpot['users']['last_name'] ?? ''}'.trim()
                                      : 'Administrator',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF111827),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (safeSpot['users'] != null && safeSpot['users']['email'] != null)
                                  Text(
                                    safeSpot['users']['email'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Additional Safe Spot Details
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              icon: Icons.access_time,
                              label: 'Created At',
                              value: safeSpot['created_at'] != null
                                  ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(safeSpot['created_at']))} at ${DateFormat('HH:mm').format(DateTime.parse(safeSpot['created_at']))}'
                                  : 'Unknown date',
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              ],
            ),
          ) : const SizedBox(),
        ),
      ],
    ),
  );
}


//SAFE SPOT DESKTOP

Widget _buildSafeSpotsPageDesktop() {
  return Column(
    children: [
      // Search and Filter Bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Expanded Search Bar (larger space)
            Expanded(
              flex: 3,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: TextField(
                  controller: _safeSpotSearchController,
                  onChanged: (value) {
                    _filterSafeSpots();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search safe spots by name, type, or description...',
                    hintStyle: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Status Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedSafeSpotStatus,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableSafeSpotStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateSafeSpotFilter('status', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Type Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedSafeSpotType,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableSafeSpotTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateSafeSpotFilter('type', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Verification Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedSafeSpotVerified,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableSafeSpotVerified.map((verified) {
                    return DropdownMenuItem(
                      value: verified,
                      child: Text(
                        verified,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateSafeSpotFilter('verified', value);
                    }
                  },
                ),
              ),
            ),
            
            // Clear Filters Button
            if (_safeSpotSearchController.text.isNotEmpty || 
                _selectedSafeSpotStatus != 'All Status' || 
                _selectedSafeSpotType != 'All Types' ||
                _selectedSafeSpotVerified != 'All Verification')
              Container(
                margin: const EdgeInsets.only(left: 16),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF87171)),
                ),
                child: IconButton(
                  onPressed: _clearSafeSpotFilters,
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: 'Clear Filters',
                ),
              ),
          ],
        ),
      ),
      
      // Data Table
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: _filteredSafeSpotsData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 64, color: Color(0xFF9CA3AF)),
                        SizedBox(height: 16),
                        Text(
                          'No safe spots found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search terms',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  )
                : DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 56,
                    dataRowHeight: 56,
                    horizontalMargin: 24,
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Verification',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Created At',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Added By',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    rows: _filteredSafeSpotsData.map((safeSpot) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              safeSpot['name'] ?? 'Unnamed Safe Spot',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              safeSpot['safe_spot_types']?['name'] ?? 'Unknown Type',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(safeSpot['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _getStatusColor(safeSpot['status'])),
                              ),
                              child: Text(
                                (safeSpot['status'] ?? 'PENDING').toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(safeSpot['status']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: safeSpot['verified'] == true ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: safeSpot['verified'] == true ? Colors.green : Colors.grey,
                                ),
                              ),
                              child: Text(
                                safeSpot['verified'] == true ? 'VERIFIED' : 'UNVERIFIED',
                                style: TextStyle(
                                  color: safeSpot['verified'] == true ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              safeSpot['description']?.toString() ?? 'No description',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DataCell(
                            Text(
                              safeSpot['created_at'] != null
                                  ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(safeSpot['created_at']))} at ${DateFormat('HH:mm').format(DateTime.parse(safeSpot['created_at']))}'
                                  : 'Unknown date',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getInitials(safeSpot['users'] != null
                                          ? '${safeSpot['users']['first_name'] ?? ''} ${safeSpot['users']['last_name'] ?? ''}'
                                          : 'Admin'),
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  safeSpot['users'] != null
                                      ? '${safeSpot['users']['first_name'] ?? ''} ${safeSpot['users']['last_name'] ?? ''}'.trim()
                                      : 'Administrator',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ),
    ],
  );
}


// OFFICER PAGE MOBILE
Widget _buildOfficersPage() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 768) {
        // Desktop view for screens wider than 768px
        return _buildOfficersPageDesktop();
      } else {
  return Column(
    children: [
      // Search and Filter Bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Main Search Row
            Row(
              children: [
                // Expanded Search Bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _officerSearchController,
                      onChanged: (value) {
                        _filterOfficers();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search officers by name, email, or username...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Filter Toggle Button
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showFilters ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      Icons.tune,
                      color: _showFilters ? Colors.white : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    tooltip: 'Toggle Filters',
                  ),
                ),
                
                // Clear Filters Button
              if (_officerSearchController.text.isNotEmpty || 
                  _selectedOfficerGender != 'All Genders' ||
                  _selectedOfficerRank != 'All Ranks' ||
                  _selectedOfficerStation != 'All Stations')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _clearOfficerFilters,
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFFF87171),
                        size: 20,
                      ),
                      tooltip: 'Clear Filters',
                    ),
                  ),
              ],
            ),
            
// Collapsible Filters Row
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  height: _showFilters ? 120 : 0, // Increased height for two rows
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 300),
    opacity: _showFilters ? 1.0 : 0.0,
    child: _showFilters
        ? Container(
            margin: const EdgeInsets.only(top: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // First row: Gender and Rank
                  Row(
                    children: [
                      // Gender Filter Dropdown
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedOfficerGender,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: _availableOfficerGenders.map((gender) {
                              return DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateOfficerFilter('gender', value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Rank Filter Dropdown
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedOfficerRank,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: _availablePoliceRanks.map((rank) {
                              return DropdownMenuItem(
                                value: rank,
                                child: Text(rank),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateOfficerFilter('rank', value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row: Station and Sort
                  Row(
                    children: [
                      // Station Filter Dropdown
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedOfficerStation,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: _availablePoliceStations.map((station) {
                              return DropdownMenuItem(
                                value: station,
                                child: Text(station, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _updateOfficerFilter('station', value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sort Options
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: DropdownButton<String>(
                            value: _officerSortBy,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                              DropdownMenuItem(value: 'email', child: Text('Sort by Email')),
                              DropdownMenuItem(value: 'rank', child: Text('Sort by Rank')),
                              DropdownMenuItem(value: 'station', child: Text('Sort by Station')),
                              DropdownMenuItem(value: 'date_joined', child: Text('Date Joined')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _updateOfficerFilter('sort', value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        : const SizedBox(),
  ),
),
          ],
        ),
      ),
      
      // Officer List
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: _filteredOfficersData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No officers found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filters',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredOfficersData.length,
                  itemBuilder: (context, index) {
                    final officer = _filteredOfficersData[index];
                    return _buildOfficerCard(officer);
                       },
                      ),
              ),
            ),
          ],
        );
      }
    },
  );
}


Widget _buildOfficerCard(Map<String, dynamic> officer) {
  final officerId = officer['id'] ?? 0;
  final isExpanded = _expandedOfficerCards.contains(officerId);
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        // Main Card Content
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedOfficerCards.remove(officerId);
              } else {
                _expandedOfficerCards.add(officerId);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Officer Avatar with shield
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.indigo.withOpacity(0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          _getInitials('${officer['first_name'] ?? ''} ${officer['last_name'] ?? ''}'),
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                                Icons.local_police,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Main Officer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${officer['first_name'] ?? ''} ${officer['last_name'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          // Officer Badge with rank if available (using old rank for familiarity)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.indigo.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              officer['police_ranks']?['old_rank'] ?? 'OFFICER',
                              style: const TextStyle(
                                color: Colors.indigo,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        officer['email'] ?? 'No email',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (officer['gender'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getGenderColor(officer['gender']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getGenderColor(officer['gender']).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                officer['gender'] ?? 'N/A',
                                style: TextStyle(
                                  color: _getGenderColor(officer['gender']),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Show station if available
                          if (officer['police_stations']?['name'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                officer['police_stations']['name'],
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            officer['created_at'] != null
                                ? _getTimeAgo(DateTime.parse(officer['created_at']))
                                : 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Expanded Details Section
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: isExpanded ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildDetailItem(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: officer['username'] ?? 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.cake,
                  label: 'Birthday',
                  value: officer['bday'] != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(officer['bday']))
                      : 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.person,
                  label: 'Age',
                  value: officer['bday'] != null
                      ? '${_calculateAge(officer['bday']) ?? 'Unknown'} years old'
                      : 'Not provided',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.phone,
                  label: 'Contact',
                  value: officer['contact_number'] ?? 'Not provided',
                ),

                // Updated police rank and station fields
                const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.military_tech,
                label: 'Police Rank',
                value: officer['police_ranks']?['new_rank'] != null && officer['police_ranks']?['old_rank'] != null
                    ? '${officer['police_ranks']['new_rank']} (${officer['police_ranks']['old_rank']})'
                    : officer['police_ranks']?['new_rank'] ?? officer['police_ranks']?['old_rank'] ?? 'Not assigned',
                subtitle: null,
              ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.location_city,
                  label: 'Assigned Station',
                  value: officer['police_stations']?['name'] ?? 'Not assigned',
                  subtitle: officer['police_stations']?['station_number'] != null 
                      ? 'Station #${officer['police_stations']['station_number']}'
                      : null,
                ),
              ],
            ),
          ) : const SizedBox(),
        ),
      ],
    ),
  );
}

// OFFICER PAGE DESKTOP 

Widget _buildOfficersPageDesktop() {
  return Column(
    children: [
      // Search and Filter Bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Expanded Search Bar (larger space)
            Expanded(
              flex: 3,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: TextField(
                  controller: _officerSearchController,
                  onChanged: (value) {
                    _filterOfficers();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search officers by name, email, or username...',
                    hintStyle: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Gender Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedOfficerGender,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availableOfficerGenders.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(
                        gender,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateOfficerFilter('gender', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Rank Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedOfficerRank,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availablePoliceRanks.map((rank) {
                    return DropdownMenuItem(
                      value: rank,
                      child: Text(
                        rank,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateOfficerFilter('rank', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Station Filter Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedOfficerStation,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: _availablePoliceStations.map((station) {
                    return DropdownMenuItem(
                      value: station,
                      child: Text(
                        station,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateOfficerFilter('station', value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Sort By Dropdown
            Expanded(
              flex: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xE0E0E0)),
                ),
                child: DropdownButton<String>(
                  value: _officerSortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Sort by Name', style: TextStyle(fontSize: 14, color: Color(0xFF374151)))),
                    DropdownMenuItem(value: 'email', child: Text('Sort by Email', style: TextStyle(fontSize: 14, color: Color(0xFF374151)))),
                    DropdownMenuItem(value: 'rank', child: Text('Sort by Rank', style: TextStyle(fontSize: 14, color: Color(0xFF374151)))),
                    DropdownMenuItem(value: 'station', child: Text('Sort by Station', style: TextStyle(fontSize: 14, color: Color(0xFF374151)))),
                    DropdownMenuItem(value: 'date_joined', child: Text('Date Joined', style: TextStyle(fontSize: 14, color: Color(0xFF374151)))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateOfficerFilter('sort', value);
                    }
                  },
                ),
              ),
            ),
            
            // Clear Filters Button
            if (_officerSearchController.text.isNotEmpty || 
                _selectedOfficerGender != 'All Genders' ||
                _selectedOfficerRank != 'All Ranks' ||
                _selectedOfficerStation != 'All Stations')
              Container(
                margin: const EdgeInsets.only(left: 16),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF87171)),
                ),
                child: IconButton(
                  onPressed: _clearOfficerFilters,
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: 'Clear Filters',
                ),
              ),
          ],
        ),
      ),
      
      // Data Table
      Expanded(
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFAFAFA),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: _filteredOfficersData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 64,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No officers found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  )
                : DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 56,
                    dataRowHeight: 56,
                    horizontalMargin: 24,
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Email',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Gender',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Station',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Username',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Birthday',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Age',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Contact',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Date Joined',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    rows: _filteredOfficersData.map((officer) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${officer['first_name'] ?? ''} ${officer['last_name'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['email'] ?? 'No email',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getGenderColor(officer['gender']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getGenderColor(officer['gender']).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                officer['gender'] ?? 'N/A',
                                style: TextStyle(
                                  color: _getGenderColor(officer['gender']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                              ),
                              child: Text(
                                officer['police_ranks']?['new_rank'] != null && officer['police_ranks']?['old_rank'] != null
                                    ? '${officer['police_ranks']['new_rank']} (${officer['police_ranks']['old_rank']})'
                                    : officer['police_ranks']?['new_rank'] ?? officer['police_ranks']?['old_rank'] ?? 'OFFICER',
                                style: const TextStyle(
                                  color: Colors.indigo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                officer['police_stations']?['name'] ?? 'Not assigned',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['username'] ?? 'Not provided',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['bday'] != null
                                  ? DateFormat('MMM d, yyyy').format(DateTime.parse(officer['bday']))
                                  : 'Not provided',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['bday'] != null
                                  ? '${_calculateAge(officer['bday']) ?? 'Unknown'} years old'
                                  : 'Not provided',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['contact_number'] ?? 'Not provided',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              officer['created_at'] != null
                                  ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(officer['created_at']))} at ${DateFormat('HH:mm').format(DateTime.parse(officer['created_at']))}'
                                  : 'Unknown date',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ),
    ],
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
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isSidebarOpen = !_isSidebarOpen;
              });
              if (_isSidebarOpen) {
                _sidebarController.forward();
              } else {
                _sidebarController.reverse();
              }
            },
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _sidebarAnimation,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPageTitle(),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getPageSubtitle(),
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (_currentPage == 'dashboard')
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


/// ======================
/// ALL SAFE SPOT CHARTS SECTION
/// ======================
Widget _buildSafeSpotChartsSection({bool isWide = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'SafeSpot Analytics',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      const SizedBox(height: 20),

      // Desktop Layout
      if (isWide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
            
                child: _buildSafeSpotStatusChartDesktop(isCombined: true),
              
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildSafeSpotTypesChartDesktop(),
            ),
          ],
        )
      // Mobile Layout
      else
        Column(
          children: [
            _buildSafeSpotStatusChartMobile(), // 👈 mobile version
            const SizedBox(height: 20),
            _buildSafeSpotVerificationChart(),
            const SizedBox(height: 20),
            _buildSafeSpotTypesChart(),
          ],
        ),

      const SizedBox(height: 20),
      _buildSafeSpotTrendChart(),
    ],
  );
}


/// ======================
/// DESKTOP VERSION
/// ======================
Widget _buildSafeSpotStatusChartDesktop({bool isCombined = false}) {
  final totalSafeSpots = _safeSpotStats['total'] ?? 0;
  Map<String, int> statusData = Map.from(_safeSpotStats['status'] ?? {});
  Map<String, int> verificationData = Map.from(_safeSpotStats['verification'] ?? {});

  // Combine if requested
  Map<String, int> combinedData = isCombined
      ? {...statusData, ...verificationData}
      : statusData;

  combinedData.removeWhere((key, value) => value == 0);

  if (totalSafeSpots == 0) {
    // ✅ Empty card (no forced height, same as other charts)
    return Container(
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
      child: _buildEmptyCard('No SafeSpot data available'),
    );
  }

  // ✅ Chart container (fixed height for actual data)
  return Container(
    height: 420,
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
        Text(
          isCombined
              ? 'SafeSpots by Status & Verification'
              : 'SafeSpots by Status',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  sections: combinedData.entries.map((entry) {
                    double percentage = (entry.value / totalSafeSpots) * 100;
                    double animatedValue =
                        entry.value.toDouble() * _chartAnimation.value;

                    return PieChartSectionData(
                      color: isCombined &&
                              verificationData.containsKey(entry.key)
                          ? _getVerificationColor(entry.key)
                          : _getSafeSpotStatusColor(entry.key),
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8
                          ? '${percentage.toStringAsFixed(1)}%'
                          : '',
                      radius: 45 + (8 * _chartAnimation.value),
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: combinedData.entries.map((entry) {
            final color = isCombined &&
                    verificationData.containsKey(entry.key)
                ? _getVerificationColor(entry.key)
                : _getSafeSpotStatusColor(entry.key);

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




/// ======================
/// STATUS (MOBILE)
/// ======================
Widget _buildSafeSpotStatusChartMobile() {
  final totalSafeSpots = _safeSpotStats['total'] ?? 0;
  Map<String, int> statusData = _safeSpotStats['status'] ?? {};
  statusData.removeWhere((key, value) => value == 0);

  if (totalSafeSpots == 0) {
    return _buildEmptyCard('No SafeSpot status data available');
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
          'SafeSpots by Status',
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
                    double percentage = (entry.value / totalSafeSpots) * 100;
                    double animatedValue =
                        entry.value.toDouble() * _chartAnimation.value;

                    return PieChartSectionData(
                      color: _getSafeSpotStatusColor(entry.key),
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8
                          ? '${percentage.toStringAsFixed(1)}%'
                          : '',
                      radius: 60 + (10 * _chartAnimation.value), // 👈 same as gender chart
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: statusData.entries.map((entry) {
            final color = _getSafeSpotStatusColor(entry.key);
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


/// ======================
/// MOBILE VERSION
/// ======================
Widget _buildSafeSpotTypesChart() {
  Map<String, int> typesData = _safeSpotStats['types'] ?? {};

  if (typesData.isEmpty) {
    return _buildEmptyCard('No SafeSpot types data available');
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
    child: _buildSafeSpotTypesChartContent(autoGrow: false),
  );
}

/// ======================
/// DESKTOP VERSION
/// ======================
Widget _buildSafeSpotTypesChartDesktop() {
  Map<String, int> typesData = _safeSpotStats['types'] ?? {};
  int itemCount = typesData.length;

  if (typesData.isEmpty) {
    return Container(
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
      child: _buildEmptyCard('No SafeSpot types data available'),
    );
  }

  return Container(
    height: 420,
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: itemCount <= 3
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildSafeSpotTypesChartContent(autoGrow: true),
              ),
            )
          : Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildSafeSpotTypesChartContent(),
              ),
            ),
    ),
  );
}



/// ======================
/// REUSABLE CONTENT
/// ======================
Widget _buildSafeSpotTypesChartContent({bool autoGrow = false}) {
  Map<String, int> typesData = _safeSpotStats['types'] ?? {};

  if (typesData.isEmpty) {
    return _buildEmptyCard('No SafeSpot types data available');
  }

  int maxValue = typesData.values.isEmpty ? 1 : typesData.values.reduce((a, b) => a > b ? a : b);
  int itemCount = typesData.length;

  // Dynamic sizing
  double fontSize = (autoGrow && itemCount <= 3) ? 16 : 14;
  double barHeight = (autoGrow && itemCount <= 3) ? 18 : 12;
  double spacing = (autoGrow && itemCount <= 3) ? 24 : 16;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'SafeSpots by Type',
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
            children: typesData.entries.map((entry) {
              Color barColor = _getSafeSpotTypeColor(entry.key);
              double progress = (entry.value / maxValue) * _chartAnimation.value;

              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          entry.value.toString(),
                          style: TextStyle(
                            fontSize: fontSize - 2,
                            fontWeight: FontWeight.w500,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: barHeight,
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
                                height: barHeight,
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
  );
}




Widget _buildSafeSpotVerificationChart() {
  final totalSafeSpots = _safeSpotStats['total'] ?? 0;
  Map<String, int> verificationData = _safeSpotStats['verification'] ?? {};
  verificationData.removeWhere((key, value) => value == 0);

  if (totalSafeSpots == 0) {
    return _buildEmptyCard('No SafeSpot verification data available');
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SafeSpots by Verification Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: $totalSafeSpots SafeSpots',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        ...verificationData.entries.map((entry) {
          double percentage = (entry.value / totalSafeSpots) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getVerificationIcon(entry.key),
                          color: _getVerificationColor(entry.key),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getVerificationColor(entry.key),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: constraints.maxWidth * (percentage / 100) * _chartAnimation.value,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [
                                      _getVerificationColor(entry.key).withOpacity(0.8),
                                      _getVerificationColor(entry.key),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildSafeSpotTrendChart() {
  if (_safeSpotsData.isEmpty) {
    return _buildEmptyCard('No SafeSpot trend data available');
  }

  // Process data for trend chart
  Map<String, int> dailyCounts = {};
  for (var safeSpot in _safeSpotsData) {
    final createdAt = DateTime.tryParse(safeSpot['created_at'] ?? '');
    if (createdAt != null &&
        createdAt.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        createdAt.isBefore(_endDate.add(const Duration(days: 1)))) {
      String date = DateFormat('yyyy-MM-dd').format(createdAt);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
  }

  if (dailyCounts.isEmpty) {
    return _buildEmptyCard('No SafeSpot data for selected date range');
  }

List<Map<String, dynamic>> chartData = dailyCounts.entries
    .map((e) => {'date': e.key, 'count': e.value})
    .toList()
  ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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
      final maxValue = chartData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
      final maxY = (maxValue * 1.3).toDouble(); // 30% padding above max value

      // Calculate interval for better grid lines
      final interval = maxY > 20 ? (maxY / 8).ceil().toDouble() :
                      maxY > 10 ? 2.0 : 1.0;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
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
            // Header with responsive title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Safe Spot Added',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
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
                    'Total: ${chartData.fold(0, (sum, item) => sum + (item['count'] as int))}',
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
                            interval: _calculateBottomInterval(chartData.length, screenWidth),
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < chartData.length) {
                                // Show fewer labels on small screens
                                final showInterval = _calculateBottomInterval(chartData.length, screenWidth);
                                if (index % showInterval.toInt() != 0 &&
                                    index != chartData.length - 1) {
                                  return const Text('');
                                }

                                String date = chartData[index]['date'];
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
                      maxX: (chartData.length - 1).toDouble(),
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
                              if (index >= 0 && index < chartData.length) {
                                final date = chartData[index]['date'];
                                final count = chartData[index]['count'];
                                final dateTime = DateTime.parse(date);

                                return LineTooltipItem(
                                  '${DateFormat('MMM d, yyyy').format(dateTime)}\n$count SafeSpots',
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
                                color: const Color(0xFF10B981).withOpacity(0.5),
                                strokeWidth: 2,
                                dashArray: [3, 3],
                              ),
                              FlDotData(
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: const Color(0xFF10B981),
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData.asMap().entries.map((entry) {
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
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          barWidth: isSmallScreen ? 3.0 : 4.0,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withOpacity(0.2),
                                const Color(0xFF34D399).withOpacity(0.05),
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
                                    : const Color(0xFF10B981),
                              );
                            },
                          ),
                        ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          // Average line
                          if (chartData.isNotEmpty)
                            HorizontalLine(
                              y: chartData.fold(0, (sum, item) => sum + (item['count'] as int)) / chartData.length,
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
                    (chartData.fold(0, (sum, item) => sum + (item['count'] as int)) / chartData.length).toStringAsFixed(1),
                    const Color(0xFFF59E0B),
                  ),
                  _buildStatItem('Days', chartData.length.toString(), const Color(0xFF10B981)),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}


// SELECT DATE - Updated for full width in mobile view
Widget _buildDateRangeCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 600;
      return Center(
        child: Container(
          width: isDesktop ? ((_getMaxWidth() ?? 300) + 70) : double.infinity,
 // Full width for mobile, constrained for desktop
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
        ),
      );
    },
  );
}

// CARDS CARDS CARDS - Unchanged from previous update
Widget _buildOverviewCards() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 600;
      return Center(
        child: Container(
          width: _getMaxWidth(),
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
      );
    },
  );
}

// Desktop layout (unchanged: all five cards in a single row)
Widget _buildDesktopLayout() {
  return Row(
    children: [
      Expanded(
        child: _buildStatsCard(
          title: 'Total Reports',
          value: '${_crimeStats['total'] ?? 0}',
          icon: Icons.report_outlined,
          gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
          delay: 0,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatsCard(
          title: 'Pending Reports',
          value: '${_reportStats['status']?['pending'] ?? 0}',
          icon: Icons.pending_outlined,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          delay: 100,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatsCard(
          title: 'Total SafeSpots',
          value: '${_safeSpotStats['total'] ?? 0}',
          icon: Icons.place_outlined,
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          delay: 200,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatsCard(
          title: 'Pending SafeSpot',
          value: '${_safeSpotStats['status']?['pending'] ?? 0}',
          icon: Icons.pending_outlined,
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          delay: 300,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatsCard(
          title: 'Registered Users',
          value: '${_userStats['total'] ?? 0}',
          icon: Icons.people_alt_outlined,
          gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
          delay: 400,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatsCard(
          title: 'Officers',
          value: '${_userStats['officers'] ?? 0}',
          icon: Icons.security_outlined,
          gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          delay: 500,
        ),
      ),
    ],
  );
}

// Mobile layout (unchanged: two cards per row, Registered Users full-width)
Widget _buildMobileLayout() {
  return Column(
    children: [
      // First Row: Total Reports | Pending Reports
      Row(
        children: [
          Expanded(
            child: _buildStatsCard(
              title: 'Total Reports',
              value: '${_crimeStats['total'] ?? 0}',
              icon: Icons.report_outlined,
              gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
              delay: 0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatsCard(
              title: 'Pending Reports',
              value: '${_reportStats['status']?['pending'] ?? 0}',
              icon: Icons.pending_outlined,
              gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
              delay: 100,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      // Second Row: Total SafeSpots | Pending SafeSpot
      Row(
        children: [
          Expanded(
            child: _buildStatsCard(
              title: 'Total SafeSpots',
              value: '${_safeSpotStats['total'] ?? 0}',
              icon: Icons.place_outlined,
              gradient: const [Color(0xFF10B981), Color(0xFF059669)],
              delay: 200,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatsCard(
              title: 'Pending SafeSpot',
              value: '${_safeSpotStats['status']?['pending'] ?? 0}',
              icon: Icons.pending_outlined,
              gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              delay: 300,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      // Third Row: Registered Users | Officers
      Row(
        children: [
          Expanded(
            child: _buildStatsCard(
              title: 'Registered Users',
              value: '${_userStats['total'] ?? 0}',
              icon: Icons.people_alt_outlined,
              gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
              delay: 400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatsCard(
              title: 'Officers',
              value: '${_userStats['officers'] ?? 0}',
              icon: Icons.security_outlined,
              gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              delay: 500,
            ),
          ),
        ],
      ),
    ],
  );
}

// Stats card (unchanged)
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



// UPDATED DASHBOARD CONTENT METHOD
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
                // Combined User and Crime Statistics
                _buildUserAndCrimeChartsSection(isWide: isWide),
                const SizedBox(height: 32),
                // Keep Status Charts separate as before
                _buildStatusChartsSection(isWide: isWide),
                const SizedBox(height: 32),
                _buildHotspotTrendSection(),
                const SizedBox(height: 32),
                _buildSafeSpotChartsSection(isWide: isWide),
              ],
            );
          },
        ),
      ],
    ),
  );
}


// COMBINED USER AND CRIME STATISTICS SECTION
Widget _buildUserAndCrimeChartsSection({bool isWide = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Only show main title on desktop
      if (isWide) ...[
        const Text(
          'User & Crime Statistics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 20),
      ],
      isWide 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SIDE - User Statistics
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildCompactGenderChartCards(), // Changed to compact version
                      const SizedBox(height: 20),
                      _buildCompactRoleChart(), // Changed to compact version
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // RIGHT SIDE - Crime Statistics  
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildCompactCrimeLevelsChart(), // Changed to compact version
                      const SizedBox(height: 20),
                      _buildCompactCrimeCategoriesChart(), // Changed to compact version
                    ],
                  ),
                ),
              ],
            )
          : Column(
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
                const SizedBox(height: 16),
                _buildGenderChartCards(),
                const SizedBox(height: 20),
                _buildRoleChart(),
                const SizedBox(height: 32),
                const Text(
                  'Crime Statistics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCrimeLevelsChart(),
                const SizedBox(height: 20),
                _buildCrimeCategoriesChart(),
              ],
            ),
    ],
  );
}

// COMPACT VERSIONS FOR DESKTOP

Widget _buildCompactGenderChartCards() {
  // Define all possible genders you want to display
  List<String> allGenders = ['Male', 'Female', 'Others', 'LGBTQ+'];

  // Initialize genderData with actual data or an empty map
  Map<String, int> genderData = _userStats['gender'] ?? {};

  // Check if genderData is empty
  if (genderData.isEmpty) {
    return _buildEmptyCard('No gender data available');
  }

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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Users by Gender',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
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
                      radius: 45 + (8 * _chartAnimation.value),
                      titleStyle: const TextStyle(
                        fontSize: 11,
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
        const SizedBox(height: 12),
        Row(
          children: allGenders.map((gender) {
            int index = allGenders.indexOf(gender);
            int value = genderData[gender] ?? 0;
            final color = colors[index % colors.length];

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gender.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      value == 0 ? 'None' : '$value',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
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

// COMPACT USER ROLE (Desktop)
Widget _buildCompactRoleChart() {
  Map<String, int> roleData = _userStats['role'] ?? {};

  if (roleData.isEmpty) {
    return _buildEmptyCard('No role data available');
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Users by Role',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: roleData.values.isEmpty
                              ? 10
                              : roleData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.white, // bright background
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                rod.toY.toInt().toString(),
                                const TextStyle(
                                  color: Colors.black, // readable text
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),

                        barGroups: roleData.entries.map((entry) {
                          int index = roleData.keys.toList().indexOf(entry.key);
                          double animatedHeight =
                              entry.value.toDouble() * _chartAnimation.value;
                    
                  return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: animatedHeight,
                          color: entry.key == 'admin' 
                              ? const Color(0xFF6366F1) 
                              : entry.key == 'officer' 
                                  ? const Color.fromARGB(255, 60, 162, 245) 
                                  : const Color(0xFF10B981),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            colors: entry.key == 'admin' 
                                ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                : entry.key == 'officer'
                                    ? [const Color.fromARGB(255, 60, 162, 245) , const Color.fromARGB(255, 48, 129, 223)]
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
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          List<String> keys = roleData.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                keys[value.toInt()].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
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

// COMPACT CRIMES BY SEVERITY LEVEL (Desktop)
Widget _buildCompactCrimeLevelsChart() {
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

  // Check if there's any actual data (all values are 0 means no data)
  int totalCrimes = levelData.values.fold(0, (sum, value) => sum + value);
  
  if (totalCrimes == 0) {
    return _buildEmptyCard('No crime severity data available');
  }

  Map<String, Color> levelColors = {
    'critical': const Color.fromARGB(255, 247, 26, 10),
    'high': const Color.fromARGB(255, 223, 106, 11),
    'medium': const Color.fromARGB(155, 202, 130, 49),
    'low': const Color.fromARGB(255, 216, 187, 23),
  };

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          'Crimes by Severity Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  sections: levelData.entries.map((entry) {
                    double percentage = (entry.value / totalCrimes) * 100;
                    double animatedValue = entry.value.toDouble() * _chartAnimation.value;
                    return PieChartSectionData(
                      color: levelColors[entry.key] ?? Colors.grey,
                      value: animatedValue,
                      title: _chartAnimation.value > 0.8 ? '${percentage.toStringAsFixed(1)}%' : '',
                      radius: 45 + (8 * _chartAnimation.value),
                      titleStyle: const TextStyle(
                        fontSize: 10,
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
        const SizedBox(height: 12),
        // Horizontal layout for legend cards
        Row(
          children: allLevels.map((level) {
            final color = levelColors[level] ?? Colors.grey;
            final value = levelData[level] ?? 0;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      value == 0 ? 'None' : '$value',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
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

// COMPACT CRIMES BY CATEGORY (Desktop)
Widget _buildCompactCrimeCategoriesChart() {
  Map<String, int> categoryData = _crimeStats['categories'] ?? {};

  if (categoryData.isEmpty) {
    return _buildEmptyCard('No crime category data available');
  }

  // Color mapping based on your filter section
  Map<String, Color> categoryColors = {
    'Property': Colors.blue,
    'Violent': Colors.red,
    'Drug': Colors.purple,
    'Public Order': Colors.orange,
    'Financial': Colors.green,
    'Traffic': Colors.blueGrey,
    'Alert': Colors.deepPurple,
    // Fallback colors for any other categories
    'default1': const Color(0xFF0891B2),
    'default2': const Color.fromARGB(255, 185, 163, 36),
  };

  // Get max value for scaling
  int maxValue = categoryData.values.isEmpty ? 1 : categoryData.values.reduce((a, b) => a > b ? a : b);
  
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return SingleChildScrollView(
                child: Column(
                  children: categoryData.entries.map((entry) {
                    // Get color based on category name, with fallback
                    Color barColor = categoryColors[entry.key] ?? Colors.grey;
                    double progress = (entry.value / maxValue) * _chartAnimation.value;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: barColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: constraints.maxWidth * progress,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
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
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
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
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}





// MOBILE CHARTS AND GRAPHS BELOW 
  // USERS BY GENDER



 Widget _buildGenderChartCards() {
  // Define all possible genders you want to display
  List<String> allGenders = ['Male', 'Female', 'Others', 'LGBTQ+'];

  // Initialize genderData with actual data or an empty map
  Map<String, int> genderData = _userStats['gender'] ?? {};

  // Check if genderData is empty
  if (genderData.isEmpty) {
    return _buildEmptyCard('No gender data available');
  }

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

// USER ROLE
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
                          maxY: roleData.values.isEmpty
                              ? 10
                              : roleData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.white, // bright background
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                rod.toY.toInt().toString(),
                                const TextStyle(
                                  color: Colors.black, // readable text
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),

                        barGroups: roleData.entries.map((entry) {
                          int index = roleData.keys.toList().indexOf(entry.key);
                          double animatedHeight =
                              entry.value.toDouble() * _chartAnimation.value;
                      
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: animatedHeight,
                          color: entry.key == 'admin' 
                              ? const Color(0xFF6366F1) 
                              : entry.key == 'officer' 
                                  ? const Color.fromARGB(255, 60, 162, 245) 
                                  : const Color(0xFF10B981),
                          width: 32,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          gradient: LinearGradient(
                            colors: entry.key == 'admin' 
                                ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                : entry.key == 'officer'
                                    ? [const Color.fromARGB(255, 60, 162, 245) , Color.fromARGB(255, 49, 124, 211)]
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



  Widget _buildStatusChartsSection({bool isWide = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports Analytics',
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

  // Check if there's any actual data (all values are 0 means no data)
  int totalCrimes = levelData.values.fold(0, (sum, value) => sum + value);
  
  if (totalCrimes == 0) {
    return _buildEmptyCard('No crime severity data available');
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
                    double percentage = (entry.value / totalCrimes) * 100;
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

  // Color mapping based on your filter section
  Map<String, Color> categoryColors = {
    'Property': Colors.blue,
    'Violent': Colors.red,
    'Drug': Colors.purple,
    'Public Order': Colors.orange,
    'Financial': Colors.green,
    'Traffic': Colors.blueGrey,
    'Alert': Colors.deepPurple,
    // Fallback colors for any other categories
    'default1': const Color(0xFF0891B2),
    'default2': const Color.fromARGB(255, 185, 163, 36),
  };

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
                // Get color based on category name, with fallback
                Color barColor = categoryColors[entry.key] ?? Colors.grey;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports by Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: $totalReports reports',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        
        // Use LayoutBuilder to detect screen width
        LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;
            
            if (isDesktop) {
              // Desktop: Bar Chart (matching your compact style)
              return SizedBox(
                height: 250,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: statusData.values.isEmpty
                            ? 10
                            : statusData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => Colors.white,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                rod.toY.toInt().toString(),
                                const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        barGroups: statusData.entries.map((entry) {
                          int index = statusData.keys.toList().indexOf(entry.key);
                          double animatedHeight =
                              entry.value.toDouble() * _chartAnimation.value;
                          
                          Color statusColor = _getStatusColor(entry.key);
                          
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: animatedHeight,
                                color: statusColor,
                                width: 24,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                gradient: LinearGradient(
                                  colors: [statusColor, statusColor.withOpacity(0.8)],
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
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(), // Convert to integer and then to string
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                List<String> keys = statusData.keys.toList();
                                if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      keys[value.toInt()].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
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
              );
            } else {
              // Mobile: Keep original pie chart
              return Column(
                children: [
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

                  // Mini cards for mobile
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
              );
            }
          },
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports by Activity Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: $totalActivities reports',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        // Use LayoutBuilder to detect screen width
        LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 800;

            if (isDesktop) {
              // Desktop View: Updated column layout with fixed height
              return SizedBox(
                height: 250, // Fixed height to match the status chart
                child: Column(
                  children: activityData.entries.map((entry) {
                    double percentage = (entry.value / totalActivities) * 100;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getActivityIcon(entry.key),
                                      color: _getActivityColor(entry.key),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.key.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _getActivityColor(entry.key),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _chartAnimation,
                                builder: (context, child) {
                                  return Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Stack(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: constraints.maxWidth * (percentage / 100) * _chartAnimation.value,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(4),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    _getActivityColor(entry.key).withOpacity(0.8),
                                                    _getActivityColor(entry.key),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            } else {
              // Mobile View: Original layout
              return Column(
                children: activityData.entries.map((entry) {
                  double percentage = (entry.value / totalActivities) * 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getActivityIcon(entry.key),
                                  color: _getActivityColor(entry.key),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _getActivityColor(entry.key),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _chartAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: constraints.maxWidth * (percentage / 100) * _chartAnimation.value,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          gradient: LinearGradient(
                                            colors: [
                                              _getActivityColor(entry.key).withOpacity(0.8),
                                              _getActivityColor(entry.key),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }
          },
        ),
      ],
    ),
  );
}




// LINE CHART FOR HOTSPOT

 Widget _buildHotspotTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

  
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

        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
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


// Helper methods (add these if you don't have them):
String _getInitials(String name) {
  if (name.isEmpty) return 'U';
  final words = name.trim().split(' ');
  if (words.length == 1) return words[0][0].toUpperCase();
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inDays > 7) {
    return '${(difference.inDays / 7).floor()}w ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

// Add helper methods
Color _getGenderColor(String? gender) {
  switch (gender?.toLowerCase()) {
    case 'male':
      return const Color(0xFF3B82F6);
    case 'female':
      return const Color(0xFFEC4899);
    case 'lgbtq+':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _getRoleColor(String? role) {
  switch (role) {
    case 'admin':
      return const Color(0xFFDC2626); // Red
    case 'officer':
      return Colors.indigo; // Indigo
    case 'user':
    default:
      return const Color(0xFF059669); // Green
  }
}

Color _getCrimeLevelColor(String? level) {
  switch (level?.toLowerCase()) {
    case 'critical':
      return const Color(0xFFDC2626);
    case 'high':
      return const Color(0xFFEA580C);
    case 'medium':
      return const Color(0xFFD97706);
    case 'low':
      return const Color(0xFF65A30D);
    default:
      return const Color(0xFF6B7280);
  }
}


  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF059669);
      case 'pending':
        return const Color.fromARGB(255, 72, 74, 199);
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
  
  _getMaxWidth() {}
}

IconData? _getActivityIcon(String key) {
  return null;

}

// SAFE SPOTS COLOR
Color _getSafeSpotStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return const Color(0xFF10B981); // Green
    case 'pending':
      return const Color(0xFFF59E0B); // Amber
    case 'rejected':
      return const Color(0xFFEF4444); // Red
    default:
      return const Color(0xFF6B7280); // Gray
  }
}

Color _getSafeSpotTypeColor(String type) {
  // Generate consistent colors for different SafeSpot types
  final colors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF84CC16), // Lime
    const Color(0xFFEC4899), // Pink
  ];
  
  int index = type.hashCode % colors.length;
  return colors[index.abs()];
}

Color _getVerificationColor(String status) {
  switch (status.toLowerCase()) {
    case 'verified':
      return const Color(0xFF14B8A6); // Teal
    case 'unverified':
      return const Color(0xFF6B7280); // Gray
    default:
      return const Color(0xFF6B7280);
  }
}

IconData _getVerificationIcon(String status) {
  switch (status.toLowerCase()) {
    case 'verified':
      return Icons.verified;
    case 'unverified':
      return Icons.pending;
    default:
      return Icons.help_outline;
  }
}

