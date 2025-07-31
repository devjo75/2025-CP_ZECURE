import 'package:flutter/material.dart';

class HotspotFilterService with ChangeNotifier {
  bool _showCritical = true;
  bool _showHigh = true;
  bool _showMedium = true;
  bool _showLow = true;
  bool _showPending = true;
  bool _showRejected = true;

  bool get showCritical => _showCritical;
  bool get showHigh => _showHigh;
  bool get showMedium => _showMedium;
  bool get showLow => _showLow;
  bool get showPending => _showPending;
  bool get showRejected => _showRejected;

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

  void togglePending() {
    _showPending = !_showPending;
    notifyListeners();
  }

  void toggleRejected() {
    _showRejected = !_showRejected;
    notifyListeners();
  }

  bool shouldShowHotspot(Map<String, dynamic> hotspot) {
    final status = hotspot['status'] ?? 'approved';
    final level = hotspot['crime_type']['level'];

    // Handle pending and rejected hotspots based solely on their status filters
    if (status == 'pending') {
      return _showPending;
    } else if (status == 'rejected') {
      return _showRejected;
    }
    // For approved hotspots, apply level filters
    else {
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
}


