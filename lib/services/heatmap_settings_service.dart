// ignore_for_file: avoid_print

import 'package:supabase_flutter/supabase_flutter.dart';

class HeatmapSettingsService {
  static final HeatmapSettingsService _instance =
      HeatmapSettingsService._internal();
  factory HeatmapSettingsService() => _instance;
  HeatmapSettingsService._internal();

  // Cache for settings
  Map<String, dynamic> _settingsCache = {};
  DateTime? _lastFetched;
  static const _cacheDuration = Duration(minutes: 5);

  // ⭐ ADD: Real-time subscription
  RealtimeChannel? _settingsChannel;
  final List<Function(Map<String, dynamic>)> _listeners = [];

  // ============================================
  // ⭐ NEW: Setup real-time subscription
  // ============================================
  void setupRealtimeSubscription() {
    if (_settingsChannel != null) {
      print('⚠️ Settings channel already exists, skipping setup');
      return;
    }

    try {
      _settingsChannel = Supabase.instance.client
          .channel('heatmap_settings_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'heatmap_settings',
            callback: (payload) {
              print(
                '📡 Heatmap setting updated: ${payload.newRecord['setting_key']}',
              );
              _handleSettingUpdate(payload.newRecord);
            },
          )
          .subscribe();

      print('✅ Heatmap settings real-time subscription active');
    } catch (e) {
      print('❌ Error setting up settings real-time: $e');
    }
  }

  // ============================================
  // ⭐ NEW: Handle setting update from real-time
  // ============================================
  void _handleSettingUpdate(Map<String, dynamic> updatedSetting) {
    final key = updatedSetting['setting_key'];
    final value = _parseValue(updatedSetting['setting_value']);

    // Update cache
    _settingsCache[key] = value;

    // Notify all listeners
    for (final listener in _listeners) {
      listener(_settingsCache);
    }

    print('✅ Updated cache for $key = $value');
    print('   Notified ${_listeners.length} listener(s)');
  }

  // ============================================
  // ⭐ NEW: Add listener for settings changes
  // ============================================
  void addListener(Function(Map<String, dynamic>) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      print('✅ Added settings listener (total: ${_listeners.length})');
    }
  }

  // ============================================
  // ⭐ NEW: Remove listener
  // ============================================
  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
    print('✅ Removed settings listener (remaining: ${_listeners.length})');
  }

  // ============================================
  // ⭐ NEW: Cleanup real-time subscription
  // ============================================
  void dispose() {
    if (_settingsChannel != null) {
      print('🔌 Unsubscribing from heatmap settings real-time...');
      _settingsChannel!.unsubscribe();
      _settingsChannel = null;
    }
    _listeners.clear();
  }

  // ============================================
  // FETCH ALL SETTINGS (existing method - no changes)
  // ============================================
  Future<Map<String, dynamic>> getAllSettings({
    bool forceRefresh = false,
  }) async {
    // Return cache if valid
    if (!forceRefresh &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < _cacheDuration &&
        _settingsCache.isNotEmpty) {
      return _settingsCache;
    }

    try {
      final response = await Supabase.instance.client
          .from('heatmap_settings')
          .select();

      _settingsCache = {};
      for (final setting in response as List) {
        _settingsCache[setting['setting_key']] = _parseValue(
          setting['setting_value'],
        );
      }

      _lastFetched = DateTime.now();
      print('✅ Loaded ${_settingsCache.length} heatmap settings');
      return _settingsCache;
    } catch (e) {
      print('Error fetching heatmap settings: $e');
      return _getDefaultSettings(); // Fallback to defaults
    }
  }

  // ============================================
  // GET SPECIFIC SETTING (existing method - no changes)
  // ============================================
  Future<T> getSetting<T>(String key, T defaultValue) async {
    try {
      if (_settingsCache.isEmpty) {
        await getAllSettings();
      }

      if (_settingsCache.containsKey(key)) {
        final value = _settingsCache[key];
        if (value is T) return value;
        // Try to convert
        if (T == double && value is int) return value.toDouble() as T;
        if (T == int && value is double) return value.toInt() as T;
      }

      return defaultValue;
    } catch (e) {
      print('Error getting setting $key: $e');
      return defaultValue;
    }
  }

  // ============================================
  // UPDATE SETTING (existing method - no changes)
  // ============================================
  Future<bool> updateSetting(String key, dynamic value, String? userId) async {
    try {
      await Supabase.instance.client
          .from('heatmap_settings')
          .update({'setting_value': value.toString(), 'updated_by': userId})
          .eq('setting_key', key);

      // Update cache
      _settingsCache[key] = value;
      print('✅ Updated setting: $key = $value');
      return true;
    } catch (e) {
      print('Error updating setting $key: $e');
      return false;
    }
  }

  // ============================================
  // PARSE VALUE FROM DATABASE (existing method - no changes)
  // ============================================
  dynamic _parseValue(dynamic value) {
    if (value is String) {
      // Try to parse as number
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        // Return int if it's a whole number
        if (doubleValue == doubleValue.toInt()) {
          return doubleValue.toInt();
        }
        return doubleValue;
      }
      return value;
    }
    return value;
  }

  // ============================================
  // DEFAULT SETTINGS (existing method - no changes)
  // ============================================
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'cluster_merge_distance': 50.0,
      'min_crimes_for_cluster': 3,
      'proximity_alert_distance': 500.0,
      'time_window_critical': 120,
      'time_window_high': 90,
      'time_window_medium': 60,
      'time_window_low': 30,
      'weight_critical': 1.0,
      'weight_high': 0.75,
      'weight_medium': 0.5,
      'weight_low': 0.25,
      'radius_critical_base': 200.0,
      'radius_critical_min': 250.0,
      'radius_critical_max': 1200.0,
      'radius_critical_count_multiplier': 15.0,
      'radius_critical_intensity_multiplier': 50.0,
      'radius_high_base': 150.0,
      'radius_high_min': 200.0,
      'radius_high_max': 900.0,
      'radius_high_count_multiplier': 10.0,
      'radius_high_intensity_multiplier': 30.0,
      'radius_medium_base': 100.0,
      'radius_medium_min': 150.0,
      'radius_medium_max': 600.0,
      'radius_medium_count_multiplier': 8.0,
      'radius_medium_intensity_multiplier': 25.0,
      'radius_low_base': 80.0,
      'radius_low_min': 100.0,
      'radius_low_max': 400.0,
      'radius_low_count_multiplier': 5.0,
      'radius_low_intensity_multiplier': 20.0,
    };
  }

  // ============================================
  // CLEAR CACHE (existing method - no changes)
  // ============================================
  void clearCache() {
    _settingsCache.clear();
    _lastFetched = null;
  }
}
