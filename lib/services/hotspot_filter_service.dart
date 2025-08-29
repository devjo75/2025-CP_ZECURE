import 'package:flutter/material.dart';

class HotspotFilterService with ChangeNotifier {
  // Severity filters
  bool _showCritical = true;
  bool _showHigh = true;
  bool _showMedium = true;
  bool _showLow = true;
  
  // Status filters
  bool _showPending = true;
  bool _showRejected = true;
  bool _showActive = true;    // New active filter
  bool _showInactive = true;  // New inactive filter
  
  // Category filters
  bool _showProperty = true;
  bool _showViolent = true;
  bool _showDrug = true;
  bool _showPublicOrder = true;
  bool _showFinancial = true;
  bool _showTraffic = true;
  bool _showAlerts = true;

  // Track current user to reset filters when user changes
  String? _currentUserId;

  // Getters
  bool get showCritical => _showCritical;
  bool get showHigh => _showHigh;
  bool get showMedium => _showMedium;
  bool get showLow => _showLow;
  bool get showPending => _showPending;
  bool get showRejected => _showRejected;
  bool get showActive => _showActive;      // New getter
  bool get showInactive => _showInactive;  // New getter
  bool get showProperty => _showProperty;
  bool get showViolent => _showViolent;
  bool get showDrug => _showDrug;
  bool get showPublicOrder => _showPublicOrder;
  bool get showFinancial => _showFinancial;
  bool get showTraffic => _showTraffic;
  bool get showAlerts => _showAlerts;

  // Method to reset filters when user changes or logs out
  void resetFiltersForUser(String? newUserId) {
    if (_currentUserId != newUserId) {
      _currentUserId = newUserId;
      
      // Reset all filters to default (true)
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
      
      notifyListeners();
    }
  }

  // Severity toggle methods
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

  // Status toggle methods
  void togglePending() {
    _showPending = !_showPending;
    notifyListeners();
  }

  void toggleRejected() {
    _showRejected = !_showRejected;
    notifyListeners();
  }

  // New active/inactive toggle methods
  void toggleActive() {
    _showActive = !_showActive;
    notifyListeners();
  }

  void toggleInactive() {
    _showInactive = !_showInactive;
    notifyListeners();
  }

  // Category toggle methods
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

  bool shouldShowHotspot(Map<String, dynamic> hotspot) {
    final status = hotspot['status'] ?? 'approved';
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
    // Only apply active/inactive filters for approved hotspots
    if (status == 'approved' || status == null) {
      final activeStatus = hotspot['active_status'] ?? 'active';
      final isActive = activeStatus == 'active';
      
      // If hotspot is active but we're not showing active ones, hide it
      if (isActive && !_showActive) return false;
      // If hotspot is inactive but we're not showing inactive ones, hide it
      if (!isActive && !_showInactive) return false;
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
}