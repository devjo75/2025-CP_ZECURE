import 'package:flutter/material.dart';

class HotspotFilterService with ChangeNotifier {
  bool get hasCustomDateRange =>
      _crimeStartDate != null || _crimeEndDate != null;
  // Severity filters
  bool _showCritical = true;
  bool _showHigh = true;
  bool _showMedium = true;
  bool _showLow = true;

  // Status filters
  bool _showPending = true;
  bool _showRejected = true;
  bool _showActive = true;
  bool _showInactive = true;

  // Category filters
  bool _showProperty = true;
  bool _showViolent = true;
  bool _showDrug = true;
  bool _showPublicOrder = true;
  bool _showFinancial = true;
  bool _showTraffic = true;
  bool _showAlerts = true;

  // Mode toggle
  bool _isShowingCrimes = true;

  // Safe Spot Type filters
  bool _showPoliceStations = true;
  bool _showGovernmentBuildings = true;
  bool _showHospitals = true;
  bool _showSchools = true;
  bool _showShoppingMalls = true;
  bool _showWellLitAreas = true;
  bool _showSecurityCameras = true;
  bool _showFireStations = true;
  bool _showReligiousBuildings = true;
  bool _showCommunityCenters = true;

  // Safe Spot Status filters
  bool _showSafeSpotsPending = true;
  bool _showSafeSpotsApproved = true;
  bool _showSafeSpotsRejected = true;

  // Safe Spot Verification filters
  bool _showVerifiedSafeSpots = true;
  bool _showUnverifiedSafeSpots = true;

  // Separate Time Frame filters
  DateTime? _crimeStartDate;
  DateTime? _crimeEndDate;
  DateTime? _safeSpotStartDate;
  DateTime? _safeSpotEndDate;

  // Track current user to reset filters when user changes
  String? _currentUserId;

  // Existing getters
  bool get showCritical => _showCritical;
  bool get showHigh => _showHigh;
  bool get showMedium => _showMedium;
  bool get showLow => _showLow;
  bool get showPending => _showPending;
  bool get showRejected => _showRejected;
  bool get showActive => _showActive;
  bool get showInactive => _showInactive;
  bool get showProperty => _showProperty;
  bool get showViolent => _showViolent;
  bool get showDrug => _showDrug;
  bool get showPublicOrder => _showPublicOrder;
  bool get showFinancial => _showFinancial;
  bool get showTraffic => _showTraffic;
  bool get showAlerts => _showAlerts;

  // New getters for safe spots
  bool get isShowingCrimes => _isShowingCrimes;
  bool get showPoliceStations => _showPoliceStations;
  bool get showGovernmentBuildings => _showGovernmentBuildings;
  bool get showHospitals => _showHospitals;
  bool get showSchools => _showSchools;
  bool get showShoppingMalls => _showShoppingMalls;
  bool get showWellLitAreas => _showWellLitAreas;
  bool get showSecurityCameras => _showSecurityCameras;
  bool get showFireStations => _showFireStations;
  bool get showReligiousBuildings => _showReligiousBuildings;
  bool get showCommunityCenters => _showCommunityCenters;

  bool get showSafeSpotsPending => _showSafeSpotsPending;
  bool get showSafeSpotsApproved => _showSafeSpotsApproved;
  bool get showSafeSpotsRejected => _showSafeSpotsRejected;

  bool get showVerifiedSafeSpots => _showVerifiedSafeSpots;
  bool get showUnverifiedSafeSpots => _showUnverifiedSafeSpots;

  // Separate Time Frame getters
  DateTime? get crimeStartDate => _crimeStartDate;
  DateTime? get crimeEndDate => _crimeEndDate;
  DateTime? get safeSpotStartDate => _safeSpotStartDate;
  DateTime? get safeSpotEndDate => _safeSpotEndDate;

  // Backward compatibility getters (deprecated but kept for existing code)
  DateTime? get startDate =>
      _isShowingCrimes ? _crimeStartDate : _safeSpotStartDate;
  DateTime? get endDate => _isShowingCrimes ? _crimeEndDate : _safeSpotEndDate;

