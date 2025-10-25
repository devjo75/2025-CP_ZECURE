class SearchAndFilterService {
  // Complete list of all 98 Zamboanga City Barangays (Official 2020 Census)
  static const List<String> zamboangaCityBarangays = [
    'Arena Blanco',
    'Ayala',
    'Baliwasan',
    'Baluno',
    'Barangay Zone I',
    'Barangay Zone II',
    'Barangay Zone III',
    'Barangay Zone IV',
    'Boalan',
    'Bolong',
    'Buenavista',
    'Bunguiao',
    'Busay',
    'Cabaluay',
    'Cabatangan',
    'Cacao',
    'Calabasa',
    'Calarian',
    'Camino Nuevo',
    'Campo Islam',
    'Canelar',
    'Capisan',
    'Cawit',
    'Culianan',
    'Curuan',
    'Dita',
    'Divisoria',
    'Dulian (Upper Bunguiao)',
    'Dulian (Upper Pasonanca)',
    'Guisao',
    'Guiwan',
    'Kasanyangan',
    'La Paz',
    'Labuan',
    'Lamisahan',
    'Landang Gua',
    'Landang Laum',
    'Lanzones',
    'Lapakan',
    'Latuan',
    'Licomo',
    'Limaong',
    'Limpapa',
    'Lubigan',
    'Lumayang',
    'Lumbangan',
    'Lunzuran',
    'Maasin',
    'Malagutay',
    'Mampang',
    'Manalipa',
    'Mangusu',
    'Manicahan',
    'Mariki',
    'Mercedes',
    'Muti',
    'Pamucutan',
    'Pangapuyan',
    'Panubigan',
    'Pasilmanta',
    'Pasobolong',
    'Pasonanca',
    'Patalon',
    'Putik',
    'Quiniput',
    'Recodo',
    'Rio Hondo',
    'Salaan',
    'San Jose Cawa-cawa',
    'San Jose Gusu',
    'San Roque',
    'Sangali',
    'Santa Barbara',
    'Santa Catalina',
    'Santa Maria',
    'Santo NiÃ±o',
    'Sibulao',
    'Sinubung',
    'Sinunoc',
    'Tagasilay',
    'Taguiti',
    'Talabaan',
    'Talisayan',
    'Talon-talon',
    'Taluksangay',
    'Tetuan',
    'Tictapul',
    'Tigbalabag',
    'Tigtabon',
    'Tolosa',
    'Tugbungan',
    'Tulungatung',
    'Tumaga',
    'Tumalutab',
    'Tumitus',
    'Victoria',
    'Vitali',
    'Zambowood',
  ];

  // User-related search and filtering methods
  static List<Map<String, dynamic>> filterUsers({
    required List<Map<String, dynamic>> users,
    String? searchQuery,
    String? roleFilter,
    String? genderFilter,
    String? sortBy,
    bool ascending = true,
  }) {
    List<Map<String, dynamic>> filteredUsers = List.from(users);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredUsers = _searchUsers(filteredUsers, searchQuery);
    }

    if (roleFilter != null && roleFilter != 'All Roles') {
      filteredUsers = filteredUsers.where((user) {
        return (user['role']?.toString() ?? 'user').toLowerCase() == roleFilter.toLowerCase();
      }).toList();
    }

    if (genderFilter != null && genderFilter != 'All Genders') {
      filteredUsers = filteredUsers.where((user) {
        return (user['gender']?.toString() ?? '').toLowerCase() == genderFilter.toLowerCase();
      }).toList();
    }

    if (sortBy != null) {
      _sortUsers(filteredUsers, sortBy, ascending);
    }

    return filteredUsers;
  }

  static List<Map<String, dynamic>> _searchUsers(
    List<Map<String, dynamic>> users,
    String query,
  ) {
    String searchTerm = query.toLowerCase().trim();
    
    return users.where((user) {
      String fullName = '${user['first_name']?.toString() ?? ''} ${user['last_name']?.toString() ?? ''}'.toLowerCase().trim();
      if (fullName.contains(searchTerm)) return true;

      String email = (user['email']?.toString() ?? '').toLowerCase();
      if (email.contains(searchTerm)) return true;

      String username = (user['username']?.toString() ?? '').toLowerCase();
      if (username.contains(searchTerm)) return true;

      String contact = (user['contact_number']?.toString() ?? '').toLowerCase();
      if (contact.contains(searchTerm)) return true;

      String role = (user['role']?.toString() ?? '').toLowerCase();
      if (role.contains(searchTerm)) return true;

      String gender = (user['gender']?.toString() ?? '').toLowerCase();
      if (gender.contains(searchTerm)) return true;

      return false;
    }).toList();
  }

  static void _sortUsers(
    List<Map<String, dynamic>> users,
    String sortBy,
    bool ascending,
  ) {
    users.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortBy) {
        case 'name':
          aValue = '${a['first_name']?.toString() ?? ''} ${a['last_name']?.toString() ?? ''}'.trim().toLowerCase();
          bValue = '${b['first_name']?.toString() ?? ''} ${b['last_name']?.toString() ?? ''}'.trim().toLowerCase();
          break;
        case 'email':
          aValue = (a['email']?.toString() ?? '').toLowerCase();
          bValue = (b['email']?.toString() ?? '').toLowerCase();
          break;
        case 'username':
          aValue = (a['username']?.toString() ?? '').toLowerCase();
          bValue = (b['username']?.toString() ?? '').toLowerCase();
          break;
        case 'role':
          aValue = (a['role']?.toString() ?? 'user').toLowerCase();
          bValue = (b['role']?.toString() ?? 'user').toLowerCase();
          break;
        case 'gender':
          aValue = (a['gender']?.toString() ?? '').toLowerCase();
          bValue = (b['gender']?.toString() ?? '').toLowerCase();
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
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      int comparison = aValue.toString().compareTo(bValue.toString());
      return ascending ? comparison : -comparison;
    });
  }

  // Report-related search and filtering methods with async barangay support
  static List<Map<String, dynamic>> filterReports({
    required List<Map<String, dynamic>> reports,
    String? searchQuery,
    String? statusFilter,
    String? levelFilter,
    String? categoryFilter,
    String? activityFilter,
    String? barangayFilter,
    String? sortBy,
    bool ascending = true,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    List<Map<String, dynamic>> filteredReports = List.from(reports);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredReports = _searchReports(filteredReports, searchQuery);
    }

    if (statusFilter != null && statusFilter != 'All Status') {
      filteredReports = filteredReports.where((report) {
        return (report['status']?.toString() ?? 'pending').toLowerCase() == statusFilter.toLowerCase();
      }).toList();
    }

    if (levelFilter != null && levelFilter != 'All Levels') {
      filteredReports = filteredReports.where((report) {
        String reportLevel = getNestedString(report, ['crime_type', 'level']);
        return reportLevel.toLowerCase() == levelFilter.toLowerCase();
      }).toList();
    }

    if (categoryFilter != null && categoryFilter != 'All Categories') {
      filteredReports = filteredReports.where((report) {
        String reportCategory = getNestedString(report, ['crime_type', 'category']);
        return reportCategory.toLowerCase() == categoryFilter.toLowerCase();
      }).toList();
    }

    if (activityFilter != null && activityFilter != 'All Activity') {
      filteredReports = filteredReports.where((report) {
        return (report['active_status']?.toString() ?? 'active').toLowerCase() == activityFilter.toLowerCase();
      }).toList();
    }

    // Apply barangay filter - this checks cached barangay data
    if (barangayFilter != null && barangayFilter != 'All Barangays') {
      filteredReports = filteredReports.where((report) {
        String reportBarangay = report['cached_barangay']?.toString() ?? '';
        return reportBarangay.toLowerCase() == barangayFilter.toLowerCase();
      }).toList();
    }

    if (startDate != null && endDate != null) {
      filteredReports = filteredReports.where((report) {
        if (report['time'] != null) {
          DateTime reportDate = DateTime.parse(report['time'].toString());
          return reportDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 reportDate.isBefore(endDate.add(const Duration(days: 1)));
        }
        return false;
      }).toList();
    }

    if (sortBy != null) {
      _sortReports(filteredReports, sortBy, ascending);
    }

    return filteredReports;
  }

  static List<Map<String, dynamic>> _searchReports(
    List<Map<String, dynamic>> reports,
    String query,
  ) {
    String searchTerm = query.toLowerCase().trim();
    
    return reports.where((report) {
      String reportId = report['id']?.toString() ?? '';
      if (reportId.contains(searchTerm)) return true;

      String crimeType = getNestedString(report, ['crime_type', 'name']).toLowerCase();
      if (crimeType.contains(searchTerm)) return true;

      String crimeCategory = getNestedString(report, ['crime_type', 'category']).toLowerCase();
      if (crimeCategory.contains(searchTerm)) return true;

      String crimeLevel = getNestedString(report, ['crime_type', 'level']).toLowerCase();
      if (crimeLevel.contains(searchTerm)) return true;

      String status = (report['status']?.toString() ?? '').toLowerCase();
      if (status.contains(searchTerm)) return true;

      String activityStatus = (report['active_status']?.toString() ?? '').toLowerCase();
      if (activityStatus.contains(searchTerm)) return true;

      // Search by cached barangay
      String barangay = (report['cached_barangay']?.toString() ?? '').toLowerCase();
      if (barangay.contains(searchTerm)) return true;

      if (report['reporter'] != null && report['reporter'] is Map<String, dynamic>) {
        String reporterFirstName = getNestedString(report, ['reporter', 'first_name']);
        String reporterLastName = getNestedString(report, ['reporter', 'last_name']);
        String reporterName = '$reporterFirstName $reporterLastName'.toLowerCase().trim();
        if (reporterName.contains(searchTerm)) return true;

        String reporterEmail = getNestedString(report, ['reporter', 'email']).toLowerCase();
        if (reporterEmail.contains(searchTerm)) return true;
      }

      if (report['users'] != null && report['users'] is Map<String, dynamic>) {
        String creatorFirstName = getNestedString(report, ['users', 'first_name']);
        String creatorLastName = getNestedString(report, ['users', 'last_name']);
        String creatorName = '$creatorFirstName $creatorLastName'.toLowerCase().trim();
        if (creatorName.contains(searchTerm)) return true;
      }

      String location = (report['location']?.toString() ?? '').toLowerCase();
      if (location.contains(searchTerm)) return true;

      String description = (report['description']?.toString() ?? '').toLowerCase();
      if (description.contains(searchTerm)) return true;

      return false;
    }).toList();
  }

  // Made public for use in PDF export modal
  static String getNestedString(Map<String, dynamic> map, List<String> keys) {
    dynamic current = map;
    for (String key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return '';
      }
    }
    return current?.toString() ?? '';
  }

  // Extract coordinates from PostGIS geometry format
  static Map<String, double>? extractCoordinates(String? location) {
    if (location == null || location.isEmpty) return null;
    
    try {
      // PostGIS format: 0101000020E6100000[hex data]
      // We need to parse the WKB (Well-Known Binary) format
      // For now, we'll handle the common POINT format
      
      // Check if it's already in a readable format (lat, lng)
      if (location.contains(',')) {
        List<String> parts = location.split(',');
        if (parts.length == 2) {
          double? lat = double.tryParse(parts[0].trim());
          double? lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            return {'lat': lat, 'lng': lng};
          }
        }
      }
      
      // If it's PostGIS binary format, we can't parse it directly in Dart
      // The coordinates need to be extracted from the database query
      return null;
    } catch (e) {
      return null;
    }
  }

  static String extractBarangayFromAddress(String? address) {
    if (address == null || address.isEmpty) return '';
    
    String addressLower = address.toLowerCase();
    
    for (String barangay in SearchAndFilterService.zamboangaCityBarangays) {
      if (addressLower.contains(barangay.toLowerCase())) {
        return barangay;
      }
    }

    List<String> parts = address.split(',').map((e) => e.trim()).toList();

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];

      if (part.toLowerCase().contains('zamboanga city') ||
          part.toLowerCase().contains('zamboanga peninsula') ||
          part.toLowerCase().contains('philippines') ||
          part.toLowerCase().contains('street') ||
          part.toLowerCase().contains('road') ||
          part.toLowerCase().contains('avenue') ||
          RegExp(r'^\d+$').hasMatch(part)) {
        continue;
      }

      for (String barangay in SearchAndFilterService.zamboangaCityBarangays) {
        if (part.toLowerCase() == barangay.toLowerCase() ||
            part.toLowerCase().contains(barangay.toLowerCase())) {
          return barangay;
        }
      }
    }

    return '';
  }

  static void _sortReports(
    List<Map<String, dynamic>> reports,
    String sortBy,
    bool ascending,
  ) {
    reports.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortBy) {
        case 'id':
          aValue = a['id'] ?? 0;
          bValue = b['id'] ?? 0;
          break;
        case 'crime_type':
          aValue = getNestedString(a, ['crime_type', 'name']).toLowerCase();
          bValue = getNestedString(b, ['crime_type', 'name']).toLowerCase();
          break;
        case 'level':
          Map<String, int> levelPriority = {
            'critical': 4,
            'high': 3,
            'medium': 2,
            'low': 1,
          };
          aValue = levelPriority[getNestedString(a, ['crime_type', 'level']).toLowerCase()] ?? 0;
          bValue = levelPriority[getNestedString(b, ['crime_type', 'level']).toLowerCase()] ?? 0;
          break;
        case 'status':
          Map<String, int> statusPriority = {
            'pending': 3,
            'approved': 2,
            'rejected': 1,
          };
          aValue = statusPriority[(a['status']?.toString() ?? '').toLowerCase()] ?? 0;
          bValue = statusPriority[(b['status']?.toString() ?? '').toLowerCase()] ?? 0;
          break;
        case 'barangay':
          aValue = (a['cached_barangay']?.toString() ?? '').toLowerCase();
          bValue = (b['cached_barangay']?.toString() ?? '').toLowerCase();
          break;
        case 'reporter':
          String aReporter = '';
          String bReporter = '';
          
          if (a['reporter'] != null && a['reporter'] is Map<String, dynamic>) {
            String aFirstName = getNestedString(a, ['reporter', 'first_name']);
            String aLastName = getNestedString(a, ['reporter', 'last_name']);
            aReporter = '$aFirstName $aLastName'.trim();
          }
          if (aReporter.isEmpty) aReporter = 'Admin';
          
          if (b['reporter'] != null && b['reporter'] is Map<String, dynamic>) {
            String bFirstName = getNestedString(b, ['reporter', 'first_name']);
            String bLastName = getNestedString(b, ['reporter', 'last_name']);
            bReporter = '$bFirstName $bLastName'.trim();
          }
          if (bReporter.isEmpty) bReporter = 'Admin';
          
          aValue = aReporter.toLowerCase();
          bValue = bReporter.toLowerCase();
          break;
        case 'date':
          aValue = a['time'] != null ? DateTime.parse(a['time'].toString()) : DateTime.now();
          bValue = b['time'] != null ? DateTime.parse(b['time'].toString()) : DateTime.now();
          break;
        case 'activity_status':
          Map<String, int> activityPriority = {
            'active': 2,
            'inactive': 1,
          };
          aValue = activityPriority[(a['active_status']?.toString() ?? '').toLowerCase()] ?? 0;
          bValue = activityPriority[(b['active_status']?.toString() ?? '').toLowerCase()] ?? 0;
          break;
        default:
          aValue = '';
          bValue = '';
      }

      if (aValue is DateTime && bValue is DateTime) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      if (aValue is int && bValue is int) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }

      int comparison = aValue.toString().compareTo(bValue.toString());
      return ascending ? comparison : -comparison;
    });
  }

  // Utility methods
  static List<String> getUniqueRoles(List<Map<String, dynamic>> users) {
    Set<String> roles = {'All Roles'};
    for (var user in users) {
      String role = user['role']?.toString() ?? 'user';
      roles.add(_capitalizeFirst(role));
    }
    return roles.toList();
  }

  static List<String> getUniqueGenders(List<Map<String, dynamic>> users) {
    Set<String> genders = {'All Genders'};
    for (var user in users) {
      String gender = user['gender']?.toString() ?? '';
      if (gender.isNotEmpty) {
        genders.add(gender);
      }
    }
    return genders.toList();
  }

  static List<String> getUniqueStatuses(List<Map<String, dynamic>> reports) {
    Set<String> statuses = {'All Status'};
    for (var report in reports) {
      String status = report['status']?.toString() ?? 'pending';
      statuses.add(_capitalizeFirst(status));
    }
    return statuses.toList();
  }

  static List<String> getUniqueLevels(List<Map<String, dynamic>> reports) {
    Set<String> levels = {'All Levels'};
    for (var report in reports) {
      String level = getNestedString(report, ['crime_type', 'level']);
      if (level.isNotEmpty) {
        levels.add(_capitalizeFirst(level));
      }
    }
    return levels.toList();
  }

  static List<String> getUniqueCategories(List<Map<String, dynamic>> reports) {
    Set<String> categories = {'All Categories'};
    for (var report in reports) {
      String category = getNestedString(report, ['crime_type', 'category']);
      if (category.isNotEmpty) {
        categories.add(category);
      }
    }
    return categories.toList();
  }

  static List<String> getUniqueActivityStatuses(List<Map<String, dynamic>> reports) {
    Set<String> statuses = {'All Activity'};
    for (var report in reports) {
      String status = report['active_status']?.toString() ?? 'active';
      statuses.add(_capitalizeFirst(status));
    }
    return statuses.toList();
  }

  // Get unique barangays from reports (only barangays with actual reports)
  static List<String> getUniqueBarangays(List<Map<String, dynamic>> reports) {
    Set<String> barangays = {};
    
    for (var report in reports) {
      String barangay = report['cached_barangay']?.toString() ?? '';
      if (barangay.isNotEmpty) {
        barangays.add(barangay);
      }
    }
    
    // Sort alphabetically and add "All Barangays" at the beginning
    List<String> sortedBarangays = barangays.toList()..sort();
    return ['All Barangays', ...sortedBarangays];
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Advanced filtering methods
  static List<Map<String, dynamic>> getRecentUsers(
    List<Map<String, dynamic>> users, 
    {int days = 30}
  ) {
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: days));
    return users.where((user) {
      if (user['created_at'] != null) {
        DateTime userDate = DateTime.parse(user['created_at'].toString());
        return userDate.isAfter(cutoffDate);
      }
      return false;
    }).toList();
  }

  static List<Map<String, dynamic>> getRecentReports(
    List<Map<String, dynamic>> reports, 
    {int days = 30}
  ) {
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: days));
    return reports.where((report) {
      if (report['created_at'] != null) {
        DateTime reportDate = DateTime.parse(report['created_at'].toString());
        return reportDate.isAfter(cutoffDate);
      }
      return false;
    }).toList();
  }

  static List<Map<String, dynamic>> getHighPriorityReports(
    List<Map<String, dynamic>> reports
  ) {
    List<String> highPriorityLevels = ['critical', 'high'];
    return reports.where((report) {
      String level = getNestedString(report, ['crime_type', 'level']).toLowerCase();
      return highPriorityLevels.contains(level);
    }).toList();
  }

  static List<Map<String, dynamic>> getPendingReports(
    List<Map<String, dynamic>> reports
  ) {
    return reports.where((report) {
      return (report['status']?.toString() ?? 'pending').toLowerCase() == 'pending';
    }).toList();
  }

  static List<Map<String, dynamic>> getActiveReports(
    List<Map<String, dynamic>> reports
  ) {
    return reports.where((report) {
      return (report['active_status']?.toString() ?? 'active').toLowerCase() == 'active';
    }).toList();
  }

  static List<Map<String, dynamic>> getReportsByBarangay(
    List<Map<String, dynamic>> reports,
    String barangay
  ) {
    if (barangay == 'All Barangays') return reports;
    
    return reports.where((report) {
      String reportBarangay = report['cached_barangay']?.toString() ?? '';
      return reportBarangay.toLowerCase() == barangay.toLowerCase();
    }).toList();
  }

  // Statistics and analytics helper methods
  static Map<String, int> getUserStatsByRole(List<Map<String, dynamic>> users) {
    Map<String, int> roleStats = {};
    for (var user in users) {
      String role = user['role']?.toString() ?? 'user';
      roleStats[role] = (roleStats[role] ?? 0) + 1;
    }
    return roleStats;
  }

  static Map<String, int> getUserStatsByGender(List<Map<String, dynamic>> users) {
    Map<String, int> genderStats = {};
    for (var user in users) {
      String gender = user['gender']?.toString() ?? 'Not specified';
      genderStats[gender] = (genderStats[gender] ?? 0) + 1;
    }
    return genderStats;
  }

  static Map<String, int> getReportStatsByStatus(List<Map<String, dynamic>> reports) {
    Map<String, int> statusStats = {};
    for (var report in reports) {
      String status = report['status']?.toString() ?? 'pending';
      statusStats[status] = (statusStats[status] ?? 0) + 1;
    }
    return statusStats;
  }

  static Map<String, int> getReportStatsByLevel(List<Map<String, dynamic>> reports) {
    Map<String, int> levelStats = {};
    for (var report in reports) {
      String level = getNestedString(report, ['crime_type', 'level']);
      if (level.isEmpty) level = 'unknown';
      levelStats[level] = (levelStats[level] ?? 0) + 1;
    }
    return levelStats;
  }

  static Map<String, int> getReportStatsByBarangay(List<Map<String, dynamic>> reports) {
    Map<String, int> barangayStats = {};
    for (var report in reports) {
      String barangay = report['cached_barangay']?.toString() ?? '';
      if (barangay.isEmpty) barangay = 'Unknown';
      barangayStats[barangay] = (barangayStats[barangay] ?? 0) + 1;
    }
    return barangayStats;
  }
}