  // Method to reset filters when user changes or logs out
  void resetFiltersForUser(String? newUserId) {
    if (_currentUserId != newUserId) {
      _currentUserId = newUserId;

      // Reset all crime filters to default (true)
      _showCritical = true;
      _showHigh = true;
      _showMedium = true;
      _showLow = true;
      _showPending = true;
      _showRejected = true;
      _showActive = true;
      _showInactive = true;
      _showProperty = true;
      _showViolent = true;
      _showDrug = true;
      _showPublicOrder = true;
      _showFinancial = true;
      _showTraffic = true;
      _showAlerts = true;

      // Reset all safe spot filters to default
      _isShowingCrimes = true;
      _showPoliceStations = true;
      _showGovernmentBuildings = true;
      _showHospitals = true;
      _showSchools = true;
      _showShoppingMalls = true;
      _showWellLitAreas = true;
      _showSecurityCameras = true;
      _showFireStations = true;
      _showReligiousBuildings = true;
      _showCommunityCenters = true;

      _showSafeSpotsPending = true;
      _showSafeSpotsApproved = true;
      _showSafeSpotsRejected = true;

      _showVerifiedSafeSpots = true;
      _showUnverifiedSafeSpots = true;

      // Reset separate time frame filters
      _crimeStartDate = null;
      _crimeEndDate = null;
      _safeSpotStartDate = null;
      _safeSpotEndDate = null;

      notifyListeners();
    }
  }

  // Mode toggle method
  void setFilterMode(bool showCrimes) {
    _isShowingCrimes = showCrimes;
    notifyListeners();
  }

  // Crime Time Frame methods
  void setCrimeStartDate(DateTime? date) {
    _crimeStartDate = date;
    notifyListeners();
  }

  void setCrimeEndDate(DateTime? date) {
    _crimeEndDate = date;
    notifyListeners();
  }

  // Safe Spot Time Frame methods
  void setSafeSpotStartDate(DateTime? date) {
    _safeSpotStartDate = date;
    notifyListeners();
  }

  void setSafeSpotEndDate(DateTime? date) {
    _safeSpotEndDate = date;
    notifyListeners();
  }

  // Backward compatibility methods (deprecated but kept for existing code)
  void setStartDate(DateTime? date) {
    if (_isShowingCrimes) {
      setCrimeStartDate(date);
    } else {
      setSafeSpotStartDate(date);
    }
  }

  void setEndDate(DateTime? date) {
    if (_isShowingCrimes) {
      setCrimeEndDate(date);
    } else {
      setSafeSpotEndDate(date);
    }
  }

  // Existing severity toggle methods
  void toggleCritical() {
    _showCritical = !_showCritical;
    notifyListeners();
  }

  void toggleHigh() {
    _showHigh = !_showHigh;
    notifyListeners();
  }

  void toggleMedium() {
    _showMedium = !_showMedium;
    notifyListeners();
  }

  void toggleLow() {
    _showLow = !_showLow;
    notifyListeners();
  }

  // Existing status toggle methods
  void togglePending() {
    _showPending = !_showPending;
    notifyListeners();
  }

  void toggleRejected() {
    _showRejected = !_showRejected;
    notifyListeners();
  }

  void toggleActive() {
    _showActive = !_showActive;
    notifyListeners();
  }

  void toggleInactive() {
    _showInactive = !_showInactive;
    notifyListeners();
  }

  // Existing category toggle methods
  void toggleProperty() {
    _showProperty = !_showProperty;
    notifyListeners();
  }

  void toggleViolent() {
    _showViolent = !_showViolent;
    notifyListeners();
  }

  void toggleDrug() {
    _showDrug = !_showDrug;
    notifyListeners();
  }

  void togglePublicOrder() {
    _showPublicOrder = !_showPublicOrder;
    notifyListeners();
  }

  void toggleFinancial() {
    _showFinancial = !_showFinancial;
    notifyListeners();
  }

  void toggleTraffic() {
    _showTraffic = !_showTraffic;
    notifyListeners();
  }

  void toggleAlerts() {
    _showAlerts = !_showAlerts;
    notifyListeners();
  }

  // Safe Spot Type toggle methods
  void togglePoliceStations() {
    _showPoliceStations = !_showPoliceStations;
    notifyListeners();
  }

  void toggleGovernmentBuildings() {
    _showGovernmentBuildings = !_showGovernmentBuildings;
    notifyListeners();
  }

  void toggleHospitals() {
    _showHospitals = !_showHospitals;
    notifyListeners();
  }

  void toggleSchools() {
    _showSchools = !_showSchools;
    notifyListeners();
  }

  void toggleShoppingMalls() {
    _showShoppingMalls = !_showShoppingMalls;
    notifyListeners();
  }

  void toggleWellLitAreas() {
    _showWellLitAreas = !_showWellLitAreas;
    notifyListeners();
  }

  void toggleSecurityCameras() {
    _showSecurityCameras = !_showSecurityCameras;
    notifyListeners();
  }

  void toggleFireStations() {
    _showFireStations = !_showFireStations;
    notifyListeners();
  }

  void toggleReligiousBuildings() {
    _showReligiousBuildings = !_showReligiousBuildings;
    notifyListeners();
  }

  void toggleCommunityCenters() {
    _showCommunityCenters = !_showCommunityCenters;
    notifyListeners();
  }

  // Safe Spot Status toggle methods
  void toggleSafeSpotsPending() {
    _showSafeSpotsPending = !_showSafeSpotsPending;
    notifyListeners();
  }

  void toggleSafeSpotsApproved() {
    _showSafeSpotsApproved = !_showSafeSpotsApproved;
    notifyListeners();
  }

  void toggleSafeSpotsRejected() {
    _showSafeSpotsRejected = !_showSafeSpotsRejected;
    notifyListeners();
  }

  // Safe Spot Verification toggle methods
  void toggleVerifiedSafeSpots() {
    _showVerifiedSafeSpots = !_showVerifiedSafeSpots;
    notifyListeners();
  }

  void toggleUnverifiedSafeSpots() {
    _showUnverifiedSafeSpots = !_showUnverifiedSafeSpots;
    notifyListeners();
  }

  // Updated hotspot filtering logic
  bool shouldShowHotspot(Map<String, dynamic> hotspot) {
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';

    // Calculate 30-day cutoff (based on incident time, not report time)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final incidentTime = DateTime.tryParse(hotspot['time'] ?? '');
    final isRecent =
        incidentTime != null && incidentTime.isAfter(thirtyDaysAgo);

    // Time frame filtering - use crime dates
    if (_crimeStartDate != null || _crimeEndDate != null) {
      final hotspotDateStr =
          hotspot['time'] ?? hotspot['created_at'] ?? hotspot['date'];
      if (hotspotDateStr != null) {
        final hotspotDate = DateTime.tryParse(hotspotDateStr);
        if (hotspotDate != null) {
          if (_crimeStartDate != null &&
              hotspotDate.isBefore(_crimeStartDate!)) {
            return false;
          }
          if (_crimeEndDate != null && hotspotDate.isAfter(_crimeEndDate!)) {
            return false;
          }
        }
      }
    } else {
      // ✅ NEW: If no custom date range, apply 30-day filter for approved crimes
      if (status == 'approved' && !isRecent) {
        return false; // Don't show approved crimes older than 30 days
      }
    }

    final crimeType = hotspot['crime_type'];
    final level = crimeType['level'];
    final category = crimeType['category'];

    // Handle pending and rejected hotspots based solely on their status filters
    if (status == 'pending') {
      return _showPending;
    } else if (status == 'rejected') {
      return _showRejected;
    }

    // For approved hotspots, check active/inactive filters
    if (status == 'approved' || status == null) {
      // ✅ Both active and inactive approved hotspots are now visible to public
      // (as long as they're within 30 days or custom date range is set)

      if (activeStatus == 'active' && !_showActive) return false;
      if (activeStatus == 'inactive' && !_showInactive) return false;
    }

    // Check category filters for approved hotspots
    switch (category) {
      case 'Property':
        if (!_showProperty) return false;
        break;
      case 'Violent':
        if (!_showViolent) return false;
        break;
      case 'Drug':
        if (!_showDrug) return false;
        break;
      case 'Public Order':
        if (!_showPublicOrder) return false;
        break;
      case 'Financial':
        if (!_showFinancial) return false;
        break;
      case 'Traffic':
        if (!_showTraffic) return false;
        break;
      case 'Alert':
        if (!_showAlerts) return false;
        break;
    }

    // Apply level filters for approved hotspots
    switch (level) {
      case 'critical':
        return _showCritical;
      case 'high':
        return _showHigh;
      case 'medium':
        return _showMedium;
      case 'low':
        return _showLow;
      default:
        return true;
    }
  }

  // Updated safe spot filtering logic
  bool shouldShowSafeSpot(Map<String, dynamic> safeSpot) {
    // Time frame filtering - use safe spot dates
    if (_safeSpotStartDate != null || _safeSpotEndDate != null) {
      final safeSpotDateStr = safeSpot['created_at'] ?? safeSpot['date'];
      if (safeSpotDateStr != null) {
        final safeSpotDate = DateTime.tryParse(safeSpotDateStr);
        if (safeSpotDate != null) {
          if (_safeSpotStartDate != null &&
              safeSpotDate.isBefore(_safeSpotStartDate!)) {
            return false;
          }
          if (_safeSpotEndDate != null &&
              safeSpotDate.isAfter(_safeSpotEndDate!)) {
            return false;
          }
        }
      }
    }

    // Status filtering
    final status = safeSpot['status'] ?? 'pending';
    if (status == 'pending' && !_showSafeSpotsPending) return false;
    if (status == 'approved' && !_showSafeSpotsApproved) return false;
    if (status == 'rejected' && !_showSafeSpotsRejected) return false;

    // Verification filtering
    final verified = safeSpot['verified'] ?? false;
    if (verified && !_showVerifiedSafeSpots) return false;
    if (!verified && !_showUnverifiedSafeSpots) return false;

    // Type filtering
    final safeSpotType = safeSpot['safe_spot_types'];
    if (safeSpotType != null) {
      final typeName = safeSpotType['name']?.toString().toLowerCase() ?? '';

      if (typeName.contains('police') && !_showPoliceStations) return false;
      if (typeName.contains('government') && !_showGovernmentBuildings) {
        return false;
      }
      if (typeName.contains('hospital') && !_showHospitals) return false;
      if (typeName.contains('school') && !_showSchools) return false;
      if (typeName.contains('mall') && !_showShoppingMalls) return false;
      if (typeName.contains('lit') && !_showWellLitAreas) return false;
      if (typeName.contains('security') && !_showSecurityCameras) return false;
      if (typeName.contains('fire') && !_showFireStations) return false;
      if ((typeName.contains('church') || typeName.contains('religious')) &&
          !_showReligiousBuildings) {
        return false;
      }
      if (typeName.contains('community') && !_showCommunityCenters) {
        return false;
      }
    }

    return true;
  }

  // Reset all safe spot filters
  void resetSafeSpotFilters() {
    _showPoliceStations = true;
    _showGovernmentBuildings = true;
    _showHospitals = true;
    _showSchools = true;
    _showShoppingMalls = true;
    _showWellLitAreas = true;
    _showSecurityCameras = true;
    _showFireStations = true;
    _showReligiousBuildings = true;
    _showCommunityCenters = true;

    _showSafeSpotsPending = true;
    _showSafeSpotsApproved = true;
    _showSafeSpotsRejected = true;

    _showVerifiedSafeSpots = true;
    _showUnverifiedSafeSpots = true;

    // Reset safe spot time frame filters
    _safeSpotStartDate = null;
    _safeSpotEndDate = null;

    notifyListeners();
  }
}
