// ignore_for_file: prefer_final_fields, constant_identifier_names, avoid_print, unrelated_type_equality_checks, prefer_is_not_operator, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/chatbox/chat_channels_screen.dart';
import 'package:zecure/chatbox/chat_service.dart';
import 'package:zecure/chatbox/chat_desktop_screen.dart';
import 'package:zecure/desktop/desktop_mini_legends.dart';
import 'package:zecure/desktop/hotlines_desktop.dart';
import 'package:zecure/desktop/quick_access_desktop.dart';
import 'package:zecure/main.dart';
import 'package:zecure/savepoint/add_save_point.dart';
import 'package:zecure/auth/register_screen.dart';
import 'package:zecure/quick_access/quick_access_screen.dart';
import 'package:zecure/savepoint/save_point.dart';
import 'package:zecure/savepoint/save_point_details.dart';
import 'package:zecure/screens/welcome_message_first_timer.dart';
import 'package:zecure/screens/welcome_message_screen.dart';
import 'package:zecure/screens/hotlines_screen.dart';
import 'package:zecure/screens/profile_screen.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/desktop/report_hotspot_form_desktop.dart';
import 'package:zecure/desktop/hotspot_filter_dialog_desktop.dart';
import 'package:zecure/desktop/location_options_dialog_desktop.dart';
import 'package:zecure/desktop/desktop_sidebar.dart';
import 'package:zecure/desktop/save_point_desktop.dart';
import 'package:zecure/services/firebase_service.dart';
import 'package:zecure/services/heatmap_settings_service.dart';
import 'package:zecure/services/photo_upload_service.dart';
import 'package:zecure/services/pulsing_hotspot_marker.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:zecure/safespot/safe_spot_details.dart';
import 'package:zecure/safespot/safe_spot_form.dart';
import 'package:zecure/safespot/safe_spot_service.dart';
import 'package:zecure/savepoint/save_point_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MainTab { map, chat, quickAccess, notifications, profile, savePoints }

enum TravelMode { walking, driving, cycling }

enum MapType { defaultMap, standard, satellite, cycleMap }

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final _authService = AuthService(Supabase.instance.client);

  // 2. Change the default map type to defaultMap
  MapType _currentMapType = MapType.defaultMap;

  // 3. Update mapConfigurations with defaultMap first
  Map<MapType, Map<String, dynamic>> get mapConfigurations => {
    MapType.defaultMap: {
      'name': 'Default',
      'urlTemplate': 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      'fallbackUrl': 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      'attribution':
          '© OpenStreetMap contributors, Humanitarian OpenStreetMap Team',
    },

    MapType.standard: {
      'name': 'Standard',
      'urlTemplate': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'fallbackUrl': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors',
    },

    MapType.satellite: {
      'name': 'Satellite',
      'urlTemplate':
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'fallbackUrl':
          'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'attribution': '© Esri, Maxar, Earthstar Geographics',
    },

    MapType.cycleMap: {
      'name': 'Cycle Map',
      'urlTemplate':
          'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      'fallbackUrl':
          'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors, CyclOSM',
    },
  };

  Map<String, dynamic> getRoutingStatistics() {
    return {
      'total_failed_attempts': _failedRoutingAttempts.length,
      'recent_attempts': _failedRoutingAttempts.take(5).toList(),
      'current_retry_count': _routingRetryCount,
      'max_retries': MAX_RETRY_ATTEMPTS,
    };
  }

  //CHATBOX
  int _unreadChatCount = 0;
  RealtimeChannel? _chatUpdatesSubscription;

  //TRAVEL MODE
  TravelMode _selectedTravelMode = TravelMode.driving;
  bool _showTravelModeSelector = false;
  bool _showMapTypeSelector = false;

  //MAP ZOOM FOR LABEL
  double _currentZoom = 15.5;

  //MAP ROTATION
  double _currentMapRotation = 0.0;
  bool _isRotationLocked = false;
  bool _showRotationFeedback = false;

  // Side bar for Desktop
  bool _isSidebarVisible = false;

  // Photo upload state

  // Location state
  LatLng? _currentPosition;
  LatLng? _destination;
  bool _isLoading = true;
  final List<LatLng> _polylinePoints = [];
  bool _locationButtonPressed = false;
  LatLng? _tempPinnedLocation;

  // ADD: ROUTE TRACKING
  List<LatLng> _routePoints = []; // Only for directions/safe routes
  bool _hasActiveRoute = false;
  Timer? _routeUpdateTimer;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // Only update if moved 5+ meters
    // timeLimit: Duration(seconds: 30), // REMOVE THIS LINE
  );

  // NEARBY ALERT
  List<Map<String, dynamic>> _nearbyHotspots = [];
  bool _showProximityAlert = false;
  Timer? _proximityCheckTimer;

  // NEW: Heatmap proximity alerts
  List<HeatmapCluster> _nearbyHeatmapClusters = [];
  bool _showHeatmapProximityAlert = false;
  String _proximityAlertType =
      'none'; // 'hotspot', 'heatmap', 'both', or 'none'

  // Directions state
  double _distance = 0;
  String _duration = '';

  // Live tracking state
  StreamSubscription<Position>? _positionStream;
  bool _hotspotsChannelConnected = false;
  bool _notificationsChannelConnected = false;
  Timer? _reconnectionTimer;

  // User state
  Map<String, dynamic>? _userProfile;
  bool _isAdmin = false;
  bool _isOfficer = false;

  // Helper getter for admin or officer permissions (for general access)
  bool get _hasAdminPermissions => _isAdmin || _isOfficer;

  // NEW: Specific getter for admin-only actions
  MainTab _currentTab = MainTab.map;
  late ProfileScreen _profileScreen;

  //HOTSPOT MARKER LIMIT ON THE MAP
  bool _markersLoaded = false;
  int _maxMarkersToShow = 77; // Progressive loading
  Timer? _deferredLoadTimer;

  // HOTSPOT
  List<Map<String, dynamic>> _hotspots = [];
  Map<String, dynamic>? _selectedHotspot;
  RealtimeChannel? _hotspotsChannel;

  final Set<int> _processedHotspotIds = {};

  //HEATMAP
  List<HeatmapCluster> _heatmapClusters = [];
  List<Map<String, dynamic>> _heatmapCrimes = [];
  bool _showHeatmap = true; // Toggle for users
  bool _isCalculatingHeatmap = false;
  Timer? _heatmapUpdateTimer;

  // HEATMAP SETTINGS SERVICE
  final HeatmapSettingsService _heatmapSettings = HeatmapSettingsService();
  Timer? _settingsUpdateDebouncer;

  // Dynamic settings (loaded from database)
  double _clusterMergeDistance = 500.0;
  int _minCrimesForCluster = 3;
  double _proximityAlertDistance = 500.0;

  Map<String, int> _severityTimeWindows = {
    'critical': 120,
    'high': 90,
    'medium': 60,
    'low': 30,
  };

  Map<String, double> _severityWeights = {
    'critical': 1.0,
    'high': 0.75,
    'medium': 0.5,
    'low': 0.25,
  };

  Map<String, Map<String, double>> _severityRadiusConfig = {
    'critical': {
      'base': 400.0,
      'min': 500.0,
      'max': 2500.0,
      'countMultiplier': 30.0,
      'intensityMultiplier': 80.0,
    },
    'high': {
      'base': 300.0,
      'min': 400.0,
      'max': 1800.0,
      'countMultiplier': 25.0,
      'intensityMultiplier': 60.0,
    },
    'medium': {
      'base': 250.0,
      'min': 300.0,
      'max': 1200.0,
      'countMultiplier': 20.0,
      'intensityMultiplier': 50.0,
    },
    'low': {
      'base': 200.0,
      'min': 250.0,
      'max': 800.0,
      'countMultiplier': 15.0,
      'intensityMultiplier': 40.0,
    },
  };

  // PERSISTENT HEATMAP CLUSTERS
  List<Map<String, dynamic>> _persistentClusters = [];
  RealtimeChannel? _clustersChannel;
  Timer? _clusterUpdateDebouncer;
  bool _hasPendingClusterUpdate = false;

  // NOTIFICATIONS
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _notificationsChannel;
  int _unreadNotificationCount = 0;
  String _notificationFilter = 'All';

  // SAFE SPOT
  Map<String, dynamic>? _selectedSafeSpot; // Add this to your state variables
  List<Map<String, dynamic>> _safeSpots = [];
  RealtimeChannel? _safeSpotsChannel;
  bool _showSafeSpots = true;

  Set<String> _processedUpdateIds = {}; // Track processed updates
  Timer? _updateDebounceTimer;
  Map<String, Timer> _updateTimers = {}; // Per-ID debounce timers

  //SAFE ROUTES RETRY
  List<Map<String, dynamic>> _failedRoutingAttempts = [];
  bool _isShowingRouteModal = false;
  List<LatLng>? _lastRegularRoute;
  int _routingRetryCount = 0;
  static const int MAX_RETRY_ATTEMPTS = 3;

  // SAVE POINTS
  Map<String, dynamic>? _selectedSavePoint;
  List<Map<String, dynamic>> _savePoints = [];
  final SavePointService _savePointService = SavePointService();
  bool _showSavePointSelector = false; // New state for savepoint button

  Timer? _timeUpdateTimer;

  // NEW: Progressive marker loading based on zoom level
  List<Map<String, dynamic>> get _visibleHotspots {
    if (!_markersLoaded) return [];

    final currentUserId = _userProfile?['id'];
    final filterService = Provider.of<HotspotFilterService>(
      context,
      listen: false,
    );

    // Check if user has set a custom date range
    final hasCustomDateRange =
        filterService.crimeStartDate != null ||
        filterService.crimeEndDate != null;

    // Calculate 30-day cutoff date (for incident time, not report time)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    if (_currentZoom < 8.0) {
      return _hotspots
          .where((h) {
            final status = h['status'] ?? 'approved';
            final activeStatus = h['active_status'] ?? 'active';

            // Show only approved and active hotspots
            if (status != 'approved' || activeStatus != 'active') return false;

            // Filter by 30-day rule unless custom date range is set
            if (!hasCustomDateRange) {
              final incidentTime = DateTime.tryParse(h['time'] ?? '');
              if (incidentTime == null ||
                  incidentTime.isBefore(thirtyDaysAgo)) {
                return false;
              }
            }

            return true;
          })
          .take(100)
          .toList();
    } else if (_currentZoom < 10.0) {
      return _hotspots
          .where((h) {
            final status = h['status'] ?? 'approved';
            final activeStatus = h['active_status'] ?? 'active';
            final createdBy = h['created_by'];
            final reportedBy = h['reported_by'];
            final isOwnHotspot =
                currentUserId != null &&
                (currentUserId == createdBy || currentUserId == reportedBy);

            // For pending: only show to admin/officer or owner
            if (status == 'pending') {
              return _hasAdminPermissions || isOwnHotspot;
            }

            // Show approved active hotspots
            if (status == 'approved' && activeStatus == 'active') {
              // Filter by 30-day rule unless custom date range is set
              if (!hasCustomDateRange) {
                final incidentTime = DateTime.tryParse(h['time'] ?? '');
                if (incidentTime == null ||
                    incidentTime.isBefore(thirtyDaysAgo)) {
                  return false;
                }
              }
              return true;
            }

            return false;
          })
          .take(50)
          .toList();
    } else if (_currentZoom < 13.0) {
      return _hotspots
          .where((h) {
            final status = h['status'] ?? 'approved';
            final activeStatus = h['active_status'] ?? 'active';
            final createdBy = h['created_by'];
            final reportedBy = h['reported_by'];
            final isOwnHotspot =
                currentUserId != null &&
                (currentUserId == createdBy || currentUserId == reportedBy);
            final incidentTime = DateTime.tryParse(h['time'] ?? '');
            final isRecent =
                incidentTime != null && incidentTime.isAfter(thirtyDaysAgo);

            // Admin sees everything
            if (_hasAdminPermissions) return true;

            // For pending: only show to owner
            if (status == 'pending') {
              return isOwnHotspot;
            }

            // For rejected: only show to owner
            if (status == 'rejected') {
              return isOwnHotspot;
            }

            // For approved active: show to everyone if recent (or custom date range)
            if (status == 'approved' && activeStatus == 'active') {
              return hasCustomDateRange || isRecent;
            }

            // For approved inactive: show to everyone IF within 30 days (or custom date range)
            if (status == 'approved' && activeStatus == 'inactive') {
              return hasCustomDateRange || isRecent;
            }

            return false;
          })
          .take(_maxMarkersToShow)
          .toList();
    } else if (_currentZoom < 15.5) {
      return _hotspots
          .where((h) {
            final status = h['status'] ?? 'approved';
            final activeStatus = h['active_status'] ?? 'active';
            final createdBy = h['created_by'];
            final reportedBy = h['reported_by'];
            final isOwnHotspot =
                currentUserId != null &&
                (currentUserId == createdBy || currentUserId == reportedBy);
            final incidentTime = DateTime.tryParse(h['time'] ?? '');
            final isRecent =
                incidentTime != null && incidentTime.isAfter(thirtyDaysAgo);

            // Admin sees everything
            if (_hasAdminPermissions) return true;

            // For pending: only show to owner
            if (status == 'pending') {
              return isOwnHotspot;
            }

            // For rejected: only show to owner
            if (status == 'rejected') {
              return isOwnHotspot;
            }

            // For approved active: show to everyone if recent (or custom date range)
            if (status == 'approved' && activeStatus == 'active') {
              return hasCustomDateRange || isRecent;
            }

            // For approved inactive: show to everyone IF within 30 days (or custom date range)
            if (status == 'approved' && activeStatus == 'inactive') {
              return hasCustomDateRange || isRecent;
            }

            return false;
          })
          .take(_maxMarkersToShow)
          .toList();
    } else {
      // ✅ Zoom 16+: Show ALL including rejected, inactive, and OLD crimes
      return _hotspots.where((h) {
        final status = h['status'] ?? 'approved';
        final activeStatus = h['active_status'] ?? 'active';
        final createdBy = h['created_by'];
        final reportedBy = h['reported_by'];
        final isOwnHotspot =
            currentUserId != null &&
            (currentUserId == createdBy || currentUserId == reportedBy);
        final createdAt = DateTime.tryParse(h['created_at'] ?? '');
        final isRecent = createdAt != null && createdAt.isAfter(thirtyDaysAgo);

        // ✅ CRITICAL: If date filter is active, include ALL approved crimes (active or inactive)
        if (hasCustomDateRange && status == 'approved') {
          return true;
        }

        // Admin sees everything
        if (_hasAdminPermissions) {
          return true;
        }

        // For pending: only show to owner
        if (status == 'pending') {
          return isOwnHotspot;
        }

        // For rejected: only show to owner
        if (status == 'rejected') {
          return isOwnHotspot;
        }

        // For approved active: show to everyone if recent (or custom date range)
        if (status == 'approved' && activeStatus == 'active') {
          return hasCustomDateRange || isRecent;
        }

        // For approved inactive: show to everyone IF within 30 days (or custom date range)
        if (status == 'approved' && activeStatus == 'inactive') {
          return hasCustomDateRange || isRecent;
        }

        return false;
      }).toList(); // ✅ REMOVED .take() - No limit on markers
    }
  }

  // NEW: Progressive safe spots loading
  List<Map<String, dynamic>> get _visibleSafeSpots {
    if (!_markersLoaded || !_showSafeSpots) return [];

    final markerLimit = _getMarkerLimit();

    if (_currentZoom < 8.0) {
      return _safeSpots.where((s) => s['verified'] == true).take(50).toList();
    } else if (_currentZoom < 12.0) {
      return _safeSpots
          .where((s) => s['verified'] == true)
          .take(markerLimit ~/ 3)
          .toList();
    } else if (_currentZoom < 16.0) {
      // Below zoom 16: Only show approved and pending (NO rejected)
      return _safeSpots
          .where((safeSpot) {
            final status = safeSpot['status'] ?? 'pending';
            final currentUserId = _userProfile?['id'];

            if (status == 'approved') return true;
            if (status == 'pending' && currentUserId != null) return true;
            if (_hasAdminPermissions) return true;
            return false;
          })
          .take(markerLimit)
          .toList();
    } else {
      // Zoom 16+: Show ALL including rejected
      return _safeSpots
          .where((safeSpot) {
            final status = safeSpot['status'] ?? 'pending';
            final currentUserId = _userProfile?['id'];
            final createdBy = safeSpot['created_by'];
            final isOwnSpot =
                currentUserId != null && currentUserId == createdBy;

            if (status == 'approved') return true;
            if (status == 'pending' && currentUserId != null) return true;
            if (isOwnSpot && status == 'rejected') return true;
            if (_hasAdminPermissions) return true;
            return false;
          })
          .take(markerLimit)
          .toList();
    }
  }

  int _getMarkerLimit() {
    if (_currentZoom < 8.0) return 100;
    if (_currentZoom < 10.0) return 150;
    if (_currentZoom < 12.0) return 250;
    if (_currentZoom < 14.0) return 400;
    if (_currentZoom < 16.0) return 600;
    return 1000; // Max markers at closest zoom
  }

  Timer? _zoomDebounceTimer;

  void _onMapZoomChanged(double newZoom) {
    // Cancel any existing timer
    _zoomDebounceTimer?.cancel();

    // Set a new timer to update zoom after 100ms of no changes
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _currentZoom != newZoom) {
        setState(() {
          _currentZoom = newZoom;
        });
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    switch (_notificationFilter) {
      case 'Unread':
        return _notifications.where((n) => !n['is_read']).toList();
      case 'Critical':
        return _notifications.where((notification) {
          if (notification['type'] == 'report' &&
              notification['hotspot_id'] != null) {
            final relatedHotspot = _hotspots.firstWhere(
              (hotspot) => hotspot['id'] == notification['hotspot_id'],
              orElse: () => {},
            );
            return relatedHotspot.isNotEmpty &&
                relatedHotspot['crime_type']?['level'] == 'critical';
          }
          return false;
        }).toList();
      case 'High':
        return _notifications.where((notification) {
          if (notification['type'] == 'report' &&
              notification['hotspot_id'] != null) {
            final relatedHotspot = _hotspots.firstWhere(
              (hotspot) => hotspot['id'] == notification['hotspot_id'],
              orElse: () => {},
            );
            return relatedHotspot.isNotEmpty &&
                relatedHotspot['crime_type']?['level'] == 'high';
          }
          return false;
        }).toList();
      case 'Medium':
        return _notifications.where((notification) {
          if (notification['type'] == 'report' &&
              notification['hotspot_id'] != null) {
            final relatedHotspot = _hotspots.firstWhere(
              (hotspot) => hotspot['id'] == notification['hotspot_id'],
              orElse: () => {},
            );
            return relatedHotspot.isNotEmpty &&
                relatedHotspot['crime_type']?['level'] == 'medium';
          }
          return false;
        }).toList();
      case 'Low':
        return _notifications.where((notification) {
          if (notification['type'] == 'report' &&
              notification['hotspot_id'] != null) {
            final relatedHotspot = _hotspots.firstWhere(
              (hotspot) => hotspot['id'] == notification['hotspot_id'],
              orElse: () => {},
            );
            return relatedHotspot.isNotEmpty &&
                relatedHotspot['crime_type']?['level'] == 'low';
          }
          return false;
        }).toList();
      // NEW: Add safe spot filter
      case 'Safe Spots':
        return _notifications.where((notification) {
          return [
            'safe_spot_report',
            'safe_spot_approval',
            'safe_spot_rejection',
          ].contains(notification['type']);
        }).toList();
      default:
        return _notifications;
    }
  }

  @override
  void initState() {
    super.initState();

    // Only critical startup operations
    _initializeEssentials();

    // Defer heavy operations to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredInitialization();
    });

    // ✅ Setup filter listeners (including date filter for heatmap)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final filterService = Provider.of<HotspotFilterService>(
          context,
          listen: false,
        );

        // General filter listener (existing)
        filterService.addListener(_onFilterChanged);

        // ✅ NEW: Date filter listener specifically for heatmap
        filterService.addListener(_onDateFilterChanged);
      }
    });
  }

  // EXISTING: Handle general filter changes
  void _onFilterChanged() {
    if (!mounted) return;

    print('🔄 Filter changed - reloading heatmap data...');

    _loadHeatmapData().then((_) {
      if (mounted) {
        _calculateHeatmap();
      }
    });
  }

  // ✅ NEW: Handle date filter changes specifically
  void _onDateFilterChanged() async {
    final filterService = Provider.of<HotspotFilterService>(
      context,
      listen: false,
    );

    final hasCustomDateRange =
        filterService.crimeStartDate != null ||
        filterService.crimeEndDate != null;

    print('📅 Date filter changed. Custom range: $hasCustomDateRange');

    // Reload everything when date filter changes
    await _loadHeatmapData();
    await _loadPersistentClusters();
    await _calculateHeatmap();
  }

  bool _authListenerSetup = false; // Prevent duplicate listeners
  bool _isLoadingProfile = false; // Prevent duplicate profile loads

  void _initializeEssentials() {
    // Only setup auth listener once
    if (!_authListenerSetup) {
      _authListenerSetup = true;

      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.session != null && mounted && !_isLoadingProfile) {
          print('User logged in, loading profile and setting up real-time');
          _isLoadingProfile = true;

          _loadUserProfile()
              .then((_) {
                _isLoadingProfile = false;
                if (mounted) {
                  final filterService = Provider.of<HotspotFilterService>(
                    context,
                    listen: false,
                  );
                  filterService.resetFiltersForUser(
                    _userProfile?['id']?.toString(),
                  );

                  // ✅ Setup Firebase notifications after profile is loaded
                  _initializeFirebaseForUser();

                  // ✅ Load unread chat count and setup realtime subscription
                  _loadUnreadChatCount();
                  _setupChatRealtimeSubscription();

                  // Only setup notifications if not already done
                  if (_notificationsChannel == null) {
                    _deferredLoadTimer = Timer(
                      Duration(milliseconds: 1000),
                      () {
                        if (mounted) {
                          _setupNotificationsRealtime();
                          _loadNotifications();
                        }
                      },
                    );
                  }
                }
              })
              .catchError((e) {
                _isLoadingProfile = false;
                print('Error loading profile: $e');
              });
        } else if (event.session == null && mounted) {
          print('User logged out, cleaning up');
          _isLoadingProfile = false;

          // ✅ Clear Firebase token on logout
          _clearFirebaseToken();

          setState(() {
            _userProfile = null;
            _isAdmin = false;
            _isOfficer = false;
            _hotspots = [];
            _notifications = [];
            _unreadNotificationCount = 0;
            _unreadChatCount = 0; // ✅ Reset chat count on logout
          });

          final filterService = Provider.of<HotspotFilterService>(
            context,
            listen: false,
          );
          filterService.resetFiltersForUser(null);

          _cleanupChannels();
          _chatUpdatesSubscription
              ?.unsubscribe(); // ✅ Cleanup chat subscription
        }
      });
    }

    // Start location immediately (but don't block)
    _getCurrentLocationAsync();
  }

  // ✅ NEW: Initialize Firebase for logged-in user
  Future<void> _initializeFirebaseForUser() async {
    try {
      // Subscribe to general crime alerts topic
      await FirebaseService().subscribeToTopic('crime_alerts');
      print('✅ Subscribed to crime_alerts topic');

      // Subscribe to role-specific topics
      if (_isAdmin || _isOfficer) {
        await FirebaseService().subscribeToTopic('admin_alerts');
        print('✅ Subscribed to admin_alerts topic');
      }

      // Save FCM token to database
      final token = FirebaseService().fcmToken;
      if (token != null && _userProfile != null) {
        await Supabase.instance.client
            .from('users')
            .update({
              'fcm_token': token,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _userProfile!['id']);

        print('✅ FCM token saved for user: ${_userProfile!['email']}');
      }
    } catch (e) {
      print('❌ Error initializing Firebase for user: $e');
    }
  }

  // ✅ NEW: Clear Firebase token on logout
  Future<void> _clearFirebaseToken() async {
    try {
      // Unsubscribe from all topics
      await FirebaseService().unsubscribeFromTopic('crime_alerts');
      await FirebaseService().unsubscribeFromTopic('admin_alerts');

      // Clear FCM token
      await FirebaseService().clearToken();

      print('✅ Firebase cleaned up on logout');
    } catch (e) {
      print('❌ Error clearing Firebase token: $e');
    }
  }

  // Helper method to clean up channels safely
  void _cleanupChannels() {
    _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    _hotspotsChannel?.unsubscribe();
    _hotspotsChannel = null;
    _safeSpotsChannel?.unsubscribe();
    _safeSpotsChannel = null;

    if (_clustersChannel != null) {
      _clustersChannel!.unsubscribe();
      _clustersChannel = null;
    }

    // ⭐ ADD: Remove heatmap settings listener
    try {
      _heatmapSettings.removeListener(_onHeatmapSettingsChanged);
    } catch (e) {
      print('Error removing heatmap settings listener: $e');
    }

    // Remove filter listener
    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );
      filterService.removeListener(_onFilterChanged);
    } catch (e) {
      print('Error removing filter listener: $e');
    }
  }

  // NEW: Async location loading that doesn't block startup
  void _getCurrentLocationAsync() async {
    try {
      await _getCurrentLocation();
      if (mounted) {
        // Don't change _isInitialLoading anymore - map renders immediately

        // Wait for the map to be rendered before any MapController operations
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPosition != null) {
            // Safe to use MapController now
            try {
              _mapController.move(_currentPosition!, 15.5);
            } catch (e) {
              // MapController might not be ready yet, that's okay
              print('MapController not ready yet, will retry: $e');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error getting location: ${e.toString()}');
      }
    }
  }

  bool _deferredInitialized = false; // Prevent multiple deferred loads
  // OPTIMIZED: Deferred initialization with staggered loading - PREVENT DUPLICATES
  void _deferredInitialization() async {
    if (!mounted || _deferredInitialized) return;
    _deferredInitialized = true;

    print('Starting deferred initialization...');

    // Show welcome modal IMMEDIATELY after basic setup - don't wait for everything
    Timer(Duration(milliseconds: 500), () {
      // Much shorter delay
      if (mounted) {
        _showWelcomeModal();
      }
    });

    // Load user profile first (lightweight) - only if not already loaded
    if (_userProfile == null && !_isLoadingProfile) {
      await _loadUserProfile();
      if (!mounted) return;

      // Reset filters
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );
      filterService.resetFiltersForUser(_userProfile?['id']?.toString());
    }

    // Stagger heavy operations to prevent frame drops
    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    // Load hotspots first (most important) - only if not already loaded
    if (_hotspots.isEmpty) {
      print('Loading hotspots...');
      await _loadHotspots();
      if (!mounted) return;
    }

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    // Setup realtime for hotspots - only if not already setup
    if (_hotspotsChannel == null) {
      print('Setting up hotspots realtime...');
      _setupRealtimeSubscription();
    }

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    // Load safe spots - only if not already loaded
    if (_safeSpots.isEmpty) {
      print('Loading safe spots...');
      await _loadSafeSpots();
      if (!mounted) return;
    }

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    // Setup safe spots realtime - only if not already setup
    if (_safeSpotsChannel == null) {
      print('Setting up safe spots realtime...');
      _setupSafeSpotsRealtime();
    }

    if (_userProfile != null) {
      await Future.delayed(Duration(milliseconds: 200));
      if (!mounted) return;

      print('Loading chat unread count...');
      _loadUnreadChatCount();
    }

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    // Load save points - only if not already loaded
    if (_savePoints.isEmpty) {
      print('Loading save points...');
      await _loadSavePoints();
      if (!mounted) return;
    }

    // Mark markers as loaded
    setState(() {
      _markersLoaded = true;
    });

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;

    print('Loading heatmap settings...');
    await _loadHeatmapSettings();
    if (!mounted) return;

    print('Setting up heatmap settings real-time...');
    _heatmapSettings.setupRealtimeSubscription();
    _heatmapSettings.addListener(_onHeatmapSettingsChanged);

    // HEATMAP INITIALIZATION
    await Future.delayed(Duration(milliseconds: 300));
    if (!mounted) return;

    // Load heatmap data (all approved crimes)
    print('Loading heatmap data...');
    await _loadHeatmapData();
    if (!mounted) return;

    // Load persistent clusters from database
    print('Loading persistent clusters...');
    await _loadPersistentClusters();
    if (!mounted) return;

    // Setup real-time for clusters
    print('Setting up clusters real-time...');
    _setupClustersRealtime();

    // Calculate initial heatmap (processes crimes against clusters)
    print('Initializing crime heatmap...');
    await _calculateHeatmap();
    if (!mounted) return;

    print('✅ Heatmap ready: ${_heatmapClusters.length} hotspots identified');

    // Setup periodic tasks with initial delays (REDUCED FREQUENCY)
    _setupPeriodicTasksOptimized();
    _startPeriodicClusterMaintenance();

    // DELAY location services startup to prevent early proximity checking
    _deferredLoadTimer = Timer(Duration(milliseconds: 2000), () {
      if (mounted) {
        print('Starting location services...');
        _startLiveLocationDeferred();
      }
    });

    // Add this at the end of _deferredInitialization()
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {}); // Updates time indicators
      }
    });

    print('Deferred initialization completed.');
  }

  // NEW: Setup periodic tasks with optimized intervals - MUCH LESS AGGRESSIVE
  void _setupPeriodicTasksOptimized() {
    // Cleanup orphaned notifications (much less frequent initially)
    Timer(Duration(minutes: 10), () {
      // Increased from 5 minutes
      if (mounted) {
        Timer.periodic(
          const Duration(hours: 2),
          (_) => _cleanupOrphanedNotifications(),
        ); // Increased from 1 hour
      }
    });

    // Connection check (much less frequent initially)
    Timer(Duration(minutes: 5), () {
      // Increased from 1 minute
      if (mounted) {
        Timer.periodic(
          const Duration(minutes: 5),
          (_) => _checkRealtimeConnection(),
        ); // Increased from 2 minutes
      }
    });

    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _cleanupExpiredHeatmapCrimes();
      }
    });
  }

  void _startLiveLocationDeferred() {
    // Start with longer intervals, then optimize based on usage
    Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _startLiveLocation();
      }
    });
  }

  // OPTIMIZED: Enhanced dispose with timer cleanup
  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _profileScreen.disposeControllers();
    _hotspotsChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    _reconnectionTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _proximityCheckTimer?.cancel();
    _deferredLoadTimer?.cancel();
    _chatUpdatesSubscription?.unsubscribe();

    if (_safeSpotsChannel != null) {
      print('Unsubscribing from safe spots real-time channel...');
      _safeSpotsChannel!.unsubscribe();
      _safeSpotsChannel = null;
    }

    for (final timer in _updateTimers.values) {
      timer.cancel();
    }

    if (_clustersChannel != null) {
      print('Unsubscribing from clusters real-time channel...');
      _clustersChannel!.unsubscribe();
      _clustersChannel = null;
    }
    _persistentClusters.clear();
    _clusterUpdateDebouncer?.cancel();

    _updateTimers.clear();
    _updateDebounceTimer?.cancel();
    _processedUpdateIds.clear();
    _savePoints.clear();
    _heatmapUpdateTimer?.cancel();
    _timeUpdateTimer?.cancel();
    _settingsUpdateDebouncer?.cancel();

    // ⭐ EXISTING: Remove heatmap settings listener
    try {
      _heatmapSettings.removeListener(_onHeatmapSettingsChanged);
      print('Removed heatmap settings listener');
    } catch (e) {
      print('Error removing heatmap settings listener in dispose: $e');
    }

    // ✅ UPDATED: Remove both filter listeners
    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );

      // Remove general filter listener
      filterService.removeListener(_onFilterChanged);

      // ✅ NEW: Remove date filter listener
      filterService.removeListener(_onDateFilterChanged);

      print('Removed filter listeners');
    } catch (e) {
      print('Error removing filter listeners in dispose: $e');
    }

    super.dispose();
  }

  Future<void> _loadSavePoints() async {
    if (_userProfile == null) return;

    try {
      print('=== LOADING SAVE POINTS ===');
      print('User ID: ${_userProfile!['id']}');

      final points = await _savePointService.getUserSavePoints(
        _userProfile!['id'],
      );
      print('Loaded ${points.length} save points from database');

      // CRITICAL: Validate and clean the save points data
      final validSavePoints = <Map<String, dynamic>>[];

      for (final point in points) {
        try {
          // Validate required fields
          if (point['id'] == null) {
            print('❌ Skipping save point with null ID');
            continue;
          }

          if (point['location'] == null) {
            print('❌ Skipping save point ${point['id']} with null location');
            continue;
          }

          // Handle different location data formats
          Map<String, dynamic> locationData;

          if (point['location'] is String) {
            // Handle PostGIS string format like "POINT(-122.4194 37.7749)"
            final locationStr = point['location'] as String;
            print('Processing location string: $locationStr');

            // Extract coordinates from POINT string
            final regex = RegExp(
              r'POINT\s*\(\s*(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s*\)',
            );
            final match = regex.firstMatch(locationStr);

            if (match != null) {
              final longitude = double.parse(match.group(1)!);
              final latitude = double.parse(match.group(2)!);

              locationData = {
                'type': 'Point',
                'coordinates': [longitude, latitude],
              };
            } else {
              print(
                '❌ Could not parse location string for save point ${point['id']}',
              );
              continue;
            }
          } else if (point['location'] is Map) {
            // Handle GeoJSON format
            locationData = Map<String, dynamic>.from(point['location']);

            // Validate coordinates
            if (locationData['coordinates'] == null ||
                !(locationData['coordinates'] is List) ||
                (locationData['coordinates'] as List).length != 2) {
              print('❌ Invalid coordinates for save point ${point['id']}');
              continue;
            }
          } else {
            print(
              '❌ Unknown location format for save point ${point['id']}: ${point['location'].runtimeType}',
            );
            continue;
          }

          // Validate coordinates are valid numbers
          final coords = locationData['coordinates'] as List;
          final longitude = coords[0];
          final latitude = coords[1];

          if (longitude is! num || latitude is! num) {
            print('❌ Non-numeric coordinates for save point ${point['id']}');
            continue;
          }

          if (longitude < -180 ||
              longitude > 180 ||
              latitude < -90 ||
              latitude > 90) {
            print(
              '❌ Invalid coordinate ranges for save point ${point['id']}: [$longitude, $latitude]',
            );
            continue;
          }

          // Create clean save point data
          final cleanSavePoint = {
            'id': point['id'],
            'name': point['name']?.toString() ?? 'Save Point',
            'description': point['description']?.toString(),
            'location': locationData,
            'created_at': point['created_at'],
            'updated_at': point['updated_at'],
            'user_id': point['user_id'],
          };

          validSavePoints.add(cleanSavePoint);
          print(
            '✅ Valid save point: ${cleanSavePoint['name']} at [${coords[0]}, ${coords[1]}]',
          );
        } catch (e) {
          print('❌ Error processing save point ${point['id']}: $e');
          continue;
        }
      }

      print(
        'Validated ${validSavePoints.length} out of ${points.length} save points',
      );

      if (mounted) {
        setState(() {
          _savePoints = validSavePoints;
        });
        print('✅ Save points state updated successfully');
      }
    } catch (e) {
      print('❌ Error loading save points: $e');
      if (mounted) {
        // Don't show error to user unless it's critical
        print('Setting empty save points list due to error');
        setState(() {
          _savePoints = [];
        });
      }
    }
    print('=== END LOADING SAVE POINTS ===');
  }

  // SAFE SPOTS METHOD STARTS HERE
  void _removeDuplicateSafeSpots() {
    final Map<String, Map<String, dynamic>> uniqueSpots = {};

    // Keep only the last occurrence of each safe spot ID
    for (final spot in _safeSpots) {
      final spotId = spot['id'] as String;
      uniqueSpots[spotId] = spot;
    }

    final originalCount = _safeSpots.length;
    _safeSpots = uniqueSpots.values.toList();
    final newCount = _safeSpots.length;

    if (originalCount != newCount) {
      print('⚠️  Removed ${originalCount - newCount} duplicate safe spots');
      print('Safe spots count: $originalCount -> $newCount');
    }
  }

  // Updated _loadSafeSpots method
  Future<void> _loadSafeSpots() async {
    try {
      print('=== LOADING SAFE SPOTS ===');
      print('User ID: ${_userProfile?['id']}');
      print('Is Admin: $_isAdmin');
      print('Current safe spots count: ${_safeSpots.length}');

      final safeSpots = await SafeSpotService.getSafeSpots(
        userId: _userProfile?['id'],
        isAdmin: _hasAdminPermissions, // Use combined permissions
      );

      print('Loaded ${safeSpots.length} safe spots from database');

      // Log the status distribution for debugging
      final statusCounts = <String, int>{};
      for (final spot in safeSpots) {
        final status = spot['status'] ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      print('Status distribution: $statusCounts');

      if (mounted) {
        setState(() {
          _safeSpots = safeSpots;
          // Remove any duplicates that might exist
          _removeDuplicateSafeSpots();
        });
        print('✅ Safe spots state updated successfully');
        print('New _safeSpots.length: ${_safeSpots.length}');
      }
    } catch (e) {
      print('❌ Error loading safe spots: $e');
      if (mounted) {
        _showSnackBar('Error loading safe spots: ${e.toString()}');
      }
    }
    print('=== END LOADING SAFE SPOTS ===');
  }

  //  REAL-TIME SAFE SPOTS

  void _setupSafeSpotsRealtime() {
    _safeSpotsChannel?.unsubscribe();

    _safeSpotsChannel = Supabase.instance.client
        .channel('safe_spots_realtime_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'safe_spots',
          callback: _handleSafeSpotInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'safe_spots',
          callback: _handleSafeSpotUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'safe_spots',
          callback: _handleSafeSpotDelete,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'safe_spot_upvotes',
          callback: _handleSafeSpotUpvoteChange,
        )
        .subscribe((status, error) {
          print('Safe spots channel status: $status, error: $error');

          if (status == 'SUBSCRIBED') {
            print('Successfully connected to safe spots channel');
          } else if (status == 'CHANNEL_ERROR' || status == 'CLOSED') {
            print('Error with safe spots channel: $error');

            // Attempt to reconnect after delay
            Timer(const Duration(seconds: 3), () {
              if (mounted) {
                print('Attempting to reconnect safe spots channel...');
                _setupSafeSpotsRealtime();
              }
            });
          }
        });
  }

  void _handleSafeSpotInsert(PostgresChangePayload payload) async {
    if (!mounted) return;

    try {
      // Fetch the complete safe spot data with proper relations
      final response = await Supabase.instance.client
          .from('safe_spots')
          .select('''
          *,
          safe_spot_types!inner (
            id,
            name,
            icon,
            description
          ),
          users!safe_spots_created_by_fkey (
            id,
            first_name,
            last_name,
            role
          )
        ''')
          .eq('id', payload.newRecord['id'])
          .single();

      if (mounted) {
        // Check if this user should see this safe spot
        final shouldShow = _shouldUserSeeSafeSpot(response);

        if (shouldShow) {
          // CHECK FOR DUPLICATES BEFORE ADDING
          final spotId = response['id'] as String;
          final existingIndex = _safeSpots.indexWhere((s) => s['id'] == spotId);

          setState(() {
            if (existingIndex == -1) {
              // Only add if it doesn't already exist
              _safeSpots.insert(0, response);
            } else {
              // Update existing spot instead of adding duplicate
              _safeSpots[existingIndex] = response;
            }
          });

          print('New safe spot added via real-time: ${response['name']}');

          // Show notification if it's not the current user's creation
          if (response['created_by'] != _userProfile?['id']) {
            final typeName = response['safe_spot_types']['name'];
            _showSnackBar('New safe spot added: $typeName');
          }
        }
      }
    } catch (e) {
      print('Error in _handleSafeSpotInsert: $e');
      // Fallback with minimal data
      if (mounted) {
        final spotId = payload.newRecord['id'] as String;
        final existingIndex = _safeSpots.indexWhere((s) => s['id'] == spotId);

        setState(() {
          if (existingIndex == -1) {
            _safeSpots.insert(0, payload.newRecord);
          }
        });
      }
    }
  }

  void _showUpdateMessage(
    Map<String, dynamic> previousSafeSpot,
    Map<String, dynamic> response,
    String? previousStatus,
  ) {
    final newStatus = response['status'] ?? 'pending';
    final typeName = response['safe_spot_types']['name'];

    print(
      'Message check - Previous status: $previousStatus, New status: $newStatus',
    );

    // Only show messages for actual status changes
    if (previousStatus != null && newStatus != previousStatus) {
      if (newStatus == 'approved') {
        print('🟢 Showing approved message');
        _showSnackBar('Safe spot approved: $typeName');
      } else if (newStatus == 'rejected') {
        print('🔴 Showing rejected message');
        _showSnackBar('Safe spot rejected: $typeName');
      } else {
        print('📝 Status changed to: $newStatus');
        _showSnackBar('Safe spot status updated: $typeName');
      }
    } else if (previousStatus == newStatus && previousSafeSpot.isNotEmpty) {
      // Check if it's an edit (content changed but status stayed same)
      final previousName = previousSafeSpot['name'] ?? '';
      final newName = response['name'] ?? '';
      final previousDescription = previousSafeSpot['description'] ?? '';
      final newDescription = response['description'] ?? '';
      final previousTypeId = previousSafeSpot['type_id'];
      final newTypeId = response['type_id'];
      final previousUpvotes = previousSafeSpot['upvotes'] ?? 0;
      final newUpvotes = response['upvotes'] ?? 0;

      // Check if the only change is to upvotes
      bool isUpvoteOnlyChange =
          previousName == newName &&
          previousDescription == newDescription &&
          previousTypeId == newTypeId &&
          previousUpvotes != newUpvotes;

      if (isUpvoteOnlyChange) {
        print('ℹ️ Upvote-only change detected, skipping message');
        return; // Skip showing message for upvote changes
      }

      bool isEdit =
          (previousName != newName ||
          previousDescription != newDescription ||
          previousTypeId != newTypeId);

      if (isEdit) {
        print('✏️ Showing edit confirmation message');
        _showSnackBar('Safe spot updated: $typeName');
      } else {
        print('ℹ️ No significant changes detected, skipping message');
      }
    }
  }

  void _handleSafeSpotUpdate(PostgresChangePayload payload) async {
    if (!mounted) return;

    final spotId = payload.newRecord['id'] as String;
    final updateKey = '${spotId}_${payload.newRecord['updated_at']}';

    if (_processedUpdateIds.contains(updateKey)) {
      print('🔄 Skipping duplicate update for safe spot: $spotId');
      return;
    }

    _updateTimers[spotId]?.cancel();
    _updateTimers[spotId] = Timer(Duration(milliseconds: 500), () async {
      if (!mounted) return;

      _processedUpdateIds.add(updateKey);
      if (_processedUpdateIds.length > 100) {
        final oldIds = _processedUpdateIds
            .take(_processedUpdateIds.length - 50)
            .toList();
        _processedUpdateIds.removeAll(oldIds);
      }

      print('=== PROCESSING SAFE SPOT UPDATE ===');
      print('Spot ID: $spotId');
      print('Update key: $updateKey');

      try {
        final response = await Supabase.instance.client
            .from('safe_spots')
            .select('''
            *,
            safe_spot_types!inner (
              id,
              name,
              icon,
              description
            ),
            users!safe_spots_created_by_fkey (
              id,
              first_name,
              last_name,
              role
            ),
            approved_profile:approved_by (
              id,
              first_name,
              last_name
            ),
            rejected_profile:rejected_by (
              id,
              first_name,
              last_name
            ),
            updated_profile:last_updated_by (
              id,
              first_name,
              last_name
            )
          ''')
            .eq('id', spotId)
            .single();

        if (!mounted) return;

        final shouldShow = _shouldUserSeeSafeSpot(response);
        setState(() {
          final existingIndex = _safeSpots.indexWhere((s) => s['id'] == spotId);
          Map<String, dynamic> previousSafeSpot = {};
          if (existingIndex != -1) {
            previousSafeSpot = Map<String, dynamic>.from(
              _safeSpots[existingIndex],
            );
          }

          if (shouldShow) {
            if (existingIndex != -1) {
              _safeSpots[existingIndex] = response;
              print('✅ Updated existing safe spot at index $existingIndex');
            } else {
              _safeSpots.add(response);
              print('✅ Added previously hidden safe spot');
            }
          } else if (existingIndex != -1) {
            _safeSpots.removeAt(existingIndex);
            print('🗑️ Removed safe spot that should no longer be visible');
          }
          print('Final safe spots count: ${_safeSpots.length}');

          // Only call _showUpdateMessage if the update isn't handled by upvote change
          if (payload.newRecord['upvotes'] == null ||
              previousSafeSpot['upvotes'] != response['upvotes']) {
            print('ℹ️ Update likely due to upvote change, checking further...');
            _showUpdateMessage(
              previousSafeSpot,
              response,
              previousSafeSpot['status'] ?? 'pending',
            );
          } else {
            _showUpdateMessage(
              previousSafeSpot,
              response,
              previousSafeSpot['status'] ?? 'pending',
            );
          }
        });
      } catch (e) {
        print('❌ Error in _handleSafeSpotUpdate: $e');
        if (mounted) {
          _showSnackBar('Error updating safe spot: ${e.toString()}');
        }
      }

      _updateTimers.remove(spotId);
      print('=== END PROCESSING SAFE SPOT UPDATE ===\n');
    });
  }

  // Also add debug to the visibility check
  bool _shouldUserSeeSafeSpot(Map<String, dynamic> safeSpot) {
    final status = safeSpot['status'] ?? 'pending';
    final createdBy = safeSpot['created_by'];
    final currentUserId = _userProfile?['id'];

    print('--- Visibility Check ---');
    print('Status: $status');
    print('Created by: $createdBy');
    print('Current user: $currentUserId');
    print('Is admin: $_isAdmin');
    print('Is officer: $_isOfficer');
    print('Has admin permissions: $_hasAdminPermissions');

    // Admins and Officers can see everything
    if (_hasAdminPermissions) {
      print('Admin/Officer can see: true');
      return true;
    }

    // Users can see their own spots regardless of status
    if (createdBy == currentUserId) {
      print('Own spot: true');
      return true;
    }

    // Users can see approved and pending spots (for voting)
    if (status == 'approved' || status == 'pending') {
      print('Approved/pending spot: true');
      return true;
    }

    // Hide rejected spots from other users
    print('Rejected spot from other user: false');
    return false;
  }

  void _handleSafeSpotDelete(PostgresChangePayload payload) {
    if (!mounted) return;

    final deletedSafeSpotId = payload.oldRecord['id'];

    setState(() {
      final deletedSafeSpot = _safeSpots.firstWhere(
        (s) => s['id'] == deletedSafeSpotId,
        orElse: () => {},
      );

      // Remove the safe spot from local state
      _safeSpots.removeWhere((spot) => spot['id'] == deletedSafeSpotId);

      // Remove related notifications from local state
      final relatedNotifications = _notifications
          .where(
            (notification) => notification['safe_spot_id'] == deletedSafeSpotId,
          )
          .toList();

      // Update unread count for any unread notifications that will be removed
      for (final notification in relatedNotifications) {
        if (!(notification['is_read'] ?? false)) {
          _unreadNotificationCount = (_unreadNotificationCount - 1)
              .clamp(0, double.infinity)
              .toInt();
        }
      }

      // Remove the notifications
      _notifications.removeWhere(
        (notification) => notification['safe_spot_id'] == deletedSafeSpotId,
      );

      // Clear selection if the deleted safe spot was selected
      if (_selectedSafeSpot != null &&
          _selectedSafeSpot!['id'] == deletedSafeSpotId) {
        _selectedSafeSpot = null;
      }

      print('Safe spot deleted via real-time: $deletedSafeSpotId');
      print('Related notifications removed: ${relatedNotifications.length}');
      print('Updated unread count: $_unreadNotificationCount');

      // Show notification
      if (deletedSafeSpot.isNotEmpty) {
        final typeName =
            deletedSafeSpot['safe_spot_types']?['name'] ?? 'Safe spot';
        _showSnackBar('$typeName deleted');
      }
    });
  }

  void _handleSafeSpotUpvoteChange(PostgresChangePayload payload) {
    if (!mounted) return;

    // Get the safe spot ID from the upvote record
    final safeSpotId =
        payload.newRecord['safe_spot_id'] ?? payload.oldRecord['safe_spot_id'];
    if (safeSpotId == null) return;

    print('Safe spot upvote changed for spot: $safeSpotId');

    // Debounce upvote updates to prevent excessive API calls
    Timer(Duration(milliseconds: 1000), () async {
      if (!mounted) return;

      try {
        // Refresh just this specific safe spot's upvote count
        final response = await Supabase.instance.client
            .from('safe_spots')
            .select('id, upvotes')
            .eq('id', safeSpotId)
            .single();

        if (mounted) {
          setState(() {
            final index = _safeSpots.indexWhere((s) => s['id'] == safeSpotId);
            if (index != -1) {
              _safeSpots[index]['upvotes'] = response['upvotes'];
              print('Updated upvote count for safe spot $safeSpotId');
            }
          });
        }
      } catch (e) {
        print('Error updating upvote count: $e');
      }
    });
  }

  // FUNCTION TO CALL WELCOME
  void _showWelcomeModal() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('first_name, role, has_seen_welcome')
            .eq('id', user.id)
            .single();

        final role = response['role'];
        final isAdmin = role == 'admin';
        final isOfficer = role == 'officer';
        final firstName = response['first_name'];
        final hasSeenWelcome = response['has_seen_welcome'] ?? false;

        if (!hasSeenWelcome) {
          // Show first-time welcome and mark as seen
          showFirstTimeWelcomeModal(context, userName: firstName);

          // Mark as seen in database
          await Supabase.instance.client
              .from('users')
              .update({'has_seen_welcome': true})
              .eq('id', user.id);
        } else {
          // Show regular welcome
          UserType userType;
          if (isAdmin) {
            userType = UserType.admin;
          } else if (isOfficer) {
            userType = UserType.officer;
          } else {
            userType = UserType.user;
          }

          showWelcomeModal(
            context,
            userType: userType,
            userName: firstName,
            isSidebarVisible: _isSidebarVisible,
            sidebarWidth: 285,
          );
        }
      } catch (e) {
        showWelcomeModal(
          context,
          userType: UserType.user,
          isSidebarVisible: _isSidebarVisible,
          sidebarWidth: 285,
        );
      }
    } else {
      showWelcomeModal(
        context,
        userType: UserType.guest,
        onCreateAccount: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
        isSidebarVisible: _isSidebarVisible,
        sidebarWidth: 285,
      );
    }
  }

  void _startProximityMonitoring() {
    _proximityCheckTimer?.cancel();
    _proximityCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkProximityToHotspots();
      _checkProximityToHeatmaps(); // NEW: Check heatmaps too
    });
  }

  // ============================================
  // NEW: Check proximity to heatmap clusters
  // ============================================
  void _checkProximityToHeatmaps() {
    if (_currentPosition == null || !mounted || _heatmapClusters.isEmpty) {
      // ⭐ ADD THIS: Clear alerts if no clusters
      if (_showHeatmapProximityAlert) {
        setState(() {
          _nearbyHeatmapClusters.clear();
          _showHeatmapProximityAlert = false;
          _updateAlertType(); // Helper method (see below)
        });
      }
      return;
    }

    final nearbyHeatmaps = <Map<String, dynamic>>[];

    for (final cluster in _heatmapClusters) {
      // ⭐ ADD THIS: Verify cluster still exists in persistent list
      final stillExists = _persistentClusters.any((pc) {
        final pcCenter = LatLng(pc['center_lat'], pc['center_lng']);
        return _calculateDistance(cluster.center, pcCenter) <
            10.0; // Within 10m
      });

      if (!stillExists) {
        print('⚠️ Skipping stale cluster that no longer exists');
        continue;
      }

      final distanceToCenter = _calculateDistance(
        _currentPosition!,
        cluster.center,
      );
      final distanceToEdge = distanceToCenter - cluster.radius;

      final bufferZone = 50.0;
      final isInside = distanceToCenter <= (cluster.radius - bufferZone);
      final isApproaching = !isInside && distanceToEdge <= 150;

      if (isInside || isApproaching) {
        nearbyHeatmaps.add({
          'cluster': cluster,
          'distanceToCenter': distanceToCenter,
          'distanceToEdge': distanceToEdge,
          'isInside': isInside,
        });

        if (isInside) {
          print(
            '🚨 INSIDE heatmap zone! ${distanceToCenter.toStringAsFixed(1)}m from center (radius: ${cluster.radius.toStringAsFixed(0)}m)',
          );
        } else {
          print(
            '⚠️ Approaching heatmap zone! ${distanceToEdge.toStringAsFixed(1)}m from edge',
          );
        }
      }
    }

    // Sort by priority: inside zones first, then by distance to edge
    nearbyHeatmaps.sort((a, b) {
      if (a['isInside'] && !b['isInside']) return -1;
      if (!a['isInside'] && b['isInside']) return 1;
      return (a['distanceToEdge'] as double).compareTo(
        b['distanceToEdge'] as double,
      );
    });

    final previousHeatmapAlertState = _showHeatmapProximityAlert;

    if (mounted) {
      setState(() {
        _nearbyHeatmapClusters = nearbyHeatmaps
            .map((h) => h['cluster'] as HeatmapCluster)
            .toList();
        _showHeatmapProximityAlert = nearbyHeatmaps.isNotEmpty;

        // Determine alert type priority: both > heatmap > hotspot
        if (_showProximityAlert && _showHeatmapProximityAlert) {
          _proximityAlertType = 'both';
        } else if (_showHeatmapProximityAlert) {
          _proximityAlertType = 'heatmap';
        } else if (_showProximityAlert) {
          _proximityAlertType = 'hotspot';
        } else {
          _proximityAlertType = 'none';
        }
      });

      // Haptic feedback for new heatmap alerts
      if (_showHeatmapProximityAlert && !previousHeatmapAlertState) {
        final isInside = nearbyHeatmaps.first['isInside'] as bool;

        if (isInside) {
          HapticFeedback.mediumImpact(); // Stronger feedback when inside
          print('🚨 HEATMAP ALERT ACTIVATED: Inside danger zone');
        } else {
          HapticFeedback.lightImpact();
          print('⚠️ HEATMAP ALERT ACTIVATED: Approaching danger zone');
        }
      }
    }
  }

  // ⭐ ADD THIS METHOD: Centralized alert type update
  void _updateAlertType() {
    if (_showProximityAlert && _showHeatmapProximityAlert) {
      _proximityAlertType = 'both';
    } else if (_showHeatmapProximityAlert) {
      _proximityAlertType = 'heatmap';
    } else if (_showProximityAlert) {
      _proximityAlertType = 'hotspot';
    } else {
      _proximityAlertType = 'none';
    }
  }

  // Main method to check proximity to active hotspots
  void _checkProximityToHotspots() {
    if (_currentPosition == null || !mounted) {
      print(
        'DEBUG: Cannot check proximity - position: $_currentPosition, mounted: $mounted',
      );
      return;
    }

    print(
      'DEBUG: Checking proximity from position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
    );
    print('DEBUG: Total hotspots to check: ${_hotspots.length}');

    final nearbyHotspots = <Map<String, dynamic>>[];

    for (final hotspot in _hotspots) {
      // Only check active, approved hotspots
      final status = hotspot['status'] ?? 'approved';
      final activeStatus = hotspot['active_status'] ?? 'active';
      final crimeTypeName = hotspot['crime_type']?['name'] ?? 'Unknown';
      final crimeLevel = hotspot['crime_type']?['level'] ?? 'medium';

      print(
        'DEBUG: Checking hotspot ${hotspot['id']} ($crimeTypeName - $crimeLevel) - status: $status, active: $activeStatus',
      );

      if (status != 'approved' || activeStatus != 'active') {
        print('DEBUG: Skipping hotspot ${hotspot['id']} - not approved/active');
        continue;
      }

      final coords = hotspot['location']['coordinates'];
      final hotspotPosition = LatLng(coords[1], coords[0]);
      final distance = _calculateDistance(_currentPosition!, hotspotPosition);

      // Get alert distance based on crime level (for Option 2)
      // final alertDistance = _alertDistances[crimeLevel] ?? 200.0;

      // For Option 1, just use the constant:
      final alertDistance = _proximityAlertDistance;

      print(
        'DEBUG: Hotspot ${hotspot['id']} ($crimeTypeName - $crimeLevel) distance: ${distance.toStringAsFixed(1)}m (threshold: ${alertDistance.toStringAsFixed(0)}m)',
      );

      if (distance <= alertDistance) {
        print(
          'DEBUG: ✅ Hotspot ${hotspot['id']} ($crimeTypeName) is within range! Adding to nearby list.',
        );
        nearbyHotspots.add({...hotspot, 'distance': distance});
      } else {
        print(
          'DEBUG: ❌ Hotspot ${hotspot['id']} ($crimeTypeName) is too far (${distance.toStringAsFixed(1)}m > ${alertDistance.toStringAsFixed(0)}m)',
        );
      }
    }

    print('DEBUG: Found ${nearbyHotspots.length} nearby hotspots');

    // Sort by distance (closest first)
    nearbyHotspots.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    // Always update state based on what we found
    final hasNearbyHotspots = nearbyHotspots.isNotEmpty;
    final previousAlertState = _showProximityAlert;

    if (mounted) {
      setState(() {
        _nearbyHotspots = nearbyHotspots;
        _showProximityAlert = hasNearbyHotspots;
        _updateAlertType();
      });

      // Log state changes
      if (_showProximityAlert != previousAlertState) {
        if (_showProximityAlert) {
          final closestDistance = nearbyHotspots.first['distance'] as double;
          print(
            'DEBUG: 🚨 ALERT ACTIVATED - ${nearbyHotspots.length} crimes nearby (closest: ${closestDistance.toStringAsFixed(1)}m)',
          );
          HapticFeedback.lightImpact(); // Haptic feedback when alert appears
        } else {
          print('DEBUG: ✅ ALERT CLEARED - moved away from danger zone');
        }
      }

      print(
        'DEBUG: Updated state - showAlert: $_showProximityAlert, nearbyCount: ${_nearbyHotspots.length}',
      );
    }
  }

  // NOTIFICATION REALTIME METHOD

  void _setupNotificationsRealtime() {
    _notificationsChannel?.unsubscribe();
    _notificationsChannelConnected = false;

    // Only set up if user is logged in
    if (_userProfile == null || _userProfile!['id'] == null) {
      print('Cannot setup notifications - no user profile');
      return;
    }

    final userId = _userProfile!['id'];
    print('Setting up notifications channel for user: $userId');

    // FIXED: Use unfiltered subscription like your working code
    _notificationsChannel = Supabase.instance.client
        .channel(
          'notifications_realtime_${DateTime.now().millisecondsSinceEpoch}',
        ) // Unique channel name
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          // REMOVED: filter parameter - let all notifications come through
          callback: _handleNotificationInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          // REMOVED: filter parameter - let all notifications come through
          callback: _handleNotificationUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          // REMOVED: filter parameter - let all notifications come through
          callback: _handleNotificationDelete,
        )
        .subscribe((status, error) {
          print('Notifications channel status: $status, error: $error');

          if (status == 'SUBSCRIBED') {
            print('Notifications channel connected successfully');
            setState(() => _notificationsChannelConnected = true);
          } else if (status == 'CHANNEL_ERROR' ||
              status == 'CLOSED' ||
              error != null) {
            print('Notifications channel error: $error');
            setState(() => _notificationsChannelConnected = false);
            _reconnectNotificationsChannel();
          }
        });
  }

  void _reconnectNotificationsChannel() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _setupNotificationsRealtime();
    });
  }

  void _handleNotificationInsert(PostgresChangePayload payload) {
    if (!mounted) return;

    final newNotification = payload.newRecord;

    // FIXED: Filter by user ID in the handler, not in the subscription
    if (newNotification['user_id'] != _userProfile?['id']) {
      return; // Not for this user, ignore
    }

    print(
      'Handling notification insert for current user: ${newNotification['title']}',
    );

    // Check if notification already exists by ID (more reliable than checking multiple fields)
    final exists = _notifications.any((n) => n['id'] == newNotification['id']);

    if (!exists) {
      setState(() {
        _notifications.insert(0, newNotification);

        // Update unread count
        if (!(newNotification['is_read'] ?? false)) {
          _unreadNotificationCount++;
        }
      });

      print(
        'New notification added. Total: ${_notifications.length}, Unread: $_unreadNotificationCount',
      );

      // Show snackbar notification only if not currently on notifications tab
      if (_currentTab != MainTab.notifications) {
        _showSnackBar('📢 ${newNotification['title'] ?? 'New notification'}');
      }
    } else {
      print('Notification already exists, skipping');
    }
  }

  void _handleNotificationUpdate(PostgresChangePayload payload) {
    if (!mounted) return;

    final updatedNotification = payload.newRecord;

    // FIXED: Filter by user ID in the handler
    if (updatedNotification['user_id'] != _userProfile?['id']) {
      return; // Not for this user, ignore
    }

    final notificationId = updatedNotification['id'];

    print('Handling notification update for current user, ID: $notificationId');

    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      final wasRead = _notifications[index]['is_read'] ?? false;
      final isNowRead = updatedNotification['is_read'] ?? false;

      setState(() {
        _notifications[index] = updatedNotification;

        // Update unread count based on read status change
        if (wasRead != isNowRead) {
          if (isNowRead && !wasRead) {
            // Changed from unread to read
            _unreadNotificationCount = (_unreadNotificationCount - 1)
                .clamp(0, double.infinity)
                .toInt();
          } else if (!isNowRead && wasRead) {
            // Changed from read to unread (unlikely but possible)
            _unreadNotificationCount++;
          }
        }
      });

      print('Notification updated. Unread count: $_unreadNotificationCount');
    } else {
      print('Notification not found in local list for update');
    }
  }

  void _handleNotificationDelete(PostgresChangePayload payload) {
    if (!mounted) return;

    final deletedNotification = payload.oldRecord;

    // FIXED: Filter by user ID in the handler
    if (deletedNotification['user_id'] != _userProfile?['id']) {
      return; // Not for this user, ignore
    }

    final notificationId = deletedNotification['id'];

    print('Handling notification delete for current user, ID: $notificationId');

    setState(() {
      final removedNotification = _notifications.firstWhere(
        (n) => n['id'] == notificationId,
        orElse: () => <String, dynamic>{},
      );

      if (removedNotification.isNotEmpty) {
        _notifications.removeWhere((n) => n['id'] == notificationId);

        // Update unread count if the deleted notification was unread
        if (!(removedNotification['is_read'] ?? false)) {
          _unreadNotificationCount = (_unreadNotificationCount - 1)
              .clamp(0, double.infinity)
              .toInt();
        }
      }
    });

    print(
      'Notification deleted. Total: ${_notifications.length}, Unread: $_unreadNotificationCount',
    );
  }

  Future<void> _loadNotifications() async {
    if (_userProfile == null || _userProfile!['id'] == null) {
      print('Cannot load notifications - no user profile');
      return;
    }

    final userId = _userProfile!['id'];
    print('Loading notifications for user: $userId');

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('''
          *,
          safe_spots:safe_spot_id (
            id,
            name,
            location
          )
        ''') // Include safe spot data in the query
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('Loaded ${response.length} notifications from database');

      // Remove duplicates before setting state
      final uniqueNotifications = _removeDuplicateNotifications(response);

      if (mounted) {
        setState(() {
          _notifications = uniqueNotifications;
          _unreadNotificationCount = _notifications
              .where((n) => !(n['is_read'] ?? false))
              .length;
        });

        print(
          'Notifications loaded. Total: ${_notifications.length}, Unread: $_unreadNotificationCount',
        );
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        _showSnackBar('Error loading notifications: ${e.toString()}');
      }
    }
  }

  // Update your duplicate removal to handle safe spot notifications
  List<Map<String, dynamic>> _removeDuplicateNotifications(
    List<dynamic> notifications,
  ) {
    final uniqueKeys = <String>{};
    final uniqueNotifications = <Map<String, dynamic>>[];

    for (final notification in notifications.cast<Map<String, dynamic>>()) {
      // Create unique key based on notification type and related IDs
      String key;
      if (notification['safe_spot_id'] != null) {
        key =
            '${notification['safe_spot_id']}_${notification['user_id']}_${notification['type']}';
      } else if (notification['hotspot_id'] != null) {
        key =
            '${notification['hotspot_id']}_${notification['user_id']}_${notification['type']}';
      } else {
        key =
            '${notification['id']}_${notification['user_id']}_${notification['type']}';
      }

      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        uniqueNotifications.add(notification);
      }
    }

    return uniqueNotifications;
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      print('Marking notification as read: $notificationId');

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // The real-time subscription should handle the UI update automatically
      // But as a fallback, we can also update locally
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1 && !(_notifications[index]['is_read'] ?? false)) {
        setState(() {
          _notifications[index]['is_read'] = true;
          _unreadNotificationCount = (_unreadNotificationCount - 1)
              .clamp(0, double.infinity)
              .toInt();
        });
      }

      print(
        'Notification marked as read. Unread count: $_unreadNotificationCount',
      );
    } catch (e) {
      print('Error marking notification as read: $e');
      if (mounted) {
        _showSnackBar('Error updating notification: ${e.toString()}');
      }
    }
  }

  // 7. Fix the markAllAsRead method
  Future<void> _markAllAsRead() async {
    if (_userProfile == null) return;

    try {
      print('Marking all notifications as read');

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userProfile!['id'])
          .eq('is_read', false);

      // The real-time subscription should handle the UI update automatically
      // But as a fallback, we can also update locally
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
        _unreadNotificationCount = 0;
      });

      print('All notifications marked as read');
    } catch (e) {
      print('Error marking all notifications as read: $e');
      if (mounted) {
        _showSnackBar('Error updating notifications: ${e.toString()}');
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select()
            .eq('email', user.email as Object)
            .single();

        if (mounted) {
          setState(() {
            _userProfile = response;
            _isAdmin = response['role'] == 'admin';
            _isOfficer = response['role'] == 'officer';
            _profileScreen = ProfileScreen(
              _authService,
              _userProfile,
              _isAdmin,
              _hasAdminPermissions,
            );
            _profileScreen.initControllers();
          });

          print('User profile loaded: ${_userProfile!['id']}');
          // Profile photo URL: ${_userProfile!['profile_picture_url'] ?? 'none'}

          // Setup real-time subscriptions after profile is loaded
          _setupNotificationsRealtime();
          await _loadNotifications();
          await _loadHotspots();
        }
      } catch (e) {
        print('Error loading user profile: $e');
        if (mounted) {
          _showSnackBar('Error loading profile: ${e.toString()}');
        }
      }
    } else {
      print('No user logged in');
    }
  }

  // ============================================
  // SETUP REAL-TIME FOR PERSISTENT CLUSTERS
  // ============================================
  void _setupClustersRealtime() {
    if (_clustersChannel != null) {
      print('⚠️ Clusters channel already exists, skipping setup');
      return;
    }

    try {
      _clustersChannel = Supabase.instance.client
          .channel('heatmap_clusters_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'heatmap_clusters',
            callback: _handleClusterInsert,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'heatmap_clusters',
            callback: _handleClusterUpdate,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'heatmap_clusters',
            callback: _handleClusterDelete,
          )
          .subscribe();

      print('✅ Clusters real-time subscription active');
    } catch (e) {
      print('Error setting up clusters real-time: $e');
    }
  }

  // ============================================
  // CLUSTER REAL-TIME HANDLERS
  // ============================================
  void _handleClusterInsert(PostgresChangePayload payload) async {
    if (!mounted) return;

    print('📥 Cluster insert received, debouncing...');
    _hasPendingClusterUpdate = true;

    _clusterUpdateDebouncer?.cancel();
    _clusterUpdateDebouncer = Timer(
      const Duration(milliseconds: 800),
      () async {
        if (!mounted || !_hasPendingClusterUpdate) return;
        _hasPendingClusterUpdate = false;

        await _loadPersistentClusters();

        if (mounted) {
          setState(() {
            // Convert to display clusters
            _heatmapClusters = _persistentClusters
                .where((pc) => pc['status'] == 'active')
                .map((pc) => _convertPersistentToDisplayCluster(pc))
                .toList();
          });
        }
      },
    );
  }

  void _handleClusterUpdate(PostgresChangePayload payload) async {
    if (!mounted) return;

    print('📥 Cluster update received, debouncing...');
    _hasPendingClusterUpdate = true;

    _clusterUpdateDebouncer?.cancel();
    _clusterUpdateDebouncer = Timer(
      const Duration(milliseconds: 800),
      () async {
        if (!mounted || !_hasPendingClusterUpdate) return;
        _hasPendingClusterUpdate = false;

        await _loadPersistentClusters();

        if (mounted) {
          setState(() {
            _heatmapClusters = _persistentClusters
                .where((pc) => pc['status'] == 'active')
                .map((pc) => _convertPersistentToDisplayCluster(pc))
                .toList();
          });
        }
      },
    );
  }

  void _handleClusterDelete(PostgresChangePayload payload) {
    if (!mounted) return;

    final clusterId = payload.oldRecord['id'];

    setState(() {
      _persistentClusters.removeWhere((c) => c['id'] == clusterId);
      _heatmapClusters = _persistentClusters
          .where((pc) => pc['status'] == 'active')
          .map((pc) => _convertPersistentToDisplayCluster(pc))
          .toList();

      // ⭐ ADD THIS: Clear proximity alerts if the deleted cluster was in the alert list
      _nearbyHeatmapClusters.removeWhere((cluster) {
        // Check if this cluster matches the deleted one (by comparing center coordinates)
        final matchesPersistent = _persistentClusters.any((pc) {
          final pcCenter = LatLng(pc['center_lat'], pc['center_lng']);
          return _calculateDistance(cluster.center, pcCenter) <
              10.0; // Within 10m
        });
        return !matchesPersistent; // Remove if not in persistent list
      });

      // ⭐ Update alert state
      _showHeatmapProximityAlert = _nearbyHeatmapClusters.isNotEmpty;

      // ⭐ Update combined alert type
      if (_showProximityAlert && _showHeatmapProximityAlert) {
        _proximityAlertType = 'both';
      } else if (_showHeatmapProximityAlert) {
        _proximityAlertType = 'heatmap';
      } else if (_showProximityAlert) {
        _proximityAlertType = 'hotspot';
      } else {
        _proximityAlertType = 'none';
      }
    });

    _updateAlertType();

    print('🗑️ Cluster $clusterId deleted instantly');
    print('   Remaining heatmap clusters: ${_heatmapClusters.length}');
    print('   Nearby clusters in alert: ${_nearbyHeatmapClusters.length}');
  }

  //REAL TIME HOTSPOT
  void _setupRealtimeSubscription() {
    _hotspotsChannel?.unsubscribe();
    _hotspotsChannelConnected = false;

    final channelName =
        'hotspots_realtime_${DateTime.now().millisecondsSinceEpoch}';

    _hotspotsChannel = Supabase.instance.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'hotspot',
          callback: _handleHotspotInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'hotspot',
          callback: _handleHotspotUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'hotspot',
          callback: _handleHotspotDelete,
        )
        .subscribe((status, error) {
          print('=== REALTIME STATUS: $status ===');
          if (error != null) print('Error: $error');

          if (status == 'SUBSCRIBED') {
            print('✅ Successfully connected to hotspots channel: $channelName');
            setState(() => _hotspotsChannelConnected = true);
          } else if (status == 'CHANNEL_ERROR' || status == 'CLOSED') {
            print('❌ Error with hotspots channel: $error');
            setState(() => _hotspotsChannelConnected = false);

            // Attempt to reconnect after delay
            _reconnectionTimer?.cancel();
            _reconnectionTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                print('🔄 Attempting to reconnect hotspots channel...');
                _setupRealtimeSubscription();
              }
            });
          }
        });
  }

  void _handleHotspotInsert(PostgresChangePayload payload) async {
    if (!mounted) return;

    final hotspotId = payload.newRecord['id'];
    final currentUserId = _userProfile?['id'];
    final createdBy = payload.newRecord['created_by'];
    final reportedBy = payload.newRecord['reported_by'];

    // ✅ CRITICAL: Skip ONLY if this hotspot was created by the CURRENT user
    // This prevents duplicate markers for the user who submitted the report
    // But allows admins/officers to see new reports in real-time
    final isMyOwnReport =
        currentUserId != null &&
        (currentUserId == createdBy || currentUserId == reportedBy);

    if (isMyOwnReport && _processedHotspotIds.contains(hotspotId)) {
      print(
        '⚠️ Hotspot $hotspotId was just created by current user - SKIPPING',
      );
      return;
    }

    // ✅ CRITICAL: Check if hotspot already exists BEFORE any async operations
    final existingIndex = _hotspots.indexWhere((h) => h['id'] == hotspotId);

    if (existingIndex != -1) {
      print(
        '⚠️ Hotspot $hotspotId ALREADY EXISTS at index $existingIndex - SKIPPING ENTIRELY',
      );
      return; // Exit early, don't even fetch from database
    }

    try {
      // Add delay to ensure database relationships are committed
      await Future.delayed(const Duration(milliseconds: 300));

      // Double-check after delay (in case another handler added it)
      if (_hotspots.any((h) => h['id'] == hotspotId)) {
        print('⚠️ Hotspot $hotspotId was added during delay - SKIPPING');
        return;
      }

      // Fetch the complete hotspot data
      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
          *,
          crime_type: type_id (id, name, level, category, description),
          created_by_profile: created_by (id, username, email),
          reported_by_profile: reported_by (id, username, email),
          verifier_profile: verified_by (first_name, last_name)
        ''')
          .eq('id', hotspotId)
          .single();

      if (!mounted) return;

      // ✅ Check visibility permissions for non-admin users
      if (!_hasAdminPermissions) {
        final shouldShow = _shouldNonAdminOfficerSeeHotspot(response);

        if (!shouldShow) {
          print('🚫 Hotspot $hotspotId not visible to current user - SKIPPING');
          return;
        }
      }

      // Triple-check before adding to list
      if (_hotspots.any((h) => h['id'] == hotspotId)) {
        print(
          '⚠️ Hotspot $hotspotId appeared during fetch - SKIPPING LIST INSERT',
        );
      } else {
        setState(() {
          final crimeType = response['crime_type'];
          final crimeTypeData = crimeType != null && crimeType is Map
              ? {
                  'id': crimeType['id'] ?? response['type_id'],
                  'name': crimeType['name'] ?? 'Unknown',
                  'level': crimeType['level'] ?? 'unknown',
                  'category': crimeType['category'] ?? 'General',
                  'description': crimeType['description'],
                }
              : {
                  'id': response['type_id'],
                  'name': 'Unknown',
                  'level': 'unknown',
                  'category': 'General',
                  'description': null,
                };

          _hotspots.insert(0, {
            ...response,
            'created_by': response['created_by'],
            'reported_by': response['reported_by'],
            'crime_type': crimeTypeData,
          });

          print(
            '✅ Added hotspot $hotspotId with crime type: ${crimeTypeData['name']}',
          );
        });
      }

      // ✅ Always update heatmap (even if duplicate in list)
      _updateHeatmapOnInsert(response);
    } catch (e) {
      print('❌ Error in _handleHotspotInsert: $e');

      // Retry logic
      try {
        await Future.delayed(const Duration(milliseconds: 800));

        // Check again before retry
        if (_hotspots.any((h) => h['id'] == hotspotId)) {
          print('⚠️ Hotspot $hotspotId found during retry - SKIPPING');
          return;
        }

        final retryResponse = await Supabase.instance.client
            .from('hotspot')
            .select('''
            *,
            crime_type: type_id (id, name, level, category, description),
            created_by_profile: created_by (id, username, email),
            reported_by_profile: reported_by (id, username, email),
            verifier_profile: verified_by (first_name, last_name)
          ''')
            .eq('id', hotspotId)
            .single();

        if (!mounted) return;

        // Check visibility for non-admin users
        if (!_hasAdminPermissions) {
          final shouldShow = _shouldNonAdminOfficerSeeHotspot(retryResponse);
          if (!shouldShow) {
            print('🚫 Retry: Hotspot $hotspotId not visible to user');
            return;
          }
        }

        // Final check before adding
        if (!_hotspots.any((h) => h['id'] == hotspotId)) {
          setState(() {
            final crimeType = retryResponse['crime_type'];
            final crimeTypeData = crimeType != null && crimeType is Map
                ? {
                    'id': crimeType['id'] ?? retryResponse['type_id'],
                    'name': crimeType['name'] ?? 'Unknown',
                    'level': crimeType['level'] ?? 'unknown',
                    'category': crimeType['category'] ?? 'General',
                    'description': crimeType['description'],
                  }
                : {
                    'id': retryResponse['type_id'],
                    'name': 'Unknown',
                    'level': 'unknown',
                    'category': 'General',
                    'description': null,
                  };

            _hotspots.insert(0, {
              ...retryResponse,
              'created_by': retryResponse['created_by'],
              'reported_by': retryResponse['reported_by'],
              'crime_type': crimeTypeData,
            });

            print('✅ Retry successful - added hotspot $hotspotId');
          });
        }

        _updateHeatmapOnInsert(retryResponse);
      } catch (retryError) {
        print('❌ Retry also failed: $retryError');

        // Last resort: add minimal data only if still not in list
        if (mounted && !_hotspots.any((h) => h['id'] == hotspotId)) {
          setState(() {
            _hotspots.insert(0, {
              ...payload.newRecord,
              'created_by': payload.newRecord['created_by'],
              'reported_by': payload.newRecord['reported_by'],
              'crime_type': {
                'id': payload.newRecord['type_id'],
                'name': 'Loading...',
                'level': 'unknown',
                'category': 'General',
                'description': null,
              },
            });
          });

          // Schedule refresh to fix incomplete data
          Timer(const Duration(seconds: 2), () {
            if (mounted) _loadHotspots();
          });
        }

        _updateHeatmapOnInsert(payload.newRecord);
      }
    }
  }

  // FIXED: Update handler - no changes needed here, but ensure it handles updates properly
  void _handleHotspotUpdate(PostgresChangePayload payload) async {
    if (!mounted) return;

    print('=== HOTSPOT UPDATE RECEIVED ===');
    print('Updated record: ${payload.newRecord}');

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final previousHotspot = _hotspots.firstWhere(
        (h) => h['id'] == payload.newRecord['id'],
        orElse: () => {},
      );

      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
  *,
  crime_type: type_id (id, name, level, category, description),
  created_by_profile: created_by (id, name, email),
  reported_by_profile: reported_by (id, name, email),
  verifier_profile: verified_by (first_name, last_name)  // ← ADD THIS
''')
          .eq('id', payload.newRecord['id'])
          .single();

      print(
        'Fetched complete hotspot data: ${response['id']} - ${response['crime_type']?['name']}',
      );

      // Check if this is an auto-expiration
      final wasActive = previousHotspot['active_status'] == 'active';
      final isNowInactive = response['active_status'] == 'inactive';
      final hasExpirationTime = response['expires_at'] != null;

      if (wasActive && isNowInactive && hasExpirationTime) {
        _handleAutoExpiration(response, previousHotspot);
      }

      if (mounted) {
        setState(() {
          final index = _hotspots.indexWhere(
            (h) => h['id'] == payload.newRecord['id'],
          );

          final shouldShowForNonAdminOfficer = _shouldNonAdminOfficerSeeHotspot(
            response,
          );

          print(
            'Hotspot index: $index, Should show: $shouldShowForNonAdminOfficer, Is admin: $_hasAdminPermissions',
          );

          if (index != -1) {
            if (_hasAdminPermissions || shouldShowForNonAdminOfficer) {
              final crimeType = response['crime_type'] ?? {};
              _hotspots[index] = {
                ...response,
                'crime_type': {
                  'id': crimeType['id'] ?? response['type_id'],
                  'name': crimeType['name'] ?? 'Unknown',
                  'level': crimeType['level'] ?? 'unknown',
                  'category': crimeType['category'] ?? 'General',
                  'description': crimeType['description'],
                },
              };
              print('✅ Updated existing hotspot at index $index');
            } else {
              _hotspots.removeAt(index);
              print('Removed hotspot from non-admin view');
            }
          } else {
            // ✅ Only add if it doesn't exist
            if (_hasAdminPermissions || shouldShowForNonAdminOfficer) {
              final crimeType = response['crime_type'] ?? {};
              _hotspots.add({
                ...response,
                'crime_type': {
                  'id': crimeType['id'] ?? response['type_id'],
                  'name': crimeType['name'] ?? 'Unknown',
                  'level': crimeType['level'] ?? 'unknown',
                  'category': crimeType['category'] ?? 'General',
                  'description': crimeType['description'],
                },
              });
              print('Added new hotspot to list via update');
            }
          }
        });

        _handleStatusChangeMessages(previousHotspot, response);

        final wasVisible =
            previousHotspot['status'] == 'approved' &&
            previousHotspot['active_status'] == 'active';
        final isNowVisible =
            response['status'] == 'approved' &&
            response['active_status'] == 'active';

        if (wasVisible != isNowVisible ||
            previousHotspot['type_id'] != response['type_id'] ||
            previousHotspot['location'] != response['location']) {
          print('🔄 Heatmap affected by update - recalculating...');
          _updateHeatmapOnUpdate(response);
        }
      }
    } catch (e) {
      print('Error in _handleHotspotUpdate: $e');

      if (mounted) {
        setState(() {
          final index = _hotspots.indexWhere(
            (h) => h['id'] == payload.newRecord['id'],
          );
          if (index != -1) {
            _hotspots[index] = {
              ..._hotspots[index],
              ...payload.newRecord,
              'crime_type':
                  _hotspots[index]['crime_type'] ??
                  {
                    'id': payload.newRecord['type_id'],
                    'name': 'Unknown',
                    'level': 'unknown',
                    'category': 'General',
                    'description': null,
                  },
            };
            print('Fallback update applied');
          }
        });

        _updateHeatmapOnUpdate(payload.newRecord);
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        print('Forcing full reload due to update error');
        await _loadHotspots();
        _updateHeatmapOnUpdate({});
      }
    }
  }

  /// Handle auto-expiration notifications and UI updates
  void _handleAutoExpiration(
    Map<String, dynamic> expiredHotspot,
    Map<String, dynamic> previousData,
  ) {
    print('⏰ HOTSPOT AUTO-EXPIRED: ${expiredHotspot['id']}');

    final crimeTypeName =
        expiredHotspot['crime_type']?['name'] ?? 'Crime incident';

    // Show notification to admin
    if (_isAdmin || _isOfficer) {
      _showSnackBar(
        '$crimeTypeName investigation period has ended and is now inactive.',
      );
    }

    // Optional: Create a system notification
    _createExpirationNotification(expiredHotspot);

    // Update heatmap if needed
    print('🔄 Heatmap: Removing expired hotspot from active crimes...');
    _updateHeatmapOnUpdate(expiredHotspot);
  }

  /// Create a notification when hotspot expires
  Future<void> _createExpirationNotification(
    Map<String, dynamic> expiredHotspot,
  ) async {
    try {
      final notification = {
        'user_id': _userProfile?['id'],
        'title': 'Investigation Period Ended',
        'message':
            'The investigation for "${expiredHotspot['crime_type']?['name'] ?? 'crime incident'}" has automatically ended.',
        'type': 'expiration',
        'hotspot_id': expiredHotspot['id'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await Supabase.instance.client.from('notifications').insert(notification);
    } catch (e) {
      print('Error creating expiration notification: $e');
    }
  }

  /// Show remaining time until expiration in hotspot details
  String formatTimeRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return 'No expiration set';

    final now = DateTime.now();
    final remaining = expiresAt.difference(now);

    if (remaining.isNegative) {
      return 'Expired';
    }

    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h remaining';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
    } else {
      return '${remaining.inMinutes}m remaining';
    }
  }

  // HOTSPOT DELETE
  void _handleHotspotDelete(PostgresChangePayload payload) async {
    if (!mounted) return;

    final deletedHotspotId = payload.oldRecord['id'];

    print('🗑️ Handling hotspot deletion: $deletedHotspotId');

    // First, clean up clusters BEFORE updating local state
    await _cleanupClusterAfterCrimeDeletion(deletedHotspotId);

    // Small delay to ensure database operations complete
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      // Remove the hotspot from local state
      _hotspots.removeWhere((hotspot) => hotspot['id'] == deletedHotspotId);

      // Remove from heatmap dataset too
      _heatmapCrimes.removeWhere((crime) => crime['id'] == deletedHotspotId);

      // Remove any notifications related to this hotspot
      _notifications.removeWhere(
        (notification) => notification['hotspot_id'] == deletedHotspotId,
      );

      // Update unread notifications count
      _unreadNotificationCount = _notifications
          .where((n) => !n['is_read'])
          .length;
    });

    // Force reload clusters from database to ensure UI is in sync
    await _loadPersistentClusters();

    if (mounted) {
      setState(() {
        _heatmapClusters = _persistentClusters
            .where((pc) => pc['status'] == 'active')
            .map((pc) => _convertPersistentToDisplayCluster(pc))
            .toList();
        _checkProximityToHeatmaps();
      });
    }

    print('✅ Crime deletion and cluster cleanup completed');
    print('   Active clusters: ${_heatmapClusters.length}');
  }

  // ============================================
  // NEW: Cleanup clusters after crime deletion
  // ============================================
  Future<void> _cleanupClusterAfterCrimeDeletion(int deletedCrimeId) async {
    try {
      // Find all clusters containing this crime
      final clusterLinks = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('cluster_id')
          .eq('hotspot_id', deletedCrimeId);

      if ((clusterLinks as List).isEmpty) {
        print('Crime was not in any cluster');
        return;
      }

      // Remove the crime from junction table
      await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .delete()
          .eq('hotspot_id', deletedCrimeId);

      print('✅ Removed crime $deletedCrimeId from heatmap_cluster_crimes');

      // Check each affected cluster
      for (final link in clusterLinks) {
        final clusterId = link['cluster_id'];

        // Count remaining crimes in this cluster
        final remainingCrimes = await Supabase.instance.client
            .from('heatmap_cluster_crimes')
            .select('hotspot_id, is_still_active')
            .eq('cluster_id', clusterId);

        final crimeCount = (remainingCrimes as List).length;
        final activeCrimeCount = remainingCrimes
            .where((c) => c['is_still_active'] == true)
            .length;

        // Check if cluster should be deleted based on minimum crime requirements
        if (crimeCount == 0 || crimeCount < _minCrimesForCluster) {
          // Not enough crimes to maintain cluster - check special cases
          bool shouldDelete = true;

          if (crimeCount > 0) {
            // Fetch the remaining crimes to check severity
            final remainingCrimesData = await Supabase.instance.client
                .from('hotspot')
                .select('''
          id,
          type_id,
          crime_type: type_id (id, name, level, category, description)
        ''')
                .inFilter(
                  'id',
                  remainingCrimes.map((c) => c['hotspot_id']).toList(),
                );

            final criticalCount = (remainingCrimesData as List)
                .where((c) => c['crime_type']?['level'] == 'critical')
                .length;
            final highCount = remainingCrimesData
                .where((c) => c['crime_type']?['level'] == 'high')
                .length;

            // Check if remaining crimes meet minimum cluster requirements
            if (criticalCount >= 1 && crimeCount >= 2) {
              shouldDelete = false; // 1 critical + 1 other crime is enough
            } else if (highCount >= 2) {
              shouldDelete = false; // 2 high severity crimes is enough
            }
          }

          if (shouldDelete) {
            // Delete the cluster
            await Supabase.instance.client
                .from('heatmap_clusters')
                .delete()
                .eq('id', clusterId);

            print(
              '🗑️ Deleted cluster $clusterId (only $crimeCount crime(s) remaining - below minimum)',
            );

            // Remove from local state
            setState(() {
              _persistentClusters.removeWhere((c) => c['id'] == clusterId);
              _heatmapClusters = _persistentClusters
                  .where((pc) => pc['status'] == 'active')
                  .map((pc) => _convertPersistentToDisplayCluster(pc))
                  .toList();
            });

            return; // Exit early since cluster is deleted
          }
        }

        if (activeCrimeCount == 0) {
          // No active crimes left - deactivate cluster
          await Supabase.instance.client
              .from('heatmap_clusters')
              .update({
                'status': 'inactive',
                'deactivated_at': DateTime.now().toIso8601String(),
                'active_crime_count': 0,
                'total_crime_count': crimeCount,
              })
              .eq('id', clusterId);

          print('⏸️ Deactivated cluster $clusterId (no active crimes)');
        } else {
          // Still has crimes - recalculate cluster properties
          await _recalculateClusterAfterDeletion(clusterId);
        }
      }
    } catch (e) {
      print('Error cleaning up cluster after crime deletion: $e');
    }
  }

  // ============================================
  // NEW: Recalculate cluster after crime deletion
  // ============================================
  Future<void> _recalculateClusterAfterDeletion(String clusterId) async {
    try {
      // Fetch remaining crimes
      final crimeLinks = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('hotspot_id, is_still_active')
          .eq('cluster_id', clusterId);

      final hotspotIds = (crimeLinks as List)
          .map((link) => link['hotspot_id'])
          .toList();

      if (hotspotIds.isEmpty) return;

      final crimesResponse = await Supabase.instance.client
          .from('hotspot')
          .select('''
          id,
          type_id,
          location,
          time,
          status,
          active_status,
          created_by,
          reported_by,
          created_at,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .inFilter('id', hotspotIds);

      final allCrimes = (crimesResponse as List)
          .map((c) => _formatCrimeForHeatmap(c))
          .toList();

      final activeCrimes = allCrimes
          .where((c) => _isWithinHeatmapTimeWindow(c))
          .toList();

      if (activeCrimes.isEmpty) {
        // Deactivate cluster
        await Supabase.instance.client
            .from('heatmap_clusters')
            .update({
              'status': 'inactive',
              'deactivated_at': DateTime.now().toIso8601String(),
              'active_crime_count': 0,
              'total_crime_count': allCrimes.length,
            })
            .eq('id', clusterId);
        return;
      }

      // Recalculate properties with remaining crimes
      final clusterData = _calculateClusterProperties(activeCrimes);

      final reductionFactor = activeCrimes.length / allCrimes.length;
      final adjustedRadius = (clusterData['radius'] * reductionFactor).clamp(
        _severityRadiusConfig[clusterData['dominantSeverity']]!['min']!, // ⭐ CHANGED
        _severityRadiusConfig[clusterData['dominantSeverity']]!['max']!, // ⭐ CHANGED
      );

      await Supabase.instance.client
          .from('heatmap_clusters')
          .update({
            'center_lat': clusterData['center'].latitude,
            'center_lng': clusterData['center'].longitude,
            'current_radius': adjustedRadius,
            'dominant_severity': clusterData['dominantSeverity'],
            'intensity': clusterData['intensity'],
            'active_crime_count': activeCrimes.length,
            'total_crime_count': allCrimes.length,
            'last_recalculated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clusterId);

      print('✅ Recalculated cluster $clusterId after deletion');
      print(
        '   ${activeCrimes.length} active / ${allCrimes.length} total crimes',
      );
    } catch (e) {
      print('Error recalculating cluster after deletion: $e');
    }
  }

  // ============================================
  // HEATMAP UPDATE HELPER METHODS
  // ============================================

  void _updateHeatmapOnInsert(Map<String, dynamic> newCrime) async {
    print('🔥 _updateHeatmapOnInsert called for crime: ${newCrime['id']}');

    // Only add if approved
    if (newCrime['status'] != 'approved') {
      print('❌ Crime not approved - not adding to heatmap');
      return;
    }

    // Check if already exists in heatmap
    final existsInHeatmap = _heatmapCrimes.any(
      (c) => c['id'] == newCrime['id'],
    );
    if (existsInHeatmap) {
      print(
        '⚠️ Crime ${newCrime['id']} already in heatmap, triggering recalculation only',
      );
      _scheduleHeatmapUpdate();
      return;
    }

    // Fetch complete crime data to ensure we have crime_type
    try {
      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
          id,
          type_id,
          location,
          time,
          status,
          active_status,
          created_by,
          reported_by,
          created_at,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .eq('id', newCrime['id'])
          .single();

      final formattedCrime = _formatCrimeForHeatmap(response);

      // ✅ Check if crime falls within current date filter (if active)
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );

      final hasCustomDateRange =
          filterService.crimeStartDate != null ||
          filterService.crimeEndDate != null;

      bool shouldAddToHeatmap = true;

      // If date filter is active, check if crime is within range
      if (hasCustomDateRange) {
        final crimeTime = DateTime.tryParse(formattedCrime['time'] ?? '');

        if (crimeTime != null) {
          final isAfterStart =
              filterService.crimeStartDate == null ||
              crimeTime.isAfter(filterService.crimeStartDate!) ||
              crimeTime.isAtSameMomentAs(filterService.crimeStartDate!);

          final isBeforeEnd =
              filterService.crimeEndDate == null ||
              crimeTime.isBefore(filterService.crimeEndDate!) ||
              crimeTime.isAtSameMomentAs(filterService.crimeEndDate!);

          shouldAddToHeatmap = isAfterStart && isBeforeEnd;
        }
      }

      if (!shouldAddToHeatmap) {
        print(
          '⚠️ Crime ${newCrime['id']} outside current date filter range - not adding to heatmap display',
        );
        // Still process it for database, but don't show in current view
        return;
      }

      // Double-check it wasn't added during the async operation
      final stillNotInHeatmap = !_heatmapCrimes.any(
        (c) => c['id'] == newCrime['id'],
      );

      if (stillNotInHeatmap) {
        setState(() {
          _heatmapCrimes.add(formattedCrime);
        });

        print(
          '✅ Crime inserted into heatmap (${formattedCrime['crime_type']['name']}) '
          '${hasCustomDateRange ? "[Historical Mode]" : "[Live Mode]"}',
        );
      } else {
        print('⚠️ Crime was added to heatmap during fetch, skipping');
      }

      // ✅ Trigger cluster processing (will create cluster even in historical mode)
      _scheduleHeatmapUpdate();
    } catch (e) {
      print('Error fetching complete crime data for heatmap insert: $e');
      _scheduleHeatmapUpdate();
    }
  }

  // ============================================
  // MODIFIED: Update handler with time validation
  // ============================================
  void _updateHeatmapOnUpdate(Map<String, dynamic> updatedCrime) async {
    if (updatedCrime.isEmpty) {
      _scheduleHeatmapUpdate();
      return;
    }

    final crimeId = updatedCrime['id'];
    final index = _heatmapCrimes.indexWhere((c) => c['id'] == crimeId);

    try {
      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
          id,
          type_id,
          location,
          time,
          status,
          active_status,
          created_by,
          reported_by,
          created_at,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .eq('id', crimeId)
          .single();

      final formattedCrime = _formatCrimeForHeatmap(response);

      final shouldBeInHeatmap = formattedCrime['status'] == 'approved';

      if (shouldBeInHeatmap) {
        if (index != -1) {
          setState(() {
            _heatmapCrimes[index] = formattedCrime;
          });
          print(
            '✅ Updated crime in heatmap (${formattedCrime['crime_type']['name']})',
          );
        } else {
          setState(() {
            _heatmapCrimes.add(formattedCrime);
          });
          print(
            '✅ Added crime to heatmap after update (${formattedCrime['crime_type']['name']})',
          );
        }

        // ⭐ NEW: Update is_still_active status in clusters
        await _updateCrimeActiveStatusInClusters(formattedCrime);
      } else {
        if (index != -1) {
          setState(() {
            _heatmapCrimes.removeAt(index);
          });
          print('❌ Removed crime from heatmap (not approved)');
        }
      }

      _scheduleHeatmapUpdate();
    } catch (e) {
      print('Error fetching complete crime data for heatmap update: $e');
      _scheduleHeatmapUpdate();
    }
  }

  // ============================================
  // SIMPLIFIED: Update is_still_active and recalculate cluster
  // ============================================
  Future<void> _updateCrimeActiveStatusInClusters(
    Map<String, dynamic> crime,
  ) async {
    try {
      final crimeId = crime['id'];
      // ⭐ USE FILTER-AWARE CHECK
      final isStillActive = _isWithinHeatmapTimeWindow(crime);

      // Find which clusters contain this crime
      final clusterLinks = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('cluster_id, is_still_active')
          .eq('hotspot_id', crimeId);

      if ((clusterLinks as List).isEmpty) {
        print('Crime $crimeId not in any cluster');
        return;
      }

      // Update the is_still_active status
      await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .update({'is_still_active': isStillActive})
          .eq('hotspot_id', crimeId);

      print('✅ Updated is_still_active=$isStillActive for crime $crimeId');

      // Recalculate each affected cluster
      for (final link in clusterLinks) {
        final clusterId = link['cluster_id'];

        // Count active crimes in this cluster
        final activeCountResponse = await Supabase.instance.client
            .from('heatmap_cluster_crimes')
            .select('hotspot_id')
            .eq('cluster_id', clusterId)
            .eq('is_still_active', true);

        final activeCrimeCount = (activeCountResponse as List).length;

        // ⭐ CRITICAL: Keep active if at least 1 active crime
        if (activeCrimeCount >= 1) {
          // Fetch all crimes for full recalculation
          final allCrimeLinks = await Supabase.instance.client
              .from('heatmap_cluster_crimes')
              .select('hotspot_id')
              .eq('cluster_id', clusterId);

          final hotspotIds = (allCrimeLinks as List)
              .map((l) => l['hotspot_id'])
              .toList();

          final crimesResponse = await Supabase.instance.client
              .from('hotspot')
              .select('''
            id,
            type_id,
            location,
            time,
            status,
            active_status,
            created_by,
            reported_by,
            created_at,
            crime_type: type_id (id, name, level, category, description)
          ''')
              .inFilter('id', hotspotIds);

          final allCrimes = (crimesResponse as List)
              .map((c) => _formatCrimeForHeatmap(c))
              .toList();

          // Recalculate with all crimes (uses filter-aware _isWithinHeatmapTimeWindow)
          await _recalculateClusterProperties(clusterId, allCrimes);
        } else {
          // No active crimes - deactivate
          await Supabase.instance.client
              .from('heatmap_clusters')
              .update({
                'status': 'inactive',
                'deactivated_at': DateTime.now().toIso8601String(),
                'active_crime_count': 0,
              })
              .eq('id', clusterId);

          print('⏸️ Deactivated cluster $clusterId (no active crimes)');
        }
      }

      // Reload clusters to reflect changes
      await _loadPersistentClusters();

      if (mounted) {
        setState(() {
          _heatmapClusters = _persistentClusters
              .where((pc) => pc['status'] == 'active')
              .map((pc) => _convertPersistentToDisplayCluster(pc))
              .toList();
        });
      }
    } catch (e) {
      print('Error updating crime active status: $e');
    }
  }

  // ============================================
  // Delete handler (no changes needed)
  // ============================================

  // Centralized debounced update scheduler
  void _scheduleHeatmapUpdate() {
    _heatmapUpdateTimer?.cancel();
    _heatmapUpdateTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        print('♻️ Recalculating heatmap...');
        _calculateHeatmap();
      }
    });
  }

  // ============================================
  // PERIODIC CLUSTER MAINTENANCE
  // ============================================

  void _startPeriodicClusterMaintenance() {
    // Run every 5 minutes to check for crimes that expired
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      await _performClusterMaintenance();
    });

    // Also run once after 30 seconds on startup
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _performClusterMaintenance();
      }
    });
  }

  Future<void> _performClusterMaintenance() async {
    if (_persistentClusters.isEmpty) return;

    print('🔧 Running cluster maintenance...');

    Provider.of<HotspotFilterService>(context, listen: false);

    for (final cluster in _persistentClusters) {
      if (cluster['status'] != 'active') continue;

      try {
        // Get all crimes in this cluster
        final crimeLinks = await Supabase.instance.client
            .from('heatmap_cluster_crimes')
            .select('hotspot_id, is_still_active')
            .eq('cluster_id', cluster['id']);

        if ((crimeLinks as List).isEmpty) {
          // No crimes - delete cluster
          await Supabase.instance.client
              .from('heatmap_clusters')
              .delete()
              .eq('id', cluster['id']);
          continue;
        }

        final hotspotIds = crimeLinks
            .map((link) => link['hotspot_id'])
            .toList();

        // Fetch complete crime data
        final crimesResponse = await Supabase.instance.client
            .from('hotspot')
            .select('''
            id,
            type_id,
            location,
            time,
            status,
            active_status,
            created_by,
            reported_by,
            created_at,
            crime_type: type_id (id, name, level, category, description)
          ''')
            .inFilter('id', hotspotIds);

        final allCrimes = (crimesResponse as List)
            .map((c) => _formatCrimeForHeatmap(c))
            .toList();

        // Check each crime's active status
        bool hasChanges = false;
        for (final crime in allCrimes) {
          // ⭐ USE FILTER-AWARE CHECK
          final isActive = _isWithinHeatmapTimeWindow(crime);
          final currentLink = crimeLinks.firstWhere(
            (link) => link['hotspot_id'] == crime['id'],
            orElse: () => {},
          );

          if (currentLink['is_still_active'] != isActive) {
            // Update the status
            await Supabase.instance.client
                .from('heatmap_cluster_crimes')
                .update({'is_still_active': isActive})
                .eq('cluster_id', cluster['id'])
                .eq('hotspot_id', crime['id']);

            hasChanges = true;
            print('Updated crime ${crime['id']} active status to $isActive');
          }
        }

        if (hasChanges) {
          // Recalculate cluster properties
          await _recalculateClusterProperties(cluster['id'], allCrimes);
        }
      } catch (e) {
        print('Error in cluster maintenance for ${cluster['id']}: $e');
      }
    }

    // Reload clusters after maintenance
    await _loadPersistentClusters();

    if (mounted) {
      setState(() {
        _heatmapClusters = _persistentClusters
            .where((pc) => pc['status'] == 'active')
            .map((pc) => _convertPersistentToDisplayCluster(pc))
            .toList();
      });
    }

    print('✅ Cluster maintenance complete');
  }

  // ============================================
  // SIMPLIFIED: Just recalculate properties
  // ============================================
  Future<void> _recalculateClusterProperties(
    String clusterId,
    List<Map<String, dynamic>> allCrimes,
  ) async {
    try {
      // ⭐ USE FILTER-AWARE CHECK to determine active crimes
      final activeCrimes = allCrimes
          .where((c) => _isWithinHeatmapTimeWindow(c))
          .toList();

      print(
        'Recalculating cluster $clusterId: ${activeCrimes.length} active / ${allCrimes.length} total',
      );

      // Even if no active crimes, keep cluster alive (just update counts via trigger)
      if (activeCrimes.isEmpty) {
        print('⚠️ No active crimes but cluster remains (historical data)');

        if (mounted) {
          await _loadPersistentClusters();
          setState(() {
            _heatmapClusters = _persistentClusters
                .where((pc) => pc['status'] == 'active')
                .map((pc) => _convertPersistentToDisplayCluster(pc))
                .toList();
          });
        }

        return;
      }

      // ✅ Has active crimes - recalculate properties
      final clusterData = _calculateClusterProperties(activeCrimes);

      final reductionFactor = activeCrimes.length / allCrimes.length;
      final adjustedRadius = (clusterData['radius'] * reductionFactor).clamp(
        _severityRadiusConfig[clusterData['dominantSeverity']]!['min']!, // ⭐ CHANGED
        _severityRadiusConfig[clusterData['dominantSeverity']]!['max']!, // ⭐ CHANGED
      );

      await Supabase.instance.client
          .from('heatmap_clusters')
          .update({
            'center_lat': clusterData['center'].latitude,
            'center_lng': clusterData['center'].longitude,
            'current_radius': adjustedRadius,
            'dominant_severity': clusterData['dominantSeverity'],
            'intensity': clusterData['intensity'],
            'active_crime_count': activeCrimes.length,
            'total_crime_count': allCrimes.length,
            'last_recalculated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clusterId);

      print(
        '✅ Recalculated cluster $clusterId (${activeCrimes.length}/${allCrimes.length})',
      );

      if (mounted) {
        await _loadPersistentClusters();
        setState(() {
          _heatmapClusters = _persistentClusters
              .where((pc) => pc['status'] == 'active')
              .map((pc) => _convertPersistentToDisplayCluster(pc))
              .toList();
        });
      }
    } catch (e) {
      print('Error recalculating cluster properties: $e');
    }
  }

  void _handleStatusChangeMessages(
    Map<String, dynamic> previousHotspot,
    Map<String, dynamic> newHotspot,
  ) {
    final previousStatus = previousHotspot['status'] ?? 'approved';
    final newStatus = newHotspot['status'] ?? 'approved';
    final previousActiveStatus = previousHotspot['active_status'] ?? 'active';
    final newActiveStatus = newHotspot['active_status'] ?? 'active';
    final crimeType = newHotspot['crime_type']?['name'] ?? 'Unknown';

    // Status change messages
    if (newStatus != previousStatus) {
      if (newStatus == 'approved') {
        _showSnackBar('Crime report approved: $crimeType');
      } else if (newStatus == 'rejected') {
        _showSnackBar('Crime report rejected: $crimeType');
      }
    }

    // Active status change messages
    if (newActiveStatus != previousActiveStatus) {
      if (newActiveStatus == 'active') {
        _showSnackBar('Crime report activated: $crimeType');
      } else {
        _showSnackBar('Crime report deactivated: $crimeType');
      }
    }

    // Crime type change (this was missing!)
    final previousCrimeType = previousHotspot['crime_type']?['name'];
    final newCrimeType = newHotspot['crime_type']?['name'];
    if (previousCrimeType != null &&
        newCrimeType != null &&
        previousCrimeType != newCrimeType) {
      _showSnackBar('Crime type changed: $previousCrimeType → $newCrimeType');
    }
  }

  Future<void> _handlePhotoUpdates({
    required int hotspotId,
    required Map<String, dynamic>? existingPhoto,
    required XFile? newPhoto,
    required bool deleteExisting,
  }) async {
    try {
      // If user wants to delete existing photo
      if (deleteExisting && existingPhoto != null) {
        await PhotoService.deletePhoto(existingPhoto);
        print('Existing photo deleted for hotspot $hotspotId');
      }

      // If user selected a new photo
      if (newPhoto != null) {
        // If there's an existing photo and we're not explicitly deleting it, delete it first
        if (existingPhoto != null && !deleteExisting) {
          await PhotoService.deletePhoto(existingPhoto);
          print('Replaced existing photo for hotspot $hotspotId');
        }

        // Upload new photo
        await PhotoService.uploadPhoto(
          imageFile: newPhoto,
          hotspotId: hotspotId,
          userId: _userProfile!['id'],
        );
        print('New photo uploaded for hotspot $hotspotId');
      }
    } catch (e) {
      print('Error handling photo updates: $e');
      throw Exception('Failed to update photos: $e');
    }
  }

  // 3. Build edit photo section widget
  Widget _buildEditPhotoSection({
    required Map<String, dynamic>? existingPhoto,
    required XFile? newSelectedPhoto,
    required bool isUploadingPhoto,
    required bool deleteExistingPhoto,
    required Function(XFile?, bool) onPhotoChanged,
    required Function(bool) onDeleteExistingToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo Management',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          // Show existing photo if available and not marked for deletion
          if (existingPhoto != null &&
              !deleteExistingPhoto &&
              newSelectedPhoto == null) ...[
            const Text(
              'Current Photo:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      existingPhoto['photo_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('Error loading image'));
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () {
                        onDeleteExistingToggle(true);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Show new selected photo
          if (newSelectedPhoto != null) ...[
            const Text(
              'New Photo:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            newSelectedPhoto.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Error loading image'),
                              );
                            },
                          )
                        : Image.file(
                            File(newSelectedPhoto.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Error loading image'),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () {
                        onPhotoChanged(null, false);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Photo action buttons
          if (newSelectedPhoto == null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploadingPhoto
                        ? null
                        : () async {
                            onPhotoChanged(null, true);
                            try {
                              final photo = await PhotoService.pickImage();
                              onPhotoChanged(photo, false);
                              if (photo != null) {
                                onDeleteExistingToggle(
                                  false,
                                ); // Reset delete flag
                              }
                            } catch (e) {
                              onPhotoChanged(null, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error taking photo: $e'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploadingPhoto
                        ? null
                        : () async {
                            onPhotoChanged(null, true);
                            try {
                              final photo =
                                  await PhotoService.pickImageFromGallery();
                              onPhotoChanged(photo, false);
                              if (photo != null) {
                                onDeleteExistingToggle(
                                  false,
                                ); // Reset delete flag
                              }
                            } catch (e) {
                              onPhotoChanged(null, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error selecting photo: $e'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],

          if (isUploadingPhoto)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  bool shouldShowForNonAdminOfficer(Map<String, dynamic> hotspot) {
    final currentUserId = _userProfile?['id'];
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    final createdBy = hotspot['created_by'];
    final reportedBy = hotspot['reported_by'];

    // User's own hotspots (always visible to them)
    final isOwnHotspot =
        currentUserId != null &&
        (currentUserId == createdBy || currentUserId == reportedBy);

    if (isOwnHotspot) {
      return true;
    }

    // Only show approved hotspots to public
    if (status != 'approved') {
      return false;
    }

    // For approved hotspots: show active ones always
    if (activeStatus == 'active') {
      return true;
    }

    // For approved inactive: show only if within 30 days (based on incident time)
    if (activeStatus == 'inactive') {
      final incidentTime = DateTime.tryParse(hotspot['time'] ?? '');
      if (incidentTime != null) {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        return incidentTime.isAfter(thirtyDaysAgo);
      }
      return false; // If no incident time, don't show
    }

    return false;
  }

  Future<void> _cleanupOrphanedNotifications() async {
    try {
      // Get all hotspot IDs
      final hotspots = await Supabase.instance.client
          .from('hotspot')
          .select('id');

      final hotspotIds = hotspots.map((h) => h['id']).toList();

      // Delete notifications for non-existent hotspots
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .not('hotspot_id', 'in', hotspotIds.isEmpty ? [''] : hotspotIds);

      // Refresh notifications
      await _loadNotifications();
    } catch (e) {
      print('Error cleaning up notifications: $e');
    }
  }

  Future<void> _loadHotspots() async {
    try {
      // Start building the query with proper crime type data
      final query = Supabase.instance.client.from('hotspot').select('''
        *,
        crime_type: type_id (id, name, level, category, description)
      ''');

      // Apply filters based on admin/officer status
      PostgrestFilterBuilder filteredQuery;
      if (!_hasAdminPermissions) {
        print('Filtering hotspots for non-admin/officer user');
        final currentUserId = _userProfile?['id'];

        // Calculate 30 days ago (based on incident time, not report time)
        final thirtyDaysAgo = DateTime.now()
            .subtract(const Duration(days: 30))
            .toUtc()
            .toIso8601String();

        if (currentUserId != null) {
          // For non-admins/officers, show:
          // 1. All approved active hotspots
          // 2. Approved inactive hotspots created within last 30 days
          // 3. User's own reports (regardless of status and active_status)
          filteredQuery = query.or(
            'and(active_status.eq.active,status.eq.approved),'
            'and(active_status.eq.inactive,status.eq.approved,created_at.gte.$thirtyDaysAgo),'
            'created_by.eq.$currentUserId,'
            'reported_by.eq.$currentUserId',
          );
        } else {
          // If user ID is null, show:
          // 1. Approved active hotspots
          // 2. Approved inactive hotspots within 30 days
          filteredQuery = query.or(
            'and(active_status.eq.active,status.eq.approved),'
            'and(active_status.eq.inactive,status.eq.approved,created_at.gte.$thirtyDaysAgo)',
          );
        }
      } else {
        print('Admin/Officer user - loading all hotspots');
        filteredQuery = query;
      }

      // Add ordering after filtering
      final orderedQuery = filteredQuery.order('time', ascending: false);

      // Execute the query
      final response = await orderedQuery;

      if (mounted) {
        setState(() {
          _hotspots = List<Map<String, dynamic>>.from(response).map((hotspot) {
            // Ensure proper crime_type structure for each hotspot
            final crimeType = hotspot['crime_type'] ?? {};
            return {
              ...hotspot,
              'crime_type': {
                'id': crimeType['id'] ?? hotspot['type_id'],
                'name': crimeType['name'] ?? 'Unknown',
                'level': crimeType['level'] ?? 'unknown',
                'category': crimeType['category'] ?? 'General',
                'description': crimeType['description'],
              },
            };
          }).toList();

          print('Loaded ${_hotspots.length} hotspots');
          if (_hasAdminPermissions) {
            final inactiveCount = _hotspots
                .where((h) => h['active_status'] == 'inactive')
                .length;
            print('Inactive hotspots count: $inactiveCount');
          } else {
            final inactiveCount = _hotspots
                .where((h) => h['active_status'] == 'inactive')
                .length;
            print(
              'Approved inactive hotspots (within 30 days) visible to public: $inactiveCount',
            );
          }
        });
      }
    } catch (e) {
      print('Error loading hotspots: $e');
      if (mounted) {
        _showSnackBar('Error loading hotspots: ${e.toString()}');
      }
    }
  }

  // ============================================
  // LOAD HEATMAP SETTINGS FROM DATABASE
  // ============================================
  Future<void> _loadHeatmapSettings() async {
    try {
      print('📊 Loading heatmap settings from database...');

      final settings = await _heatmapSettings.getAllSettings();

      if (!mounted) return;

      setState(() {
        // Distance settings
        _clusterMergeDistance =
            settings['cluster_merge_distance']?.toDouble() ?? 500.0;
        _minCrimesForCluster = settings['min_crimes_for_cluster'] ?? 3;
        _proximityAlertDistance =
            settings['proximity_alert_distance']?.toDouble() ?? 500.0;

        // Time windows
        _severityTimeWindows = {
          'critical': settings['time_window_critical'] ?? 120,
          'high': settings['time_window_high'] ?? 90,
          'medium': settings['time_window_medium'] ?? 60,
          'low': settings['time_window_low'] ?? 30,
        };

        // Weights
        _severityWeights = {
          'critical': settings['weight_critical']?.toDouble() ?? 1.0,
          'high': settings['weight_high']?.toDouble() ?? 0.75,
          'medium': settings['weight_medium']?.toDouble() ?? 0.5,
          'low': settings['weight_low']?.toDouble() ?? 0.25,
        };

        // Radius configs
        _severityRadiusConfig = {
          'critical': {
            'base': settings['radius_critical_base']?.toDouble() ?? 400.0,
            'min': settings['radius_critical_min']?.toDouble() ?? 500.0,
            'max': settings['radius_critical_max']?.toDouble() ?? 2500.0,
            'countMultiplier':
                settings['radius_critical_count_multiplier']?.toDouble() ??
                30.0,
            'intensityMultiplier':
                settings['radius_critical_intensity_multiplier']?.toDouble() ??
                80.0,
          },
          'high': {
            'base': settings['radius_high_base']?.toDouble() ?? 300.0,
            'min': settings['radius_high_min']?.toDouble() ?? 400.0,
            'max': settings['radius_high_max']?.toDouble() ?? 1800.0,
            'countMultiplier':
                settings['radius_high_count_multiplier']?.toDouble() ?? 25.0,
            'intensityMultiplier':
                settings['radius_high_intensity_multiplier']?.toDouble() ??
                60.0,
          },
          'medium': {
            'base': settings['radius_medium_base']?.toDouble() ?? 250.0,
            'min': settings['radius_medium_min']?.toDouble() ?? 300.0,
            'max': settings['radius_medium_max']?.toDouble() ?? 1200.0,
            'countMultiplier':
                settings['radius_medium_count_multiplier']?.toDouble() ?? 20.0,
            'intensityMultiplier':
                settings['radius_medium_intensity_multiplier']?.toDouble() ??
                50.0,
          },
          'low': {
            'base': settings['radius_low_base']?.toDouble() ?? 200.0,
            'min': settings['radius_low_min']?.toDouble() ?? 250.0,
            'max': settings['radius_low_max']?.toDouble() ?? 800.0,
            'countMultiplier':
                settings['radius_low_count_multiplier']?.toDouble() ?? 15.0,
            'intensityMultiplier':
                settings['radius_low_intensity_multiplier']?.toDouble() ?? 40.0,
          },
        };
      });

      print('✅ Heatmap settings loaded successfully');
      print('   Cluster merge distance: $_clusterMergeDistance m');
      print('   Min crimes for cluster: $_minCrimesForCluster');
      print('   Proximity alert distance: $_proximityAlertDistance m');
    } catch (e) {
      print('❌ Error loading heatmap settings: $e');
      // Keep default values already set
      if (mounted) {
        setState(() {
          // Mark as loaded even on error to prevent blocking
        });
      }
    }
  }

  // Alternative safer approach - separate queries for different cases

  void _moveToCurrentLocation() {
    if (_currentPosition != null && mounted) {
      // Check if MapController is ready before using it
      try {
        _mapController.move(_currentPosition!, 15.5);
        setState(() {
          _locationButtonPressed = true;
        });

        // Reset the button state after animation
        Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _locationButtonPressed = false;
            });
          }
        });
      } catch (e) {
        // If MapController isn't ready, wait and try again
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPosition != null) {
            try {
              _mapController.move(_currentPosition!, 15.5);
              setState(() {
                _locationButtonPressed = true;
              });

              Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _locationButtonPressed = false;
                  });
                }
              });
            } catch (e) {
              _showSnackBar('Unable to center map on location');
            }
          }
        });
      }
    } else if (_currentPosition == null) {
      _showSnackBar('Location not available yet');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        _showSnackBar('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Location permissions are permanently denied');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        // REMOVE THIS LINE: _mapController.move(_currentPosition!, 15.5);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  void _startLiveLocation() {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings,
        ).listen(
          (Position position) {
            if (mounted) {
              final newPosition = LatLng(position.latitude, position.longitude);

              // Only update if the position has actually changed significantly
              if (_currentPosition == null ||
                  _calculateDistance(_currentPosition!, newPosition) > 10) {
                // Increased to 10m to reduce API calls

                final oldPosition = _currentPosition;
                setState(() {
                  _currentPosition = newPosition;
                  _isLoading = false;
                });

                // CRITICAL: Update route if we have an active route and moved significantly
                if (_hasActiveRoute &&
                    _destination != null &&
                    oldPosition != null) {
                  // Only update route if we've moved more than 20 meters to avoid excessive API calls
                  if (_calculateDistance(oldPosition, newPosition) > 20) {
                    _updateRouteProgress();
                  }
                }
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              if (!error.toString().contains('TimeoutException') &&
                  !error.toString().contains('Time limit reached')) {
                _showSnackBar('Location error: ${error.toString()}');
              }
            }
          },
        );

    _startProximityMonitoring();
  }

  void _clearDirections() {
    _routeUpdateTimer?.cancel();
    setState(() {
      _routePoints.clear();
      _distance = 0;
      _duration = '';
      _destination = null;
      _hasActiveRoute = false;
      _routeWasCalculatedAsSafe = false; // RESET THE FLAG
      _tempPinnedLocation = null;
    });
  }

  void _startRouteUpdates() {
    _routeUpdateTimer?.cancel();
    // Reduced from 10 seconds to 5 seconds for more responsive route following
    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasActiveRoute && _destination != null && _currentPosition != null) {
        _updateRouteProgress();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _updateRouteProgress() async {
    if (_currentPosition == null || _destination == null || !_hasActiveRoute) {
      return;
    }

    try {
      // CRITICAL FIX: Check if this is a safe route vs regular route
      final isUsingSafeRoute = _routeWasCalculatedAsSafe; // Add this flag

      List<LatLng> newRoute;

      if (isUsingSafeRoute) {
        // For safe routes: Recalculate with safety considerations
        newRoute = await _recalculateSafeRoute(
          _currentPosition!,
          _destination!,
        );
      } else {
        // For regular routes: Use standard recalculation
        newRoute = await _getRouteFromAPI(_currentPosition!, _destination!);
      }

      // Calculate remaining distance and time using the new safe route
      final distance = _calculateRouteDistance(newRoute);
      final duration = _estimateRouteDuration(distance);

      if (mounted) {
        setState(() {
          _routePoints = newRoute;
          _distance = distance / 1000;
          _duration = _formatDuration(duration);
        });

        // Check if arrived (less than 50 meters)
        if (distance < 50) {
          _showSnackBar('You have arrived at your destination!');
          _clearDirections();
        }
      }
    } catch (e) {
      print('Error updating route progress: $e');
      // Don't update route if there's an error - keep the existing safe route
    }
  }

  // NEW: Flag to track if current route was calculated for safety
  bool _routeWasCalculatedAsSafe = false;

  // NEW: Recalculate safe route from current position
  Future<List<LatLng>> _recalculateSafeRoute(
    LatLng start,
    LatLng destination,
  ) async {
    try {
      // First check if the direct route from current position is already safe
      final directRoute = await _getRouteFromAPI(start, destination);
      final unsafeSegments = _findUnsafeSegments(directRoute);

      // If direct route is safe now, use it
      if (unsafeSegments.isEmpty) {
        print('Direct route from current position is now safe');
        return directRoute;
      }

      // If still unsafe, apply safety strategies from current position
      print(
        'Recalculating safe route from current position: ${unsafeSegments.length} unsafe segments',
      );
      return await _findBestSafeRoute(start, destination, unsafeSegments);
    } catch (e) {
      print('Error recalculating safe route: $e');
      // Fallback: try to get any route
      return await _getRouteFromAPI(start, destination);
    }
  }

  Future<void> _getDirections(LatLng destination) async {
    if (_currentPosition == null) return;

    // NOW set the destination when user explicitly chooses to navigate
    setState(() {
      _destination = destination;
      _destinationFromSearch = false;
      _routeWasCalculatedAsSafe = false; // CLEAR THE FLAG for regular routes
      _tempPinnedLocation = null;
    });

    // Rest of your existing _getDirections code remains the same...
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${_currentPosition!.longitude},${_currentPosition!.latitude};'
              '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
            ),
            headers: {'User-Agent': 'YourAppName/1.0'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Route request timed out',
              const Duration(seconds: 15),
            ),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          _showSnackBar('No route found to destination');
          return;
        }

        final route = data['routes'][0];
        final distance = _safeParseDouble(route['distance']) ?? 0.0;
        final duration = _safeParseDouble(route['duration']) ?? 0.0;

        List<LatLng> routePoints = [];
        try {
          final coordinates = route['geometry']?['coordinates'] as List?;
          if (coordinates != null) {
            routePoints = coordinates.map((coord) {
              final coordList = coord as List;
              final lng = _safeParseDouble(coordList[0]) ?? 0.0;
              final lat = _safeParseDouble(coordList[1]) ?? 0.0;
              return LatLng(lat, lng);
            }).toList();
          }
        } catch (e) {
          print('Error parsing route coordinates: $e');
          _showSnackBar('Error processing route data');
          return;
        }

        if (mounted) {
          setState(() {
            _distance = distance / 1000;
            _duration = _formatDuration(duration);
            _routePoints = routePoints;
            _hasActiveRoute = true;
          });

          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(_currentPosition!, destination),
              padding: const EdgeInsets.all(50.0),
            ),
          );

          _startRouteUpdates();
        }
      } else {
        print('Directions API returned status: ${response.statusCode}');
        _showSnackBar('Failed to get directions (${response.statusCode})');
      }
    } catch (e) {
      print('Directions error: $e');
      _showSnackBar('Failed to get directions: ${e.toString()}');
    }
  }

  // Helper method to safely parse numbers that might be int or double
  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Updated _formatDuration to handle the double properly
  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) {
      return 'Unknown duration';
    }

    final duration = Duration(seconds: seconds.round());
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showHotspotFilterDialog() {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      // Show centered dialog on desktop/web
      showDialog(
        context: context,
        builder: (context) {
          return HotspotFilterDialogDesktop(
            userProfile: _userProfile,
            buildFilterToggle: _buildFilterToggle,
          );
        },
      );
    } else {
      // Show bottom sheet on mobile
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              top: 25.0, // Add top padding to the modal itself
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Consumer<HotspotFilterService>(
              builder: (context, filterService, child) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    bool isShowingCrimes = filterService.isShowingCrimes;

                    return GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        // Detect swipe direction
                        if (details.delta.dx < -5 && isShowingCrimes) {
                          // Right-to-left swipe: switch to Safe Spots
                          setModalState(() {
                            filterService.setFilterMode(false);
                          });
                        } else if (details.delta.dx > 5 && !isShowingCrimes) {
                          // Left-to-right swipe: switch to Crimes
                          setModalState(() {
                            filterService.setFilterMode(true);
                          });
                        }
                      },
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            24.0,
                            16.0,
                            16.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with toggle
                              Row(
                                children: [
                                  Text(
                                    isShowingCrimes
                                        ? 'Filter Crimes'
                                        : 'Safe Spots',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Toggle button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              filterService.setFilterMode(
                                                true,
                                              ); // Show crimes
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isShowingCrimes
                                                  ? Colors.red.shade600
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.warning_rounded,
                                                  size: 16,
                                                  color: isShowingCrimes
                                                      ? Colors.white
                                                      : Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Crimes',
                                                  style: TextStyle(
                                                    color: isShowingCrimes
                                                        ? Colors.white
                                                        : Colors.grey.shade600,
                                                    fontWeight: isShowingCrimes
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              filterService.setFilterMode(
                                                false,
                                              ); // Show safe spots
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: !isShowingCrimes
                                                  ? Colors.green.shade600
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.shield_rounded,
                                                  size: 16,
                                                  color: !isShowingCrimes
                                                      ? Colors.white
                                                      : Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Safe Spots',
                                                  style: TextStyle(
                                                    color: !isShowingCrimes
                                                        ? Colors.white
                                                        : Colors.grey.shade600,
                                                    fontWeight: !isShowingCrimes
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Time Frame section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Time Frame',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Date Range Row
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    filterService.startDate ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime.now(),
                                              );
                                              if (date != null) {
                                                filterService.setStartDate(
                                                  date,
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      filterService.startDate !=
                                                          null
                                                      ? Colors.blue.shade300
                                                      : Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color:
                                                    filterService.startDate !=
                                                        null
                                                    ? Colors.blue.shade50
                                                    : Colors.white,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color:
                                                        filterService
                                                                .startDate !=
                                                            null
                                                        ? Colors.blue.shade600
                                                        : Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      filterService.startDate !=
                                                              null
                                                          ? '${filterService.startDate!.day}/${filterService.startDate!.month}/${filterService.startDate!.year}'
                                                          : 'Start Date',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            filterService
                                                                    .startDate !=
                                                                null
                                                            ? Colors
                                                                  .blue
                                                                  .shade700
                                                            : Colors
                                                                  .grey
                                                                  .shade600,
                                                        fontWeight:
                                                            filterService
                                                                    .startDate !=
                                                                null
                                                            ? FontWeight.w500
                                                            : FontWeight.normal,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Container(
                                            width: 20,
                                            height: 1,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    filterService.endDate ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime.now(),
                                              );
                                              if (date != null) {
                                                filterService.setEndDate(date);
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      filterService.endDate !=
                                                          null
                                                      ? Colors.blue.shade300
                                                      : Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color:
                                                    filterService.endDate !=
                                                        null
                                                    ? Colors.blue.shade50
                                                    : Colors.white,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color:
                                                        filterService.endDate !=
                                                            null
                                                        ? Colors.blue.shade600
                                                        : Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      filterService.endDate !=
                                                              null
                                                          ? '${filterService.endDate!.day}/${filterService.endDate!.month}/${filterService.endDate!.year}'
                                                          : 'End Date',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            filterService
                                                                    .endDate !=
                                                                null
                                                            ? Colors
                                                                  .blue
                                                                  .shade700
                                                            : Colors
                                                                  .grey
                                                                  .shade600,
                                                        fontWeight:
                                                            filterService
                                                                    .endDate !=
                                                                null
                                                            ? FontWeight.w500
                                                            : FontWeight.normal,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Clear dates option - bottom right
                                  if (filterService.startDate != null ||
                                      filterService.endDate != null) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              filterService.setStartDate(null);
                                              filterService.setEndDate(null);
                                            },
                                            child: Text(
                                              'Clear dates',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Dynamic content based on toggle
                              if (isShowingCrimes) ...[
                                // CRIMES FILTERS
                                // Severity filters
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    'Severity',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildFilterToggle(
                                  context,
                                  'Critical',
                                  FontAwesomeIcons.exclamationTriangle,
                                  const Color.fromARGB(255, 219, 0, 0),
                                  filterService.showCritical,
                                  (value) => filterService.toggleCritical(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'High',
                                  Icons.priority_high,
                                  const Color.fromARGB(255, 223, 106, 11),
                                  filterService.showHigh,
                                  (value) => filterService.toggleHigh(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Medium',
                                  Icons.remove,
                                  const Color.fromARGB(167, 116, 66, 9),
                                  filterService.showMedium,
                                  (value) => filterService.toggleMedium(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Low',
                                  Icons.low_priority,
                                  const Color.fromARGB(255, 216, 187, 23),
                                  filterService.showLow,
                                  (value) => filterService.toggleLow(),
                                ),
                                const SizedBox(height: 16),

                                // Category filters
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    'Categories',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildFilterToggle(
                                  context,
                                  'Violent',
                                  FontAwesomeIcons.triangleExclamation,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showViolent,
                                  (value) => filterService.toggleViolent(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Property',
                                  FontAwesomeIcons.bagShopping,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showProperty,
                                  (value) => filterService.toggleProperty(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Drug',
                                  FontAwesomeIcons.cannabis,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showDrug,
                                  (value) => filterService.toggleDrug(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Public Order',
                                  Icons.balance,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showPublicOrder,
                                  (value) => filterService.togglePublicOrder(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Financial',
                                  Icons.attach_money,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showFinancial,
                                  (value) => filterService.toggleFinancial(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Traffic',
                                  Icons.traffic,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showTraffic,
                                  (value) => filterService.toggleTraffic(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Alerts',
                                  Icons.campaign,
                                  const Color.fromARGB(255, 139, 96, 96),
                                  filterService.showAlerts,
                                  (value) => filterService.toggleAlerts(),
                                ),

                                const SizedBox(height: 16),

                                // Status filters (only for logged-in users)
                                if (_userProfile != null) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFilterToggle(
                                    context,
                                    'Pending',
                                    Icons.hourglass_empty,
                                    Colors.deepPurple,
                                    filterService.showPending,
                                    (value) => filterService.togglePending(),
                                  ),
                                  _buildFilterToggle(
                                    context,
                                    'Rejected',
                                    Icons.cancel_outlined,
                                    Colors.red,
                                    filterService.showRejected,
                                    (value) => filterService.toggleRejected(),
                                  ),

                                  // Active/Inactive filters (for admin, officer, and regular users)
                                  if (_userProfile?['role'] == 'admin' ||
                                      _userProfile?['role'] == 'officer' ||
                                      _userProfile?['role'] == 'user') ...[
                                    _buildFilterToggle(
                                      context,
                                      'Active',
                                      Icons.check_circle_outline,
                                      Colors.green,
                                      filterService.showActive,
                                      (value) => filterService.toggleActive(),
                                    ),
                                    _buildFilterToggle(
                                      context,
                                      'Inactive',
                                      Icons.pause_circle_outline,
                                      Colors.grey,
                                      filterService.showInactive,
                                      (value) => filterService.toggleInactive(),
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                ],
                              ] else ...[
                                // SAFE SPOTS FILTERS
                                // Safe Spot Types
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    'Safe Spot Types',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildFilterToggle(
                                  context,
                                  'Police Station',
                                  Icons.local_police,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showPoliceStations,
                                  (value) =>
                                      filterService.togglePoliceStations(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Government Building',
                                  Icons.account_balance,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showGovernmentBuildings,
                                  (value) =>
                                      filterService.toggleGovernmentBuildings(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Hospital',
                                  Icons.local_hospital,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showHospitals,
                                  (value) => filterService.toggleHospitals(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'School',
                                  Icons.school,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showSchools,
                                  (value) => filterService.toggleSchools(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Shopping Mall',
                                  Icons.store,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showShoppingMalls,
                                  (value) =>
                                      filterService.toggleShoppingMalls(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Well-lit Area',
                                  Icons.lightbulb,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showWellLitAreas,
                                  (value) => filterService.toggleWellLitAreas(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Security Camera',
                                  Icons.security,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showSecurityCameras,
                                  (value) =>
                                      filterService.toggleSecurityCameras(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Fire Station',
                                  Icons.local_fire_department,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showFireStations,
                                  (value) => filterService.toggleFireStations(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Religious Building',
                                  Icons.church,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showReligiousBuildings,
                                  (value) =>
                                      filterService.toggleReligiousBuildings(),
                                ),
                                _buildFilterToggle(
                                  context,
                                  'Community Center',
                                  Icons.group,
                                  const Color.fromARGB(255, 96, 139, 109),
                                  filterService.showCommunityCenters,
                                  (value) =>
                                      filterService.toggleCommunityCenters(),
                                ),

                                const SizedBox(height: 16),

                                // Safe Spot Status filters (only for logged-in users)
                                if (_userProfile != null) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFilterToggle(
                                    context,
                                    'Pending',
                                    Icons.hourglass_empty,
                                    Colors.deepPurple,
                                    filterService.showSafeSpotsPending,
                                    (value) =>
                                        filterService.toggleSafeSpotsPending(),
                                  ),
                                  _buildFilterToggle(
                                    context,
                                    'Approved',
                                    Icons.check_circle_outline,
                                    Colors.green,
                                    filterService.showSafeSpotsApproved,
                                    (value) =>
                                        filterService.toggleSafeSpotsApproved(),
                                  ),
                                  _buildFilterToggle(
                                    context,
                                    'Rejected',
                                    Icons.cancel_outlined,
                                    Colors.red,
                                    filterService.showSafeSpotsRejected,
                                    (value) =>
                                        filterService.toggleSafeSpotsRejected(),
                                  ),

                                  const SizedBox(height: 16),

                                  // Verification filters
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Verification',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFilterToggle(
                                    context,
                                    'Verified',
                                    Icons.verified,
                                    Colors.blue.shade600,
                                    filterService.showVerifiedSafeSpots,
                                    (value) =>
                                        filterService.toggleVerifiedSafeSpots(),
                                  ),
                                  _buildFilterToggle(
                                    context,
                                    'Unverified',
                                    Icons.help_outline,
                                    Colors.grey.shade600,
                                    filterService.showUnverifiedSafeSpots,
                                    (value) => filterService
                                        .toggleUnverifiedSafeSpots(),
                                  ),

                                  const SizedBox(height: 16),
                                ],
                              ],

                              // Close button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      );
    }
  }

  Widget _buildFilterToggle(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged, activeColor: color),
        ],
      ),
    );
  }

  void _showLocationOptions(LatLng position) async {
    String locationName = "Loading location...";
    final isDesktop = _isDesktopScreen();

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        locationName =
            data['display_name'] ??
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      }
    } catch (e) {
      locationName =
          "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) {
          return LocationOptionsDialogDesktop(
            locationName: locationName,
            isAdmin: _hasAdminPermissions,
            userProfile: _userProfile,
            distance: _distance,
            duration: _duration,
            onGetDirections: () => _getDirections(position),
            onGetSafeRoute: () => _getSafeRoute(position),
            onShareLocation: () => _shareLocation(position),
            onReportHotspot: () => _showReportHotspotForm(position),
            onAddHotspot: () => _showAddHotspotForm(position),
            onAddSafeSpot: () => _navigateToSafeSpotForm(position),
            // Add this callback for save points
            onCreateSavePoint: () {
              AddSavePointScreen.showAddSavePointForm(
                context: context,
                userProfile: _userProfile,
                initialLocation: position,
                onUpdate: () {
                  print('onUpdate: Reloading save points...');
                  _loadSavePoints(); // Reload save points to update _savePoints
                  setState(() {}); // Ensure the UI rebuilds
                },
              );
            },
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    locationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions),
                  title: const Text('Get Regular Route'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _tempPinnedLocation = null; // Clear temp pin
                    });
                    _getDirections(position);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.safety_check, color: Colors.green),
                  title: const Text('Get Safe Route'),
                  subtitle: const Text('Avoids reported hotspots'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _tempPinnedLocation = null; // Clear temp pin
                    });
                    _getSafeRoute(position);
                  },
                ),

                // === TEMPORARILY DISABLED: Report Crime for regular users ===
                /*
                if (!_hasAdminPermissions && _userProfile != null)
                  FutureBuilder<int>(
                    future: _getDailyReportCount(),
                    builder: (context, snapshot) {
                      final dailyCount = snapshot.data ?? 0;
                      final canReport = dailyCount < 5;

                      return ListTile(
                        leading: Icon(
                          Icons.report,
                          color: canReport ? Colors.orange : Colors.grey,
                        ),
                        title: const Text('Report Crime'),
                        subtitle: Text(
                          canReport
                              ? 'Submit for admin approval ($dailyCount/5 today)'
                              : 'Daily limit reached (5/5)',
                        ),
                        enabled: canReport,
                        onTap: canReport
                            ? () {
                                Navigator.pop(context);
                                setState(() {
                                  _tempPinnedLocation = null; // Clear temp pin
                                });
                                _showReportHotspotForm(position);
                              }
                            : null,
                      );
                    },
                  ),
                */
                if (_hasAdminPermissions)
                  ListTile(
                    leading: const Icon(Icons.add_location_alt),
                    title: const Text('Add Crime Incident'),
                    subtitle: const Text('Immediately published'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _tempPinnedLocation = null; // Clear temp pin
                      });
                      _showAddHotspotForm(position);
                    },
                  ),

                if (_userProfile != null)
                  ListTile(
                    leading: const Icon(Icons.safety_check, color: Colors.blue),
                    title: const Text('Add Safe Spot'),
                    subtitle: const Text('Mark this as a safe location'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _tempPinnedLocation = null; // Clear temp pin
                      });
                      _navigateToSafeSpotForm(position);
                    },
                  ),

                if (_userProfile != null)
                  ListTile(
                    leading: const Icon(
                      Icons.bookmark_add,
                      color: Colors.purple,
                    ),
                    title: const Text('Save This Location'),
                    subtitle: const Text('Bookmark for quick navigation'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _tempPinnedLocation = null; // Clear temp pin
                      });
                      AddSavePointScreen.showAddSavePointForm(
                        context: context,
                        userProfile: _userProfile,
                        initialLocation: position,
                        onUpdate: () {
                          print('onUpdate: Reloading save points...');
                          _loadSavePoints(); // Reload save points to update _savePoints
                          setState(() {}); // Ensure the UI rebuilds
                        },
                      );
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share Location'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _tempPinnedLocation = null; // Clear temp pin
                    });
                    _shareLocation(position);
                  },
                ),

                if (_distance > 0)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Distance: ${_distance.toStringAsFixed(2)} km | Duration: $_duration',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _navigateToSafeSpotForm(LatLng position) {
    setState(() {
      _tempPinnedLocation = null; // Clear temp pin
    });

    if (_userProfile == null) {
      _showSnackBar('Please log in to add safe spots');
      return;
    }

    SafeSpotForm.showSafeSpotForm(
      context: context,
      position: position,
      userProfile: _userProfile,
      onUpdate: () {
        _loadSafeSpots(); // Reload safe spots to show the new one
      },
    );
  }

  // Helper methods for safe route calculation
  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  List<LatLng> _findUnsafeSegments(List<LatLng> route) {
    final unsafeSegments = <LatLng>[];
    const safeDistance = 150.0; // Distance for active hotspots

    // Filter hotspots to only include active + approved ones (PRIORITY 1)
    final activeApprovedHotspots = _hotspots.where((hotspot) {
      final status = hotspot['status'] ?? 'approved';
      final activeStatus = hotspot['active_status'] ?? 'active';
      return status == 'approved' && activeStatus == 'active';
    }).toList();

    // Check each route point
    for (final point in route) {
      bool isUnsafe = false;

      // PRIORITY 1: Check active hotspots
      for (final hotspot in activeApprovedHotspots) {
        final coords = hotspot['location']['coordinates'];
        final hotspotLatLng = LatLng(coords[1], coords[0]);
        if (_calculateDistance(point, hotspotLatLng) < safeDistance) {
          isUnsafe = true;
          break;
        }
      }

      // PRIORITY 2: Check heatmap clusters (only if not already marked unsafe)
      if (!isUnsafe && _showHeatmap && _heatmapClusters.isNotEmpty) {
        for (final cluster in _heatmapClusters) {
          final distanceToCluster = _calculateDistance(point, cluster.center);

          // Use cluster radius + safety buffer based on severity
          final safetyBuffer = _getClusterSafetyBuffer(
            cluster.dominantSeverity,
          );
          final totalSafeDistance = cluster.radius + safetyBuffer;

          if (distanceToCluster < totalSafeDistance) {
            isUnsafe = true;
            break;
          }
        }
      }

      if (isUnsafe) {
        unsafeSegments.add(point);
      }
    }

    return unsafeSegments;
  }

  // NEW: Get safety buffer based on cluster severity
  double _getClusterSafetyBuffer(String severity) {
    switch (severity) {
      case 'critical':
        return 300.0; // 300m extra buffer for critical zones
      case 'high':
        return 200.0; // 200m extra buffer for high zones
      case 'medium':
        return 150.0; // 150m extra buffer for medium zones
      case 'low':
        return 100.0; // 100m extra buffer for low zones
      default:
        return 100.0;
    }
  }

  // Helper to get minimum distance to any active hotspot

  Future<List<LatLng>> _getRouteWithWaypoints(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) async {
    final limitedWaypoints = waypoints.take(2).toList();

    if (limitedWaypoints.isEmpty) {
      return await _getRouteFromAPI(start, end);
    }

    final waypointsStr = limitedWaypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final isWeb = kIsWeb;

    String apiUrl;
    Uri requestUri;

    if (isWeb) {
      // Build the OSRM URL first
      apiUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '$waypointsStr;'
          '${end.longitude},${end.latitude}?overview=full&geometries=geojson&continue_straight=false&alternatives=false';

      // Use a more reliable CORS proxy or try multiple options
      final corsProxies = [
        'https://cors-anywhere.herokuapp.com/',
        'https://api.allorigins.win/raw?url=',
        'https://corsproxy.io/?',
      ];

      // Try first proxy
      requestUri = Uri.parse('${corsProxies[1]}${Uri.encodeComponent(apiUrl)}');
    } else {
      // Direct API call for mobile
      apiUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '$waypointsStr;'
          '${end.longitude},${end.latitude}?overview=full&geometries=geojson&continue_straight=false&alternatives=false';

      requestUri = Uri.parse(apiUrl);
    }

    try {
      final response = await http
          .get(
            requestUri,
            headers: isWeb
                ? {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  }
                : {'User-Agent': 'Zecure/1.0', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          throw Exception('No safe route found with waypoints');
        }

        final route = data['routes'][0];
        final coordinates = route['geometry']?['coordinates'] as List?;

        if (coordinates == null) {
          throw Exception('No route coordinates found');
        }

        return coordinates.map((coord) {
          final coordList = coord as List;
          final lng = _safeParseDouble(coordList[0]) ?? 0.0;
          final lat = _safeParseDouble(coordList[1]) ?? 0.0;
          return LatLng(lat, lng);
        }).toList();
      }
      throw Exception(
        'Failed to get safe route with waypoints (${response.statusCode})',
      );
    } catch (e) {
      if (isWeb) {
        // Fallback: try different CORS proxy
        return await _getRouteWithWaypointsFallback(start, end, waypoints);
      }
      rethrow;
    }
  }

  Future<List<LatLng>> _getRouteWithWaypointsFallback(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) async {
    final limitedWaypoints = waypoints.take(2).toList();
    final waypointsStr = limitedWaypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    // Try corsproxy.io as fallback
    final apiUrl =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '$waypointsStr;'
        '${end.longitude},${end.latitude}?overview=full&geometries=geojson&continue_straight=false&alternatives=false';

    final requestUri = Uri.parse(
      'https://corsproxy.io/?${Uri.encodeComponent(apiUrl)}',
    );

    final response = await http
        .get(
          requestUri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        throw Exception('No safe route found with waypoints');
      }

      final route = data['routes'][0];
      final coordinates = route['geometry']?['coordinates'] as List?;

      if (coordinates == null) {
        throw Exception('No route coordinates found');
      }

      return coordinates.map((coord) {
        final coordList = coord as List;
        final lng = _safeParseDouble(coordList[0]) ?? 0.0;
        final lat = _safeParseDouble(coordList[1]) ?? 0.0;
        return LatLng(lat, lng);
      }).toList();
    }
    throw Exception(
      'Failed to get safe route with waypoints (${response.statusCode})',
    );
  }

  Future<List<LatLng>> _getRouteFromAPI(LatLng start, LatLng end) async {
    final isWeb = kIsWeb;

    String apiUrl;
    Uri requestUri;

    if (isWeb) {
      // Build the OSRM URL first
      apiUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}?overview=full&geometries=geojson';

      // Use CORS proxy with proper encoding
      requestUri = Uri.parse(
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(apiUrl)}',
      );
    } else {
      // Direct API call for mobile
      apiUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}?overview=full&geometries=geojson';

      requestUri = Uri.parse(apiUrl);
    }

    try {
      final response = await http
          .get(
            requestUri,
            headers: isWeb
                ? {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  }
                : {'User-Agent': 'Zecure/1.0', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          throw Exception('No route found');
        }

        final route = data['routes'][0];
        final coordinates = route['geometry']?['coordinates'] as List?;

        if (coordinates == null) {
          throw Exception('No route coordinates found');
        }

        return coordinates.map((coord) {
          final coordList = coord as List;
          final lng = _safeParseDouble(coordList[0]) ?? 0.0;
          final lat = _safeParseDouble(coordList[1]) ?? 0.0;
          return LatLng(lat, lng);
        }).toList();
      }
      throw Exception('Failed to get route (${response.statusCode})');
    } catch (e) {
      if (isWeb) {
        // Fallback: try different CORS proxy
        return await _getRouteFromAPIFallback(start, end);
      }
      rethrow;
    }
  }

  Future<List<LatLng>> _getRouteFromAPIFallback(
    LatLng start,
    LatLng end,
  ) async {
    // Try corsproxy.io as fallback
    final apiUrl =
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    final requestUri = Uri.parse(
      'https://corsproxy.io/?${Uri.encodeComponent(apiUrl)}',
    );

    final response = await http
        .get(
          requestUri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        throw Exception('No route found');
      }

      final route = data['routes'][0];
      final coordinates = route['geometry']?['coordinates'] as List?;

      if (coordinates == null) {
        throw Exception('No route coordinates found');
      }

      return coordinates.map((coord) {
        final coordList = coord as List;
        final lng = _safeParseDouble(coordList[0]) ?? 0.0;
        final lat = _safeParseDouble(coordList[1]) ?? 0.0;
        return LatLng(lat, lng);
      }).toList();
    }
    throw Exception('Failed to get route (${response.statusCode})');
  }

  //SAFE ROUTE METHOD
  Future<void> _getSafeRoute(LatLng destination) async {
    if (_currentPosition == null) return;

    setState(() {
      _destination = destination;
      _currentTab = MainTab.map;
      _selectedHotspot = null;
      _routeWasCalculatedAsSafe = true;
      _tempPinnedLocation = null;
      _routingRetryCount = 0; // Reset retry count for new destination
    });

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(_currentPosition!, destination),
        padding: const EdgeInsets.all(50.0),
      ),
    );

    await _attemptSafeRouting(destination, showProgressMessage: true);
  }

  // FIXED: Core safe routing logic with proper route handling
  Future<void> _attemptSafeRouting(
    LatLng destination, {
    bool showProgressMessage = false,
  }) async {
    if (showProgressMessage) {
      _showSnackBar('Calculating safest route...');
    }

    try {
      final regularRoute = await _getRouteFromAPI(
        _currentPosition!,
        destination,
      );
      _lastRegularRoute = regularRoute; // Store for fallback

      final unsafeSegments = _findUnsafeSegments(regularRoute);

      if (unsafeSegments.isEmpty) {
        // Route is already safe
        await _applySuccessfulRoute(
          regularRoute,
          destination,
          'Route is already safe!',
        );
        return;
      }

      // Try to find a safer route
      final safeRoute = await _findBestSafeRoute(
        _currentPosition!,
        destination,
        unsafeSegments,
      );
      final newUnsafeSegments = _findUnsafeSegments(safeRoute);

      if (newUnsafeSegments.isEmpty) {
        await _applySuccessfulRoute(
          safeRoute,
          destination,
          'Safe route found!',
        );
      } else if (newUnsafeSegments.length < unsafeSegments.length * 0.7) {
        // 30% improvement
        await _applySuccessfulRoute(
          safeRoute,
          destination,
          'Safer route found!',
        );
      } else {
        // Could not find significantly safer route
        // FIXED: Pass the attempted safe route for analysis
        await _handleFailedSafeRouting(
          destination,
          unsafeSegments.length,
          newUnsafeSegments.length,
          attemptedRoute: safeRoute, // NEW: Pass the route
        );
      }
    } catch (e) {
      print('Safe route error: $e');
      // FIXED: Pass the regular route (fallback) for analysis
      await _handleFailedSafeRouting(
        destination,
        -1,
        -1,
        error: e.toString(),
        attemptedRoute: _lastRegularRoute, // NEW: Pass the route
      );
    }
  }

  // FIXED: Handle successful route application without premature display
  Future<void> _applySuccessfulRoute(
    List<LatLng> route,
    LatLng destination,
    String message,
  ) async {
    final distance = _calculateRouteDistance(route);
    final duration = _estimateRouteDuration(distance);

    setState(() {
      _routePoints = route; // NOW it's safe to display the route
      _distance = distance / 1000;
      _duration = _formatDuration(duration);
      _hasActiveRoute = true;
      _routingRetryCount = 0; // Reset on success
    });

    _showSnackBar(message);
    _startRouteUpdates();
  }

  // FIXED: Handle failed safe routing with modal confirmation
  Future<void> _handleFailedSafeRouting(
    LatLng destination,
    int originalUnsafe,
    int newUnsafe, {
    String? error,
    List<LatLng>? attemptedRoute, // NEW: Pass the route that was attempted
  }) async {
    if (_isShowingRouteModal) return; // Prevent multiple modals

    // Record this failed attempt
    _recordFailedRoutingAttempt(destination, originalUnsafe, newUnsafe, error);

    // CRITICAL FIX: Don't set route in state until user confirms
    // Store the attempted route temporarily but don't display it yet

    // Show confirmation modal with the attempted route for analysis
    _isShowingRouteModal = true;

    final shouldProceed = await _showRouteConfirmationModal(
      destination: destination,
      originalUnsafeCount: originalUnsafe,
      newUnsafeCount: newUnsafe,
      error: error,
      currentRoute:
          attemptedRoute ?? _lastRegularRoute, // FIXED: Pass the route
    );

    _isShowingRouteModal = false;

    if (shouldProceed == true) {
      // User chose to proceed with regular route
      if (_lastRegularRoute != null) {
        await _applySuccessfulRoute(
          _lastRegularRoute!,
          destination,
          'Using regular route as requested',
        );
      } else {
        // Fallback: get regular route
        try {
          final regularRoute = await _getRouteFromAPI(
            _currentPosition!,
            destination,
          );
          await _applySuccessfulRoute(
            regularRoute,
            destination,
            'Using regular route as requested',
          );
        } catch (e) {
          _showSnackBar('Unable to get any route. Please try again.');
        }
      }
    } else if (shouldProceed == false) {
      // User chose to cancel
      setState(() {
        _hasActiveRoute = false;
        _routePoints = []; // FIXED: Clear any route points
        _destination = null;
      });
    }
    // If shouldProceed is null, user chose "Try Harder" - modal already closed
  }

  // Record failed routing attempt for analysis
  void _recordFailedRoutingAttempt(
    LatLng destination,
    int originalUnsafe,
    int newUnsafe,
    String? error,
  ) {
    final attempt = {
      'destination': destination,
      'timestamp': DateTime.now(),
      'original_unsafe_segments': originalUnsafe,
      'new_unsafe_segments': newUnsafe,
      'error': error,
      'retry_count': _routingRetryCount,
    };

    _failedRoutingAttempts.add(attempt);

    // Keep only last 10 attempts to prevent memory issues
    if (_failedRoutingAttempts.length > 10) {
      _failedRoutingAttempts.removeAt(0);
    }

    print('Recorded failed routing attempt: $attempt');
  }

  // FIXED: Show route confirmation modal with proper route calculation
  Future<bool?> _showRouteConfirmationModal({
    required LatLng destination,
    required int originalUnsafeCount,
    required int newUnsafeCount,
    String? error,
    List<LatLng>? currentRoute, // NEW: Pass the actual route being evaluated
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isMobile = screenWidth < 600;

        // FIXED: Calculate zones from the passed route, not _routePoints
        final heatmapZonesCount = _showHeatmap && currentRoute != null
            ? _countHeatmapZonesInRoute(currentRoute)
            : 0;

        return AlertDialog(
          insetPadding: isMobile
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Safe Route Challenge',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? null : 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ...[
                    Text('Error occurred: $error'),
                    const SizedBox(height: 12),
                  ],
                  if (originalUnsafeCount > 0 && newUnsafeCount > 0) ...[
                    Text(
                      'Found route with $newUnsafeCount unsafe areas '
                      '(vs $originalUnsafeCount in direct route).',
                    ),
                    const SizedBox(height: 8),
                  ],

                  // FIXED: Show heatmap warning BEFORE the explanation
                  if (_showHeatmap && heatmapZonesCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.heat_pump,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Crime Heatmap Zones Detected',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Route passes through $heatmapZonesCount high-crime density area${heatmapZonesCount > 1 ? 's' : ''}. '
                            'These zones are calculated from historical crime patterns.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'We couldn\'t find a significantly safer route to your destination. '
                    'This might be due to:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Limited alternative roads in the area'),
                  const Text('• Multiple hotspots along possible routes'),
                  if (heatmapZonesCount > 0)
                    const Text(
                      '• High-crime density zones blocking alternatives',
                    ),
                  const Text('• API routing limitations'),
                  const SizedBox(height: 12),

                  if (_routingRetryCount < MAX_RETRY_ATTEMPTS) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Try Again Options:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• Extended detour search (may be much longer)',
                          ),
                          const Text('• Alternative routing strategies'),
                          if (heatmapZonesCount > 0)
                            const Text(
                              '• Wider avoidance of crime density zones',
                            ),
                          Text(
                            '• Attempt ${_routingRetryCount + 1} of $MAX_RETRY_ATTEMPTS',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'What would you like to do?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_routingRetryCount < MAX_RETRY_ATTEMPTS)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(null);
                      _retryWithExtendedSearch(destination);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Harder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (_routingRetryCount < MAX_RETRY_ATTEMPTS)
                  const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.route),
                  label: const Text('Use Regular Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // FIXED: Accept route parameter to avoid race conditions
  int _countHeatmapZonesInRoute([List<LatLng>? routeToCheck]) {
    final route = routeToCheck ?? _routePoints;

    if (route.isEmpty || _heatmapClusters.isEmpty) return 0;

    int count = 0;
    final checkedClusters = <HeatmapCluster>{};

    for (final point in route) {
      for (final cluster in _heatmapClusters) {
        if (checkedClusters.contains(cluster)) continue;

        final distance = _calculateDistance(point, cluster.center);
        final safetyBuffer = _getClusterSafetyBuffer(cluster.dominantSeverity);

        if (distance <= cluster.radius + safetyBuffer) {
          count++;
          checkedClusters.add(cluster);
        }
      }
    }

    return count;
  }

  // Retry with extended search parameters
  Future<void> _retryWithExtendedSearch(LatLng destination) async {
    _routingRetryCount++;
    _showSnackBar(
      'Attempting extended route search... ($_routingRetryCount/$MAX_RETRY_ATTEMPTS)',
    );

    try {
      final regularRoute = await _getRouteFromAPI(
        _currentPosition!,
        destination,
      );
      _lastRegularRoute = regularRoute; // Update fallback
      final unsafeSegments = _findUnsafeSegments(regularRoute);

      if (unsafeSegments.isEmpty) {
        await _applySuccessfulRoute(
          regularRoute,
          destination,
          'Route is now safe!',
        );
        return;
      }

      // Use more aggressive safe routing with extended parameters
      final safeRoute = await _findBestSafeRouteExtended(
        _currentPosition!,
        destination,
        unsafeSegments,
      );
      final newUnsafeSegments = _findUnsafeSegments(safeRoute);

      if (newUnsafeSegments.length < unsafeSegments.length * 0.8) {
        // Accept 20% improvement
        await _applySuccessfulRoute(
          safeRoute,
          destination,
          'Extended search found safer route!',
        );
      } else {
        // Still couldn't find better route
        // FIXED: Pass the attempted route
        await _handleFailedSafeRouting(
          destination,
          unsafeSegments.length,
          newUnsafeSegments.length,
          attemptedRoute: safeRoute, // NEW: Pass the route
        );
      }
    } catch (e) {
      print('Extended search error: $e');
      // FIXED: Pass the fallback route
      await _handleFailedSafeRouting(
        destination,
        -1,
        -1,
        error: 'Extended search failed: $e',
        attemptedRoute: _lastRegularRoute, // NEW: Pass the route
      );
    }
  }

  // Extended safe route finding with more aggressive parameters
  Future<List<LatLng>> _findBestSafeRouteExtended(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    print(
      'Extended safe route search: ${unsafeSegments.length} unsafe segments',
    );

    // More aggressive strategies with wider detours
    final strategies = [
      () => _tryVeryWideDetourStrategy(start, destination, unsafeSegments),
      () => _tryMultipleWaypointStrategy(start, destination, unsafeSegments),
      () => _tryAlternativeCorridorStrategy(start, destination, unsafeSegments),
      () => _tryPerpendicularDetourStrategy(start, destination, unsafeSegments),
      () => _tryRadialAvoidanceStrategy(start, destination, unsafeSegments),
    ];

    for (final strategy in strategies) {
      try {
        final route = await strategy();
        if (route.isNotEmpty) {
          final newUnsafeSegments = _findUnsafeSegments(route);
          print(
            'Extended strategy result: ${newUnsafeSegments.length} remaining unsafe segments',
          );

          // More lenient acceptance criteria for extended search
          if (newUnsafeSegments.length < unsafeSegments.length * 0.8) {
            return route;
          }
        }
      } catch (e) {
        print('Extended strategy failed: $e');
        continue;
      }
    }

    // If still no luck, return the best route we found
    return await _getRouteFromAPI(start, destination);
  }

  // Very wide detour strategy for extended search
  Future<List<LatLng>> _tryVeryWideDetourStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    final mainBearing = _calculateBearing(start, destination);
    final routeDistance = _calculateDistance(start, destination);
    final waypoints = <LatLng>[];

    // Much wider detour - up to 3km offset
    final detourDistances = [1500.0, 2000.0, 3000.0];
    final numWaypoints = routeDistance > 10000 ? 4 : 3;

    for (final detourDistance in detourDistances) {
      waypoints.clear();

      for (int i = 1; i <= numWaypoints; i++) {
        final fraction = i / (numWaypoints + 1.0);
        final baseLat =
            start.latitude + (destination.latitude - start.latitude) * fraction;
        final baseLng =
            start.longitude +
            (destination.longitude - start.longitude) * fraction;
        final basePoint = LatLng(baseLat, baseLng);

        final perpBearing = (mainBearing + 90) % 360;
        final waypoint1 = _calculateDestination(
          basePoint,
          perpBearing,
          detourDistance,
        );
        final waypoint2 = _calculateDestination(
          basePoint,
          (perpBearing + 180) % 360,
          detourDistance,
        );

        final safety1 = _evaluateWaypointSafety(waypoint1);
        final safety2 = _evaluateWaypointSafety(waypoint2);

        if (safety1 > safety2 && safety1 > 200) {
          waypoints.add(waypoint1);
        } else if (safety2 > 200) {
          waypoints.add(waypoint2);
        }
      }

      if (waypoints.length >= 2) {
        try {
          return await _getRouteWithWaypoints(start, destination, waypoints);
        } catch (e) {
          continue; // Try next detour distance
        }
      }
    }

    throw Exception('Very wide detour strategy failed');
  }

  // Multiple waypoint strategy using more waypoints
  Future<List<LatLng>> _tryMultipleWaypointStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    final hotspotClusters = _clusterHotspots(unsafeSegments);
    final waypoints = <LatLng>[];

    // Try to create waypoints for each cluster
    for (final cluster in hotspotClusters.take(4)) {
      // Up to 4 clusters
      final clusterCenter = _getClusterCenter(cluster);
      final avoidanceDistance = 800.0; // Increased avoidance distance

      // Try multiple directions for each cluster
      final directions = [30, 60, 120, 150, 210, 240, 300, 330];

      for (final direction in directions) {
        final candidate = _calculateDestination(
          clusterCenter,
          direction.toDouble(),
          avoidanceDistance,
        );
        final safety = _evaluateWaypointSafety(candidate);

        if (safety > 300) {
          // Higher safety requirement
          waypoints.add(candidate);
          break;
        }
      }
    }

    if (waypoints.length >= 2) {
      return await _getRouteWithWaypoints(
        start,
        destination,
        waypoints.take(3).toList(),
      );
    }

    throw Exception('Multiple waypoint strategy failed');
  }

  // Alternative corridor strategy - try completely different route corridors
  Future<List<LatLng>> _tryAlternativeCorridorStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    // Create waypoints that force the route through different corridors
    final mainBearing = _calculateBearing(start, destination);
    final waypoints = <LatLng>[];

    // Try different corridor angles
    final corridorOffsets = [45.0, -45.0, 90.0, -90.0, 135.0, -135.0];

    for (final offset in corridorOffsets) {
      final corridorBearing = (mainBearing + offset) % 360;
      final corridorDistance =
          _calculateDistance(start, destination) *
          0.7; // 70% of direct distance

      final corridorWaypoint = _calculateDestination(
        start,
        corridorBearing,
        corridorDistance,
      );
      final safety = _evaluateWaypointSafety(corridorWaypoint);

      if (safety > 400) {
        // Even higher safety requirement for corridor
        waypoints.add(corridorWaypoint);
        break;
      }
    }

    if (waypoints.isNotEmpty) {
      return await _getRouteWithWaypoints(start, destination, waypoints);
    }

    throw Exception('Alternative corridor strategy failed');
  }

  // Enhanced safe routing with multiple strategies to find alternative routes
  // that avoid hotspots even when the free API doesn't provide them directly

  // 1. ENHANCED: Multiple waypoint strategies for better hotspot avoidance
  Future<List<LatLng>> _findBestSafeRoute(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    print(
      'Finding safe route: ${unsafeSegments.length} unsafe segments detected',
    );

    // Strategy 1: Try multiple alternative routes with different approaches
    final strategies = [
      () => _tryPerpendicularDetourStrategy(start, destination, unsafeSegments),
      () => _tryRadialAvoidanceStrategy(start, destination, unsafeSegments),
      () => _trySegmentBySegmentAvoidance(start, destination, unsafeSegments),
      () => _tryWideDetourStrategy(start, destination, unsafeSegments),
    ];

    for (final strategy in strategies) {
      try {
        final route = await strategy();
        if (route.isNotEmpty) {
          final newUnsafeSegments = _findUnsafeSegments(route);
          print(
            'Strategy result: ${newUnsafeSegments.length} remaining unsafe segments',
          );

          // Accept route if it's significantly safer (50% reduction or better)
          if (newUnsafeSegments.length <= unsafeSegments.length * 0.5) {
            return route;
          }
        }
      } catch (e) {
        print('Strategy failed: $e');
        continue;
      }
    }

    // If all strategies fail, return the original route with warning
    print('All safe route strategies failed, using original route');
    return await _getRouteFromAPI(start, destination);
  }

  // 2. NEW: Perpendicular detour strategy - creates waypoints perpendicular to hotspot clusters
  Future<List<LatLng>> _tryPerpendicularDetourStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    final hotspotClusters = _clusterHotspots(unsafeSegments);
    final waypoints = <LatLng>[];

    // Process both active hotspot clusters AND heatmap clusters
    for (final cluster in hotspotClusters) {
      final clusterCenter = _getClusterCenter(cluster);

      // Calculate perpendicular directions to the main route
      final mainRouteDirection = _calculateBearing(start, destination);
      final perpendicularDirection1 = (mainRouteDirection + 90) % 360;
      final perpendicularDirection2 = (mainRouteDirection - 90) % 360;

      // Increased distances to account for heatmap zones
      final distances = [
        600.0,
        900.0,
        1400.0,
      ]; // Increased from [500, 800, 1200]

      for (final distance in distances) {
        final waypoint1 = _calculateDestination(
          clusterCenter,
          perpendicularDirection1,
          distance,
        );
        final waypoint2 = _calculateDestination(
          clusterCenter,
          perpendicularDirection2,
          distance,
        );

        // Enhanced safety evaluation (considers both hotspots and heatmap)
        final safety1 = _evaluateWaypointSafety(waypoint1);
        final safety2 = _evaluateWaypointSafety(waypoint2);

        // Also check if waypoints are in heatmap danger zones
        final inDanger1 = _isPointInHeatmapDangerZone(waypoint1);
        final inDanger2 = _isPointInHeatmapDangerZone(waypoint2);

        if (!inDanger1 && safety1 > safety2 && safety1 > 250) {
          // Increased from 200
          waypoints.add(waypoint1);
          break;
        } else if (!inDanger2 && safety2 > 250) {
          // Increased from 200
          waypoints.add(waypoint2);
          break;
        }
      }
    }

    // NEW: Also create waypoints to avoid heatmap clusters directly
    if (_showHeatmap && _heatmapClusters.isNotEmpty) {
      final mainBearing = _calculateBearing(start, destination);

      for (final heatCluster in _heatmapClusters) {
        // Only process high-danger clusters
        if (heatCluster.dominantSeverity == 'critical' ||
            heatCluster.dominantSeverity == 'high') {
          final safetyBuffer = _getClusterSafetyBuffer(
            heatCluster.dominantSeverity,
          );
          final avoidanceDistance =
              heatCluster.radius + safetyBuffer + 200; // Extra margin

          // Try perpendicular directions
          final perpBearing1 = (mainBearing + 90) % 360;
          final perpBearing2 = (mainBearing - 90) % 360;

          final candidate1 = _calculateDestination(
            heatCluster.center,
            perpBearing1,
            avoidanceDistance,
          );
          final candidate2 = _calculateDestination(
            heatCluster.center,
            perpBearing2,
            avoidanceDistance,
          );

          final safety1 = _evaluateWaypointSafety(candidate1);
          final safety2 = _evaluateWaypointSafety(candidate2);

          if (safety1 > 300 && !_isPointInHeatmapDangerZone(candidate1)) {
            waypoints.add(candidate1);
          } else if (safety2 > 300 &&
              !_isPointInHeatmapDangerZone(candidate2)) {
            waypoints.add(candidate2);
          }
        }
      }
    }

    if (waypoints.isNotEmpty) {
      return await _getRouteWithWaypoints(
        start,
        destination,
        waypoints.take(3).toList(),
      );
    }

    throw Exception('No safe perpendicular route found');
  }

  // 3. NEW: Radial avoidance strategy - creates waypoints in a radial pattern around hotspots
  Future<List<LatLng>> _tryRadialAvoidanceStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    final hotspotClusters = _clusterHotspots(unsafeSegments);
    final waypoints = <LatLng>[];

    for (final cluster in hotspotClusters) {
      final clusterCenter = _getClusterCenter(cluster);
      final directions = [0, 45, 90, 135, 180, 225, 270, 315];
      final avoidanceDistance = 600.0;

      LatLng? bestWaypoint;
      double bestSafety = 0;
      double lowestDanger = double.infinity; // NEW

      for (final direction in directions) {
        final candidate = _calculateDestination(
          clusterCenter,
          direction.toDouble(),
          avoidanceDistance,
        );
        final safety = _evaluateWaypointSafety(candidate);
        final dangerScore = _getClusterDangerScore(
          candidate,
        ); // NEW: Use it here

        // Prioritize waypoints with high safety AND low danger score
        if (safety > bestSafety ||
            (safety == bestSafety && dangerScore < lowestDanger)) {
          bestSafety = safety;
          lowestDanger = dangerScore;
          bestWaypoint = candidate;
        }
      }

      if (bestWaypoint != null && bestSafety > 250 && lowestDanger < 2.0) {
        // NEW: danger threshold
        waypoints.add(bestWaypoint);
        print(
          '🎯 Added waypoint with danger score: ${lowestDanger.toStringAsFixed(2)}',
        );
      }
    }

    if (waypoints.isNotEmpty) {
      return await _getRouteWithWaypoints(
        start,
        destination,
        waypoints.take(2).toList(),
      );
    }

    throw Exception('No safe radial route found');
  }

  // 4. NEW: Segment-by-segment avoidance - targets specific unsafe route segments
  Future<List<LatLng>> _trySegmentBySegmentAvoidance(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    // Get the original route to analyze segments
    final originalRoute = await _getRouteFromAPI(start, destination);
    final waypoints = <LatLng>[];

    // Find the most problematic segments (those passing closest to hotspots)
    final problematicSegments = <Map<String, dynamic>>[];

    for (int i = 0; i < originalRoute.length - 1; i++) {
      final segmentStart = originalRoute[i];
      final segmentEnd = originalRoute[i + 1];
      final segmentMidpoint = LatLng(
        (segmentStart.latitude + segmentEnd.latitude) / 2,
        (segmentStart.longitude + segmentEnd.longitude) / 2,
      );

      // Check if this segment is near any hotspots
      double minDistanceToHotspot = double.infinity;
      for (final hotspot in _hotspots.where(
        (h) => h['status'] == 'approved' && h['active_status'] == 'active',
      )) {
        final coords = hotspot['location']['coordinates'];
        final hotspotLatLng = LatLng(coords[1], coords[0]);
        final distance = _calculateDistance(segmentMidpoint, hotspotLatLng);
        if (distance < minDistanceToHotspot) {
          minDistanceToHotspot = distance;
        }
      }

      if (minDistanceToHotspot < 200) {
        // Segment is too close to hotspots
        problematicSegments.add({
          'index': i,
          'midpoint': segmentMidpoint,
          'danger_level': 200 - minDistanceToHotspot,
        });
      }
    }

    // Sort by danger level and create waypoints to avoid the worst segments
    problematicSegments.sort(
      (a, b) =>
          (b['danger_level'] as double).compareTo(a['danger_level'] as double),
    );

    for (final segment in problematicSegments.take(3)) {
      // Max 3 segments
      final midpoint = segment['midpoint'] as LatLng;

      // Create waypoint offset from the problematic segment
      final offsetDistance = 400.0;
      final offsetDirections = [45, 135, 225, 315]; // Diagonal offsets

      for (final direction in offsetDirections) {
        final waypoint = _calculateDestination(
          midpoint,
          direction.toDouble(),
          offsetDistance,
        );
        final safety = _evaluateWaypointSafety(waypoint);

        if (safety > 200) {
          waypoints.add(waypoint);
          break;
        }
      }
    }

    if (waypoints.isNotEmpty) {
      return await _getRouteWithWaypoints(start, destination, waypoints);
    }

    throw Exception('No segment-based safe route found');
  }

  // 5. NEW: Wide detour strategy - creates a wider arc around hotspot areas
  Future<List<LatLng>> _tryWideDetourStrategy(
    LatLng start,
    LatLng destination,
    List<LatLng> unsafeSegments,
  ) async {
    // Calculate the main route bearing
    final mainBearing = _calculateBearing(start, destination);
    final routeDistance = _calculateDistance(start, destination);

    // Create waypoints that form a wide arc around the problematic area
    final waypoints = <LatLng>[];

    // Create intermediate points along a curved path
    final numWaypoints = routeDistance > 5000
        ? 3
        : 2; // More waypoints for longer routes

    for (int i = 1; i <= numWaypoints; i++) {
      final fraction = i / (numWaypoints + 1.0);

      // Base position along direct route
      final baseLat =
          start.latitude + (destination.latitude - start.latitude) * fraction;
      final baseLng =
          start.longitude +
          (destination.longitude - start.longitude) * fraction;
      final basePoint = LatLng(baseLat, baseLng);

      // Offset perpendicular to main route to create arc
      final perpBearing = (mainBearing + 90) % 360;
      final arcOffset = 1000.0; // 1km offset for wide detour

      final waypoint1 = _calculateDestination(
        basePoint,
        perpBearing,
        arcOffset,
      );
      final waypoint2 = _calculateDestination(
        basePoint,
        (perpBearing + 180) % 360,
        arcOffset,
      );

      // Choose safer side of the arc
      final safety1 = _evaluateWaypointSafety(waypoint1);
      final safety2 = _evaluateWaypointSafety(waypoint2);

      if (safety1 > safety2 && safety1 > 300) {
        waypoints.add(waypoint1);
      } else if (safety2 > 300) {
        waypoints.add(waypoint2);
      }
    }

    if (waypoints.isNotEmpty) {
      return await _getRouteWithWaypoints(start, destination, waypoints);
    }

    throw Exception('No wide detour route found');
  }

  // 6. HELPER: Cluster nearby hotspots to treat them as single obstacles
  List<List<LatLng>> _clusterHotspots(List<LatLng> unsafeSegments) {
    final clusters = <List<LatLng>>[];
    final processed = List<bool>.filled(unsafeSegments.length, false);

    for (int i = 0; i < unsafeSegments.length; i++) {
      if (processed[i]) continue;

      final cluster = <LatLng>[unsafeSegments[i]];
      processed[i] = true;

      // Find nearby points within 300m
      for (int j = i + 1; j < unsafeSegments.length; j++) {
        if (!processed[j] &&
            _calculateDistance(unsafeSegments[i], unsafeSegments[j]) < 300) {
          cluster.add(unsafeSegments[j]);
          processed[j] = true;
        }
      }

      clusters.add(cluster);
    }

    return clusters;
  }

  // 7. HELPER: Get center point of a hotspot cluster
  LatLng _getClusterCenter(List<LatLng> cluster) {
    final avgLat =
        cluster.map((p) => p.latitude).reduce((a, b) => a + b) / cluster.length;
    final avgLng =
        cluster.map((p) => p.longitude).reduce((a, b) => a + b) /
        cluster.length;
    return LatLng(avgLat, avgLng);
  }

  // 8. HELPER: Calculate bearing between two points (in degrees)
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1Rad = start.latitude * pi / 180;
    final lat2Rad = end.latitude * pi / 180;
    final deltaLngRad = (end.longitude - start.longitude) * pi / 180;

    final x = sin(deltaLngRad) * cos(lat2Rad);
    final y =
        cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);

    final bearingRad = atan2(x, y);
    final bearingDeg = bearingRad * 180 / pi;

    return (bearingDeg + 360) % 360; // Normalize to 0-360
  }

  // 9. HELPER: Calculate destination point from bearing and distance
  LatLng _calculateDestination(LatLng start, double bearing, double distance) {
    const double earthRadius = 6371000; // meters
    final bearingRad = bearing * pi / 180;
    final lat1Rad = start.latitude * pi / 180;
    final lng1Rad = start.longitude * pi / 180;

    final lat2Rad = asin(
      sin(lat1Rad) * cos(distance / earthRadius) +
          cos(lat1Rad) * sin(distance / earthRadius) * cos(bearingRad),
    );

    final lng2Rad =
        lng1Rad +
        atan2(
          sin(bearingRad) * sin(distance / earthRadius) * cos(lat1Rad),
          cos(distance / earthRadius) - sin(lat1Rad) * sin(lat2Rad),
        );

    return LatLng(lat2Rad * 180 / pi, lng2Rad * 180 / pi);
  }

  // 10. HELPER: Evaluate how safe a waypoint is (returns minimum distance to any active hotspot)
  double _evaluateWaypointSafety(LatLng waypoint) {
    double minDistance = double.infinity;

    // PRIORITY 1: Check active hotspots
    final activeHotspots = _hotspots.where((hotspot) {
      final status = hotspot['status'] ?? 'approved';
      final activeStatus = hotspot['active_status'] ?? 'active';
      return status == 'approved' && activeStatus == 'active';
    });

    for (final hotspot in activeHotspots) {
      final coords = hotspot['location']['coordinates'];
      final hotspotLatLng = LatLng(coords[1], coords[0]);
      final distance = _calculateDistance(waypoint, hotspotLatLng);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // PRIORITY 2: Check heatmap clusters
    if (_showHeatmap && _heatmapClusters.isNotEmpty) {
      for (final cluster in _heatmapClusters) {
        // Distance to cluster edge (not center)
        final distanceToCenter = _calculateDistance(waypoint, cluster.center);
        final safetyBuffer = _getClusterSafetyBuffer(cluster.dominantSeverity);
        final effectiveDistance =
            distanceToCenter - cluster.radius - safetyBuffer;

        // Penalize waypoints inside or near cluster boundaries
        if (effectiveDistance < minDistance) {
          minDistance = effectiveDistance;
        }
      }
    }

    return minDistance;
  }

  // NEW: Check if a point is within any heatmap cluster danger zone
  bool _isPointInHeatmapDangerZone(LatLng point) {
    if (!_showHeatmap || _heatmapClusters.isEmpty) return false;

    for (final cluster in _heatmapClusters) {
      final distanceToCenter = _calculateDistance(point, cluster.center);
      final safetyBuffer = _getClusterSafetyBuffer(cluster.dominantSeverity);
      final dangerZoneRadius = cluster.radius + safetyBuffer;

      if (distanceToCenter <= dangerZoneRadius) {
        return true;
      }
    }

    return false;
  }

  // NEW: Get cluster danger score for a point (for prioritization)
  double _getClusterDangerScore(LatLng point) {
    if (!_showHeatmap || _heatmapClusters.isEmpty) return 0.0;

    double maxDangerScore = 0.0;

    for (final cluster in _heatmapClusters) {
      final distanceToCenter = _calculateDistance(point, cluster.center);
      final safetyBuffer = _getClusterSafetyBuffer(cluster.dominantSeverity);
      final dangerZoneRadius = cluster.radius + safetyBuffer;

      if (distanceToCenter <= dangerZoneRadius) {
        // Calculate danger score based on proximity and severity
        final proximityFactor = 1.0 - (distanceToCenter / dangerZoneRadius);
        final severityWeight =
            _severityWeights[cluster.dominantSeverity] ?? 0.25;
        final dangerScore =
            proximityFactor * severityWeight * cluster.intensity;

        if (dangerScore > maxDangerScore) {
          maxDangerScore = dangerScore;
        }
      }
    }

    return maxDangerScore;
  }

  // Helper to calculate total distance of a route in meters
  double _calculateRouteDistance(List<LatLng> route) {
    double totalDistance = 0;
    for (int i = 1; i < route.length; i++) {
      totalDistance += _calculateDistance(route[i - 1], route[i]);
    }
    return totalDistance;
  }

  // Helper to estimate duration based on distance (assuming 50km/h average speed)
  double _estimateRouteDuration(double distanceMeters) {
    double averageSpeedKmh;

    switch (_selectedTravelMode) {
      case TravelMode.walking:
        averageSpeedKmh = 5.0; // 5 km/h walking speed
        break;
      case TravelMode.cycling:
        averageSpeedKmh = 13.0; // 15 km/h cycling speed
        break;
      case TravelMode.driving:
        averageSpeedKmh =
            38.0; // 40 km/h average driving speed (considering traffic, stops, etc.)
        break;
    }

    final distanceKm = distanceMeters / 1000;
    return (distanceKm / averageSpeedKmh) * 3600; // duration in seconds
  }

  // ADD: Method to get travel mode icon
  IconData _getTravelModeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.cycling:
        return Icons.directions_bike;
      case TravelMode.driving:
        return Icons.directions_car;
    }
  }

  // ADD: Method to get travel mode label
  String _getTravelModeLabel(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.cycling:
        return 'Cycling';
      case TravelMode.driving:
        return 'Driving';
    }
  }

  // TRAVEL TIME DURATION WITH CLOSE BUTTON
  Widget _buildFloatingDurationWidget() {
    // Only show if there's a destination and we have calculated distance
    if (_destination == null || _currentPosition == null || _distance <= 0) {
      return const SizedBox.shrink();
    }

    // Calculate duration using existing method
    final distanceMeters = _distance * 1000; // Convert km to meters
    final durationSeconds = _estimateRouteDuration(distanceMeters);
    final formattedDuration = _formatDuration(durationSeconds);

    return Positioned(
      bottom: 10, // Position above bottom nav bar
      left: 16, // Bottom left corner
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Travel mode selector (when visible) - FURTHER MINIMIZED
          if (_showTravelModeSelector)
            Container(
              margin: const EdgeInsets.only(bottom: 6), // Reduced from 8
              padding: const EdgeInsets.all(8), // Reduced from 12
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8), // Reduced from 10
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08), // Reduced opacity
                    blurRadius: 4, // Reduced from 6
                    offset: const Offset(0, 1), // Reduced from (0, 2)
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Travel Mode',
                    style: TextStyle(
                      fontSize: 12, // Reduced from 14
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced from 8
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: TravelMode.values.map((mode) {
                      final isSelected = _selectedTravelMode == mode;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTravelMode = mode;
                            _showTravelModeSelector = false;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(
                            right: 6,
                          ), // Reduced from 8
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ), // Reduced padding
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(
                              4,
                            ), // Reduced from 6
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getTravelModeIcon(mode),
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                                size: 16, // Reduced from 18
                              ),
                              const SizedBox(height: 1), // Reduced from 2
                              Text(
                                _getTravelModeLabel(mode),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 9, // Reduced from 10
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
            ),

          // Duration display widget with close button
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(8), // Reduced from 10
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12), // Reduced opacity
                  blurRadius: 4, // Reduced from 6
                  offset: const Offset(0, 1), // Reduced from (0, 2)
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main duration display (clickable to toggle travel mode selector)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTravelModeSelector = !_showTravelModeSelector;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ), // Reduced padding
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTravelModeIcon(_selectedTravelMode),
                          color: Colors.white,
                          size: 14, // Reduced from 16
                        ),
                        const SizedBox(width: 4), // Reduced from 6
                        Text(
                          '${_distance.toStringAsFixed(1)} km • $formattedDuration',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11, // Reduced from 12
                          ),
                        ),
                        const SizedBox(width: 4), // Reduced from 6
                        Icon(
                          _showTravelModeSelector
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 12, // Reduced from 14
                        ),
                      ],
                    ),
                  ),
                ),

                // Close/Cancel route button
                GestureDetector(
                  onTap: () {
                    _clearDirections(); // Call your existing clear directions method
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ADD HOTSPOT
  // UPDATED: _showAddHotspotForm with OPTIONAL duration selection
  void _showAddHotspotForm(LatLng position) async {
    final isDesktop = _isDesktopScreen();
    setState(() {
      _tempPinnedLocation = null;
    });
    try {
      final crimeTypesResponse = await Supabase.instance.client
          .from('crime_type')
          .select('*')
          .order('name');

      if (crimeTypesResponse.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No crime types available.')),
        );
        return;
      }

      final crimeTypes = List<Map<String, dynamic>>.from(crimeTypesResponse);
      final formKey = GlobalKey<FormState>();
      final descriptionController = TextEditingController();
      final dateController = TextEditingController();
      final timeController = TextEditingController();

      String selectedCrimeType = crimeTypes[0]['name'];
      int selectedCrimeId = crimeTypes[0]['id'];
      bool isActiveStatus = true;
      String selectedActiveStatus = 'active';
      XFile? selectedPhoto;
      bool isUploadingPhoto = false;
      bool isTimeValid = true;

      // NEW: Optional duration tracking
      bool hasDuration = false; // Default: no duration
      int selectedDurationHours = 24; // Default 24 hours when enabled
      DateTime? expirationTime;

      final now = DateTime.now();
      dateController.text =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      timeController.text = TimeOfDay.fromDateTime(now).format(context);

      bool validateDateTime() {
        try {
          final dateParts = dateController.text.split('-');
          final timeParts = timeController.text.split(' ');
          final time = timeParts[0].split(':');
          final isPM =
              timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm';

          int hour = int.parse(time[0]);
          final minute = int.parse(time[1]);

          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;

          final selectedDateTime = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            hour,
            minute,
          );

          return !selectedDateTime.isAfter(DateTime.now());
        } catch (e) {
          return false;
        }
      }

      // Calculate expiration time
      void updateExpirationTime() {
        if (hasDuration) {
          final now = DateTime.now();
          expirationTime = now.add(Duration(hours: selectedDurationHours));
        } else {
          expirationTime = null;
        }
      }

      void onSubmit() async {
        if (formKey.currentState!.validate() && isTimeValid) {
          try {
            final dateParts = dateController.text.split('-');
            final timeParts = timeController.text.split(' ');
            final time = timeParts[0].split(':');
            final isPM =
                timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm';

            int hour = int.parse(time[0]);
            final minute = int.parse(time[1]);

            if (isPM && hour != 12) hour += 12;
            if (!isPM && hour == 12) hour = 0;

            final dateTime = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
              hour,
              minute,
            );

            // Calculate expiration only if active AND has duration
            updateExpirationTime();

            final hotspotId = await _saveHotspot(
              selectedCrimeId.toString(),
              descriptionController.text,
              position,
              dateTime,
              selectedActiveStatus,
              expirationTime: (isActiveStatus && hasDuration)
                  ? expirationTime
                  : null,
            );

            if (selectedPhoto != null && hotspotId != null) {
              try {
                await PhotoService.uploadPhoto(
                  imageFile: selectedPhoto!,
                  hotspotId: hotspotId,
                  userId: _userProfile!['id'],
                );
              } catch (e) {
                print('Photo upload failed: $e');
                if (mounted) {
                  _showSnackBar(
                    'Crime saved but photo upload failed: ${e.toString()}',
                  );
                }
              }
            }

            await _loadHotspots();

            if (mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save crime report: ${e.toString()}'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }

      if (isDesktop) {
        showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('Add Crime Incident'),
                content: SizedBox(
                  width: 400,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedCrimeType,
                            decoration: const InputDecoration(
                              labelText: 'Crime Type',
                              border: OutlineInputBorder(),
                            ),
                            items: crimeTypes.map((crimeType) {
                              return DropdownMenuItem<String>(
                                value: crimeType['name'],
                                child: Text(
                                  '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final selected = crimeTypes.firstWhere(
                                  (c) => c['name'] == value,
                                );
                                setState(() {
                                  selectedCrimeType = value;
                                  selectedCrimeId = selected['id'];
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a crime type';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          _buildPhotoSection(selectedPhoto, isUploadingPhoto, (
                            photo,
                            uploading,
                          ) {
                            setState(() {
                              selectedPhoto = photo;
                              isUploadingPhoto = uploading;
                            });
                          }),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: dateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date of Incident',
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: now,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    setState(() {
                                      dateController.text =
                                          "${pickedDate?.year}-${pickedDate?.month.toString().padLeft(2, '0')}-${pickedDate?.day.toString().padLeft(2, '0')}";
                                      isTimeValid = validateDateTime();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: timeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Time of Incident',
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    TimeOfDay?
                                    pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                      builder: (context, child) {
                                        return MediaQuery(
                                          data: MediaQuery.of(context).copyWith(
                                            alwaysUse24HourFormat: false,
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (pickedTime != null) {
                                      setState(() {
                                        timeController.text = pickedTime.format(
                                          context,
                                        );
                                        isTimeValid = validateDateTime();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (!isTimeValid)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Error: Selected time cannot be in the future',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (_hasAdminPermissions)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Active Status:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Switch(
                                            value: isActiveStatus,
                                            onChanged: (value) {
                                              setState(() {
                                                isActiveStatus = value;
                                                selectedActiveStatus = value
                                                    ? 'active'
                                                    : 'inactive';
                                                if (value && hasDuration) {
                                                  updateExpirationTime();
                                                }
                                              });
                                            },
                                            activeColor: Colors.green,
                                            inactiveThumbColor: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isActiveStatus
                                                ? 'Active'
                                                : 'Inactive',
                                            style: TextStyle(
                                              color: isActiveStatus
                                                  ? Colors.green
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // NEW: Optional duration checkbox and selector for desktop
                                  if (isActiveStatus) ...[
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: hasDuration,
                                          onChanged: (value) {
                                            setState(() {
                                              hasDuration = value ?? false;
                                              if (hasDuration) {
                                                updateExpirationTime();
                                              } else {
                                                expirationTime = null;
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Set investigation duration',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Auto-deactivate this incident after the specified time',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasDuration) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Slider(
                                              value: selectedDurationHours
                                                  .toDouble(),
                                              min: 1,
                                              max: 168,
                                              divisions: 167,
                                              label: '$selectedDurationHours h',
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedDurationHours = value
                                                      .toInt();
                                                  updateExpirationTime();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              '$selectedDurationHours h',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // IMPROVED: Centered expiration display
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule,
                                                    size: 18,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Expires at:',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                expirationTime
                                                        ?.toLocal()
                                                        .toString()
                                                        .split('.')[0] ??
                                                    'Not set',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade800,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: (isUploadingPhoto || !isTimeValid)
                            ? null
                            : onSubmit,
                        child: isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isUploadingPhoto
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // MOBILE VERSION
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.95,
          ),
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) => IntrinsicHeight(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 20,
                            left: 16,
                            right: 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_location_alt,
                                      size: 32,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Crime Incident',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Report a new crime incident to the system',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Form(
                                key: formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: selectedCrimeType,
                                      decoration: const InputDecoration(
                                        labelText: 'Crime Type',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: crimeTypes.map((crimeType) {
                                        return DropdownMenuItem<String>(
                                          value: crimeType['name'],
                                          child: Text(
                                            '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        if (newValue != null) {
                                          final selected = crimeTypes
                                              .firstWhere(
                                                (crime) =>
                                                    crime['name'] == newValue,
                                              );
                                          setState(() {
                                            selectedCrimeType = newValue;
                                            selectedCrimeId = selected['id'];
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a crime type';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: descriptionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Description (optional)',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPhotoSection(
                                      selectedPhoto,
                                      isUploadingPhoto,
                                      (photo, uploading) {
                                        setState(() {
                                          selectedPhoto = photo;
                                          isUploadingPhoto = uploading;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: dateController,
                                      decoration: const InputDecoration(
                                        labelText: 'Date of Incident',
                                        border: OutlineInputBorder(),
                                      ),
                                      readOnly: true,
                                      onTap: () async {
                                        DateTime? pickedDate =
                                            await showDatePicker(
                                              context: context,
                                              initialDate: now,
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime.now(),
                                            );
                                        setState(() {
                                          dateController.text =
                                              "${pickedDate?.year}-${pickedDate?.month.toString().padLeft(2, '0')}-${pickedDate?.day.toString().padLeft(2, '0')}";
                                          isTimeValid = validateDateTime();
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: timeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Time of Incident',
                                        border: OutlineInputBorder(),
                                      ),
                                      readOnly: true,
                                      onTap: () async {
                                        TimeOfDay? pickedTime =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.now(),
                                              builder: (context, child) {
                                                return MediaQuery(
                                                  data: MediaQuery.of(context)
                                                      .copyWith(
                                                        alwaysUse24HourFormat:
                                                            false,
                                                      ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                        if (pickedTime != null) {
                                          setState(() {
                                            timeController.text = pickedTime
                                                .format(context);
                                            isTimeValid = validateDateTime();
                                          });
                                        }
                                      },
                                    ),
                                    if (!isTimeValid)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Error: Selected time cannot be in the future',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    if (_hasAdminPermissions)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActiveStatus
                                              ? Colors.green.shade50
                                              : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isActiveStatus
                                                ? Colors.green.shade200
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isActiveStatus
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      color: isActiveStatus
                                                          ? Colors.green
                                                          : Colors.grey,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Status: ${isActiveStatus ? 'Active' : 'Inactive'}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isActiveStatus
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : Colors
                                                                  .grey
                                                                  .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Transform.scale(
                                                  scale: 0.8,
                                                  child: Switch(
                                                    value: isActiveStatus,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        isActiveStatus = value;
                                                        selectedActiveStatus =
                                                            value
                                                            ? 'active'
                                                            : 'inactive';
                                                        if (value &&
                                                            hasDuration) {
                                                          updateExpirationTime();
                                                        }
                                                      });
                                                    },
                                                    activeColor: Colors.green,
                                                    inactiveThumbColor:
                                                        Colors.grey,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // NEW: Optional duration checkbox and selector for mobile
                                            if (isActiveStatus) ...[
                                              const SizedBox(height: 12),
                                              const Divider(),
                                              const SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Checkbox(
                                                    value: hasDuration,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        hasDuration =
                                                            value ?? false;
                                                        if (hasDuration) {
                                                          updateExpirationTime();
                                                        } else {
                                                          expirationTime = null;
                                                        }
                                                      });
                                                    },
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 12,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Set investigation duration',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            'Auto-deactivate this incident after the specified time',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                              height: 1.3,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (hasDuration) ...[
                                                const SizedBox(height: 8),
                                                Column(
                                                  children: [
                                                    Slider(
                                                      value:
                                                          selectedDurationHours
                                                              .toDouble(),
                                                      min: 1,
                                                      max: 168,
                                                      divisions: 167,
                                                      label:
                                                          '$selectedDurationHours h',
                                                      onChanged: (value) {
                                                        setState(() {
                                                          selectedDurationHours =
                                                              value.toInt();
                                                          updateExpirationTime();
                                                        });
                                                      },
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            '1h',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          Text(
                                                            '$selectedDurationHours hours',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .blue,
                                                                ),
                                                          ),
                                                          Text(
                                                            '7d',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.blue.shade200,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.schedule,
                                                            size: 16,
                                                            color: Colors
                                                                .blue
                                                                .shade700,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'Will expire at:',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        expirationTime
                                                                ?.toLocal()
                                                                .toString()
                                                                .split(
                                                                  '.',
                                                                )[0] ??
                                                            'Not set',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            (isUploadingPhoto || !isTimeValid)
                                            ? null
                                            : onSubmit,
                                        child: isUploadingPhoto
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Submit'),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: isUploadingPhoto
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading crime types: ${e.toString()}');
      }
    }
  }

  Widget _buildPhotoSection(
    XFile? selectedPhoto,
    bool isUploading,
    Function(XFile?, bool) onPhotoChanged,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (selectedPhoto != null)
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            selectedPhoto.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Error loading image'),
                              );
                            },
                          )
                        : Image.file(
                            File(selectedPhoto.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Error loading image'),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () {
                        onPhotoChanged(null, false);
                      },
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            onPhotoChanged(null, true);
                            try {
                              final photo = await PhotoService.pickImage();
                              onPhotoChanged(photo, false);
                            } catch (e) {
                              onPhotoChanged(null, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error taking photo: $e'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            onPhotoChanged(null, true);
                            try {
                              final photo =
                                  await PhotoService.pickImageFromGallery();
                              onPhotoChanged(photo, false);
                            } catch (e) {
                              onPhotoChanged(null, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error selecting photo: $e'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          if (isUploading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showReportHotspotForm(LatLng position) async {
    setState(() {
      _tempPinnedLocation = null; // Clear temp pin
    });
    final dailyCount = await _getDailyReportCount();

    if (dailyCount >= 5) {
      _showSnackBar('Daily report limit reached (5/5). Try again tomorrow.');
      return;
    }

    try {
      final crimeTypesResponse = await Supabase.instance.client
          .from('crime_type')
          .select('*')
          .order('name');

      if (crimeTypesResponse.isEmpty) {
        if (mounted) _showSnackBar('No crime types available');
        return;
      }

      final crimeTypes = List<Map<String, dynamic>>.from(crimeTypesResponse);
      final now = DateTime.now();

      if (_isDesktopScreen()) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            child: ReportHotspotFormDesktop(
              position: position,
              crimeTypes: crimeTypes,
              onSubmit: _reportHotspot,
              onCancel: () => Navigator.of(context).pop(),
              dailyCount: dailyCount,
            ),
          ),
        );
      } else {
        await _showMobileReportForm(position, crimeTypes, now, dailyCount);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading crime types: ${e.toString()}');
      }
    }
  }

  Future<void> _showMobileReportForm(
    LatLng position,
    List<Map<String, dynamic>> crimeTypes,
    DateTime now,
    int dailyCount,
  ) async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    final timeController = TextEditingController(
      text: TimeOfDay.fromDateTime(now).format(context),
    );

    String selectedCrimeType = crimeTypes[0]['name'];
    int selectedCrimeId = crimeTypes[0]['id'];
    bool isSubmitting = false;
    XFile? selectedPhoto;
    bool isUploadingPhoto = false;
    bool isTimeValid = true;

    bool validateDateTime() {
      try {
        final dateParts = dateController.text.split('-');
        final timeParts = timeController.text.split(' ');
        final time = timeParts[0].split(':');
        final isPM = timeParts.length > 1 && timeParts[1].toLowerCase() == 'pm';

        int hour = int.parse(time[0]);
        final minute = int.parse(time[1]);

        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;

        final selectedDateTime = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          hour,
          minute,
        );

        return !selectedDateTime.isAfter(DateTime.now());
      } catch (e) {
        return false;
      }
    }

    final _ = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return IntrinsicHeight(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                          left: 16,
                          right: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _getDailyCounterColor(dailyCount),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getDailyCounterBorderColor(
                                    dailyCount,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.today,
                                    size: 20,
                                    color: _getDailyCounterTextColor(
                                      dailyCount,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Daily Reports: $dailyCount/5',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getDailyCounterTextColor(
                                        dailyCount,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.report_problem,
                                    size: 32,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Report Crime Incident',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submit a crime report for admin review',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Form(
                              key: formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: selectedCrimeType,
                                    decoration: const InputDecoration(
                                      labelText: 'Crime Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: crimeTypes.map((crimeType) {
                                      return DropdownMenuItem<String>(
                                        value: crimeType['name'],
                                        child: Text(
                                          '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: isSubmitting
                                        ? null
                                        : (newValue) {
                                            if (newValue != null) {
                                              final selected = crimeTypes
                                                  .firstWhere(
                                                    (c) =>
                                                        c['name'] == newValue,
                                                  );
                                              setState(() {
                                                selectedCrimeType = newValue;
                                                selectedCrimeId =
                                                    selected['id'];
                                              });
                                            }
                                          },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select a crime type';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: descriptionController,
                                    decoration: const InputDecoration(
                                      labelText: 'Description (optional)',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                    enabled: !isSubmitting,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPhotoSection(
                                    selectedPhoto,
                                    isUploadingPhoto,
                                    (photo, uploading) {
                                      setState(() {
                                        selectedPhoto = photo;
                                        isUploadingPhoto = uploading;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: dateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Date of Incident',
                                      border: OutlineInputBorder(),
                                    ),
                                    readOnly: true,
                                    onTap: isSubmitting
                                        ? null
                                        : () async {
                                            final pickedDate =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate: now,
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime.now(),
                                                );
                                            if (pickedDate != null) {
                                              setState(() {
                                                dateController.text =
                                                    DateFormat(
                                                      'yyyy-MM-dd',
                                                    ).format(pickedDate);
                                                isTimeValid =
                                                    validateDateTime();
                                              });
                                            }
                                          },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: timeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Time of Incident',
                                      border: OutlineInputBorder(),
                                    ),
                                    readOnly: true,
                                    onTap: isSubmitting
                                        ? null
                                        : () async {
                                            final pickedTime =
                                                await showTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay.now(),
                                                  builder: (context, child) {
                                                    return MediaQuery(
                                                      data:
                                                          MediaQuery.of(
                                                            context,
                                                          ).copyWith(
                                                            alwaysUse24HourFormat:
                                                                false,
                                                          ),
                                                      child: child!,
                                                    );
                                                  },
                                                );
                                            if (pickedTime != null) {
                                              setState(() {
                                                timeController.text = pickedTime
                                                    .format(context);
                                                isTimeValid =
                                                    validateDateTime();
                                              });
                                            }
                                          },
                                  ),
                                  if (!isTimeValid)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Error: Selected time cannot be in the future',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: Colors.red[600],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Important Notice',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Daily limit: 5 reports. Avoid reporting same location twice. False reports may result in account restrictions.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          (isSubmitting ||
                                              isUploadingPhoto ||
                                              !isTimeValid)
                                          ? null
                                          : () async {
                                              if (formKey.currentState!
                                                  .validate()) {
                                                setState(
                                                  () => isSubmitting = true,
                                                );
                                                try {
                                                  final dateParts =
                                                      dateController.text.split(
                                                        '-',
                                                      );
                                                  final timeParts =
                                                      timeController.text.split(
                                                        ' ',
                                                      );
                                                  final time = timeParts[0]
                                                      .split(':');
                                                  final isPM =
                                                      timeParts.length > 1 &&
                                                      timeParts[1]
                                                              .toLowerCase() ==
                                                          'pm';

                                                  int hour = int.parse(time[0]);
                                                  final minute = int.parse(
                                                    time[1],
                                                  );

                                                  if (isPM && hour != 12) {
                                                    hour += 12;
                                                  }
                                                  if (!isPM && hour == 12) {
                                                    hour = 0;
                                                  }

                                                  final dateTime = DateTime(
                                                    int.parse(dateParts[0]),
                                                    int.parse(dateParts[1]),
                                                    int.parse(dateParts[2]),
                                                    hour,
                                                    minute,
                                                  );

                                                  final success =
                                                      await _reportHotspot(
                                                        selectedCrimeId,
                                                        descriptionController
                                                            .text,
                                                        position,
                                                        dateTime,
                                                        selectedPhoto,
                                                      );

                                                  if (mounted) {
                                                    Navigator.pop(
                                                      context,
                                                      success,
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          isSubmitting = false,
                                                    );
                                                    _showSnackBar(
                                                      'Failed to report hotspot: ${e.toString()}',
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                      child: (isSubmitting || isUploadingPhoto)
                                          ? const CircularProgressIndicator()
                                          : Text(
                                              'Submit Report (${5 - dailyCount} remaining)',
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper methods for daily counter styling
  Color _getDailyCounterColor(int count) {
    if (count >= 5) return Colors.red.withOpacity(0.1);
    if (count >= 3) return Colors.orange.withOpacity(0.1);
    return Colors.green.withOpacity(0.1);
  }

  Color _getDailyCounterBorderColor(int count) {
    if (count >= 5) return Colors.red.withOpacity(0.3);
    if (count >= 3) return Colors.orange.withOpacity(0.3);
    return Colors.green.withOpacity(0.3);
  }

  Color _getDailyCounterTextColor(int count) {
    if (count >= 5) return Colors.red.shade700;
    if (count >= 3) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  // EDIT HOTSPOT

  void _showEditHotspotForm(Map<String, dynamic> hotspot) async {
    try {
      // Fetch crime types and existing photo
      final crimeTypesResponse = await Supabase.instance.client
          .from('crime_type')
          .select('*')
          .order('name');

      // Get existing photo if any
      Map<String, dynamic>? existingPhoto;
      try {
        existingPhoto = await PhotoService.getHotspotPhoto(hotspot['id']);
      } catch (e) {
        print('Error fetching existing photo: $e');
      }

      final formKey = GlobalKey<FormState>();
      final descriptionController = TextEditingController(
        text: hotspot['description'] ?? '',
      );

      // FIXED: Consistent timezone handling for edit form
      final hotspotDateTime = parseStoredDateTime(hotspot['time']);

      final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(hotspotDateTime),
      );
      final timeController = TextEditingController(
        text: DateFormat('h:mm a').format(hotspotDateTime),
      );

      final crimeTypes = List<Map<String, dynamic>>.from(crimeTypesResponse);
      String selectedCrimeType = hotspot['crime_type']['name'];
      int selectedCrimeId = hotspot['type_id'];

      // Active status variables
      String selectedActiveStatus = hotspot['active_status'] ?? 'active';
      bool isActiveStatus = selectedActiveStatus == 'active';

      // Photo state
      XFile? newSelectedPhoto;
      bool isUploadingPhoto = false;
      bool _ = existingPhoto != null;
      bool deleteExistingPhoto = false;

      // NEW: Validation state
      bool isTimeValid = true;
      String? timeErrorMessage;

      // NEW: Optional duration tracking for edit
      bool hasDuration = hotspot['expires_at'] != null;
      int selectedDurationHours = 24;
      DateTime? expirationTime = hotspot['expires_at'] != null
          ? DateTime.parse(hotspot['expires_at'])
          : null;

      // Calculate initial duration hours if exists
      if (hasDuration && expirationTime != null) {
        final now = DateTime.now();
        final remaining = expirationTime.difference(now);
        selectedDurationHours = remaining.inHours.clamp(1, 168);
      }

      // HELPER FUNCTION: Parse time from controller
      DateTime parseTimeFromControllers() {
        final dateParts = dateController.text.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);

        // Parse AM/PM time format consistently
        final timeFormat = DateFormat('h:mm a');
        final timeOnly = timeFormat.parse(timeController.text);

        return DateTime(year, month, day, timeOnly.hour, timeOnly.minute);
      }

      // HELPER FUNCTION: Get consistent reported DateTime
      DateTime getReportedDateTime() {
        try {
          final createdString = hotspot['created_at'];
          final parsedCreated = DateTime.parse(createdString);

          if (createdString.endsWith('Z')) {
            return parsedCreated.toLocal();
          } else {
            return parsedCreated;
          }
        } catch (e) {
          return DateTime.now();
        }
      }

      // HELPER FUNCTION: Update expiration time
      void updateExpirationTime() {
        if (hasDuration) {
          final now = DateTime.now();
          expirationTime = now.add(Duration(hours: selectedDurationHours));
        } else {
          expirationTime = null;
        }
      }

      // HELPER FUNCTION: Validate incident time and update state
      void validateTime(StateSetter setState) {
        try {
          final dateTime = parseTimeFromControllers();
          final reportedDateTime = getReportedDateTime();
          final currentDateTime = DateTime.now();

          if (dateTime.isAfter(currentDateTime)) {
            setState(() {
              isTimeValid = false;
              timeErrorMessage = 'Incident time cannot be in the future';
            });
          } else if (dateTime.isAfter(reportedDateTime)) {
            setState(() {
              isTimeValid = false;
              timeErrorMessage =
                  'Incident time cannot be later than when it was reported (${DateFormat('MMM d, yyyy h:mm a').format(reportedDateTime)})';
            });
          } else {
            setState(() {
              isTimeValid = true;
              timeErrorMessage = null;
            });
          }
        } catch (e) {
          setState(() {
            isTimeValid = false;
            timeErrorMessage = 'Invalid date or time format';
          });
        }
      }

      // Desktop/Web view
      if (_isDesktopScreen()) {
        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Edit Crime Report'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Crime type dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCrimeType,
                          decoration: const InputDecoration(
                            labelText: 'Crime Type',
                            border: OutlineInputBorder(),
                          ),
                          items: crimeTypes.map((crimeType) {
                            return DropdownMenuItem<String>(
                              value: crimeType['name'],
                              child: Text(
                                '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final selected = crimeTypes.firstWhere(
                                (c) => c['name'] == value,
                              );
                              setState(() {
                                selectedCrimeType = value;
                                selectedCrimeId = selected['id'];
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a crime type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description field
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Photo management section
                        _buildEditPhotoSection(
                          existingPhoto: existingPhoto,
                          newSelectedPhoto: newSelectedPhoto,
                          isUploadingPhoto: isUploadingPhoto,
                          deleteExistingPhoto: deleteExistingPhoto,
                          onPhotoChanged: (photo, uploading) {
                            setState(() {
                              newSelectedPhoto = photo;
                              isUploadingPhoto = uploading;
                            });
                          },
                          onDeleteExistingToggle: (delete) {
                            setState(() {
                              deleteExistingPhoto = delete;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date and time fields
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: dateController,
                                decoration: const InputDecoration(
                                  labelText: 'Date of Incident',
                                  border: OutlineInputBorder(),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final reportedDate = getReportedDateTime();
                                  final currentDate = DateTime.now();
                                  final maxDate = DateTime(
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.year
                                        : reportedDate.year,
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.month
                                        : reportedDate.month,
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.day
                                        : reportedDate.day,
                                  );

                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        hotspotDateTime.isBefore(maxDate)
                                        ? hotspotDateTime
                                        : maxDate,
                                    firstDate: DateTime(2000),
                                    lastDate: maxDate,
                                  );
                                  dateController.text = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(pickedDate!);
                                  validateTime(setState);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: timeController,
                                decoration: const InputDecoration(
                                  labelText: 'Time of Incident',
                                  border: OutlineInputBorder(),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      hotspotDateTime,
                                    ),
                                  );

                                  if (pickedTime != null) {
                                    final selectedDate = DateTime.parse(
                                      dateController.text,
                                    );
                                    final pickedDateTime = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );

                                    timeController.text = DateFormat(
                                      'h:mm a',
                                    ).format(pickedDateTime);
                                    validateTime(setState);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Error message display
                        if (!isTimeValid && timeErrorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 16,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    timeErrorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Active status for admins
                        if (_hasAdminPermissions)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Active Status:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Switch(
                                          value: isActiveStatus,
                                          onChanged: (value) {
                                            setState(() {
                                              isActiveStatus = value;
                                              selectedActiveStatus = value
                                                  ? 'active'
                                                  : 'inactive';
                                              if (value && hasDuration) {
                                                updateExpirationTime();
                                              }
                                            });
                                          },
                                          activeColor: Colors.green,
                                          inactiveThumbColor: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isActiveStatus
                                              ? 'Active'
                                              : 'Inactive',
                                          style: TextStyle(
                                            color: isActiveStatus
                                                ? Colors.green
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Duration section for desktop
                                if (isActiveStatus) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: hasDuration,
                                        onChanged: (value) {
                                          setState(() {
                                            hasDuration = value ?? false;
                                            if (hasDuration) {
                                              updateExpirationTime();
                                            } else {
                                              expirationTime = null;
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Set investigation duration',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Auto-deactivate this incident after the specified time',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasDuration) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: selectedDurationHours
                                                .toDouble(),
                                            min: 1,
                                            max: 168,
                                            divisions: 167,
                                            label: '$selectedDurationHours h',
                                            onChanged: (value) {
                                              setState(() {
                                                selectedDurationHours = value
                                                    .toInt();
                                                updateExpirationTime();
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            '$selectedDurationHours h',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  size: 18,
                                                  color: Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Expires at:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              expirationTime
                                                      ?.toLocal()
                                                      .toString()
                                                      .split('.')[0] ??
                                                  'Not set',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: (isUploadingPhoto || !isTimeValid)
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              final dateTime = parseTimeFromControllers();

                              // Update hotspot first
                              await _updateHotspot(
                                hotspot['id'],
                                selectedCrimeId,
                                descriptionController.text,
                                dateTime,
                                selectedActiveStatus,
                                expirationTime: (isActiveStatus && hasDuration)
                                    ? expirationTime
                                    : null,
                              );

                              // Handle photo updates
                              await _handlePhotoUpdates(
                                hotspotId: hotspot['id'],
                                existingPhoto: existingPhoto,
                                newPhoto: newSelectedPhoto,
                                deleteExisting: deleteExistingPhoto,
                              );

                              await _loadHotspots();
                              if (mounted) {
                                Navigator.pop(context);
                                _showSnackBar('Crime report updated');
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update crime report: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isUploadingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // MOBILE VIEW
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.95,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              left: 16.0,
              right: 16.0,
              top: 25.0,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                // Initialize validation on first build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  validateTime(setState);
                });

                return Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedCrimeType,
                          decoration: const InputDecoration(
                            labelText: 'Crime Type',
                            border: OutlineInputBorder(),
                          ),
                          items: crimeTypes.map((crimeType) {
                            return DropdownMenuItem<String>(
                              value: crimeType['name'],
                              child: Text(
                                '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              final selected = crimeTypes.firstWhere(
                                (crime) => crime['name'] == newValue,
                              );
                              setState(() {
                                selectedCrimeType = newValue;
                                selectedCrimeId = selected['id'];
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a crime type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Photo section for mobile
                        _buildEditPhotoSection(
                          existingPhoto: existingPhoto,
                          newSelectedPhoto: newSelectedPhoto,
                          isUploadingPhoto: isUploadingPhoto,
                          deleteExistingPhoto: deleteExistingPhoto,
                          onPhotoChanged: (photo, uploading) {
                            setState(() {
                              newSelectedPhoto = photo;
                              isUploadingPhoto = uploading;
                            });
                          },
                          onDeleteExistingToggle: (delete) {
                            setState(() {
                              deleteExistingPhoto = delete;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date and time fields with real-time validation
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: dateController,
                                decoration: const InputDecoration(
                                  labelText: 'Date of Incident',
                                  border: OutlineInputBorder(),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final reportedDate = getReportedDateTime();
                                  final currentDate = DateTime.now();
                                  final maxDate = DateTime(
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.year
                                        : reportedDate.year,
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.month
                                        : reportedDate.month,
                                    currentDate.isBefore(reportedDate)
                                        ? currentDate.day
                                        : reportedDate.day,
                                  );

                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        hotspotDateTime.isBefore(maxDate)
                                        ? hotspotDateTime
                                        : maxDate,
                                    firstDate: DateTime(2000),
                                    lastDate: maxDate,
                                  );
                                  dateController.text = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(pickedDate!);
                                  validateTime(setState);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: timeController,
                                decoration: const InputDecoration(
                                  labelText: 'Time of Incident',
                                  border: OutlineInputBorder(),
                                ),
                                readOnly: true,
                                onTap: () async {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      hotspotDateTime,
                                    ),
                                  );

                                  if (pickedTime != null) {
                                    final selectedDate = DateTime.parse(
                                      dateController.text,
                                    );
                                    final pickedDateTime = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );

                                    timeController.text = DateFormat(
                                      'h:mm a',
                                    ).format(pickedDateTime);
                                    validateTime(setState);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Error message display
                        if (!isTimeValid && timeErrorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 16,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    timeErrorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Add active status toggle for admins only
                        if (_hasAdminPermissions)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActiveStatus
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActiveStatus
                                    ? Colors.green.shade200
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isActiveStatus
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: isActiveStatus
                                              ? Colors.green
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Status: ${isActiveStatus ? 'Active' : 'Inactive'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isActiveStatus
                                                ? Colors.green.shade700
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: isActiveStatus,
                                        onChanged: (value) {
                                          setState(() {
                                            isActiveStatus = value;
                                            selectedActiveStatus = value
                                                ? 'active'
                                                : 'inactive';
                                            if (value && hasDuration) {
                                              updateExpirationTime();
                                            }
                                          });
                                        },
                                        activeColor: Colors.green,
                                        inactiveThumbColor: Colors.grey,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                                // Duration section for mobile
                                if (isActiveStatus) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: hasDuration,
                                        onChanged: (value) {
                                          setState(() {
                                            hasDuration = value ?? false;
                                            if (hasDuration) {
                                              updateExpirationTime();
                                            } else {
                                              expirationTime = null;
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Set investigation duration',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Auto-deactivate this incident after the specified time',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasDuration) ...[
                                    const SizedBox(height: 8),
                                    Column(
                                      children: [
                                        Slider(
                                          value: selectedDurationHours
                                              .toDouble(),
                                          min: 1,
                                          max: 168,
                                          divisions: 167,
                                          label: '$selectedDurationHours h',
                                          onChanged: (value) {
                                            setState(() {
                                              selectedDurationHours = value
                                                  .toInt();
                                              updateExpirationTime();
                                            });
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '1h',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '$selectedDurationHours hours',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              Text(
                                                '7d',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 16,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Will expire at:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            expirationTime
                                                    ?.toLocal()
                                                    .toString()
                                                    .split('.')[0] ??
                                                'Not set',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),

                        // Update and Cancel buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (isUploadingPhoto || !isTimeValid)
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          try {
                                            final dateTime =
                                                parseTimeFromControllers();

                                            // Show loading indicator
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (BuildContext context) {
                                                return const AlertDialog(
                                                  content: Row(
                                                    children: [
                                                      CircularProgressIndicator(),
                                                      SizedBox(width: 16),
                                                      Text('Updating...'),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );

                                            // Update hotspot
                                            await _updateHotspot(
                                              hotspot['id'],
                                              selectedCrimeId,
                                              descriptionController.text,
                                              dateTime,
                                              selectedActiveStatus,
                                              expirationTime:
                                                  (isActiveStatus &&
                                                      hasDuration)
                                                  ? expirationTime
                                                  : null,
                                            );

                                            // Handle photo updates
                                            await _handlePhotoUpdates(
                                              hotspotId: hotspot['id'],
                                              existingPhoto: existingPhoto,
                                              newPhoto: newSelectedPhoto,
                                              deleteExisting:
                                                  deleteExistingPhoto,
                                            );

                                            await _loadHotspots();

                                            if (mounted) {
                                              // Close loading dialog
                                              Navigator.of(context).pop();
                                              // Close edit dialog
                                              Navigator.pop(context);
                                              _showSnackBar(
                                                'Crime report updated successfully',
                                              );
                                            }
                                          } catch (e) {
                                            print('Update error details: $e');
                                            if (mounted) {
                                              // Close loading dialog if it's open
                                              Navigator.of(context).pop();

                                              // Show error dialog
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.error,
                                                          color:
                                                              Colors.red[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Text(
                                                          'Update Failed',
                                                        ),
                                                      ],
                                                    ),
                                                    content: Text(
                                                      'Failed to update crime report:\n\n${e.toString()}',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            }
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: isUploadingPhoto
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Update'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[500],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading crime types: ${e.toString()}');
      }
    }
  }

  // MODIFIED: _reportHotspot - Clear temp pin IMMEDIATELY before database operation
  Future<bool> _reportHotspot(
    int typeId,
    String description,
    LatLng position,
    DateTime dateTime, [
    XFile? photo,
  ]) async {
    try {
      final currentUserId = _userProfile?['id'];
      if (currentUserId == null) {
        _showSnackBar('User not authenticated');
        return false;
      }

      // ✅ CRITICAL FIX: Clear temp pin IMMEDIATELY before any async operations
      if (mounted) {
        setState(() {
          _tempPinnedLocation = null;
        });
      }

      // Check daily report limit (5 per day)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dailyReportsResponse = await Supabase.instance.client
          .from('hotspot')
          .select('id')
          .eq('reported_by', currentUserId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      if (dailyReportsResponse.length >= 5) {
        _showSnackBar(
          'Daily report limit reached (5 reports per day). Please try again tomorrow.',
        );
        return false;
      }

      // Check for nearby reports (within 50 meters)
      final nearbyDistance = 50;
      final nearbyReportsResponse = await Supabase.instance.client.rpc(
        'get_nearby_hotspots',
        params: {
          'lat': position.latitude,
          'lng': position.longitude,
          'distance_meters': nearbyDistance,
        },
      );

      final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
      final recentNearbyReports = (nearbyReportsResponse as List).where((
        report,
      ) {
        final createdAt = DateTime.parse(report['created_at']);
        return createdAt.isAfter(oneDayAgo);
      }).toList();

      if (recentNearbyReports.isNotEmpty) {
        _showSnackBar(
          'A recent report already exists near this location. Please check existing reports or try a different location.',
        );
        return false;
      }

      // Proceed with report submission
      final insertData = {
        'type_id': typeId,
        'description': description.trim().isNotEmpty
            ? description.trim()
            : null,
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'time': dateTime.toUtc().toIso8601String(),
        'status': 'pending',
        'verification_status': 'unverified',
        'created_by': currentUserId,
        'reported_by': currentUserId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('hotspot')
          .insert(insertData)
          .select('id')
          .single();

      print('✅ Hotspot inserted successfully: ${response['id']}');
      final hotspotId = response['id'] as int;

      // ✅ CRITICAL FIX: Mark as processed to prevent _handleHotspotInsert from adding it again
      _processedHotspotIds.add(hotspotId);

      // ✅ Manually fetch and add the hotspot for the current user
      // This ensures they see their own report immediately without waiting for realtime
      try {
        final newHotspot = await Supabase.instance.client
            .from('hotspot')
            .select('''
              *,
              crime_type: type_id (id, name, level, category, description),
              created_by_profile: created_by (id, username, email),
              reported_by_profile: reported_by (id, username, email),
              verifier_profile: verified_by (first_name, last_name)
            ''')
            .eq('id', hotspotId)
            .single();

        if (mounted) {
          setState(() {
            final crimeType = newHotspot['crime_type'];
            final crimeTypeData = crimeType != null && crimeType is Map
                ? {
                    'id': crimeType['id'] ?? newHotspot['type_id'],
                    'name': crimeType['name'] ?? 'Unknown',
                    'level': crimeType['level'] ?? 'unknown',
                    'category': crimeType['category'] ?? 'General',
                    'description': crimeType['description'],
                  }
                : {
                    'id': newHotspot['type_id'],
                    'name': 'Unknown',
                    'level': 'unknown',
                    'category': 'General',
                    'description': null,
                  };

            _hotspots.insert(0, {
              ...newHotspot,
              'created_by': newHotspot['created_by'],
              'reported_by': newHotspot['reported_by'],
              'crime_type': crimeTypeData,
            });
          });

          // Update heatmap with the new hotspot
          _updateHeatmapOnInsert(newHotspot);
        }
      } catch (fetchError) {
        print('Error fetching newly created hotspot: $fetchError');
        // Fallback to reload if fetch fails
        if (mounted) await _loadHotspots();
      }

      // Upload photo if provided
      if (photo != null) {
        try {
          await PhotoService.uploadPhoto(
            imageFile: photo,
            hotspotId: hotspotId,
            userId: currentUserId,
          );
          print('Photo uploaded successfully for hotspot $hotspotId');
        } catch (e) {
          print('Photo upload failed: $e');
          _showSnackBar(
            'Report saved but photo upload failed: ${e.toString()}',
          );
        }
      }

      // Create admin notifications
      try {
        final admins = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('role', 'admin');

        if (admins.isNotEmpty) {
          final notifications = admins
              .map(
                (admin) => {
                  'user_id': admin['id'],
                  'title': 'New Crime Report',
                  'message': 'New crime report awaiting review',
                  'type': 'report',
                  'hotspot_id': hotspotId,
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                },
              )
              .toList();

          await Supabase.instance.client
              .from('notifications')
              .insert(notifications);
        }
      } catch (notificationError) {
        print('Error creating notifications: $notificationError');
      }

      final remainingReports = 4 - dailyReportsResponse.length;
      _showSnackBar(
        'Report submitted successfully and is awaiting admin approval. You have $remainingReports reports remaining today.',
      );
      return true;
    } catch (e) {
      _showSnackBar('Failed to report hotspot: ${e.toString()}');
      print('Error in _reportHotspot: $e');
      return false;
    }
  }

  // Optional: Method to check current day's report count for UI display
  Future<int> _getDailyReportCount() async {
    try {
      final currentUserId = _userProfile?['id'];
      if (currentUserId == null) return 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dailyReportsResponse = await Supabase.instance.client
          .from('hotspot')
          .select('id')
          .eq('reported_by', currentUserId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      return dailyReportsResponse.length;
    } catch (e) {
      print('Error getting daily report count: $e');
      return 0;
    }
  }

  // 7. Add method to check and refresh if real-time is disconnected
  void _checkRealtimeConnection() {
    if (_userProfile != null) {
      if (!_hotspotsChannelConnected) {
        print('Hotspots channel disconnected, attempting reconnection...');
        _setupRealtimeSubscription();
      }

      if (!_notificationsChannelConnected) {
        print('Notifications channel disconnected, attempting reconnection...');
        _setupNotificationsRealtime();
      }
    }
  }

  // SAVE HOTSPOT
  Future<int?> _saveHotspot(
    String typeId,
    String description,
    LatLng position,
    DateTime dateTime,
    String activeStatus, {
    DateTime? expirationTime,
  }) async {
    try {
      final currentUserId = _userProfile?['id'];
      if (currentUserId == null) {
        _showSnackBar('User not authenticated');
        return null;
      }

      final nearbyDistance = 50;
      final nearbyHotspotsResponse = await Supabase.instance.client.rpc(
        'get_nearby_hotspots',
        params: {
          'lat': position.latitude,
          'lng': position.longitude,
          'distance_meters': nearbyDistance,
        },
      );

      final thirtyMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 30),
      );
      final recentNearbyHotspots = (nearbyHotspotsResponse as List).where((
        hotspot,
      ) {
        final createdAt = DateTime.parse(hotspot['created_at']);
        return createdAt.isAfter(thirtyMinutesAgo);
      }).toList();

      if (recentNearbyHotspots.isNotEmpty) {
        final shouldProceed = await _showNearbyHotspotConfirmation(
          position,
          recentNearbyHotspots,
        );

        if (!shouldProceed) {
          return null;
        }
      }

      final insertData = {
        'type_id': int.parse(typeId),
        'description': description.trim().isNotEmpty
            ? description.trim()
            : null,
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'time': dateTime.toUtc().toIso8601String(),
        'created_by': currentUserId,
        'status': 'approved',
        'active_status': activeStatus,
        'verification_status': 'verified', // ← NEW
        'verified_by': currentUserId, // ← NEW
        'verified_at': DateTime.now().toIso8601String(), // ← NEW
        if (expirationTime != null)
          'expires_at': expirationTime.toUtc().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('hotspot')
          .insert(insertData)
          .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .single();

      print('Crime report added successfully: ${response['id']}');

      await Future.delayed(const Duration(milliseconds: 500));

      final hotspotExists = _hotspots.any((h) => h['id'] == response['id']);

      if (!hotspotExists) {
        print('Real-time failed, manually adding hotspot to UI');
        if (mounted) {
          setState(() {
            final crimeType = response['crime_type'] ?? {};
            _hotspots.insert(0, {
              ...response,
              'crime_type': {
                'id': crimeType['id'] ?? response['type_id'],
                'name': crimeType['name'] ?? 'Unknown',
                'level': crimeType['level'] ?? 'unknown',
                'category': crimeType['category'] ?? 'General',
                'description': crimeType['description'],
              },
            });
          });
        }
      }

      if (mounted) {
        _showSnackBar('Crime record saved');
      }

      return response['id'] as int?;
    } catch (e) {
      _showSnackBar('Failed to save hotspot: ${e.toString()}');
      print('Error details: $e');
      return null;
    }
  }

  // Show confirmation dialog for nearby hotspots (Admin version)
  Future<bool> _showNearbyHotspotConfirmation(
    LatLng position,
    List<dynamic> nearbyHotspots,
  ) async {
    final isDesktop = _isDesktopScreen();

    if (isDesktop) {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Nearby Crime Reports Found'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'There ${nearbyHotspots.length == 1 ? 'is' : 'are'} ${nearbyHotspots.length} recent crime report${nearbyHotspots.length == 1 ? '' : 's'} within 50 meters of this location:',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Column(
                          children: nearbyHotspots.take(3).map((hotspot) {
                            final createdAt = DateTime.parse(
                              hotspot['created_at'],
                            );
                            final timeAgo = _getTimeAgo(createdAt);
                            final distance =
                                (hotspot['distance_meters'] as double).round();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Crime Type: ${hotspot['type_name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Distance: ${distance}m away',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Created: $timeAgo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    if (nearbyHotspots.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${nearbyHotspots.length - 3} more',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'This might be a duplicate report or misclick. Do you still want to add this crime incident?',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Add Anyway'),
                ),
              ],
            ),
          ) ??
          false;
    } else {
      return await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (context) => Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nearby Crime Reports Found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content
                  Text(
                    'There ${nearbyHotspots.length == 1 ? 'is' : 'are'} ${nearbyHotspots.length} recent crime report${nearbyHotspots.length == 1 ? '' : 's'} within 50 meters:',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        children: nearbyHotspots.take(3).map((hotspot) {
                          final createdAt = DateTime.parse(
                            hotspot['created_at'],
                          );
                          final timeAgo = _getTimeAgo(createdAt);
                          final distance =
                              (hotspot['distance_meters'] as double).round();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Crime Type: ${hotspot['type_name']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Distance: ${distance}m away'),
                                  Text(
                                    'Created: $timeAgo',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  if (nearbyHotspots.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${nearbyHotspots.length - 3} more',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'This might be a duplicate report or misclick. Do you still want to add this crime incident?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Add Anyway'),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ) ??
          false;
    }
  }

  DateTime parseStoredDateTime(String timeString) {
    try {
      final parsedTime = DateTime.parse(timeString);

      // ALWAYS treat Supabase timestamps as UTC and convert to Philippine time
      // Supabase stores in UTC, so we must convert to local timezone
      return parsedTime.toUtc().toLocal();
    } catch (e) {
      print('Error parsing datetime: $e');
      return DateTime.now();
    }
  }

  // ============================================
  // FIXED: Your _getTimeAgo with safeguard
  // ============================================

  String _getTimeAgo(DateTime dateTime, {bool compact = false}) {
    // Ensure we're comparing in local time (Philippine time)
    final now = DateTime.now(); // This is in device's local time
    final localDateTime = dateTime.toLocal(); // Ensure input is also local
    final difference = now.difference(localDateTime);

    // Safeguard against negative durations (timezone issues)
    if (difference.isNegative) {
      print('⚠️ Warning: Negative time difference detected for $dateTime');
      return compact ? 'now' : 'Just now';
    }

    if (compact) {
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } else {
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    }
  }

  //SHARE LOCATION
  Future<void> _shareLocation(LatLng position) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final geoUrl =
        'geo:${position.latitude},${position.longitude}?q=${position.latitude},${position.longitude}';

    try {
      if (await canLaunchUrl(Uri.parse(geoUrl))) {
        await launchUrl(Uri.parse(geoUrl));
        return;
      }

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        return;
      }

      await Share.share('My location: $url');
    } catch (e) {
      _showSnackBar('Could not share location: ${e.toString()}');
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    isLoggingOut = true; // Set the flag
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  //LOGOUT MODAL
  void _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      _logout();
    }
  }

  void _showProfileDialog() {
    final isDesktopOrWeb =
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.windows ||
        kIsWeb;

    if (!isDesktopOrWeb) {
      return;
    }

    void toggleEditMode() {
      setState(() {
        // Reset save button state when entering edit mode
        if (!_profileScreen.isEditingProfile) {
          _profileScreen.resetSaveButtonState(); // Option 2
          // OR
          // _profileScreen.saveButtonState = SaveButtonState.normal; // Option 1
        }

        _profileScreen.isEditingProfile = !_profileScreen.isEditingProfile;
      });
      Navigator.pop(context);
      _showProfileDialog();
    }

    Future<void> refreshProfile() async {
      final user = _authService.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _userProfile = response;
            _isAdmin = response['role'] == 'admin';
            _isOfficer = response['role'] == 'officer';
            _profileScreen = ProfileScreen(
              _authService,
              _userProfile,
              _isAdmin,
              _hasAdminPermissions,
            );
            _profileScreen.initControllers();
          });
        }
      }
    }

    void handleSuccess() {
      refreshProfile().then((_) {
        setState(() {
          _profileScreen.isEditingProfile = false;
        });
        Navigator.pop(context);
        _showProfileDialog();
      });
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.only(
          left: _isSidebarVisible ? 285 : 85,
          top: 100,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800),
          child: _profileScreen.isEditingProfile
              ? _profileScreen.buildDesktopEditProfileForm(
                  context,
                  toggleEditMode,
                  onSuccess: handleSuccess,
                  isSidebarVisible: _isSidebarVisible,
                  onStateChange: setState, // Pass setState
                )
              : _profileScreen.buildDesktopProfileView(
                  context,
                  toggleEditMode,
                  onClosePressed: () => Navigator.pop(context),
                  isSidebarVisible: _isSidebarVisible,
                ),
        ),
      ),
    ).then((_) {
      if (!_profileScreen.isEditingProfile) {
        setState(() => _currentTab = MainTab.map);
      }
    });
  }

  // FOR QUICK ACCESS
  void _showOnMap(Map<String, dynamic> item) {
    try {
      final coords = item['location']['coordinates'];
      if (coords == null || coords.length < 2) {
        _showSnackBar('Invalid location data');
        return;
      }

      final itemLocation = LatLng(coords[1], coords[0]);

      // Switch to map tab
      setState(() {
        _currentTab = MainTab.map;

        // Set appropriate selections based on item type
        if (item['crime_type'] != null) {
          // It's a hotspot
          _selectedHotspot = item;
          _selectedSafeSpot = null;
          _selectedSavePoint = null; // Clear save point selection
        } else if (item['safe_spot_types'] != null) {
          // It's a safe spot
          _selectedSafeSpot = item;
          _selectedHotspot = null;
          _selectedSavePoint = null; // Clear save point selection
        } else {
          // It's a save point
          _selectedSavePoint = item;
          _selectedSafeSpot = null;
          _selectedHotspot = null;
        }
      });

      // Center map on the location
      _mapController.move(itemLocation, 16.0);

      // Show details after a brief delay to allow map to center
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          if (item['crime_type'] != null) {
            // It's a hotspot
            _showHotspotDetails(item);
          } else if (item['safe_spot_types'] != null) {
            // It's a safe spot
            SafeSpotDetails.showSafeSpotDetails(
              context: context,
              safeSpot: item,
              userProfile: _userProfile,
              isAdmin: _hasAdminPermissions,
              onUpdate: () => _loadSafeSpots(),
              onGetSafeRoute: _getSafeRoute,
            );
          } else {
            // It's a save point
            SavePointDetails.showSavePointDetails(
              context: context,
              savePoint: item,
              userProfile: _userProfile,
              onUpdate: () =>
                  _loadSavePoints(), // Ensure _loadSavePoints is defined
              onGetSafeRoute: _getSafeRoute,
            );
          }
        }
      });
    } catch (e) {
      print('Error showing item on map: $e');
      _showSnackBar('Unable to show location on map');
    }
  }

  // Keep your existing _navigateToSafeSpot method (for safe spots navigation without details)
  void _navigateToSafeSpot(Map<String, dynamic> safeSpot) {
    final coords = safeSpot['location']['coordinates'];
    final safeSpotLocation = LatLng(coords[1], coords[0]);

    setState(() {
      _currentTab = MainTab.map; // Switch to map tab
      _selectedSafeSpot = safeSpot; // Select the safe spot
      _selectedHotspot = null; // Clear hotspot selection
    });

    // Move map to safe spot location
    _mapController.move(safeSpotLocation, 16.0);

    // Start navigation directly without showing details dialog
    _getDirections(safeSpotLocation);
  }

  // Update your existing _navigateToHotspot method (for hotspots navigation without details)
  void _navigateToHotspot(Map<String, dynamic> hotspot) {
    final coords = hotspot['location']['coordinates'];
    final hotspotLocation = LatLng(coords[1], coords[0]);

    setState(() {
      _currentTab = MainTab.map; // Switch to map tab
      _selectedHotspot = hotspot; // Select the hotspot
      _selectedSafeSpot = null; // Clear safe spot selection
    });

    // Move map to hotspot location
    _mapController.move(hotspotLocation, 16.0);

    // Start navigation directly without showing details dialog
    _getDirections(hotspotLocation);
  }

  // AUTO ADJUST FROM SIDEBAR TO BOTTOM NAVBAR WHEN SCREEN is MINIMIZED
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = _isDesktopScreen(); // Use consistent method

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        body: isDesktop
            ? _buildResponsiveDesktopLayout()
            : _buildCurrentScreen(isDesktop),
        floatingActionButton: _currentTab == MainTab.map
            ? _buildFloatingActionButtons()
            : null,
        bottomNavigationBar: _buildResponsiveBottomNav(isDesktop),
      ),
    );
  }

  bool _isDesktopScreen() {
    return MediaQuery.of(context).size.width >= 800;
  }

  // BOTTOM NAV BARS MAIN WIDGETS

  Widget _buildBottomNavBar() {
    final profilePictureUrl = _userProfile?['profile_picture_url'];
    final hasProfilePhoto =
        profilePictureUrl != null && profilePictureUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom Nav Bar
            BottomNavigationBar(
              currentIndex: _getBottomNavIndexFromMainTab(_currentTab),
              onTap: _handleBottomNavTap,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    _currentTab == MainTab.map
                        ? Icons.explore_rounded
                        : Icons.explore_outlined,
                    size: 26,
                  ),
                  label: 'Map',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _currentTab == MainTab.chat
                            ? Icons.chat
                            : Icons.chat_outlined,
                        size: 26,
                        color: _currentTab == MainTab.chat
                            ? Colors
                                  .blue
                                  .shade600 // ✅ Blue when active
                            : Colors.grey.shade600, // Gray when inactive
                      ),

                      if (_unreadChatCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadChatCount > 99
                                  ? '99+'
                                  : '$_unreadChatCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Chat',
                ),

                const BottomNavigationBarItem(
                  icon: SizedBox(width: 30, height: 30),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _currentTab == MainTab.notifications
                            ? Icons.notifications_rounded
                            : Icons.notifications_outlined,
                        size: 26,
                      ),
                      if (_unreadNotificationCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadNotificationCount > 99
                                  ? '99+'
                                  : '$_unreadNotificationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: hasProfilePhoto
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentTab == MainTab.profile
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              profilePictureUrl,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  _currentTab == MainTab.profile
                                      ? Icons.person_rounded
                                      : Icons.person_outline_rounded,
                                  size: 26,
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Icon(
                                      _currentTab == MainTab.profile
                                          ? Icons.person_rounded
                                          : Icons.person_outline_rounded,
                                      size: 26,
                                    );
                                  },
                            ),
                          ),
                        )
                      : Icon(
                          _currentTab == MainTab.profile
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          size: 26,
                        ),
                  label: 'Profile',
                ),
              ],
              selectedItemColor: Colors.blue.shade600,
              unselectedItemColor: Colors.grey.shade600,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white.withOpacity(0.95),
              elevation: 0,
            ),

            // Center + Button
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _showQuickActionDialog,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 400, // Limit width for larger screens
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50, // Lightened background
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'Choose an action to perform',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Location info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Actions will use your current location automatically',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons - Vertical layout
                  Column(
                    children: [
                      _buildVerticalActionButton(
                        icon: Icons.report_problem_rounded,
                        iconColor: Colors.orange.shade600,
                        backgroundColor: Colors.orange.shade50,
                        borderColor: Colors.orange.shade100,
                        title: 'Report Incident',
                        subtitle: 'Report crime or dangerous situation',
                        onTap: () {
                          Navigator.pop(context);
                          _quickReportCrime();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildVerticalActionButton(
                        icon: Icons.verified_user_rounded,
                        iconColor: Colors.green.shade600,
                        backgroundColor: Colors.green.shade50,
                        borderColor: Colors.green.shade100,
                        title: 'Add Safe Spot',
                        subtitle: 'Mark a location as safe for the community',
                        onTap: () {
                          Navigator.pop(context);
                          _quickAddSafeSpot();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildVerticalActionButton(
                        icon: Icons.bookmark_add_rounded,
                        iconColor: Colors.blue.shade600,
                        backgroundColor: Colors.blue.shade50,
                        borderColor: Colors.blue.shade100,
                        title: 'Save Point',
                        subtitle: 'Bookmark this location for quick access',
                        onTap: () {
                          Navigator.pop(context);
                          _quickAddSavePoint();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalActionButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // Helper for desktop sidebar - maps visual order to MainTab enum
  MainTab _getMainTabFromDesktopIndex(int index) {
    switch (index) {
      case 0:
        return MainTab.map;
      case 1:
        return MainTab.quickAccess;
      case 2:
        return MainTab.savePoints; // Desktop has savePoints in sidebar
      case 3:
        return MainTab.notifications;
      case 4:
        return MainTab.profile;
      default:
        return MainTab.map;
    }
  }

  // Helper to get desktop sidebar index from MainTab
  int _getDesktopIndexFromMainTab(MainTab tab) {
    switch (tab) {
      case MainTab.map:
        return 0;
      case MainTab.quickAccess:
        return 1;
      case MainTab.savePoints:
        return 2;
      case MainTab.notifications:
        return 3;
      case MainTab.profile:
        return 4;
      case MainTab.chat:
        return 0; // Chat not in desktop sidebar, default to map
    }
  }

  // New helper for the mobile bottom navigation bar index
  int _getBottomNavIndexFromMainTab(MainTab tab) {
    switch (tab) {
      case MainTab.map:
        return 0;
      case MainTab.chat:
        return 1; // Correct index for Chat tab
      // Index 2 is the placeholder, so we skip it here.
      case MainTab.notifications:
        return 3;
      case MainTab.profile:
        return 4;
      case MainTab.quickAccess:
      case MainTab.savePoints:
        // These aren't tabs on the bottom nav, default to map or an error state
        return 0;
    }
  }

  void _handleBottomNavTap(int index) {
    MainTab? targetTab;

    switch (index) {
      case 0:
        targetTab = MainTab.map;
        break;
      case 1:
        targetTab = MainTab.chat;
        break;
      case 2:
        // Center + button - handled by floating button
        return;
      case 3:
        targetTab = MainTab.notifications;
        break;
      case 4:
        targetTab = MainTab.profile;
        break;
    }

    if (targetTab != null) {
      setState(() {
        _currentTab = targetTab!;

        if (_currentTab == MainTab.profile) {
          _profileScreen.isEditingProfile = false;
          _profileScreen.resetTab();
        }

        // ✅ Refresh chat count when switching to chat
        if (_currentTab == MainTab.chat) {
          _loadUnreadChatCount();
        }
      });
    }
  }

  //  QUICK REPORT FUNCTION
  void _quickReportCrime() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current location
      await _getCurrentLocation();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (_currentPosition == null) {
        _showSnackBar('Unable to get current location. Please try again.');
        return;
      }

      // FIXED: Use consistent screen size check instead of admin status
      if (_hasAdminPermissions) {
        _showAddHotspotForm(_currentPosition!);
      } else {
        _showReportHotspotForm(_currentPosition!);
      }

      // Optionally switch to map tab to show the location
      setState(() {
        _currentTab = MainTab.map;
      });
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  // QUICK ADD SAFE SPOT FUNCTION
  void _quickAddSafeSpot() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current location
      await _getCurrentLocation();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (_currentPosition == null) {
        _showSnackBar('Unable to get current location. Please try again.');
        return;
      }

      // Show safe spot form
      SafeSpotForm.showSafeSpotForm(
        context: context,
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        userProfile: _userProfile,
        onUpdate: () {
          // Refresh safe spots on map or any other necessary updates
          _loadSafeSpots(); // You'll need to implement this method if not already present
        },
      );

      // Optionally switch to map tab to show the location
      setState(() {
        _currentTab = MainTab.map;
      });
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  // QUICK ADD SAVE POINT FUNCTION
  void _quickAddSavePoint() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current location
      await _getCurrentLocation();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (_currentPosition == null) {
        _showSnackBar('Unable to get current location. Please try again.');
        return;
      }

      if (_userProfile == null) {
        _showSnackBar('Please log in to save points.');
        return;
      }

      // Show save point form using the existing AddSavePointScreen
      AddSavePointScreen.showAddSavePointForm(
        context: context,
        userProfile: _userProfile,
        initialLocation: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        onUpdate: () {
          // Refresh save points on map
          _loadSavePoints();
        },
      );

      // Optionally switch to map tab to show the location
      setState(() {
        _currentTab = MainTab.map;
      });
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  Widget? _buildResponsiveBottomNav(bool isDesktop) {
    // Only show bottom nav on mobile screens AND when user is logged in
    // Don't show on desktop even when sidebar is hidden
    if (isDesktop || _userProfile == null) {
      return null;
    }

    // Use your existing bottom nav bar design for mobile only
    return _buildBottomNavBar();
  }

  //  SIDEBAR FOR DESKTOP
  Widget _buildResponsiveDesktopLayout() {
    return Stack(
      children: [
        Row(
          children: [
            ResponsiveNavigation(
              currentIndex: _getDesktopIndexFromMainTab(
                _currentTab,
              ), // ← Use helper
              onTap: (index) {
                setState(() {
                  _currentTab = _getMainTabFromDesktopIndex(
                    index,
                  ); // ← Use helper
                  if (_currentTab == MainTab.profile) {
                    _profileScreen.isEditingProfile = false;
                  }
                });
              },
              unreadNotificationCount: _unreadNotificationCount,
              isSidebarVisible: _isSidebarVisible,
              isUserLoggedIn: _userProfile != null,
              onToggle: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
            Expanded(child: _buildCurrentScreen(true)),
          ],
        ),
        // Modified backdrop overlay - excludes sidebar area
        if (_currentTab == MainTab.notifications ||
            _currentTab == MainTab.quickAccess ||
            _currentTab == MainTab.savePoints) // Add SavePoints here
          Positioned(
            left: _isSidebarVisible ? 285 : 64, // Start after sidebar
            top: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = MainTab.map;
                });
              },
              child: Container(color: Colors.black.withOpacity(0.1)),
            ),
          ),
        ResponsiveSidebarToggle(
          isSidebarVisible: _isSidebarVisible,
          isUserLoggedIn: _userProfile != null,
          currentTab: _currentTab.index,
          onToggle: () {
            setState(() {
              _isSidebarVisible = !_isSidebarVisible;
            });
          },
        ),
        if (_currentTab == MainTab.notifications)
          _buildFloatingNotificationPanel(),
        if (_currentTab == MainTab.quickAccess)
          QuickAccessDesktopScreen(
            safeSpots: _safeSpots,
            hotspots: _hotspots,
            currentPosition: _currentPosition,
            userProfile: _userProfile,
            isAdmin: _hasAdminPermissions,
            onGetDirections: _getDirections,
            onGetSafeRoute: _getSafeRoute,
            onShareLocation: _shareLocation,
            onShowOnMap: _showOnMap,
            onNavigateToSafeSpot: _navigateToSafeSpot,
            onNavigateToHotspot: _navigateToHotspot,
            onRefresh: _loadSafeSpots,
            isSidebarVisible: _isSidebarVisible,
            onClose: () {
              setState(() {
                _currentTab = MainTab.map;
              });
            },
          ),
        // Add SavePoints desktop screen
        if (_currentTab == MainTab.savePoints)
          SavePointDesktopScreen(
            userProfile: _userProfile,
            currentPosition: _currentPosition,
            onNavigateToPoint: (point) {
              _mapController.move(point, 16.0);
              setState(() {
                _destination = point;
                _currentTab = MainTab.map; // Switch back to map
              });
            },
            onShowOnMap: (savePoint) {
              _showOnMap(savePoint);
              setState(() {
                _currentTab = MainTab.map; // Switch back to map
              });
            },
            onGetSafeRoute: (point) {
              _getSafeRoute(point);
              setState(() {
                _currentTab = MainTab.map; // Switch back to map
              });
            },
            onUpdate: () => _loadSavePoints(),
            isSidebarVisible: _isSidebarVisible,
            onClose: () {
              setState(() {
                _currentTab = MainTab.map;
              });
            },
          ),
      ],
    );
  }

  // FOR BACK BUTTON CONFIRMATION TO EXIT
  Future<bool> _handleWillPop() async {
    // Check if we're on profile tab and in edit mode
    if (_currentTab == MainTab.profile &&
        _profileScreen.isEditingProfile == true) {
      // Let the profile screen handle the back button
      return true;
    }

    // If not on map tab, switch to map tab
    if (_currentTab != MainTab.map) {
      setState(() {
        _currentTab = MainTab.map;
      });
      return false;
    }

    // Check if we can pop (has previous routes)
    final canPop = Navigator.of(context).canPop();

    // If we can pop, pop the route (this will handle the landing page case)
    if (canPop) {
      Navigator.of(context).pop();
      return false;
    }

    // If this is the root route, show styled exit confirmation
    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Exit App',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to exit Zecure?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text('Exit', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ) ??
        false;

    return shouldExit;
  }

  //MODERN FLOATING ACTION BUTTONS - HORIZONTAL FOR DESKTOP

  Widget _buildFloatingActionButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    if (isDesktop) {
      return _buildDesktopFloatingActions();
    } else {
      return _buildMobileFloatingActions();
    }
  }

  // DESKTOP VERSION - HORIZONTAL LAYOUT
  Widget _buildDesktopFloatingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Map Type Selection Container
        if (_showMapTypeSelector) ...[
          Container(
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: MapType.values.map((type) {
                final isSelected = type == _currentMapType;
                return GestureDetector(
                  onTap: () {
                    _switchMapType(type);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.blue.shade300, width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getMapTypeIcon(type),
                          size: 16,
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _getMapTypeName(type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Modern Button Container - HORIZONTAL
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Map Type Toggle Button
              _buildModernActionButton(
                icon: _getMapTypeIcon(_currentMapType),
                isActive: _showMapTypeSelector,
                onTap: () {
                  setState(() {
                    _showMapTypeSelector = !_showMapTypeSelector;
                  });
                },
                tooltip: 'Map Style',
                size: 40,
              ),

              const SizedBox(width: 4),

              // Compass button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    top: -48,
                    left: -10,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showRotationFeedback ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isRotationLocked
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(-2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isRotationLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isRotationLocked ? 'Locked' : 'Unlocked',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Tooltip(
                    message: _isRotationLocked
                        ? 'Unlock Rotation (Double-tap)'
                        : 'Reset Rotation (Double-tap to lock)',
                    child: GestureDetector(
                      onTap: () {
                        if (!_isRotationLocked) {
                          _mapController.rotate(0);
                          setState(() {
                            _currentMapRotation = 0.0;
                          });
                        }
                        if (_showMapTypeSelector) {
                          setState(() {
                            _showMapTypeSelector = false;
                          });
                        }
                      },
                      onDoubleTap: () {
                        setState(() {
                          _isRotationLocked = !_isRotationLocked;
                          _showRotationFeedback = true;
                        });

                        Timer(const Duration(milliseconds: 1500), () {
                          if (mounted) {
                            setState(() {
                              _showRotationFeedback = false;
                            });
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildCompass(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 4),

              // Filter button
              _buildModernActionButton(
                icon: Icons.tune_rounded,
                isActive: false,
                onTap: () {
                  _showHotspotFilterDialog();
                  if (_showMapTypeSelector) {
                    setState(() {
                      _showMapTypeSelector = false;
                    });
                  }
                },
                tooltip: 'Filter Hotspots',
                size: 40,
              ),

              const SizedBox(width: 4),

              // Chat button - for desktop
              if (_userProfile != null) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildModernActionButton(
                      icon: Icons.chat,
                      isActive: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatDesktopScreen(userProfile: _userProfile!),
                          ),
                        ).then((_) {
                          _loadUnreadChatCount();
                        });

                        if (_showMapTypeSelector) {
                          setState(() {
                            _showMapTypeSelector = false;
                          });
                        }
                      },
                      tooltip: 'Community Chat',
                      size: 40,
                    ),
                    if (_unreadChatCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              _unreadChatCount > 99
                                  ? '99+'
                                  : '$_unreadChatCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),

        const SizedBox(width: 12),

        const SizedBox(width: 12),

        // Vertical stack: Zoom controls on top, Location button below
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom Controls
            Container(
              width: 35,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom In button
                  _buildModernActionButton(
                    icon: Icons.add_rounded,
                    isActive: false,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      final maxZoom = _getMaxZoomForMapType(
                        _currentMapType,
                      ).toDouble();
                      if (currentZoom < maxZoom) {
                        _mapController.move(
                          _mapController.camera.center,
                          (currentZoom + 1).clamp(3.0, maxZoom),
                        );
                      }
                      if (_showMapTypeSelector) {
                        setState(() {
                          _showMapTypeSelector = false;
                        });
                      }
                    },
                    tooltip: 'Zoom In',
                    size: 30,
                  ),

                  const SizedBox(height: 4),

                  // Zoom Out button
                  _buildModernActionButton(
                    icon: Icons.remove_rounded,
                    isActive: false,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      if (currentZoom > 3.0) {
                        _mapController.move(
                          _mapController.camera.center,
                          (currentZoom - 1).clamp(
                            3.0,
                            _getMaxZoomForMapType(_currentMapType).toDouble(),
                          ),
                        );
                      }
                      if (_showMapTypeSelector) {
                        setState(() {
                          _showMapTypeSelector = false;
                        });
                      }
                    },
                    tooltip: 'Zoom Out',
                    size: 30,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // My Location button
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: _buildModernLocationButton(),
            ),
          ],
        ),
      ],
    );
  }

  // MOBILE VERSION - VERTICAL LAYOUT (ORIGINAL)
  Widget _buildMobileFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Map Type Selection Container
        if (_showMapTypeSelector) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: MapType.values.map((type) {
                final isSelected = type == _currentMapType;
                return GestureDetector(
                  onTap: () {
                    _switchMapType(type);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.blue.shade300, width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getMapTypeIcon(type),
                          size: 16,
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _getMapTypeName(type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Modern Button Container
        Container(
          width: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Map Type Toggle Button
              _buildModernActionButton(
                icon: _getMapTypeIcon(_currentMapType),
                isActive: _showMapTypeSelector,
                onTap: () {
                  setState(() {
                    _showMapTypeSelector = !_showMapTypeSelector;
                  });
                },
                tooltip: 'Map Style',
                size: 40,
              ),

              const SizedBox(height: 4),

              // Compass button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    right: _showRotationFeedback ? 48 : 18,
                    top: 3,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showRotationFeedback ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isRotationLocked
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(-2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isRotationLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isRotationLocked ? 'Locked' : 'Unlocked',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Tooltip(
                    message: _isRotationLocked
                        ? 'Unlock Rotation (Double-tap)'
                        : 'Reset Rotation (Double-tap to lock)',
                    child: GestureDetector(
                      onTap: () {
                        if (!_isRotationLocked) {
                          _mapController.rotate(0);
                          setState(() {
                            _currentMapRotation = 0.0;
                          });
                        }
                        if (_showMapTypeSelector) {
                          setState(() {
                            _showMapTypeSelector = false;
                          });
                        }
                      },
                      onDoubleTap: () {
                        setState(() {
                          _isRotationLocked = !_isRotationLocked;
                          _showRotationFeedback = true;
                        });

                        Timer(const Duration(milliseconds: 1500), () {
                          if (mounted) {
                            setState(() {
                              _showRotationFeedback = false;
                            });
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildCompass(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Filter button
              _buildModernActionButton(
                icon: Icons.tune_rounded,
                isActive: false,
                onTap: () {
                  _showHotspotFilterDialog();
                  if (_showMapTypeSelector) {
                    setState(() {
                      _showMapTypeSelector = false;
                    });
                  }
                },
                tooltip: 'Filter Hotspots',
                size: 40,
              ),

              const SizedBox(height: 4),

              // Navigate button - Opens full screen
              _buildModernActionButton(
                icon: Icons.navigation_rounded,
                isActive: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuickAccessScreen(
                        safeSpots: _safeSpots,
                        hotspots: _hotspots,
                        currentPosition: _currentPosition,
                        userProfile: _userProfile,
                        isAdmin: _hasAdminPermissions,
                        onGetDirections: _getDirections,
                        onGetSafeRoute: _getSafeRoute,
                        onShareLocation: _shareLocation,
                        onShowOnMap: (location) {
                          Navigator.pop(context);
                          _showOnMap(location);
                        },
                        onNavigateToSafeSpot: (spot) {
                          Navigator.pop(context);
                          _navigateToSafeSpot(spot);
                        },
                        onNavigateToHotspot: (hotspot) {
                          Navigator.pop(context);
                          _navigateToHotspot(hotspot);
                        },
                        onRefresh: _loadSafeSpots,
                        onNavigate: (destination) {
                          Navigator.pop(context);
                          setState(() {
                            _destination = destination;
                            _currentTab = MainTab.map;
                          });
                          _mapController.move(destination, 16.0);
                        },
                        // ADD THIS NEW PARAMETER:
                        onGetSafeRouteAndClose: (location) {
                          Navigator.pop(context);
                          _getSafeRoute(location);
                        },
                      ),
                    ),
                  );

                  if (_showMapTypeSelector) {
                    setState(() {
                      _showMapTypeSelector = false;
                    });
                  }
                },
                tooltip: 'Quick Navigate',
                size: 40,
              ),

              const SizedBox(height: 4),

              // Save Points button - Only for logged-in users on mobile
              if (_userProfile != null) ...[
                _buildModernActionButton(
                  icon: Icons.bookmark_rounded,
                  isActive: _showSavePointSelector,
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SavePointScreen(
                          userProfile: _userProfile,
                          currentPosition: _currentPosition,
                          onNavigateToPoint: (point) {
                            _mapController.move(point, 16.0);
                            setState(() {
                              _destination = point;
                            });
                          },
                          onShowOnMap: _showOnMap,
                          onGetSafeRoute: _getSafeRoute,
                          onUpdate: () => _loadSavePoints(),
                        ),
                      ),
                    );

                    if (result == true) {
                      _loadSavePoints();
                    }

                    if (_showMapTypeSelector) {
                      setState(() {
                        _showMapTypeSelector = false;
                      });
                    }
                  },
                  tooltip: 'My Save Points',
                  size: 40,
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // My Location button
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: _buildModernLocationButton(),
        ),
      ],
    );
  }

  // Helper method for creating modern action buttons with size parameter
  Widget _buildModernActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    double size = 40,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(size * 0.3),
            border: isActive
                ? Border.all(color: Colors.blue.shade200, width: 1.5)
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  // BIGGER Modern My Location button
  Widget _buildModernLocationButton() {
    return Tooltip(
      message: 'My Location',
      child: GestureDetector(
        onTap: () async {
          setState(() {
            if (_showMapTypeSelector) {
              _showMapTypeSelector = false;
            }
          });

          _moveToCurrentLocation();

          if (_currentPosition == null) {
            await _getCurrentLocation();
            _moveToCurrentLocation();
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _locationButtonPressed ? Colors.blue.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: _locationButtonPressed
                ? null
                : Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Icon(
            _locationButtonPressed
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            color: _locationButtonPressed ? Colors.white : Colors.grey.shade600,
            size: 28,
          ),
        ),
      ),
    );
  }

  //COMPASS COMPASS - More Compass-Like Design

  Widget _buildCompass() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: _isRotationLocked
            ? Border.all(color: Colors.orange.shade400, width: 2)
            : Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating compass elements (only when not locked)
          Transform.rotate(
            angle: _isRotationLocked
                ? 0
                : -_currentMapRotation * (3.14159 / 180),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Compass outer ring
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                ),

                // Compass inner circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  ),
                ),

                // North needle (red)
                Positioned(
                  top: 7,
                  child: Container(
                    width: 2,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _isRotationLocked
                          ? Colors.orange.shade600
                          : Colors.red.shade500,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

                // South needle (white with border)
                Positioned(
                  bottom: 7,
                  child: Container(
                    width: 2,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                      border: Border.all(
                        color: _isRotationLocked
                            ? Colors.orange.shade600
                            : Colors.grey.shade400,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),

                // Center dot
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRotationLocked
                        ? Colors.orange.shade600
                        : Colors.grey.shade600,
                  ),
                ),

                // Cardinal direction markers (small lines)
                // North
                Positioned(
                  top: 3,
                  child: Container(
                    width: 1,
                    height: 3,
                    color: Colors.grey.shade400,
                  ),
                ),
                // East
                Positioned(
                  right: 3,
                  child: Container(
                    width: 3,
                    height: 1,
                    color: Colors.grey.shade400,
                  ),
                ),
                // West
                Positioned(
                  left: 3,
                  child: Container(
                    width: 3,
                    height: 1,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          // Modern lock indicator when rotation is locked
          if (_isRotationLocked)
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // NOTIFICATION MOBILE VIEW

  Widget _buildNotificationsScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // Compact filter icon
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.grey[700]),
            onSelected: (value) {
              setState(() {
                _notificationFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Unread', child: Text('Unread')),
              const PopupMenuItem(value: 'Critical', child: Text('Critical')),
              const PopupMenuItem(value: 'High', child: Text('High')),
              const PopupMenuItem(value: 'Medium', child: Text('Medium')),
              const PopupMenuItem(value: 'Low', child: Text('Low')),
              const PopupMenuItem(
                value: 'Safe Spots',
                child: Text('Safe Spots'),
              ),
            ],
          ),
          // Mark all as read
          if (_getFilteredNotifications().any((n) => !n['is_read']))
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _getFilteredNotifications().isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _buildMobileNotificationsList(), // ✅ NEW METHOD
            ),
    );
  }

  // ✅ NEW: Mobile notifications list with Unread/Read sections
  Widget _buildMobileNotificationsList() {
    final filteredNotifications = _getFilteredNotifications();
    final unreadNotifications = filteredNotifications
        .where((n) => !n['is_read'])
        .toList();
    final readNotifications = filteredNotifications
        .where((n) => n['is_read'])
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        // ✅ UNREAD SECTION
        if (unreadNotifications.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
            child: Row(
              children: [
                Text(
                  'Unread (${unreadNotifications.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...unreadNotifications.map((notification) {
            final createdAt = DateTime.parse(
              notification['created_at'],
            ).toLocal();
            final isToday = _isToday(createdAt);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _markAsRead(notification['id']);
                    _handleNotificationTap(notification);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getIconBackgroundColor(notification),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _getNotificationIcon(notification),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.blue[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            notification['title'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        // ✅ NEW: Show (Verified) badge for verified reports
                                        if (notification['type'] == 'report' &&
                                            notification['hotspot_id'] !=
                                                null &&
                                            _isHotspotVerified(
                                              notification['hotspot_id'],
                                            )) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.green[300]!,
                                              ),
                                            ),
                                            child: Text(
                                              'VERIFIED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _buildPriorityBadge(notification),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification['message'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isToday
                                        ? DateFormat('h:mm a').format(createdAt)
                                        : DateFormat(
                                            'MMM dd, h:mm a',
                                          ).format(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
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
              ),
            );
          }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey[300], thickness: 1),
          ),
          const SizedBox(height: 8),
        ],

        // ✅ READ SECTION
        if (readNotifications.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
            child: Text(
              'Earlier',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...readNotifications.map((notification) {
            final createdAt = DateTime.parse(
              notification['created_at'],
            ).toLocal();
            final isToday = _isToday(createdAt);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleNotificationTap(notification),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getIconBackgroundColor(notification),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _getNotificationIcon(notification),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            notification['title'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        // ✅ NEW: Show (Verified) badge for verified reports
                                        if (notification['type'] == 'report' &&
                                            notification['hotspot_id'] !=
                                                null &&
                                            _isHotspotVerified(
                                              notification['hotspot_id'],
                                            )) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.green[300]!,
                                              ),
                                            ),
                                            child: Text(
                                              'VERIFIED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _buildPriorityBadge(notification),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification['message'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isToday
                                        ? DateFormat('h:mm a').format(createdAt)
                                        : DateFormat(
                                            'MMM dd, h:mm a',
                                          ).format(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
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
              ),
            );
          }),
        ],
      ],
    );
  }

  //NOTIFICATION DESKTOP VIEW

  Widget _buildFloatingNotificationPanel() {
    if (_currentTab != MainTab.notifications) return const SizedBox.shrink();

    return Positioned(
      left: _isSidebarVisible ? 285 : 85, // Adjust based on sidebar width
      top: 100, // Adjust based on your layout
      child: Listener(
        // Prevent pointer events on the notification panel from bubbling up
        onPointerDown: (event) {
          // Stop the event from reaching the backdrop GestureDetector
          // Do nothing here - this prevents the panel from closing when clicked inside
        },
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withOpacity(0.2),
          child: Container(
            width: 450,
            height: 800,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),

                      const SizedBox(width: 8),

                      // Filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _notificationFilter,
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All'),
                              ),
                              DropdownMenuItem(
                                value: 'Unread',
                                child: Text('Unread'),
                              ),
                              DropdownMenuItem(
                                value: 'Critical',
                                child: Text('Critical'),
                              ),
                              DropdownMenuItem(
                                value: 'High',
                                child: Text('High'),
                              ),
                              DropdownMenuItem(
                                value: 'Medium',
                                child: Text('Medium'),
                              ),
                              DropdownMenuItem(
                                value: 'Low',
                                child: Text('Low'),
                              ),
                              DropdownMenuItem(
                                value: 'Safe Spots',
                                child: Text('Safe Spots'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _notificationFilter = value ?? 'All';
                              });
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Mark all as read
                      if (_getFilteredNotifications().any((n) => !n['is_read']))
                        IconButton(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all, size: 16),
                          tooltip: 'Mark all as read',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[700],
                            minimumSize: const Size(32, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Notifications List
                Expanded(
                  child: _getFilteredNotifications().isEmpty
                      ? _buildEmptyState()
                      : _buildScrollableNotifications(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableNotifications() {
    final filteredNotifications = _getFilteredNotifications();

    // ✅ NEW: Separate unread and read notifications
    final unreadNotifications = filteredNotifications
        .where((n) => !n['is_read'])
        .toList();
    final readNotifications = filteredNotifications
        .where((n) => n['is_read'])
        .toList();

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ UNREAD SECTION
          if (unreadNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Row(
                children: [
                  Text(
                    'Unread (${unreadNotifications.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...unreadNotifications.map(
              (notification) =>
                  _buildNotificationCard(notification, isUnread: true),
            ),

            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1),
            const SizedBox(height: 16),
          ],

          // ✅ READ SECTION
          if (readNotifications.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Earlier',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...readNotifications.map(
              (notification) =>
                  _buildNotificationCard(notification, isUnread: false),
            ),
          ],

          // Empty state
          if (unreadNotifications.isEmpty && readNotifications.isEmpty)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification, {
    required bool isUnread,
  }) {
    final createdAt = DateTime.parse(notification['created_at']).toLocal();
    final isToday = _isToday(createdAt);

    // ✅ NEW: Check if this is a "New Crime Report" that has been verified
    final isVerifiedReport =
        notification['type'] == 'report' &&
        notification['hotspot_id'] != null &&
        _isHotspotVerified(notification['hotspot_id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue[25] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? Colors.blue[200]! : Colors.grey[200]!,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isUnread) {
              _markAsRead(notification['id']);
            }
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with unread indicator
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIconBackgroundColor(notification),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _getNotificationIcon(notification),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    notification['title'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                // ✅ NEW: Show (Verified) badge for verified reports
                                if (isVerifiedReport) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _buildPriorityBadge(notification),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isToday
                                ? DateFormat('h:mm a').format(createdAt)
                                : DateFormat(
                                    'MMM dd, h:mm a',
                                  ).format(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
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
      ),
    );
  }

  // ✅ NEW: Helper method to check if a hotspot is verified
  bool _isHotspotVerified(int? hotspotId) {
    if (hotspotId == null) return false;

    final hotspot = _hotspots.firstWhere(
      (h) => h['id'] == hotspotId,
      orElse: () => {},
    );

    return hotspot.isNotEmpty && hotspot['verification_status'] == 'verified';
  }

  Widget _buildPriorityBadge(Map<String, dynamic> notification) {
    final type = notification['type'];

    if (type == 'report' && notification['hotspot_id'] != null) {
      final relatedHotspot = _hotspots.firstWhere(
        (hotspot) => hotspot['id'] == notification['hotspot_id'],
        orElse: () => {},
      );

      if (relatedHotspot.isNotEmpty) {
        final crimeLevel = relatedHotspot['crime_type']?['level'] ?? 'unknown';

        Color badgeColor;
        String badgeText;

        switch (crimeLevel) {
          case 'critical':
            badgeColor = const Color.fromARGB(255, 247, 26, 10);
            badgeText = 'CRITICAL';
            break;
          case 'high':
            badgeColor = const Color.fromARGB(255, 223, 106, 11);
            badgeText = 'HIGH';
            break;
          case 'medium':
            badgeColor = const Color.fromARGB(155, 202, 130, 49);
            badgeText = 'MED';
            break;
          case 'low':
            badgeColor = const Color.fromARGB(255, 216, 187, 23);
            badgeText = 'LOW';
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 0.3,
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You\'re all caught up!',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Color _getIconBackgroundColor(Map<String, dynamic> notification) {
    final type = notification['type'];

    if (type == 'verified') {
      return Colors.green.withOpacity(0.1);
    }

    if (type == 'safe_spot_report') {
      return Colors.blue.withOpacity(0.1);
    } else if (type == 'safe_spot_approval') {
      return Colors.green.withOpacity(0.1);
    } else if (type == 'safe_spot_rejection') {
      return Colors.red.withOpacity(0.1);
    }

    if (type == 'report' && notification['hotspot_id'] != null) {
      final relatedHotspot = _hotspots.firstWhere(
        (hotspot) => hotspot['id'] == notification['hotspot_id'],
        orElse: () => {},
      );

      if (relatedHotspot.isNotEmpty) {
        final crimeLevel = relatedHotspot['crime_type']?['level'] ?? 'unknown';

        switch (crimeLevel) {
          case 'critical':
            return const Color.fromARGB(255, 247, 26, 10).withOpacity(0.1);
          case 'high':
            return const Color.fromARGB(255, 223, 106, 11).withOpacity(0.1);
          case 'medium':
            return const Color.fromARGB(155, 202, 130, 49).withOpacity(0.1);
          case 'low':
            return const Color.fromARGB(255, 216, 187, 23).withOpacity(0.1);
          default:
            return Colors.orange.withOpacity(0.1);
        }
      }
    }

    switch (type) {
      case 'report':
        return Colors.orange.withOpacity(0.1);
      case 'approval':
        return Colors.green.withOpacity(0.1);
      case 'rejection':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.blue.withOpacity(0.1);
    }
  }

  Widget _getNotificationIcon(Map<String, dynamic> notification) {
    final type = notification['type'];

    if (type == 'verified') {
      return const Icon(Icons.verified, color: Colors.green, size: 18);
    }

    if (type == 'safe_spot_report') {
      return const Icon(Icons.add_location_alt, color: Colors.blue, size: 18);
    } else if (type == 'safe_spot_approval') {
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
    } else if (type == 'safe_spot_rejection') {
      return const Icon(Icons.cancel, color: Colors.red, size: 18);
    }

    if (type == 'report' && notification['hotspot_id'] != null) {
      final relatedHotspot = _hotspots.firstWhere(
        (hotspot) => hotspot['id'] == notification['hotspot_id'],
        orElse: () => {},
      );

      if (relatedHotspot.isNotEmpty) {
        final crimeLevel = relatedHotspot['crime_type']?['level'] ?? 'unknown';

        switch (crimeLevel) {
          case 'critical':
            return const Icon(
              Icons.warning_rounded,
              color: Color.fromARGB(255, 247, 26, 10),
              size: 18,
            );
          case 'high':
            return const Icon(
              Icons.error_rounded,
              color: Color.fromARGB(255, 223, 106, 11),
              size: 18,
            );
          case 'medium':
            return const Icon(
              Icons.info_rounded,
              color: Color.fromARGB(155, 202, 130, 49),
              size: 18,
            );
          case 'low':
            return const Icon(
              Icons.info_outline_rounded,
              color: Color.fromARGB(255, 216, 187, 23),
              size: 18,
            );
          default:
            return const Icon(Icons.report, color: Colors.orange, size: 18);
        }
      }
    }

    switch (type) {
      case 'report':
        return const Icon(Icons.report, color: Colors.orange, size: 18);
      case 'approval':
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case 'rejection':
        return const Icon(Icons.cancel, color: Colors.red, size: 18);
      default:
        return const Icon(Icons.notifications, color: Colors.blue, size: 18);
    }
  }

  // Helper method to check if date is today
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Handle safe spot notifications
    if (notification['safe_spot_id'] != null) {
      // Check if safe spot still exists
      final safeSpot = _safeSpots.firstWhere(
        (s) => s['id'] == notification['safe_spot_id'],
        orElse: () => {},
      );

      if (safeSpot.isNotEmpty) {
        // Get safe spot coordinates
        final coords = safeSpot['location']['coordinates'];
        final safeSpotPosition = LatLng(coords[1], coords[0]);

        setState(() {
          _currentTab = MainTab.map; // Switch to map view
          _selectedSafeSpot = safeSpot; // Store the selected safe spot
        });

        // Use post frame callback to ensure UI is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Move map to safe spot location
          _mapController.move(safeSpotPosition, 16.0);

          // Show safe spot details after a small delay to allow map animation
          Future.delayed(const Duration(milliseconds: 200), () {
            _showSafeSpotDetails(safeSpot);
          });
        });
      } else {
        _showSnackBar('The related safe spot has been deleted');
      }
    }
    // Handle hotspot notifications (existing code)
    else if (notification['hotspot_id'] != null) {
      // Check if hotspot still exists
      final hotspot = _hotspots.firstWhere(
        (h) => h['id'] == notification['hotspot_id'],
        orElse: () => {},
      );

      if (hotspot.isNotEmpty) {
        // Get hotspot coordinates
        final coords = hotspot['location']['coordinates'];
        final hotspotPosition = LatLng(coords[1], coords[0]);

        setState(() {
          _currentTab = MainTab.map; // Switch to map view
          _selectedHotspot = hotspot; // Store the selected hotspot
        });

        // Use post frame callback to ensure UI is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Move map to hotspot location
          _mapController.move(hotspotPosition, 15.5);

          // Show hotspot details after a small delay to allow map animation
          Future.delayed(const Duration(milliseconds: 200), () {
            _showHotspotDetails(hotspot);
          });
        });
      } else {
        _showSnackBar('The related hotspot has been deleted');
      }
    }
  }

  // MAP TYPE METHOD

  void _switchMapType(MapType newType) {
    if (newType == _currentMapType) return;

    final currentZoom = _mapController.camera.zoom;
    final currentMaxZoom = _getMaxZoomForMapType(_currentMapType);
    final newMaxZoom = _getMaxZoomForMapType(newType);

    setState(() {
      _currentMapType = newType;
      _showMapTypeSelector = false;
    });

    // Calculate appropriate zoom level for new map type
    double targetZoom = currentZoom;

    if (currentZoom > newMaxZoom) {
      // Current zoom exceeds new map's capability - clamp to max
      targetZoom = newMaxZoom.toDouble();
    } else if (currentZoom == currentMaxZoom && newMaxZoom > currentMaxZoom) {
      // Was at max zoom of previous map, increase zoom for higher resolution map
      targetZoom = math.min(currentZoom + 1, newMaxZoom.toDouble());
    }

    // Apply zoom change with smooth animation
    if (targetZoom != currentZoom) {
      _mapController.move(_mapController.camera.center, targetZoom);

      // Show appropriate feedback message
    }
  }

  // 4. Update the name getter
  String _getMapTypeName(MapType type) {
    switch (type) {
      case MapType.defaultMap:
        return 'Default';
      case MapType.standard:
        return 'Street';
      case MapType.satellite:
        return 'Satellite';
      case MapType.cycleMap:
        return 'Terrain';
    }
  }

  // 5. Update max zoom helper
  int _getMaxZoomForMapType(MapType type) {
    switch (type) {
      case MapType.defaultMap:
        return 19;
      case MapType.standard:
        return 19;
      case MapType.satellite:
        return 18;
      case MapType.cycleMap:
        return 19;
    }
  }

  // 6. Update icon helper with new icon for default
  IconData _getMapTypeIcon(MapType type) {
    switch (type) {
      case MapType.defaultMap:
        return Icons
            .layers_outlined; // or Icons.public_outlined, Icons.explore_outlined
      case MapType.standard:
        return Icons.map_outlined;
      case MapType.satellite:
        return Icons.satellite_alt_outlined;
      case MapType.cycleMap:
        return Icons.terrain_outlined;
    }
  }

  // NEW: Lightweight marker builder for distant zoom levels
  Widget _buildSimpleHotspotMarker({
    required Map<String, dynamic> hotspot,
    required Color markerColor,
    required IconData markerIcon,
    required double opacity,
  }) {
    return Transform.rotate(
      angle: -_currentMapRotation * pi / 180,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedHotspot = hotspot;
            _selectedSafeSpot = null;
          });
          _showHotspotDetails(hotspot);
        },
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: markerColor.withOpacity(opacity),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [],
          ),
          child: Icon(markerIcon, color: Colors.white, size: 10),
        ),
      ),
    );
  }

  // NEW: Simple dot marker for far zoom levels
  Widget _buildDotMarker(Color color, double opacity) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHistoricalModeIndicator() {
    final filterService = Provider.of<HotspotFilterService>(
      context,
      listen: true,
    );

    final hasCustomDateRange =
        filterService.crimeStartDate != null ||
        filterService.crimeEndDate != null;

    // ✅ Check screen width - only show on desktop/tablets (600px+)
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600; // Adjust breakpoint as needed

    // ✅ Only show if: desktop screen AND date filter is active AND heatmap is enabled AND there's at least 1 cluster
    if (!isDesktop ||
        !hasCustomDateRange ||
        !_showHeatmap ||
        _heatmapClusters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Historical Heatmap Mode',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_heatmapClusters.length} clusters',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MAP MAP MAP

  Widget _buildMap() {
    final currentConfig = mapConfigurations[_currentMapType]!;

    return Stack(
      children: [
        // Main Map with enhanced styling
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _currentPosition ?? const LatLng(6.9214, 122.0790),
                initialZoom: 15.5,
                maxZoom: _getMaxZoomForMapType(_currentMapType).toDouble(),
                minZoom: 3.0,

                //ONE TAP FOR DESKTOP
                onTap: (tapPosition, latLng) {
                  if (_currentTab == MainTab.notifications) {
                    setState(() {
                      _currentTab = MainTab.map;
                    });
                    return;
                  }

                  FocusScope.of(context).unfocus();

                  setState(() {
                    _selectedHotspot = null;
                    _selectedSafeSpot = null;
                    _selectedSavePoint = null;
                    _destinationFromSearch = false;
                    // Only set temp pin for desktop/web on tap
                    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
                      _tempPinnedLocation = latLng;
                      // Clear _destination unless there's an active route
                      if (!_hasActiveRoute) {
                        _destination = null;
                      }
                    }
                  });
                },

                //LONG PRESS FOR MOBILE
                onLongPress: (tapPosition, latLng) {
                  if (_currentTab == MainTab.notifications) {
                    setState(() {
                      _currentTab = MainTab.map;
                    });
                    return;
                  }

                  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                    HapticFeedback.mediumImpact();
                  }

                  setState(() {
                    _tempPinnedLocation =
                        latLng; // Set temp pin for all platforms on long press
                    _selectedHotspot = null;
                    _selectedSafeSpot = null;
                    _destinationFromSearch = false;
                    // Clear _destination unless there's an active route
                    if (!_hasActiveRoute) {
                      _destination = null;
                    }
                  });
                },

                onMapEvent: (MapEvent mapEvent) {
                  final maxZoom = _getMaxZoomForMapType(_currentMapType);
                  if (mapEvent is MapEventMove &&
                      mapEvent.camera.zoom > maxZoom) {
                    _mapController.move(
                      mapEvent.camera.center,
                      maxZoom.toDouble(),
                    );
                  }

                  // Track rotation immediately (no debounce needed for rotation)
                  if (mapEvent is MapEventRotate) {
                    setState(() {
                      _currentMapRotation = mapEvent.camera.rotation;
                    });
                  }

                  // Debounce zoom changes to reduce rebuilds
                  if (mapEvent is MapEventMove) {
                    final newZoom = mapEvent.camera.zoom;
                    // Update rotation immediately if changed
                    if (_currentMapRotation != mapEvent.camera.rotation) {
                      setState(() {
                        _currentMapRotation = mapEvent.camera.rotation;
                      });
                    }
                    // Debounce zoom updates
                    _onMapZoomChanged(newZoom);
                  }
                },
                interactionOptions: InteractionOptions(
                  // Conditionally enable/disable rotation based on lock state
                  flags: _isRotationLocked
                      ? InteractiveFlag.all &
                            ~InteractiveFlag
                                .rotate // All flags except rotate
                      : InteractiveFlag.all, // All flags including rotate
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: currentConfig['urlTemplate'],
                  userAgentPackageName: 'com.example.zecure',
                  maxZoom: _getMaxZoomForMapType(_currentMapType).toDouble(),
                  fallbackUrl: currentConfig['fallbackUrl'],
                  subdomains:
                      (_currentMapType == MapType.cycleMap ||
                          _currentMapType == MapType.defaultMap)
                      ? ['a', 'b', 'c']
                      : const [],
                  errorTileCallback: (tile, error, stackTrace) {
                    print('Tile loading error: $error');
                  },
                ),

                // UPDATED: Only show route polylines, not tracking polylines
                if (_routePoints.isNotEmpty && _hasActiveRoute) ...[
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.black.withOpacity(0.2),
                        strokeWidth: 6,
                      ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue.shade600,
                        strokeWidth: 4,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                ],

                // Enhanced Polyline layer with better styling (original)
                if (_polylinePoints.isNotEmpty) ...[
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        color: Colors.black.withOpacity(0.2),
                        strokeWidth: 6,
                      ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        color: Colors.blue.shade600,
                        strokeWidth: 4,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                ],
                _buildHeatmapLayer(),
                _buildHeatmapMarkers(),
                // Enhanced Main markers layer (current position and destination) - MINIMIZED
                MarkerLayer(
                  markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 50,
                        height: 50,
                        child: _buildEnhancedCurrentLocationMarker(),
                      ),

                    // Temporary pin marker with options button
                    if (_tempPinnedLocation != null &&
                        _tempPinnedLocation != _destination)
                      Marker(
                        point: _tempPinnedLocation!,
                        width:
                            120, // Same width as searched destination to accommodate button
                        height: 40,
                        child: _buildTempPinMarker(),
                      ),

                    if (_destination != null)
                      Marker(
                        point: _destination!,
                        width: _destinationFromSearch ? 120 : 40,
                        height: 40,
                        child: _destinationFromSearch
                            ? _buildSearchDestinationMarker()
                            : _buildEnhancedDestinationMarker(),
                      ),
                  ],
                ),

                // FIXED: Hotspots layer with stable markers and labels
                Consumer<HotspotFilterService>(
                  builder: (context, filterService, child) {
                    final thirtyDaysAgo = DateTime.now().subtract(
                      const Duration(days: 30),
                    );

                    final visibleHotspots = _visibleHotspots.where((hotspot) {
                      final currentUserId = _userProfile?['id'];
                      final hasAdminPermissions = _hasAdminPermissions;
                      final status = hotspot['status'] ?? 'approved';
                      final createdBy = hotspot['created_by'];
                      final reportedBy = hotspot['reported_by'];
                      final isOwnHotspot =
                          currentUserId != null &&
                          (currentUserId == createdBy ||
                              currentUserId == reportedBy);
                      final incidentTime = DateTime.tryParse(
                        hotspot['time'] ?? '',
                      );
                      final isRecent =
                          incidentTime != null &&
                          incidentTime.isAfter(thirtyDaysAgo);

                      // First check the filter service
                      if (!filterService.shouldShowHotspot(hotspot)) {
                        return false;
                      }

                      // Admin sees everything that passes filter service
                      if (hasAdminPermissions) return true;

                      // For pending: only show to owner
                      if (status == 'pending') {
                        return isOwnHotspot;
                      }

                      // For rejected: only show to owner
                      if (status == 'rejected') {
                        return isOwnHotspot;
                      }

                      // For approved hotspots (both active and inactive)
                      if (status == 'approved') {
                        // Check if custom date range is set
                        final hasCustomDateRange =
                            filterService.crimeStartDate != null ||
                            filterService.crimeEndDate != null;

                        // If custom date range, show all approved (handled by filter service)
                        if (hasCustomDateRange) {
                          return true;
                        }

                        // Otherwise, show if within 30 days (both active and inactive)
                        return isRecent;
                      }

                      return false;
                    }).toList();

                    return MarkerLayer(
                      key: ValueKey(
                        'hotspots_${_currentZoom.toInt()}_${visibleHotspots.length}',
                      ),
                      markers: visibleHotspots.map((hotspot) {
                        final coords = hotspot['location']['coordinates'];
                        final point = LatLng(coords[1], coords[0]);
                        final status = hotspot['status'] ?? 'approved';
                        final activeStatus =
                            hotspot['active_status'] ?? 'active';
                        final crimeLevel = hotspot['crime_type']['level'];
                        final crimeCategory = hotspot['crime_type']['category'];
                        final crimeTypeName =
                            hotspot['crime_type']['name'] ?? 'Unknown Crime';
                        final isActive = activeStatus == 'active';
                        final isOwnHotspot =
                            _userProfile?['id'] != null &&
                            (_userProfile?['id'] == hotspot['created_by'] ||
                                _userProfile?['id'] == hotspot['reported_by']);
                        final isSelected =
                            _selectedHotspot != null &&
                            _selectedHotspot!['id'] == hotspot['id'];
                        final hotspotId = hotspot['id'].toString();

                        // Determine marker complexity based on zoom
                        final useSimpleMarker = _currentZoom < 14.0;
                        final useDotMarker = _currentZoom < 12.0;

                        // Color and icon logic (cached)
                        Color markerColor;
                        IconData markerIcon;
                        double opacity = 1.0;

                        // Get verification status for pending reports
                        final verificationStatus =
                            hotspot['verification_status'] ?? 'unverified';

                        if (status == 'pending') {
                          markerColor = Colors.deepPurple;

                          // ✅ Dynamic icon based on verification status
                          if (verificationStatus == 'verified') {
                            markerIcon = Icons
                                .check_circle_outline; // ✅ Verified by officer, awaiting admin approval
                          } else if (verificationStatus ==
                              'rejected_verification') {
                            markerIcon = Icons
                                .cancel_outlined; // ❌ Rejected during verification
                            markerColor = Colors
                                .red
                                .shade700; // Change color to red for rejected verification
                          } else {
                            markerIcon = Icons
                                .hourglass_empty; // ⏰ Awaiting officer verification
                          }
                        } else if (status == 'rejected') {
                          markerColor = Colors.grey;
                          markerIcon = Icons.cancel_outlined;
                          opacity = isOwnHotspot ? 1.0 : 0.6;
                        } else {
                          // Approved status - crime level colors
                          switch (crimeLevel) {
                            case 'critical':
                              markerColor = const Color.fromARGB(
                                255,
                                219,
                                0,
                                0,
                              );
                              break;
                            case 'high':
                              markerColor = const Color.fromARGB(
                                255,
                                223,
                                106,
                                11,
                              );
                              break;
                            case 'medium':
                              markerColor = const Color.fromARGB(
                                167,
                                116,
                                66,
                                9,
                              );
                              break;
                            case 'low':
                              markerColor = const Color.fromARGB(
                                255,
                                216,
                                187,
                                23,
                              );
                              break;
                            default:
                              markerColor = Colors.blue;
                          }

                          // Crime category icons
                          switch (crimeCategory?.toLowerCase()) {
                            case 'property':
                              markerIcon = Icons.key;
                              break;
                            case 'violent':
                              markerIcon = Icons.warning;
                              break;
                            case 'drug':
                              markerIcon = FontAwesomeIcons.cannabis;
                              break;
                            case 'public order':
                              markerIcon = Icons.balance;
                              break;
                            case 'financial':
                              markerIcon = Icons.attach_money;
                              break;
                            case 'traffic':
                              markerIcon = Icons.traffic;
                              break;
                            case 'alert':
                              markerIcon = Icons.campaign;
                              break;
                            default:
                              markerIcon = Icons.location_pin;
                          }

                          if (!isActive) {
                            markerColor = markerColor.withOpacity(0.7);
                            opacity = 0.45;
                          }
                        }

                        return Marker(
                          key: ValueKey(
                            'h_${hotspotId}_${_currentZoom.toInt()}',
                          ),
                          point: point,
                          width: useDotMarker
                              ? 6
                              : (useSimpleMarker
                                    ? (isSelected ? 28 : 20)
                                    : (isSelected ? 100 : 80)),
                          height: useDotMarker
                              ? 6
                              : (useSimpleMarker
                                    ? (isSelected ? 28 : 20)
                                    : (isSelected ? 60 : 50)),
                          child: RepaintBoundary(
                            child: useDotMarker
                                ? _buildDotMarker(markerColor, opacity)
                                : useSimpleMarker
                                ? _buildSimpleHotspotMarker(
                                    hotspot: hotspot,
                                    markerColor: markerColor,
                                    markerIcon: markerIcon,
                                    opacity: opacity,
                                  )
                                : _buildStableHotspotMarker(
                                    hotspot: hotspot,
                                    markerColor: markerColor,
                                    markerIcon: markerIcon,
                                    opacity: opacity,
                                    isSelected: isSelected,
                                    isActive: isActive,
                                    isOwnHotspot: isOwnHotspot,
                                    status: status,
                                    crimeTypeName: crimeTypeName,
                                    showLabel: _currentZoom >= 15.5,
                                    crimeLevel: crimeLevel,
                                  ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                _buildHistoricalModeIndicator(),

                // Safe Spots Marker Layer
                if (_showSafeSpots)
                  Consumer<HotspotFilterService>(
                    builder: (context, filterService, child) {
                      // Filter safe spots based on filter service settings
                      final filteredSafeSpots = _visibleSafeSpots.where((
                        safeSpot,
                      ) {
                        return filterService.shouldShowSafeSpot(safeSpot);
                      }).toList();

                      return MarkerLayer(
                        key: ValueKey(
                          'safespots_${_currentZoom.toInt()}_${filteredSafeSpots.length}',
                        ),
                        markers: filteredSafeSpots.asMap().entries.map((entry) {
                          final safeSpot = entry.value;
                          final coords = safeSpot['location']['coordinates'];
                          final point = LatLng(coords[1], coords[0]);
                          final status = safeSpot['status'] ?? 'pending';
                          final verified = safeSpot['verified'] ?? false;
                          final verifiedByAdmin =
                              safeSpot['verified_by_admin'] ?? false;
                          final safeSpotType = safeSpot['safe_spot_types'];
                          final safeSpotName = safeSpot['name'] ?? 'Safe Spot';
                          final currentUserId = _userProfile?['id'];
                          final createdBy = safeSpot['created_by'];
                          final isOwnSpot =
                              currentUserId != null &&
                              currentUserId == createdBy;
                          final safeSpotId = safeSpot['id'].toString();
                          final isSelected =
                              _selectedSafeSpot != null &&
                              _selectedSafeSpot!['id'] == safeSpot['id'];

                          // Use simple markers when zoomed out
                          final useSimpleMarker = _currentZoom < 14.0;
                          final useDotMarker = _currentZoom < 12.0;

                          Color markerColor;
                          IconData markerIcon = _getIconFromString(
                            safeSpotType['icon'],
                          );
                          double opacity = 1.0;

                          switch (status) {
                            case 'pending':
                              markerColor = Colors.deepPurple;
                              opacity = 0.8;
                              break;
                            case 'approved':
                              markerColor = verified
                                  ? Colors.green.shade700
                                  : Colors.green.shade500;
                              break;
                            case 'rejected':
                              markerColor = Colors.grey;
                              opacity = isOwnSpot ? 0.7 : 0.4;
                              break;
                            default:
                              markerColor = Colors.blue;
                          }

                          return Marker(
                            key: ValueKey(
                              's_${safeSpotId}_${_currentZoom.toInt()}',
                            ),
                            point: point,
                            width: useDotMarker
                                ? 6
                                : (useSimpleMarker
                                      ? 24
                                      : (isSelected ? 120 : 100)),
                            height: useDotMarker
                                ? 6
                                : (useSimpleMarker
                                      ? 24
                                      : (isSelected ? 50 : 35)),
                            alignment: Alignment.center,
                            child: RepaintBoundary(
                              child: useDotMarker
                                  ? _buildDotMarker(Colors.green, opacity)
                                  : useSimpleMarker
                                  ? Transform.rotate(
                                      angle: -_currentMapRotation * pi / 180,
                                      alignment: Alignment.center,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSafeSpot = safeSpot;
                                            _selectedHotspot = null;
                                          });
                                          SafeSpotDetails.showSafeSpotDetails(
                                            context: context,
                                            safeSpot: safeSpot,
                                            userProfile: _userProfile,
                                            isAdmin: _hasAdminPermissions,
                                            onUpdate: () => _loadSafeSpots(),
                                            onGetSafeRoute: _getSafeRoute,
                                          );
                                        },
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: markerColor.withOpacity(
                                              opacity,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            markerIcon,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    )
                                  : _buildStableSafeSpotMarker(
                                      safeSpot: safeSpot,
                                      markerColor: markerColor,
                                      markerIcon: markerIcon,
                                      opacity: opacity,
                                      status: status,
                                      verified: verified,
                                      verifiedByAdmin: verifiedByAdmin,
                                      safeSpotName: safeSpotName,
                                      isOwnSpot: isOwnSpot,
                                      isSelected: isSelected,
                                      showLabel: _currentZoom >= 15.5,
                                    ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                // Save Points Marker Layer
                if (_userProfile != null)
                  MarkerLayer(
                    key: ValueKey(
                      'savepoints_${_currentZoom.toInt()}_${_savePoints.length}',
                    ),
                    markers: _savePoints
                        .map((savePoint) {
                          try {
                            // Defensive programming: Validate save point data before rendering
                            if (savePoint['location'] == null ||
                                savePoint['location']['coordinates'] == null) {
                              print(
                                '⚠️ Skipping save point with invalid location: ${savePoint['id']}',
                              );
                              return null;
                            }

                            final coords = savePoint['location']['coordinates'];
                            if (coords.length != 2) {
                              print(
                                '⚠️ Skipping save point with invalid coordinates length: ${savePoint['id']}',
                              );
                              return null;
                            }

                            final longitude = coords[0];
                            final latitude = coords[1];
                            if (longitude is! num || latitude is! num) {
                              print(
                                '⚠️ Skipping save point with non-numeric coordinates: ${savePoint['id']}',
                              );
                              return null;
                            }

                            final point = LatLng(
                              latitude.toDouble(),
                              longitude.toDouble(),
                            );
                            final name = savePoint['name'] ?? 'Save Point';
                            final isSelected =
                                _selectedSavePoint != null &&
                                _selectedSavePoint!['id'] == savePoint['id'];

                            // Use simple markers when zoomed out, dots when very far
                            final useSimpleMarker = _currentZoom < 14.0;
                            final useDotMarker = _currentZoom < 12.0;

                            // Build marker styling
                            return Marker(
                              key: ValueKey(
                                'sp_${savePoint['id']}_${_currentZoom.toInt()}',
                              ),
                              point: point,
                              width: useDotMarker
                                  ? 6
                                  : (useSimpleMarker
                                        ? 24
                                        : (isSelected ? 120 : 100)),
                              height: useDotMarker
                                  ? 6
                                  : (useSimpleMarker ? 24 : 35),
                              alignment: Alignment.center,
                              child: useDotMarker
                                  ? _buildDotMarker(
                                      Colors.blue.shade600,
                                      0.9,
                                    ) // Just a blue dot when zoomed out
                                  : Transform.rotate(
                                      angle:
                                          -_currentMapRotation *
                                          pi /
                                          180, // Counteract map rotation
                                      alignment: Alignment.center,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              // Update selection state
                                              setState(() {
                                                _destination = point;
                                                _selectedSavePoint = savePoint;
                                                _selectedSafeSpot = null;
                                                _selectedHotspot = null;
                                              });

                                              // Show save point details
                                              SavePointDetails.showSavePointDetails(
                                                context: context,
                                                savePoint: savePoint,
                                                userProfile: _userProfile,
                                                onUpdate: _loadSavePoints,
                                                onGetSafeRoute: _getSafeRoute,
                                              );
                                            },
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Selection indicator
                                                if (isSelected)
                                                  Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.blue
                                                            .withOpacity(0.6),
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                // Main marker
                                                Container(
                                                  width: useSimpleMarker
                                                      ? 20
                                                      : 32,
                                                  height: useSimpleMarker
                                                      ? 20
                                                      : 32,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade600
                                                        .withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius:
                                                            useSimpleMarker
                                                            ? 4
                                                            : 6,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    Icons.bookmark,
                                                    color: Colors.white,
                                                    size: useSimpleMarker
                                                        ? 12
                                                        : 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Label aligned like hotspots and safe spots
                                          if (!useSimpleMarker &&
                                              _currentZoom >= 15.5)
                                            Positioned(
                                              left: isSelected ? 93 : 78,
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                opacity: 1.0,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade600
                                                        .withOpacity(0.9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.15),
                                                        blurRadius: 3,
                                                        offset: const Offset(
                                                          1,
                                                          1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    name.length > 15
                                                        ? '${name.substring(0, 15)}...'
                                                        : name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                            );
                          } catch (e) {
                            print(
                              '❌ Error creating marker for save point ${savePoint['id']}: $e',
                            );
                            return null;
                          }
                        })
                        .where((marker) => marker != null)
                        .cast<Marker>()
                        .toList(),
                  ),
              ],
            ),
          ),
        ),

        // Cool overlay effects for map corners
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.transparent,
                  Colors.blue.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  get isSelected_ => null;

  bool get isLargeScreen {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width > 600;
  }

  // HOTSPOT MARKER - Fixed to keep marker stable like safe spots

  Widget _buildStableHotspotMarker({
    required Map<String, dynamic> hotspot,
    required Color markerColor,
    required IconData markerIcon,
    required double opacity,
    required bool isSelected,
    required bool isActive,
    required bool isOwnHotspot,
    required String status,
    required String crimeTypeName,
    required bool showLabel,
    required String crimeLevel, // ADD THIS
  }) {
    return Transform.rotate(
      angle: -_currentMapRotation * pi / 180,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.6),
                      width: 3,
                    ),
                  ),
                ),
              Opacity(
                opacity: opacity,
                child: PulsingHotspotMarker(
                  markerColor: markerColor,
                  markerIcon: markerIcon,
                  isActive: isActive && status != 'rejected',
                  pulseScale: isSelected ? 1.1 : 0.9,
                  crimeLevel: crimeLevel, // ADD THIS LINE
                  onTap: () {
                    setState(() {
                      _selectedHotspot = hotspot;
                      _selectedSafeSpot = null;
                    });
                    _showHotspotDetails(hotspot);
                  },
                ),
              ),
              if (status == 'pending' || status == 'rejected')
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status == 'pending' ? Colors.orange : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Crime type label (rest remains the same)
          if (showLabel)
            Positioned(
              left: isSelected ? 93 : 73,
              top: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: showLabel ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (status == 'rejected' ||
                                status == 'pending' ||
                                !isActive ||
                                opacity < 1.0)
                            ? markerColor.withOpacity(0.9 * opacity)
                            : markerColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (status == 'rejected' ||
                                    status == 'pending' ||
                                    !isActive ||
                                    opacity < 1.0)
                                ? Colors.black.withOpacity(0.15 * opacity)
                                : Colors.black.withOpacity(0.15),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        crimeTypeName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (hotspot['time'] != null &&
                        (status == 'approved' || status == 'pending')) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(0.5, 0.5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(1.5),
                            child: Icon(
                              Icons.access_time,
                              size: 8,
                              color: markerColor.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 3),
                          _buildTimeText(hotspot, markerColor),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // FIXED: Helper widget to build time text with special "NEW" styling
  Widget _buildTimeText(Map<String, dynamic> hotspot, Color markerColor) {
    DateTime hotspotTime;
    DateTime creationTime;

    try {
      // Parse times - they're already converted to local by parseStoredDateTime
      hotspotTime = parseStoredDateTime(hotspot['time']);
      creationTime = parseStoredDateTime(
        hotspot['created_at'] ?? hotspot['time'],
      );
    } catch (e) {
      print('Error parsing hotspot time for marker: $e');
      hotspotTime = DateTime.now();
      creationTime = DateTime.now();
    }

    // Use local time for all comparisons
    final now = DateTime.now(); // Device's local time (Philippine time)
    final creationDifference = now.difference(creationTime.toLocal());
    final incidentDifference = now.difference(hotspotTime.toLocal());

    // Show "NEW" only if both the report was created recently AND the incident time is recent
    final isNew =
        creationDifference.inHours < 1 && incidentDifference.inHours < 1;

    // Get display text based on incident time
    final timeText = isNew ? 'NEW' : _getTimeAgo(hotspotTime, compact: true);

    if (isNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.blue, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(0.5, 0.5),
            ),
          ],
        ),
        child: Text(
          timeText,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      return Text(
        timeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(1, -1),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(-1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      );
    }
  }

  // UPDATED: Safe spot marker with selection indicator and proper rotation
  Widget _buildStableSafeSpotMarker({
    required Map<String, dynamic> safeSpot,
    required Color markerColor,
    required IconData markerIcon,
    required double opacity,
    required String status,
    required bool verified,
    required bool verifiedByAdmin,
    required String safeSpotName,
    required bool isOwnSpot,
    required bool isSelected,
    required bool showLabel,
  }) {
    return Transform.rotate(
      angle:
          -_currentMapRotation *
          pi /
          180, // Counteract map rotation (degrees to radians)
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedSafeSpot = safeSpot;
                _selectedHotspot = null;
              });

              SafeSpotDetails.showSafeSpotDetails(
                context: context,
                safeSpot: safeSpot,
                userProfile: _userProfile,
                isAdmin: _hasAdminPermissions,
                onUpdate: () {
                  print('Manual refresh triggered from details');
                  _loadSafeSpots();
                },
                onGetSafeRoute: _getSafeRoute,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.6),
                        width: 3,
                      ),
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: markerColor.withOpacity(opacity),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(markerIcon, color: Colors.white, size: 16),
                ),
                if (status != 'approved')
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: status == 'pending' ? Colors.orange : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                if (status == 'approved' && verified)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: verifiedByAdmin ? Colors.purple : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (showLabel)
            Positioned(
              left: isSelected ? 97 : 80,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: showLabel ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: markerColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    safeSpotName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to convert string to IconData
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'local_police':
        return Icons.local_police;
      case 'account_balance':
        return Icons.account_balance;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'shopping_mall':
        return Icons.store;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'security':
        return Icons.security;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'church':
        return Icons.church;
      case 'community':
        return Icons.group;
      default:
        return Icons.place;
    }
  }

  // NEW: Current location marker with profile photo
  Widget _buildEnhancedCurrentLocationMarker() {
    final profilePictureUrl = _userProfile?['profile_picture_url'];
    final hasProfilePhoto =
        profilePictureUrl != null && profilePictureUrl.isNotEmpty;

    return Transform.rotate(
      angle: -_currentMapRotation * pi / 180,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.15),
            ),
          ),

          // Second ring for depth
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.25),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),

          // Main circle - Profile photo (larger with white border) or default icon (with border)
          if (hasProfilePhoto)
            // Profile photo - with white border
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: _locationButtonPressed
                      ? Colors.blue.shade600
                      : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  profilePictureUrl,
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to default icon if image fails to load
                    return _buildDefaultMarker();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    // Show default icon while loading
                    return _buildDefaultMarker();
                  },
                ),
              ),
            )
          else
            // Default icon - smaller with white border (original size)
            _buildDefaultMarker(),
        ],
      ),
    );
  }

  // Helper method for default marker (no profile photo)
  Widget _buildDefaultMarker() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _locationButtonPressed ? Colors.blue.shade600 : Colors.white,
        border: Border.all(
          color: _locationButtonPressed ? Colors.white : Colors.blue.shade600,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.person,
        size: 14,
        color: _locationButtonPressed ? Colors.white : Colors.blue.shade600,
      ),
    );
  }

  // UPDATED: Destination marker that also rotates with map (optional)
  Widget _buildEnhancedDestinationMarker() {
    return Transform.rotate(
      angle:
          -_currentMapRotation *
          pi /
          180, // Counteract map rotation (degrees to radians)
      alignment: Alignment.center,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_pin,
            color: Colors.white, // Outline
            size: 32, // Reduced from 40
          ),
          Icon(
            Icons.location_pin,
            color: Colors.red, // Bright red for visibility
            size: 28, // Reduced from 35
          ),
        ],
      ),
    );
  }

  // New method to build temporary pin marker with options button
  Widget _buildTempPinMarker() {
    return Transform.rotate(
      angle: -_currentMapRotation * pi / 180,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main temporary pin (grey version)
          const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.location_pin, color: Colors.white, size: 32),
              Icon(Icons.location_pin, color: Colors.blue, size: 28),
            ],
          ),

          // "Options" button (same style as searched destination)
          Positioned(
            left: 70,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (_tempPinnedLocation != null) {
                    _showLocationOptions(_tempPinnedLocation!);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.grey.shade200,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.black87,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Options',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method to build destination marker with button for search selections
  Widget _buildSearchDestinationMarker() {
    return Transform.rotate(
      angle: -_currentMapRotation * pi / 180,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main destination pin
          const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.location_pin, color: Colors.white, size: 32),
              Icon(Icons.location_pin, color: Colors.blue, size: 28),
            ],
          ),

          // Lighter "Options" button
          Positioned(
            left: 70, // slightly closer
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (_destination != null) {
                    _showLocationOptions(_destination!);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.grey.shade200,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.black87,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Options',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HOTSPOT DETAILS
  void _showHotspotDetails(Map<String, dynamic> hotspot) async {
    final verificationStatus = hotspot['verification_status'] ?? 'unverified';
    final verifiedAt = hotspot['verified_at'];
    // Add null safety at the beginning
    if (hotspot['location'] == null) {
      _showSnackBar('Unable to load hotspot details');
      return;
    }

    final coordinatesArray =
        hotspot['location']['coordinates']; // This is a List
    if (coordinatesArray == null || coordinatesArray.length < 2) {
      _showSnackBar('Invalid hotspot location data');
      return;
    }

    // Extract lat/lng from the array
    final lng = coordinatesArray[0]; // longitude is at index 0
    final lat = coordinatesArray[1]; // latitude is at index 1

    // Create the coordinates string for display
    final coordinatesString =
        "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

    String address = "Loading address...";
    String fullLocation = coordinatesString;

    // Fetch hotspot photo
    Map<String, dynamic>? hotspotPhoto;
    try {
      hotspotPhoto = await PhotoService.getHotspotPhoto(hotspot['id']);
    } catch (e) {
      print('Error fetching hotspot photo: $e');
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        address = data['display_name'] ?? "Unknown location";
        fullLocation = "$address\n$coordinatesString";
      }
    } catch (e) {
      address = "Could not load address";
      fullLocation = "$address\n$coordinatesString";
    }

    // Use the same parseStoredDateTime helper for consistency
    DateTime time;
    try {
      final timeString = hotspot['time'] ?? DateTime.now().toIso8601String();
      time = parseStoredDateTime(timeString);
    } catch (e) {
      print('Error parsing time: $e');
      time = DateTime.now();
    }

    final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(time);
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    bool isActiveStatus = activeStatus == 'active';
    ValueNotifier<bool> statusNotifier = ValueNotifier<bool>(isActiveStatus);
    final isOwner =
        (_userProfile?['id'] != null) &&
        (hotspot['created_by'] == _userProfile!['id'] ||
            hotspot['reported_by'] == _userProfile!['id']);

    // Add null checks for crimeType
    final crimeType = hotspot['crime_type'] ?? {};
    final category = crimeType['category'] ?? 'Unknown Category';
    final expiresAt = hotspot['expires_at'] != null
        ? DateTime.parse(hotspot['expires_at'])
        : null;

    // Fetch officer details
    Map<String, String> officerDetails = {};
    Map<String, String?> contactNumbers = {}; // NEW: Store contact numbers
    try {
      final response = await Supabase.instance.client
          .from('hotspot')
          .select('''
        approved_by,
        rejected_by,
        last_updated_by,
        created_by,
        reported_by,
        approved_profile:approved_by (first_name, last_name),
        rejected_profile:rejected_by (first_name, last_name),
        updated_profile:last_updated_by (first_name, last_name),
        creator_profile:created_by (first_name, last_name, contact_number),
        reporter_profile:reported_by (first_name, last_name, contact_number)
      ''')
          .eq('id', hotspot['id'])
          .single();

      // Process approved_by
      if (response['approved_by'] != null &&
          response['approved_profile'] != null) {
        officerDetails['approved_by'] =
            '${response['approved_profile']['first_name'] ?? ''} ${response['approved_profile']['last_name'] ?? ''}'
                .trim();
      }

      // Process rejected_by
      if (response['rejected_by'] != null &&
          response['rejected_profile'] != null) {
        officerDetails['rejected_by'] =
            '${response['rejected_profile']['first_name'] ?? ''} ${response['rejected_profile']['last_name'] ?? ''}'
                .trim();
      }

      // Process last_updated_by
      if (response['last_updated_by'] != null &&
          response['updated_profile'] != null) {
        officerDetails['last_updated_by'] =
            '${response['updated_profile']['first_name'] ?? ''} ${response['updated_profile']['last_name'] ?? ''}'
                .trim();
      }

      // Process created_by - NEW: Include contact
      if (response['created_by'] != null &&
          response['creator_profile'] != null) {
        officerDetails['created_by'] =
            '${response['creator_profile']['first_name'] ?? ''} ${response['creator_profile']['last_name'] ?? ''}'
                .trim();
        contactNumbers['creator'] =
            response['creator_profile']['contact_number']; // NEW
      }

      // Process reported_by - NEW: Include contact
      if (response['reported_by'] != null &&
          response['reporter_profile'] != null) {
        officerDetails['reported_by'] =
            '${response['reporter_profile']['first_name'] ?? ''} ${response['reporter_profile']['last_name'] ?? ''}'
                .trim();
        contactNumbers['reporter'] =
            response['reporter_profile']['contact_number']; // NEW
      }

      if (response['verified_by'] != null &&
          response['verifier_profile'] != null) {
        officerDetails['verified_by'] =
            '${response['verifier_profile']['first_name'] ?? ''} ${response['verifier_profile']['last_name'] ?? ''}'
                .trim();
      }
    } catch (e) {
      print('Error fetching officer details: $e');
    }

    // DESKTOP VIEW FOR HOTSPOT DETAILS
    if (_isDesktopScreen()) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.3),
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                child: IntrinsicHeight(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    constraints: BoxConstraints(
                      maxWidth: 600,
                      maxHeight: MediaQuery.of(context).size.height * 0.9,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Crime Report Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        // Content - Flexible to fit content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Photo section - Unchanged
                                if (hotspotPhoto != null) ...[
                                  GestureDetector(
                                    onTap: () => _showFullScreenImage(
                                      hotspotPhoto?['photo_url'],
                                    ),
                                    child: Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              hotspotPhoto['photo_url'],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress ==
                                                        null) {
                                                      return child;
                                                    }
                                                    return const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    );
                                                  },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons.error,
                                                            color: Colors.red,
                                                          ),
                                                          Text(
                                                            'Failed to load image',
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                Icons.zoom_in,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Crime details with icons
                                SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Type with icon
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.category,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Text(
                                                    'Type:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('${crimeType['name']}'),
                                                  const SizedBox(width: 12),
                                                  _buildStatusWidget(
                                                    activeStatus,
                                                    status,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Category with icon
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.category,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Text(
                                                    'Category:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(category),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Level with icon
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Text(
                                                    'Level:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('${crimeType['level']}'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Description with icon
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.description,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Description:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    (hotspot['description'] ==
                                                                null ||
                                                            hotspot['description']
                                                                .toString()
                                                                .trim()
                                                                .isEmpty)
                                                        ? 'No description'
                                                        : hotspot['description'],
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Location with icon, copy button, and get directions
                                      // Location with icon, copy button on right, and get directions below coordinates
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_pin,
                                              size: 18,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Location:',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    address,
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    coordinatesString,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),

                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: TextButton.icon(
                                                      onPressed: () {
                                                        final lat =
                                                            hotspot['location']['coordinates'][1];
                                                        final lng =
                                                            hotspot['location']['coordinates'][0];
                                                        _showDirectionsConfirmation(
                                                          LatLng(lat, lng),
                                                          context,
                                                          () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            _getDirections(
                                                              LatLng(lat, lng),
                                                            );
                                                          },
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.directions,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Get Directions',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors
                                                            .blue
                                                            .shade600,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        minimumSize: const Size(
                                                          0,
                                                          0,
                                                        ),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.copy,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                Clipboard.setData(
                                                  ClipboardData(
                                                    text: fullLocation,
                                                  ),
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Location copied to clipboard',
                                                    ),
                                                  ),
                                                );
                                              },
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Time with icon
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 18,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      const Text(
                                                        'Date and Time:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        formattedTime,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Add expiration indicator if exists
                                            if (expiresAt != null &&
                                                activeStatus == 'active') ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color:
                                                        Colors.orange.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.timer,
                                                      size: 16,
                                                      color: Colors
                                                          .orange
                                                          .shade700,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Investigation expires: ${DateFormat('MMM dd, yyyy - hh:mm a').format(expiresAt.toLocal())}',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .orange
                                                                  .shade700,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            formatTimeRemaining(
                                                              expiresAt,
                                                            ),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .orange
                                                                  .shade800,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Show rejection reason for rejected reports
                                if (status == 'rejected' &&
                                    hotspot['rejection_reason'] != null)
                                  Container(
                                    margin: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 16,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cancel,
                                              color: Colors.red.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Rejection Reason:',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          hotspot['rejection_reason']
                                                  .toString()
                                                  .trim()
                                                  .isEmpty
                                              ? 'No reason provided'
                                              : hotspot['rejection_reason'],
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Show approval note for approved reports by users
                                if (status == 'approved' &&
                                    !_hasAdminPermissions &&
                                    isOwner)
                                  Container(
                                    margin: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 16,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Your post has been approved and is being managed by the admin.',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Action buttons
                                // Officer details section - CLEANED
                                if (_hasAdminPermissions || _isOfficer) ...[
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          (officerDetails['approved_by']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? Colors.green.shade50
                                          : (officerDetails['rejected_by']
                                                    ?.isNotEmpty ??
                                                false)
                                          ? Colors.red.shade50
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            (officerDetails['approved_by']
                                                    ?.isNotEmpty ??
                                                false)
                                            ? Colors.green.shade200
                                            : (officerDetails['rejected_by']
                                                      ?.isNotEmpty ??
                                                  false)
                                            ? Colors.red.shade200
                                            : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Review Status Header
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              color:
                                                  (officerDetails['approved_by']
                                                          ?.isNotEmpty ??
                                                      false)
                                                  ? Colors.green.shade600
                                                  : (officerDetails['rejected_by']
                                                            ?.isNotEmpty ??
                                                        false)
                                                  ? Colors.red.shade600
                                                  : Colors.blue.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Review Status',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // For pending status - show reporter first
                                        if (status == 'pending') ...[
                                          if (officerDetails['reported_by']
                                                  ?.isNotEmpty ??
                                              false)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '📝 Reported by: ${officerDetails['reported_by']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (contactNumbers['reporter'] !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '📞 ${contactNumbers['reporter']}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          else if (officerDetails['created_by']
                                                  ?.isNotEmpty ??
                                              false)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '📝 Created by: ${officerDetails['created_by']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (contactNumbers['creator'] !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '📞 ${contactNumbers['creator']}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          else
                                            Text(
                                              'Reporter information not available',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ] else ...[
                                          // For approved/rejected - show creator first
                                          if (officerDetails['created_by']
                                                  ?.isNotEmpty ??
                                              false)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '📝 Created by: ${officerDetails['created_by']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (contactNumbers['creator'] !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '📞 ${contactNumbers['creator']}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          else if (officerDetails['reported_by']
                                                  ?.isNotEmpty ??
                                              false)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '📝 Reported by: ${officerDetails['reported_by']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (contactNumbers['reporter'] !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '📞 ${contactNumbers['reporter']}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          else
                                            Text(
                                              'Creator information not available',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],

                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 8),

                                        // Verification Status Badge
                                        if (verificationStatus == 'verified')
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.verified,
                                                      color:
                                                          Colors.green.shade600,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '✅ Verified',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (officerDetails['verified_by']
                                                        ?.isNotEmpty ??
                                                    false) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'By: ${officerDetails['verified_by']}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                                if (verifiedAt != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'On: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(verifiedAt).toLocal())}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          )
                                        else if (verificationStatus ==
                                            'rejected_verification')
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.red.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.cancel,
                                                  color: Colors.red.shade600,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '❌ Verification Rejected',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else if (verificationStatus ==
                                                'unverified' &&
                                            status == 'pending')
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.orange.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.pending,
                                                  color: Colors.orange.shade700,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '⚠️ Pending Verification',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors
                                                          .orange
                                                          .shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        const SizedBox(height: 8),

                                        // Show approval / rejection
                                        if (officerDetails['approved_by']
                                                ?.isNotEmpty ??
                                            false) ...[
                                          Text(
                                            '✅ Approved by: ${officerDetails['approved_by']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (officerDetails['rejected_by']
                                                ?.isNotEmpty ??
                                            false) ...[
                                          Text(
                                            '❌ Rejected by: ${officerDetails['rejected_by']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],

                                        // Always at the bottom: Last updated by
                                        if (officerDetails['last_updated_by']
                                                ?.isNotEmpty ??
                                            false) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '🔄 Last updated by: ${officerDetails['last_updated_by']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                // Add this AFTER the officer details section and BEFORE action buttons
                                if (_hasAdminPermissions &&
                                    status == 'approved') ...[
                                  StatefulBuilder(
                                    builder: (context, setStateDialog) {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal:
                                              8, // Add horizontal for mobile
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: statusNotifier.value
                                              ? Colors.green.shade50
                                              : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: statusNotifier.value
                                                ? Colors.green.shade200
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  statusNotifier.value
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  color: statusNotifier.value
                                                      ? Colors.green
                                                      : Colors.grey,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Status: ${statusNotifier.value ? 'Active' : 'Inactive'}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Switch(
                                              value: statusNotifier.value,
                                              onChanged: (value) async {
                                                // Update UI immediately
                                                setStateDialog(() {
                                                  statusNotifier.value = value;
                                                });

                                                // Update database
                                                await _updateHotspotStatus(
                                                  hotspot['id'],
                                                  value ? 'active' : 'inactive',
                                                );
                                              },
                                              activeColor: Colors.green,
                                              inactiveThumbColor: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 20),
                                _buildDesktopActionButtons(
                                  hotspot,
                                  status,
                                  isOwner,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // MOBILE VIEW FOR HOTSPOT DETAILS
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
        // ⭐ Variables for mobile view
        final activeStatusMobile = hotspot['active_status'] ?? 'active';
        final isActiveStatusMobile = activeStatusMobile == 'active';
        final statusNotifierMobile = ValueNotifier<bool>(isActiveStatusMobile);

        return GestureDetector(
          onTap: () {}, // Prevents dismissal when tapping content
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.95,
              minHeight: MediaQuery.of(context).size.height * 0.2,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle at the top
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Content wrapper that auto-expands or scrolls
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Photo section for mobile
                        if (hotspotPhoto != null) ...[
                          GestureDetector(
                            onTap: () => _showFullScreenImage(
                              hotspotPhoto?['photo_url'],
                            ),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      hotspotPhoto['photo_url'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.error,
                                                    color: Colors.red,
                                                  ),
                                                  Text('Failed to load image'),
                                                ],
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Crime Type with mini icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.category,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('Type: ${crimeType['name']}'),
                                        const SizedBox(width: 6),
                                        _buildStatusWidget(
                                          activeStatus,
                                          status,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Category: $category',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Level: ${crimeType['level']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Description with mini icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.description,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Description:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (hotspot['description'] == null ||
                                              hotspot['description']
                                                  .toString()
                                                  .trim()
                                                  .isEmpty)
                                          ? 'No description'
                                          : hotspot['description'],
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Location with mini icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_pin,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Location:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      address,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      coordinatesString,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: TextButton.icon(
                                        onPressed: () {
                                          final lat =
                                              hotspot['location']['coordinates'][1];
                                          final lng =
                                              hotspot['location']['coordinates'][0];
                                          _showDirectionsConfirmation(
                                            LatLng(lat, lng),
                                            context,
                                            () {
                                              Navigator.pop(context);
                                              _getDirections(LatLng(lat, lng));
                                            },
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.directions,
                                          size: 16,
                                        ),
                                        label: const Text('Get Directions'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue.shade600,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: fullLocation),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Location copied to clipboard',
                                      ),
                                    ),
                                  );
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),

                        // Time with mini icon
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Date and Time:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedTime,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (expiresAt != null &&
                                  activeStatus == 'active') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Investigation expires: ${DateFormat('MMM dd, yyyy - hh:mm a').format(expiresAt.toLocal())}',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatTimeRemaining(expiresAt),
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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
                          ),
                        ),

                        // Show rejection reason for rejected reports
                        if (status == 'rejected' &&
                            hotspot['rejection_reason'] != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.red.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rejection Reason:',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  hotspot['rejection_reason']
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? 'No reason provided'
                                      : hotspot['rejection_reason'],
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Show approval note for approved reports by users
                        if (status == 'approved' &&
                            !_hasAdminPermissions &&
                            isOwner)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your post has been approved and is being managed by the admin.',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Officer details section with contact numbers
                        if (_hasAdminPermissions || _isOfficer) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (officerDetails['approved_by']?.isNotEmpty ??
                                      false)
                                  ? Colors.green.shade50
                                  : (officerDetails['rejected_by']
                                            ?.isNotEmpty ??
                                        false)
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (officerDetails['approved_by']
                                            ?.isNotEmpty ??
                                        false)
                                    ? Colors.green.shade200
                                    : (officerDetails['rejected_by']
                                              ?.isNotEmpty ??
                                          false)
                                    ? Colors.red.shade200
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Review Status Header
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color:
                                          (officerDetails['approved_by']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? Colors.green.shade600
                                          : (officerDetails['rejected_by']
                                                    ?.isNotEmpty ??
                                                false)
                                          ? Colors.red.shade600
                                          : Colors.blue.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Review Status',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Creator / Reporter with contact number
                                if (status == 'pending') ...[
                                  if (officerDetails['reported_by']
                                          ?.isNotEmpty ??
                                      false)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📝 Reported by: ${officerDetails['reported_by']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (contactNumbers['reporter'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '📞 ${contactNumbers['reporter']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  else if (officerDetails['created_by']
                                          ?.isNotEmpty ??
                                      false)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📝 Created by: ${officerDetails['created_by']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (contactNumbers['creator'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '📞 ${contactNumbers['creator']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    Text(
                                      'Reporter information not available',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ] else ...[
                                  if (officerDetails['created_by']
                                          ?.isNotEmpty ??
                                      false)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📝 Created by: ${officerDetails['created_by']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (contactNumbers['creator'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '📞 ${contactNumbers['creator']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  else if (officerDetails['reported_by']
                                          ?.isNotEmpty ??
                                      false)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📝 Reported by: ${officerDetails['reported_by']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        if (contactNumbers['reporter'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '📞 ${contactNumbers['reporter']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    Text(
                                      'Creator information not available',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),

                                // Verification Status Badge
                                if (verificationStatus == 'verified')
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              color: Colors.green.shade600,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '✅ Verified',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (officerDetails['verified_by']
                                                ?.isNotEmpty ??
                                            false) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'By: ${officerDetails['verified_by']}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                        if (verifiedAt != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'On: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(verifiedAt).toLocal())}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                else if (verificationStatus ==
                                    'rejected_verification')
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cancel,
                                          color: Colors.red.shade600,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '❌ Verification Rejected',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (verificationStatus == 'unverified' &&
                                    status == 'pending')
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.pending,
                                          color: Colors.orange.shade700,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '⚠️ Pending Verification',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 8),

                                // Show approval / rejection
                                if (officerDetails['approved_by']?.isNotEmpty ??
                                    false) ...[
                                  Text(
                                    '✅ Approved by: ${officerDetails['approved_by']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (officerDetails['rejected_by']?.isNotEmpty ??
                                    false) ...[
                                  Text(
                                    '❌ Rejected by: ${officerDetails['rejected_by']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                // Last updated by
                                if (officerDetails['last_updated_by']
                                        ?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '🔄 Last updated by: ${officerDetails['last_updated_by']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Active Status Section - Only for approved posts
                        if (_hasAdminPermissions && status == 'approved') ...[
                          StatefulBuilder(
                            builder: (context, setStateDialog) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: statusNotifierMobile.value
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusNotifierMobile.value
                                        ? Colors.green.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          statusNotifierMobile.value
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: statusNotifierMobile.value
                                              ? Colors.green
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Status: ${statusNotifierMobile.value ? 'Active' : 'Inactive'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: statusNotifierMobile.value,
                                      onChanged: (value) async {
                                        setStateDialog(() {
                                          statusNotifierMobile.value = value;
                                        });
                                        await _updateHotspotStatus(
                                          hotspot['id'],
                                          value ? 'active' : 'inactive',
                                        );
                                      },
                                      activeColor: Colors.green,
                                      inactiveThumbColor: Colors.grey,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // Mobile action buttons

                        // OFFICER BUTTONS - Verify/Reject Verification
                        if (_isOfficer && !_isAdmin && status == 'pending') ...[
                          if (verificationStatus == 'unverified')
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16.0,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _verifyHotspot(hotspot['id']),
                                          icon: const Icon(
                                            Icons.verified,
                                            size: 16,
                                          ),
                                          label: const Text('Verify'),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _showRejectVerificationDialog(
                                                hotspot['id'],
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.orange,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _deleteHotspot(hotspot['id']),
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Delete'),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        verificationStatus == 'verified'
                                            ? 'This report has been verified. Waiting for admin approval.'
                                            : 'This report has been rejected.',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],

                        // ADMIN BUTTONS
                        if (_isAdmin && status == 'pending')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showApprovalWithDurationDialog(
                                          hotspot['id'],
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      verificationStatus == 'unverified'
                                          ? 'Approve*'
                                          : 'Approve',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showRejectDialog(hotspot['id']),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.blueGrey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _deleteHotspot(hotspot['id']),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // USER OWNER BUTTONS
                        if (!_hasAdminPermissions &&
                            !_isOfficer &&
                            status == 'pending' &&
                            isOwner)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showEditHotspotForm(hotspot);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: const Color.fromARGB(
                                        255,
                                        19,
                                        111,
                                        187,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Edit'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _deleteHotspot(hotspot['id']),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // REJECTED STATUS
                        if (status == 'rejected')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (isOwner || _hasAdminPermissions)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _deleteHotspot(hotspot['id']),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // APPROVED STATUS
                        if (_hasAdminPermissions && status == 'approved')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showEditHotspotForm(hotspot);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: const Color.fromARGB(
                                        255,
                                        19,
                                        111,
                                        187,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Edit'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _deleteHotspot(hotspot['id']),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

  // FULL SCREEN PHOTO VIEWER FOR HOTSPOT DETAILS
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.white, size: 50),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
              // Instructions for zoom
              Positioned(
                bottom: 30,
                left: 25,
                right: 25,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pinch with two fingers to zoom\nDrag to move around',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New helper widget to build status with effects (smaller version)
  Widget _buildStatusWidget(String activeStatus, String status) {
    Color statusColor;
    String statusText;
    bool shouldAnimate = false;

    if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'REJECTED';
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'PENDING';
      shouldAnimate = true;
    } else if (activeStatus == 'active') {
      statusColor = Colors.green;
      statusText = 'ACTIVE';
      shouldAnimate = true;
    } else if (activeStatus == 'inactive') {
      statusColor = Colors.grey;
      statusText = 'INACTIVE';
    } else {
      statusColor = Colors.grey;
      statusText = activeStatus.toUpperCase();
    }

    Widget statusWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shouldAnimate)
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.3, end: 1.0),
            builder: (context, value, child) {
              return AnimatedOpacity(
                opacity: value,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
            onEnd: () {
              // Animation repeats automatically
            },
          ),
        if (shouldAnimate) const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor, width: 1),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    return statusWidget;
  }

  //DESKTOP ACTION BUTTONS FOR HOTSPOT DETAILS - MODERN DESIGN WITH VERIFICATION
  Widget _buildDesktopActionButtons(
    Map<String, dynamic> hotspot,
    String status,
    bool isOwner,
  ) {
    final verificationStatus = hotspot['verification_status'] ?? 'unverified';
    final buttons = <Widget>[];

    // OFFICER BUTTONS - Verify/Reject Verification (Officers only, not admins)
    if (_isOfficer && !_isAdmin && status == 'pending') {
      if (verificationStatus == 'unverified') {
        buttons.addAll([
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _verifyHotspot(hotspot['id']),
              icon: const Icon(Icons.verified, size: 18),
              label: const Text(
                'Verify',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.green.shade700,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showRejectVerificationDialog(hotspot['id']),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text(
                'Reject Verification',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.orange.shade700,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _deleteHotspot(hotspot['id']),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
              ),
            ),
          ),
        ]);
      } else {
        // Officer has already verified or rejected - show info message
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  verificationStatus == 'verified'
                      ? 'This report has been verified. Waiting for admin approval.'
                      : 'This report has been rejected.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    // ADMIN BUTTONS - Approve/Reject/Delete
    else if (_isAdmin && status == 'pending') {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showApprovalWithDurationDialog(hotspot['id']),
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(
              verificationStatus == 'unverified'
                  ? 'Approve (Unverified)'
                  : 'Approve',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.green.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showRejectDialog(hotspot['id']),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.blueGrey,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _deleteHotspot(hotspot['id']),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
      ]);
    }
    // USER OWNER BUTTONS - Edit/Delete
    else if (!_hasAdminPermissions &&
        !_isOfficer &&
        status == 'pending' &&
        isOwner) {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditHotspotForm(hotspot);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.blue.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _deleteHotspot(hotspot['id']),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
      ]);
    }
    // REJECTED STATUS
    else if (status == 'rejected') {
      if (isOwner || _hasAdminPermissions) {
        buttons.add(
          Center(
            child: SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: () => _deleteHotspot(hotspot['id']),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    // APPROVED STATUS (Admin only)
    else if (_hasAdminPermissions && status == 'approved') {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditHotspotForm(hotspot);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.blue.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _deleteHotspot(hotspot['id']),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
          ),
        ),
      ]);
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons);
  }

  void _showDirectionsConfirmation(
    LatLng coordinates,
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800; // Adjust breakpoint as needed

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(
          24,
        ), // Ensures margin from screen edges
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop
                ? 500 // Fixed width for desktop
                : MediaQuery.of(context).size.width *
                      0.9, // 90% of screen width for mobile
            maxHeight:
                MediaQuery.of(context).size.height *
                0.8, // Max 80% of screen height
          ),
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Warning: Navigate to Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are about to navigate to a reported crime location. This area may be unsafe. Please ensure you are taking necessary precautions before proceeding.',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Consider traveling in groups, informing others of your destination, and avoiding the area during nighttime.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Do you want to proceed?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Proceed Anyway',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // RESPONSIVE DIALOG WRAPPER
  Widget _buildResponsiveDialog({
    required Widget child,
    double maxHeightFactor = 0.9,
  }) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: _isDesktopScreen() ? 40 : 16,
        vertical: 24,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxWidth: _isDesktopScreen() ? 500 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
        ),
        child: child,
      ),
    );
  }

  // IMPROVED REJECTION DIALOG
  void _showRejectDialog(int hotspotId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildResponsiveDialog(
        maxHeightFactor: 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.red.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reject Crime Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This will reject the report and it will not be visible on the map.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reason for Rejection (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide feedback to help the user understand why their report was rejected.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Insufficient evidence, duplicate report, incorrect location...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.red.shade300,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text(
                      'Reject Report',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _reviewHotspot(hotspotId, false, reasonController.text.trim());
    }

    reasonController.dispose();
  }

  // APPROVAL DIALOG WITH DURATION
  void _showApprovalWithDurationDialog(int hotspotId) async {
    bool hasDuration = false;
    int selectedDurationHours = 24;
    DateTime? expirationTime;

    void updateExpirationTime() {
      if (hasDuration) {
        expirationTime = DateTime.now().add(
          Duration(hours: selectedDurationHours),
        );
      } else {
        expirationTime = null;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _buildResponsiveDialog(
          maxHeightFactor: 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Approve Crime Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This will approve the report and make it visible on the map.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Investigation Duration (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a time limit for this investigation to automatically deactivate it.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: hasDuration,
                                  onChanged: (value) {
                                    setState(() {
                                      hasDuration = value ?? false;
                                      updateExpirationTime();
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Enable investigation duration',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Automatically deactivate this incident after a set period',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (hasDuration) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 20,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duration:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$selectedDurationHours hours',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: selectedDurationHours.toDouble(),
                                min: 1,
                                max: 168,
                                divisions: 167,
                                label: '$selectedDurationHours h',
                                activeColor: Colors.blue.shade600,
                                onChanged: (value) {
                                  setState(() {
                                    selectedDurationHours = value.toInt();
                                    updateExpirationTime();
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '1 hour',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '7 days',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 20,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Expiration Time',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      expirationTime
                                              ?.toLocal()
                                              .toString()
                                              .split('.')[0] ??
                                          'Not set',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'The incident will automatically become inactive at this time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Approve Report',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _reviewHotspot(hotspotId, true, null, expirationTime);
    }
  }

  // VERIFY HOTSPOT (Officer only)
  Future<void> _verifyHotspot(int hotspotId) async {
    try {
      await Supabase.instance.client
          .from('hotspot')
          .update({
            'verification_status': 'verified',
            'verified_by': _userProfile?['id'],
            'verified_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'last_updated_by': _userProfile?['id'],
          })
          .eq('id', hotspotId);

      // Send notification to admins
      await _sendVerificationNotificationToAdmins(hotspotId, verified: true);

      // ✅ NEW: Send notification to the reporter
      await _sendVerificationNotificationToReporter(hotspotId);

      await _loadHotspots();
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Report verified successfully');
      }
    } catch (e) {
      print('Error verifying report: $e');
      if (mounted) {
        _showSnackBar('Error verifying report: $e');
      }
    }
  }

  // Send notification to reporter when officer verifies their report
  Future<void> _sendVerificationNotificationToReporter(int hotspotId) async {
    try {
      final hotspotResponse = await Supabase.instance.client
          .from('hotspot')
          .select('''
          reported_by,
          created_by,
          crime_type:type_id(name)
        ''')
          .eq('id', hotspotId)
          .single();

      final reporterId =
          hotspotResponse['reported_by'] ?? hotspotResponse['created_by'];
      final verifyingOfficerId = _userProfile?['id'];

      // ✅ Only send to reporter if they're not the one who verified (edge case)
      if (reporterId != null && reporterId != verifyingOfficerId) {
        final crimeName =
            hotspotResponse['crime_type']?['name'] ?? 'Unknown crime';

        final officerName =
            _userProfile?['full_name'] ??
            '${_userProfile?['first_name']} ${_userProfile?['last_name']}' ??
            'An officer';

        final notificationData = {
          'user_id': reporterId,
          'title': 'Report Verified',
          'message':
              'Your report about $crimeName has been verified by $officerName and is awaiting admin approval',
          'type': 'verified',
          'hotspot_id': hotspotId,
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        await Supabase.instance.client
            .from('notifications')
            .insert(notificationData);
      }
    } catch (e) {
      print('Error sending verification notification to reporter: $e');
    }
  }

  // REJECT VERIFICATION (Officer only)
  Future<void> _rejectVerification(int hotspotId, String? reason) async {
    try {
      await Supabase.instance.client
          .from('hotspot')
          .update({
            'status': 'rejected',
            'active_status': 'inactive',
            'verification_status': 'rejected_verification',
            'rejection_reason': reason,
            'rejected_by': _userProfile?['id'],
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'last_updated_by': _userProfile?['id'],
          })
          .eq('id', hotspotId);

      // Notify user their report was rejected
      await _sendRejectionNotificationToUser(hotspotId, reason);

      // ✅ NEW: Update existing notifications for admins/officers
      await _updateNotificationsOnRejection(hotspotId);

      await _loadHotspots();
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Report rejected');
      }
    } catch (e) {
      print('Error rejecting verification: $e');
      if (mounted) {
        _showSnackBar('Error rejecting report: $e');
      }
    }
  }

  // Update notifications when officer rejects verification
  Future<void> _updateNotificationsOnRejection(int hotspotId) async {
    try {
      final rejectingOfficerId = _userProfile?['id'];
      final officerName =
          _userProfile?['full_name'] ??
          '${_userProfile?['first_name']} ${_userProfile?['last_name']}' ??
          'An officer';

      // ✅ FIX 1: Get all admins/officers EXCEPT the one who rejected
      final adminsAndOfficers = await Supabase.instance.client
          .from('users')
          .select('id')
          .or('role.eq.admin,role.eq.officer')
          .neq('id', rejectingOfficerId);

      if (adminsAndOfficers.isNotEmpty) {
        final otherUserIds = adminsAndOfficers.map((u) => u['id']).toList();

        // ✅ FIX 2: Delete "New Crime Report" for OTHER officers/admins
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('hotspot_id', hotspotId)
            .eq('type', 'report')
            .inFilter('user_id', otherUserIds);

        // ✅ FIX 3: Send rejection notification to OTHER officers/admins
        final notifications = adminsAndOfficers
            .map(
              (user) => {
                'user_id': user['id'],
                'title': 'Report Rejected During Verification',
                'message':
                    'A crime report was rejected during verification by $officerName',
                'type': 'rejection',
                'hotspot_id': hotspotId,
                'is_read': false,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              },
            )
            .toList();

        await Supabase.instance.client
            .from('notifications')
            .insert(notifications);
      }

      // ✅ FIX 4: Delete the rejecting officer's own "New Crime Report" notification
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('hotspot_id', hotspotId)
          .eq('type', 'report')
          .eq('user_id', rejectingOfficerId);
    } catch (e) {
      print('Error updating notifications on rejection: $e');
    }
  }

  // Send notification to user when officer rejects their report
  Future<void> _sendRejectionNotificationToUser(
    int hotspotId,
    String? reason,
  ) async {
    try {
      // Get the report details
      final hotspotResponse = await Supabase.instance.client
          .from('hotspot')
          .select('''
          reported_by,
          created_by,
          crime_type:type_id(name)
        ''')
          .eq('id', hotspotId)
          .single();

      final reporterId =
          hotspotResponse['reported_by'] ?? hotspotResponse['created_by'];

      if (reporterId != null) {
        final crimeName =
            hotspotResponse['crime_type']?['name'] ?? 'Unknown crime';

        final notificationData = {
          'user_id': reporterId,
          'title': 'Report Rejected',
          'message':
              'Your report about $crimeName was rejected. Reason: ${reason ?? "No reason provided"}',
          'type': 'rejection',
          'hotspot_id': hotspotId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        await Supabase.instance.client
            .from('notifications')
            .insert(notificationData);
      }
    } catch (e) {
      print('Error sending rejection notification: $e');
    }
  }

  // Send notification to admins when officer verifies/rejects
  Future<void> _sendVerificationNotificationToAdmins(
    int hotspotId, {
    required bool verified,
  }) async {
    try {
      final verifyingOfficerId = _userProfile?['id'];
      final officerName =
          _userProfile?['full_name'] ??
          '${_userProfile?['first_name']} ${_userProfile?['last_name']}' ??
          'An officer';

      if (verified) {
        // ✅ FIX 1: Get all admins and officers EXCEPT the one who verified
        final adminsAndOfficers = await Supabase.instance.client
            .from('users')
            .select('id')
            .or('role.eq.admin,role.eq.officer')
            .neq('id', verifyingOfficerId); // ✅ Exclude the verifying officer

        if (adminsAndOfficers.isNotEmpty) {
          // ✅ FIX 2: Delete "New Crime Report" notifications for OTHER officers/admins
          final otherUserIds = adminsAndOfficers.map((u) => u['id']).toList();

          await Supabase.instance.client
              .from('notifications')
              .delete()
              .eq('hotspot_id', hotspotId)
              .eq('type', 'report')
              .inFilter(
                'user_id',
                otherUserIds,
              ); // ✅ Only delete for OTHER users

          // ✅ FIX 3: Send "Report Verified" notification to OTHER officers/admins
          final notifications = adminsAndOfficers
              .map(
                (user) => {
                  'user_id': user['id'],
                  'title': 'Report Verified',
                  'message':
                      'A crime report has been verified by $officerName and is awaiting approval',
                  'type': 'verified',
                  'hotspot_id': hotspotId,
                  'is_read': false,
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                },
              )
              .toList();

          await Supabase.instance.client
              .from('notifications')
              .insert(notifications);
        }

        // ✅ FIX 4: Update the verifying officer's OWN notification to add verified status
        // Don't delete it, just update it so they can still see it with a badge
        await Supabase.instance.client
            .from('notifications')
            .update({
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              // You could add a custom field here if you want, like 'verified_by_me': true
            })
            .eq('hotspot_id', hotspotId)
            .eq('type', 'report')
            .eq('user_id', verifyingOfficerId);
      }
    } catch (e) {
      print('Error sending verification notification: $e');
    }
  }

  // Show reject verification dialog
  void _showRejectVerificationDialog(int hotspotId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why is this report being rejected during verification?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectVerification(hotspotId, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewHotspot(
    int id,
    bool approve, [
    String? reason,
    DateTime? expirationTime,
  ]) async {
    try {
      // First get the hotspot to notify the reporter
      final hotspotResponse = await Supabase.instance.client
          .from('hotspot')
          .select('''
        id,
        created_by,
        reported_by,
        verification_status,
        crime_type:type_id(name),
        description,
        status,
        creator_profile:created_by(id, first_name, last_name, contact_number),
        reporter_profile:reported_by(id, first_name, last_name, contact_number)
      ''')
          .eq('id', id)
          .single();

      // Extract contact information
      final reporterId =
          hotspotResponse['reported_by'] ?? hotspotResponse['created_by'];

      // Get the contact number from the appropriate profile
      String? reporterContact;
      String? reporterName;

      if (hotspotResponse['reported_by'] != null &&
          hotspotResponse['reporter_profile'] != null) {
        reporterContact = hotspotResponse['reporter_profile']['contact_number'];
        reporterName =
            '${hotspotResponse['reporter_profile']['first_name']} ${hotspotResponse['reporter_profile']['last_name']}';
      } else if (hotspotResponse['created_by'] != null &&
          hotspotResponse['creator_profile'] != null) {
        reporterContact = hotspotResponse['creator_profile']['contact_number'];
        reporterName =
            '${hotspotResponse['creator_profile']['first_name']} ${hotspotResponse['creator_profile']['last_name']}';
      }

      // Optional: Log the contact info for debugging
      print('Reporter: $reporterName, Contact: $reporterContact');

      // Get current verification status
      final currentVerificationStatus =
          hotspotResponse['verification_status'] ?? 'unverified';

      // Update the hotspot status
      final updateResponse = await Supabase.instance.client
          .from('hotspot')
          .update({
            'status': approve ? 'approved' : 'rejected',
            'active_status': approve ? 'active' : 'inactive',
            'rejection_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
            if (approve) 'created_by': _userProfile?['id'],
            if (approve) 'approved_by': _userProfile?['id'],
            if (!approve) 'rejected_by': _userProfile?['id'],
            if (approve && expirationTime != null)
              'expires_at': expirationTime.toIso8601String(),
            // Auto-verify when admin approves if not already verified
            if (approve && currentVerificationStatus != 'verified')
              'verification_status': 'verified',
            if (approve && currentVerificationStatus != 'verified')
              'verified_by': _userProfile?['id'],
            if (approve && currentVerificationStatus != 'verified')
              'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select('id')
          .single();

      print('Report update response: $updateResponse');

      // Send notification to the reporter
      if (reporterId != null) {
        final crimeName =
            hotspotResponse['crime_type']?['name'] ?? 'Unknown crime';
        final notificationData = {
          'user_id': reporterId,
          'title': approve ? 'Report Approved' : 'Report Rejected',
          'message': approve
              ? 'Your report about $crimeName has been approved'
              : 'Your report was rejected. Reason: ${reason ?? "No reason provided"}',
          'type': approve ? 'approval' : 'rejection',
          'hotspot_id': id,
        };

        print('Attempting to insert notification: $notificationData');
        print('Reporter contact: $reporterContact'); // Available for future use

        final insertResponse = await Supabase.instance.client
            .from('notifications')
            .insert(notificationData)
            .select();

        print('Notification insert response: $insertResponse');
      }

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar(
          approve ? 'Report approved' : 'Report rejected and deactivated',
        );
      }
    } catch (e) {
      print('Error in _reviewHotspot: ${e.toString()}');
      if (mounted) {
        _showSnackBar('Failed to review hotspot: ${e.toString()}');
      }
    }
  }

  //UPDATE HOTSPOT
  Future<PostgrestMap> _updateHotspot(
    int id,
    int typeId,
    String description,
    DateTime dateTime,
    String? activeStatus, {
    DateTime? expirationTime,
  }) async {
    try {
      final updateData = {
        'type_id': typeId,
        'description': description.trim().isNotEmpty
            ? description.trim()
            : null,
        'time': dateTime.toUtc().toIso8601String(),
        if (activeStatus != null) 'active_status': activeStatus,
        if (expirationTime != null)
          'expires_at': expirationTime.toUtc().toIso8601String(),
        if (expirationTime == null && activeStatus == 'inactive')
          'expires_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'last_updated_by': _userProfile?['id'],
      };

      print('=== UPDATING HOTSPOT $id ===');
      print('Update data: $updateData');

      final response = await Supabase.instance.client
          .from('hotspot')
          .update(updateData)
          .eq('id', id)
          .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .single();

      print('✅ Hotspot updated successfully: ${response['id']}');

      await Future.delayed(const Duration(milliseconds: 100));

      Timer(const Duration(seconds: 2), () async {
        if (mounted) {
          final currentHotspot = _hotspots.firstWhere(
            (h) => h['id'] == id,
            orElse: () => {},
          );

          if (currentHotspot.isNotEmpty &&
              currentHotspot['type_id'] != typeId) {
            print('🔄 Real-time update didn\'t apply, forcing reload...');
            await _loadHotspots();
          }
        }
      });

      return response;
    } catch (e) {
      print('❌ Update error: $e');
      if (mounted) {
        _showSnackBar('Failed to update hotspot: ${e.toString()}');
      }
      rethrow;
    }
  }

  // DELETE HOTSPOT
  Future<void> _deleteHotspot(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this hotspot? This will also delete any associated photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Delete associated photo first
      try {
        final existingPhoto = await PhotoService.getHotspotPhoto(id);
        if (existingPhoto != null) {
          await PhotoService.deletePhoto(existingPhoto);
          print('Deleted photo for hotspot $id');
        }
      } catch (e) {
        print('Error deleting hotspot photo: $e');
        // Continue with hotspot deletion even if photo deletion fails
      }

      // Delete the hotspot
      await Supabase.instance.client.from('hotspot').delete().eq('id', id);

      if (mounted) {
        _showSnackBar('Report deleted successfully');
        Navigator.pop(context); // Close any open dialogs
        await _loadHotspots(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete report: ${e.toString()}');
      }
    }
  }

  // SEARCH BAR
  Widget _buildSearchBar({bool isWeb = false}) {
    final bool isDesktop = isWeb; // Assuming isLargeScreen is passed as isWeb

    return Container(
      width: isDesktop ? 600 : double.infinity,
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: TypeAheadField<LocationSuggestion>(
        controller: _searchController,
        suggestionsCallback: _searchLocations,
        itemBuilder: (context, suggestion) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        onSelected: _onSuggestionSelected,
        builder: (context, controller, focusNode) => SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search location...',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emergency contacts button - shows modal on desktop
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (isDesktop) {
                        showHotlinesModal(
                          context,
                          isSidebarVisible: _isSidebarVisible,
                          sidebarWidth:
                              285, // Adjust this to match your actual sidebar width
                        ); // Use the modal for desktop
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HotlinesScreen(),
                          ),
                        );
                      }
                    },
                    tooltip: 'Emergency Hotlines',
                  ),

                  // Clear button - only visible when text is present
                  if (_searchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),

                  // If no text, add some padding to balance the emergency button
                  if (_searchController.text.isEmpty) const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // RECOMMENDED: Smart Combined Proximity Alert
  // Shows most critical threat first, with compact multi-alert display
  // ============================================
  Widget _buildProximityAlert() {
    // Show nothing if no alerts
    if (_proximityAlertType == 'none') {
      return const SizedBox.shrink();
    }

    // CASE 1: Both alerts active - Show most critical first
    if (_proximityAlertType == 'both') {
      // Determine which is more critical
      final hotspotLevel =
          _nearbyHotspots.first['crime_type']['level'] ?? 'low';
      final heatmapLevel = _nearbyHeatmapClusters.first.dominantSeverity;
      final hotspotDistance = _nearbyHotspots.first['distance'] as double;
      final heatmapDistance = _calculateDistance(
        _currentPosition!,
        _nearbyHeatmapClusters.first.center,
      );
      final isInsideHeatmap =
          heatmapDistance <= _nearbyHeatmapClusters.first.radius;

      // Priority logic:
      // 1. Inside heatmap zone = highest priority
      // 2. Critical level crimes
      // 3. High level crimes
      // 4. Closer distance

      bool showHeatmapFirst =
          isInsideHeatmap ||
          _getSeverityPriority(heatmapLevel) >
              _getSeverityPriority(hotspotLevel) ||
          (heatmapLevel == hotspotLevel && heatmapDistance < hotspotDistance);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeatmapFirst) ...[
            _buildHeatmapAlert(),
            const SizedBox(height: 6),
            _buildCompactHotspotAlert(), // Compact version when secondary
          ] else ...[
            _buildHotspotAlert(),
            const SizedBox(height: 6),
            _buildCompactHeatmapAlert(), // Compact version when secondary
          ],
        ],
      );
    }

    // CASE 2: Heatmap alert only
    if (_proximityAlertType == 'heatmap') {
      return _buildHeatmapAlert();
    }

    // CASE 3: Hotspot alert only (original behavior)
    return _buildHotspotAlert();
  }

  // Helper: Get numeric priority for severity levels
  int _getSeverityPriority(String level) {
    switch (level) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  // ============================================
  // NEW: Compact versions for secondary alerts
  // ============================================
  Widget _buildCompactHotspotAlert() {
    if (_nearbyHotspots.isEmpty) return const SizedBox.shrink();

    final closestHotspot = _nearbyHotspots.first;
    final crimeType = closestHotspot['crime_type'];
    final distance = (closestHotspot['distance'] as double).round();
    final level = crimeType['level'] ?? 'unknown';

    Color alertColor = _getAlertColor(level);
    Color textColor = level == 'low' ? Colors.black87 : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: textColor, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${crimeType['name']} • ${distance}m',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_nearbyHotspots.length > 1)
            Text(
              '+${_nearbyHotspots.length - 1}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactHeatmapAlert() {
    if (_nearbyHeatmapClusters.isEmpty) return const SizedBox.shrink();

    final closestCluster = _nearbyHeatmapClusters.first;
    final distanceToCenter = _calculateDistance(
      _currentPosition!,
      closestCluster.center,
    );
    final distanceToEdge = distanceToCenter - closestCluster.radius;
    final isInside = distanceToCenter <= closestCluster.radius;
    final level = closestCluster.dominantSeverity;

    Color alertColor = _getAlertColor(level);
    Color textColor = level == 'low' ? Colors.black87 : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInside ? Icons.dangerous : Icons.shield_outlined,
            color: textColor,
            size: 12,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isInside
                  ? 'Danger! Crime hotzone • ${closestCluster.crimeCount} crimes' // CHANGED
                  : 'Danger zone nearby • ${distanceToEdge.round().abs()}m',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_nearbyHeatmapClusters.length > 1)
            Text(
              '+${_nearbyHeatmapClusters.length - 1}',
              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10),
            ),
        ],
      ),
    );
  }

  // Helper: Centralized color logic
  Color _getAlertColor(String level) {
    switch (level) {
      case 'critical':
        return const Color.fromARGB(255, 247, 26, 10);
      case 'high':
        return const Color.fromARGB(255, 223, 106, 11);
      case 'medium':
        return const Color.fromARGB(155, 202, 130, 49);
      case 'low':
        return const Color.fromARGB(255, 216, 187, 23);
      default:
        return Colors.orange;
    }
  }

  // ============================================
  // NEW: Build heatmap-specific alert
  // FIXED: Better distance display logic
  // ============================================
  Widget _buildHeatmapAlert() {
    if (_nearbyHeatmapClusters.isEmpty) {
      return const SizedBox.shrink();
    }

    final closestCluster = _nearbyHeatmapClusters.first;
    final distanceToCenter = _calculateDistance(
      _currentPosition!,
      closestCluster.center,
    );
    final distanceToEdge = distanceToCenter - closestCluster.radius;
    final isInside = distanceToCenter <= closestCluster.radius;

    // Determine alert severity based on cluster's dominant severity
    final dominantSeverity = closestCluster.dominantSeverity;

    Color alertColor;
    IconData alertIcon;
    Color textColor = Colors.white;
    String alertEmoji;
    String alertText;

    switch (dominantSeverity) {
      case 'critical':
        alertColor = const Color.fromARGB(255, 247, 26, 10);
        alertIcon = isInside ? Icons.dangerous_rounded : Icons.warning_rounded;
        alertEmoji = isInside ? '🚨' : '⚠️';
        break;
      case 'high':
        alertColor = const Color.fromARGB(255, 223, 106, 11);
        alertIcon = isInside ? Icons.error_rounded : Icons.warning_rounded;
        alertEmoji = isInside ? '🚨' : '⚠️';
        break;
      case 'medium':
        alertColor = const Color.fromARGB(155, 202, 130, 49);
        alertIcon = Icons.info_rounded;
        alertEmoji = '⚠️';
        break;
      case 'low':
        alertColor = const Color.fromARGB(255, 216, 187, 23);
        alertIcon = Icons.info_outline_rounded;
        alertEmoji = '⚠️';
        textColor = Colors.black87;
        break;
      default:
        alertColor = Colors.orange;
        alertIcon = Icons.warning_outlined;
        alertEmoji = '⚠️';
    }

    // Build alert text with accurate distance
    if (isInside) {
      // CHANGED: Remove "Inside" wording, show crime count
      alertText =
          'Danger! Crime hotzone • ${closestCluster.crimeCount} incidents';
    } else {
      // Keep approaching alert as is
      final metersAway = distanceToEdge.round().abs();
      alertText = 'Approaching crime zone • ${metersAway}m away';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showHeatmapDetails(closestCluster),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with pulsing animation if inside
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: isInside
                      ? TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1000),
                          tween: Tween(begin: 0.5, end: 1.0),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Icon(
                                alertIcon,
                                color: textColor,
                                size: 14,
                              ),
                            );
                          },
                          onEnd: () {
                            if (mounted) setState(() {});
                          },
                        )
                      : Icon(alertIcon, color: textColor, size: 14),
                ),

                const SizedBox(width: 8),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            alertEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alertText,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Show top crime types
                      if (closestCluster.topCrimeTypes.isNotEmpty)
                        Text(
                          closestCluster.topCrimeTypes.take(2).join(', '),
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Additional zones nearby
                      if (_nearbyHeatmapClusters.length > 1)
                        Text(
                          '+${_nearbyHeatmapClusters.length - 1} more danger zones nearby',
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: textColor.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // REFACTORED: Original hotspot alert as separate method
  // ============================================
  Widget _buildHotspotAlert() {
    if (_nearbyHotspots.isEmpty) {
      return const SizedBox.shrink();
    }

    final closestHotspot = _nearbyHotspots.first;
    final crimeType = closestHotspot['crime_type'];
    final distance = (closestHotspot['distance'] as double).round();
    final level = crimeType['level'] ?? 'unknown';

    Color alertColor;
    IconData alertIcon;
    Color textColor = Colors.white;
    String alertEmoji;

    switch (level) {
      case 'critical':
        alertColor = const Color.fromARGB(255, 247, 26, 10);
        alertIcon = Icons.warning_rounded;
        alertEmoji = '🚨';
        break;
      case 'high':
        alertColor = const Color.fromARGB(255, 223, 106, 11);
        alertIcon = Icons.error_rounded;
        alertEmoji = '⚠️';
        break;
      case 'medium':
        alertColor = const Color.fromARGB(155, 202, 130, 49);
        alertIcon = Icons.info_rounded;
        alertEmoji = '⚠️';
        break;
      case 'low':
        alertColor = const Color.fromARGB(255, 216, 187, 23);
        alertIcon = Icons.info_outline_rounded;
        alertEmoji = '⚠️';
        textColor = Colors.black87;
        break;
      default:
        alertColor = Colors.orange;
        alertIcon = Icons.warning_outlined;
        alertEmoji = '⚠️';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showHotspotDetails(closestHotspot),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(alertIcon, color: textColor, size: 14),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            alertEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${crimeType['name']} • ${distance}m away',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      if (_nearbyHotspots.length > 1)
                        Text(
                          '+${_nearbyHotspots.length - 1} more nearby',
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: textColor.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // UPGRADED: Animated alert wrapper
  // ============================================
  Widget _buildAnimatedProximityAlert() {
    if (_proximityAlertType == 'none') {
      return const SizedBox.shrink();
    }

    // Use stronger animation if inside a heatmap zone
    final isInsideHeatmap =
        _nearbyHeatmapClusters.isNotEmpty &&
        _calculateDistance(
              _currentPosition!,
              _nearbyHeatmapClusters.first.center,
            ) <=
            _nearbyHeatmapClusters.first.radius;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: isInsideHeatmap ? 1500 : 2000),
      tween: Tween(begin: -3.0, end: 3.0),
      curve: Curves.easeInOut,
      builder: (context, translateY, child) {
        return Transform.translate(
          offset: Offset(0, translateY),
          child: _buildProximityAlert(),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  // BUILD CURRENT SCREEN - Updated to remove logout button only on mobile for logged-in users
  Widget _buildCurrentScreen(bool isDesktop) {
    switch (_currentTab) {
      case MainTab.map:
        return Stack(
          children: [
            _buildMap(),
            if (_isLoading && _currentPosition == null)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
                child: Center(
                  child: SizedBox(
                    width: isDesktop ? 600 : null,
                    child: (_userProfile != null && !isDesktop)
                        ? _buildSearchBar(isWeb: isDesktop)
                        : Row(
                            children: [
                              Expanded(
                                child: _buildSearchBar(isWeb: isDesktop),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 22,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _userProfile == null
                                        ? Icons.login
                                        : Icons.logout,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: _userProfile == null
                                      ? () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        }
                                      : _showLogoutConfirmation,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
                child: Center(
                  child: SizedBox(
                    width: isDesktop ? 600 : null,
                    child: _buildAnimatedProximityAlert(),
                  ),
                ),
              ),
            ),
            _buildFloatingDurationWidget(),
            if (isDesktop) const MiniLegend(),
          ],
        );

      case MainTab.chat:
        return ChatChannelsScreen(userProfile: _userProfile!);

      case MainTab.quickAccess:
        return isDesktop
            ? Stack(
                children: [
                  _buildMap(),
                  if (_isLoading && _currentPosition == null)
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      child: Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSearchBar(isWeb: isDesktop),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 22,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _userProfile == null
                                        ? Icons.login
                                        : Icons.logout,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: _userProfile == null
                                      ? () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        }
                                      : _showLogoutConfirmation,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const MiniLegend(),
                ],
              )
            : QuickAccessScreen(
                safeSpots: _safeSpots,
                hotspots: _hotspots,
                currentPosition: _currentPosition,
                userProfile: _userProfile,
                isAdmin: _hasAdminPermissions,
                onGetDirections: _getDirections,
                onGetSafeRoute: _getSafeRoute,
                onShareLocation: _shareLocation,
                onShowOnMap: _showOnMap,
                onNavigateToSafeSpot: _navigateToSafeSpot,
                onNavigateToHotspot: _navigateToHotspot,
                onRefresh: _loadSafeSpots,
                onNavigate: (destination) {
                  _mapController.move(destination, 16.0);
                  setState(() {
                    _destination = destination;
                    _currentTab = MainTab.map;
                  });
                },
              );

      case MainTab.notifications:
        return isDesktop
            ? Stack(
                children: [
                  _buildMap(),
                  if (_isLoading && _currentPosition == null)
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      child: Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSearchBar(isWeb: isDesktop),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 22,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _userProfile == null
                                        ? Icons.login
                                        : Icons.logout,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: _userProfile == null
                                      ? () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        }
                                      : _showLogoutConfirmation,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const MiniLegend(),
                ],
              )
            : _buildNotificationsScreen();

      case MainTab.profile:
        return _buildProfileScreen();

      case MainTab.savePoints:
        return isDesktop
            ? Stack(
                children: [
                  _buildMap(),
                  if (_isLoading && _currentPosition == null)
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      child: Center(
                        child: SizedBox(
                          width: 600,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSearchBar(isWeb: isDesktop),
                              ),
                              const SizedBox(width: 12),

                              if (_userProfile != null) ...[
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.08,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.chat_bubble_rounded,
                                          color: Colors.grey.shade700,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ChatDesktopScreen(
                                                    userProfile: _userProfile!,
                                                  ),
                                            ),
                                          ).then((_) {
                                            _loadUnreadChatCount();
                                          });
                                        },
                                      ),
                                    ),
                                    if (_unreadChatCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _unreadChatCount > 99
                                                  ? '99+'
                                                  : '$_unreadChatCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                              ],

                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 22,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    _userProfile == null
                                        ? Icons.login
                                        : Icons.logout,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: _userProfile == null
                                      ? () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        }
                                      : _showLogoutConfirmation,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const MiniLegend(),
                ],
              )
            : SavePointScreen(
                userProfile: _userProfile,
                currentPosition: _currentPosition,
                onNavigateToPoint: (point) {
                  _mapController.move(point, 16.0);
                  setState(() {
                    _destination = point;
                    _currentTab = MainTab.map;
                  });
                },
                onShowOnMap: _showOnMap,
                onGetSafeRoute: _getSafeRoute,
                onUpdate: () => _loadSavePoints(),
              );
    }
  }

  // PROFILE PAGE DESKTOP

  Widget _buildProfileScreen() {
    if (_userProfile == null) {
      // Instead of showing a message, redirect to login immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      });
      // Return empty container or loading indicator while redirecting
      return const SizedBox.shrink();
    }

    final isDesktop = _isDesktopScreen();

    void toggleEditMode() {
      setState(() {
        _profileScreen.setShouldScrollToTop(true);
        _profileScreen.isEditingProfile = !_profileScreen.isEditingProfile;
        if (!_profileScreen.isEditingProfile) {
          _profileScreen.resetTab();
        }
      });
    }

    void closeProfileAndGoToMap() {
      setState(() {
        _currentTab = MainTab.map;
        _profileScreen.isEditingProfile = false;
        _profileScreen.resetTab();
      });
    }

    Future<void> refreshProfile() async {
      final user = _authService.currentUser;
      if (user != null) {
        try {
          _profileScreen.disposeControllers();
          final response = await Supabase.instance.client
              .from('users')
              .select()
              .eq('id', user.id)
              .single();
          if (mounted) {
            setState(() {
              _userProfile = response;
              _isAdmin = response['role'] == 'admin';
              _isOfficer = response['role'] == 'officer';
              _profileScreen = ProfileScreen(
                _authService,
                _userProfile,
                _isAdmin,
                _hasAdminPermissions,
              );
              _profileScreen.initControllers();
            });
            print(
              'Profile refreshed successfully: Email = ${response['email']}, Role = ${response['role']}',
            );
          }
        } catch (e) {
          print('Error refreshing profile: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to refresh profile: ${e.toString()}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }

    void handleSuccess() {
      print('Profile update success - starting refresh...');
      refreshProfile()
          .then((_) {
            if (mounted) {
              setState(() {
                _profileScreen.setShouldScrollToTop(true);
                _profileScreen.isEditingProfile = false;
                _profileScreen.resetTab();
              });
              print('Profile refresh completed, UI updated');
            }
          })
          .catchError((error) {
            print('Error in handleSuccess refresh: $error');
            if (mounted) {
              setState(() {
                _profileScreen.setShouldScrollToTop(true);
                _profileScreen.isEditingProfile = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Profile updated, but display may not reflect latest changes. Please refresh.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          });
    }

    if (isDesktop) {
      return Stack(
        children: [
          _buildMap(),
          // Add the Mini Legend here for profile screen
          const MiniLegend(),
          if (_isLoading && _currentPosition == null)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 600,
                child: Row(
                  children: [
                    Expanded(child: _buildSearchBar(isWeb: isDesktop)),
                    const SizedBox(width: 12),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _userProfile == null ? Icons.login : Icons.logout,
                          color: Colors.grey.shade700,
                        ),
                        onPressed: _userProfile == null
                            ? () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              }
                            : _showLogoutConfirmation,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Fixed overlay - starts after sidebar to avoid covering MiniLegend
          Positioned(
            left: _isSidebarVisible
                ? 00
                : 00, // Start after sidebar (280 for full, 64 for mini)
            top: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: closeProfileAndGoToMap,
              child: Container(color: Colors.black.withOpacity(0.1)),
            ),
          ),
          // Profile content
          // ignore: unnecessary_null_comparison
          _profileScreen != null
              ? (_profileScreen.isEditingProfile
                    ? _profileScreen.buildDesktopEditProfileForm(
                        context,
                        toggleEditMode,
                        onSuccess: handleSuccess,
                        isSidebarVisible: _isSidebarVisible,
                        onStateChange:
                            setState, // Pass setState as onStateChange
                      )
                    : _profileScreen.buildDesktopProfileView(
                        context,
                        toggleEditMode,
                        onClosePressed: closeProfileAndGoToMap,
                        isSidebarVisible: _isSidebarVisible,
                      ))
              : Container(
                  width: 450,
                  height: 800,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading profile...'),
                      ],
                    ),
                  ),
                ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        // ignore: unnecessary_null_comparison
        child: _profileScreen != null
            ? (_profileScreen.isEditingProfile
                  ? _profileScreen.buildEditProfileForm(
                      context,
                      isDesktop,
                      toggleEditMode,
                      onSuccess: handleSuccess,
                    )
                  : _profileScreen.buildProfileView(
                      context,
                      isDesktop,
                      toggleEditMode,
                    ))
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading profile...'),
                  ],
                ),
              ),
      ),
    );
  }

  //HEAT MAP

  // ============================================
  // HEATMAP HELPER: Validate if crime is within time window
  // ============================================

  bool _isWithinHeatmapTimeWindow(Map<String, dynamic> crime) {
    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );
      final crimeTime = parseStoredDateTime(crime['time']);

      // ✅ If filter dates are set, use those instead of severity-based windows
      if (filterService.crimeStartDate != null ||
          filterService.crimeEndDate != null) {
        bool isAfterStart =
            filterService.crimeStartDate == null ||
            crimeTime.isAfter(filterService.crimeStartDate!) ||
            crimeTime.isAtSameMomentAs(filterService.crimeStartDate!);

        bool isBeforeEnd =
            filterService.crimeEndDate == null ||
            crimeTime.isBefore(filterService.crimeEndDate!) ||
            crimeTime.isAtSameMomentAs(filterService.crimeEndDate!);

        return isAfterStart && isBeforeEnd;
      }

      // ✅ Otherwise, use severity-based time windows (live mode)
      final level = crime['crime_type']['level'] ?? 'low';
      final daysWindow = _severityTimeWindows[level] ?? 30;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysWindow));

      return crimeTime.isAfter(cutoffDate);
    } catch (e) {
      print('Error parsing crime time: $e');
      return false;
    }
  }

  // ============================================
  // HEATMAP HELPER: Format crime with proper structure
  // ============================================

  Map<String, dynamic> _formatCrimeForHeatmap(Map<String, dynamic> crime) {
    final crimeType = crime['crime_type'] ?? {};
    return {
      ...crime,
      'crime_type': {
        'id': crimeType['id'] ?? crime['type_id'],
        'name': crimeType['name'] ?? 'Unknown',
        'level': crimeType['level'] ?? 'unknown',
        'category': crimeType['category'] ?? 'General',
        'description': crimeType['description'],
      },
    };
  }

  // ============================================
  // MODIFIED: Load heatmap data with proper filtering
  // ============================================
  Future<void> _loadHeatmapData() async {
    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );

      final hasCustomDateRange =
          filterService.crimeStartDate != null ||
          filterService.crimeEndDate != null;

      DateTime cutoffDate;

      if (hasCustomDateRange) {
        // ✅ Use custom start date if provided
        cutoffDate =
            filterService.crimeStartDate ??
            DateTime(2000); // Very old date as fallback
        print('📅 Loading crimes from custom date: $cutoffDate');
      } else {
        // ✅ Use severity-based time window for live mode
        final maxTimeWindow = _severityTimeWindows.values.reduce(
          (a, b) => a > b ? a : b,
        );
        cutoffDate = DateTime.now().subtract(Duration(days: maxTimeWindow));
        print('🔴 Loading crimes from last $maxTimeWindow days');
      }

      // Build query
      var query = Supabase.instance.client
          .from('hotspot')
          .select('''
          id,
          type_id,
          location,
          time,
          status,
          active_status,
          created_by,
          reported_by,
          created_at,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .eq('status', 'approved')
          .gte('time', cutoffDate.toIso8601String());

      // Add end date filter if specified
      if (filterService.crimeEndDate != null) {
        query = query.lte(
          'time',
          filterService.crimeEndDate!.toIso8601String(),
        );
      }

      final response = await query;

      setState(() {
        _heatmapCrimes = (response as List)
            .map((crime) => _formatCrimeForHeatmap(crime))
            .toList();
      });

      print(
        '✅ Loaded ${_heatmapCrimes.length} crimes for heatmap '
        '${hasCustomDateRange ? "(historical range)" : "(recent)"}',
      );
    } catch (e) {
      print('Error loading heatmap data: $e');
    }
  }

  // ============================================
  // LOAD PERSISTENT CLUSTERS FROM DATABASE
  // ============================================
  Future<void> _loadPersistentClusters() async {
    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );

      // Check if custom date range is set
      final hasCustomDateRange =
          filterService.crimeStartDate != null ||
          filterService.crimeEndDate != null;

      // Build base query
      var query = Supabase.instance.client.from('heatmap_clusters').select('''
          *,
          heatmap_cluster_crimes!inner(
            hotspot_id,
            is_still_active,
            was_renewal_trigger,
            added_at
          )
        ''');

      if (hasCustomDateRange) {
        // ✅ SHOW HISTORICAL CLUSTERS: Include both active AND inactive clusters
        // Filter clusters that overlap with the selected date range

        if (filterService.crimeStartDate != null) {
          // Show clusters that were created before or during the date range
          query = query.or(
            'status.eq.active,'
            'and(status.eq.inactive,created_at.lte.${filterService.crimeEndDate?.toIso8601String() ?? DateTime.now().toIso8601String()})',
          );
        }

        print(
          '📅 Loading historical clusters for date range: '
          '${filterService.crimeStartDate} to ${filterService.crimeEndDate}',
        );
      } else {
        // ✅ DEFAULT: Show only active clusters (current heatmap)
        query = query.eq('status', 'active');
        print('🔴 Loading only active clusters (no date filter)');
      }

      final clustersResponse = await query;
      final clusters = clustersResponse as List;

      // For each cluster, fetch full crime details
      final processedClusters = <Map<String, dynamic>>[];

      for (final clusterData in clusters) {
        final crimeLinks = clusterData['heatmap_cluster_crimes'] as List;
        final hotspotIds = crimeLinks
            .map((link) => link['hotspot_id'])
            .toList();

        if (hotspotIds.isEmpty) continue;

        // Fetch complete crime data
        var crimeQuery = Supabase.instance.client
            .from('hotspot')
            .select('''
            id,
            type_id,
            location,
            time,
            status,
            active_status,
            created_by,
            reported_by,
            created_at,
            crime_type: type_id (id, name, level, category, description)
          ''')
            .inFilter('id', hotspotIds);

        // ✅ Filter crimes by date range if custom dates are set
        if (hasCustomDateRange) {
          if (filterService.crimeStartDate != null) {
            crimeQuery = crimeQuery.gte(
              'time',
              filterService.crimeStartDate!.toIso8601String(),
            );
          }
          if (filterService.crimeEndDate != null) {
            crimeQuery = crimeQuery.lte(
              'time',
              filterService.crimeEndDate!.toIso8601String(),
            );
          }
        }

        final crimesResponse = await crimeQuery;

        final crimes = (crimesResponse as List)
            .map((crime) => _formatCrimeForHeatmap(crime))
            .toList();

        // Skip clusters with no crimes in the date range
        if (crimes.isEmpty) continue;

        // Merge is_still_active status from junction table
        for (final crime in crimes) {
          final link = crimeLinks.firstWhere(
            (l) => l['hotspot_id'] == crime['id'],
            orElse: () => {},
          );
          crime['is_still_active_in_cluster'] = link['is_still_active'] ?? true;
          crime['was_renewal_trigger'] = link['was_renewal_trigger'] ?? false;
        }

        processedClusters.add({...clusterData, 'crimes': crimes});
      }

      setState(() {
        _persistentClusters = processedClusters;
      });

      print(
        '✅ Loaded ${_persistentClusters.length} clusters '
        '${hasCustomDateRange ? "(historical + active)" : "(active only)"}',
      );
    } catch (e) {
      print('Error loading persistent clusters: $e');
    }
  }
  // ============================================
  // MODIFIED: Cleanup with persistent cluster awareness
  // ============================================

  void _cleanupExpiredHeatmapCrimes() async {
    final beforeCount = _heatmapCrimes.length;

    // Don't remove crimes that are in persistent clusters
    final crimesInClusters = <int>{};

    try {
      final clusterCrimes = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('hotspot_id');

      for (final link in clusterCrimes as List) {
        crimesInClusters.add(link['hotspot_id']);
      }
    } catch (e) {
      print('Error fetching cluster crimes: $e');
    }

    setState(() {
      _heatmapCrimes.removeWhere((crime) {
        // Keep if in a cluster OR still within time window
        return !crimesInClusters.contains(crime['id']) &&
            !_isWithinHeatmapTimeWindow(crime);
      });
    });

    final removedCount = beforeCount - _heatmapCrimes.length;

    if (removedCount > 0) {
      print(
        '🧹 Cleaned up $removedCount expired crimes (preserved cluster crimes)',
      );
      _scheduleHeatmapUpdate();
    }
  }

  // ============================================
  // MODIFIED: Calculation with persistent cluster logic
  // ============================================

  Future<void> _calculateHeatmap() async {
    if (_isCalculatingHeatmap) return;

    setState(() => _isCalculatingHeatmap = true);

    try {
      final filterService = Provider.of<HotspotFilterService>(
        context,
        listen: false,
      );

      final hasCustomDateRange =
          filterService.crimeStartDate != null ||
          filterService.crimeEndDate != null;

      // ✅ ALWAYS process new crimes first (even in historical mode)
      final validCrimes = _heatmapCrimes.where((crime) {
        return crime['status'] == 'approved';
      }).toList();

      if (validCrimes.isNotEmpty) {
        await _processCrimesAgainstPersistentClusters(validCrimes);
      }

      // ✅ Reload clusters after processing new crimes
      await _loadPersistentClusters();

      if (hasCustomDateRange) {
        // ✅ HISTORICAL MODE: Display all clusters from date range
        final displayClusters = _persistentClusters
            .map((pc) => _convertPersistentToDisplayCluster(pc))
            .toList();

        setState(() {
          _heatmapClusters = displayClusters;
        });

        print(
          '✅ Historical heatmap displayed: ${displayClusters.length} clusters',
        );
      } else {
        // ✅ LIVE MODE: Display only active clusters
        final displayClusters = _persistentClusters
            .where((pc) => pc['status'] == 'active')
            .map((pc) => _convertPersistentToDisplayCluster(pc))
            .toList();

        setState(() {
          _heatmapClusters = displayClusters;
        });

        print(
          '✅ Live heatmap updated: ${displayClusters.length} active clusters',
        );
      }
    } catch (e) {
      print('Heatmap calculation error: $e');
    } finally {
      setState(() => _isCalculatingHeatmap = false);
    }
  }

  // ============================================
  // PROCESS CRIMES AGAINST PERSISTENT CLUSTERS
  // ============================================

  // ============================================
  // IMPROVED: Process crimes against persistent clusters (works with historical data)
  // ============================================
  Future<void> _processCrimesAgainstPersistentClusters(
    List<Map<String, dynamic>> crimes,
  ) async {
    if (crimes.isEmpty) return;

    // Get existing crime IDs that are already in clusters
    final existingCrimeIds = <int>{};
    try {
      final links = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('hotspot_id');

      for (final link in links as List) {
        existingCrimeIds.add(link['hotspot_id']);
      }
    } catch (e) {
      print('Error fetching existing cluster crimes: $e');
    }

    // Only process NEW crimes that aren't in any cluster yet
    final newCrimes = crimes
        .where((c) => !existingCrimeIds.contains(c['id']))
        .toList();

    if (newCrimes.isEmpty) {
      print('✅ No new crimes to process, skipping cluster assignment');
      return;
    }

    print(
      '🔄 Processing ${newCrimes.length} new crimes against ${_persistentClusters.length} clusters',
    );

    for (final crime in newCrimes) {
      final crimePoint = LatLng(
        crime['location']['coordinates'][1].toDouble(),
        crime['location']['coordinates'][0].toDouble(),
      );

      bool foundCluster = false;

      // ✅ CHANGED: Check against BOTH active AND inactive clusters
      // This allows historical crimes to be added to inactive clusters
      for (final cluster in _persistentClusters) {
        final clusterCenter = LatLng(
          cluster['center_lat'],
          cluster['center_lng'],
        );
        final distance = _calculateDistance(clusterCenter, crimePoint);

        if (distance <= _clusterMergeDistance) {
          await _addCrimeToExistingCluster(cluster['id'], crime);
          foundCluster = true;

          // ✅ If adding to an inactive cluster, check if it should be reactivated
          if (cluster['status'] == 'inactive') {
            final isActive = _isWithinHeatmapTimeWindow(crime);
            if (isActive) {
              // Reactivate the cluster
              await Supabase.instance.client
                  .from('heatmap_clusters')
                  .update({'status': 'active', 'deactivated_at': null})
                  .eq('id', cluster['id']);

              print(
                '✅ Reactivated cluster ${cluster['id']} with new active crime',
              );
            }
          }

          break;
        }
      }

      // Create new cluster only if NOT found in any existing cluster
      if (!foundCluster) {
        await _checkAndCreateNewCluster(crime, crimes);
      }
    }

    // Update only affected clusters (not all)
    await _updateAffectedClusters(newCrimes);
  }

  // ============================================
  // NEW: Update only clusters that were affected
  // ============================================

  Future<void> _updateAffectedClusters(
    List<Map<String, dynamic>> affectedCrimes,
  ) async {
    if (affectedCrimes.isEmpty) return;

    try {
      // Get cluster IDs that contain these crimes
      final crimeIds = affectedCrimes.map((c) => c['id']).toList();

      final links = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('cluster_id')
          .inFilter('hotspot_id', crimeIds);

      final affectedClusterIds = (links as List)
          .map((link) => link['cluster_id'])
          .toSet()
          .toList();

      if (affectedClusterIds.isEmpty) return;

      print('🔧 Updating ${affectedClusterIds.length} affected clusters');

      // Update only these clusters
      for (final clusterId in affectedClusterIds) {
        final cluster = _persistentClusters.firstWhere(
          (c) => c['id'] == clusterId,
          orElse: () => {},
        );

        if (cluster.isEmpty) continue;

        await _updateSingleCluster(clusterId, cluster);
      }
    } catch (e) {
      print('Error updating affected clusters: $e');
    }
  }

  // ============================================
  // NEW: Update a single cluster
  // ============================================

  Future<void> _updateSingleCluster(
    String clusterId,
    Map<String, dynamic> cluster,
  ) async {
    try {
      final crimes = cluster['crimes'] as List<Map<String, dynamic>>;

      if (crimes.isEmpty) {
        await Supabase.instance.client
            .from('heatmap_clusters')
            .update({
              'status': 'inactive',
              'deactivated_at': DateTime.now().toIso8601String(),
              'active_crime_count': 0,
            })
            .eq('id', clusterId);
        return;
      }

      // Count active crimes
      int activeCrimeCount = 0;
      for (final crime in crimes) {
        final isActive = _isWithinHeatmapTimeWindow(crime);
        if (isActive) activeCrimeCount++;
      }

      if (activeCrimeCount == 0) {
        await Supabase.instance.client
            .from('heatmap_clusters')
            .update({
              'status': 'inactive',
              'deactivated_at': DateTime.now().toIso8601String(),
              'active_crime_count': 0,
            })
            .eq('id', clusterId);
        return;
      }

      // Recalculate properties
      final activeCrimes = crimes
          .where((c) => _isWithinHeatmapTimeWindow(c))
          .toList();
      final clusterData = _calculateClusterProperties(activeCrimes);

      final reductionFactor = activeCrimeCount / crimes.length;
      final adjustedRadius = (clusterData['radius'] * reductionFactor).clamp(
        _severityRadiusConfig[clusterData['dominantSeverity']]!['min']!, // ⭐ CHANGED
        _severityRadiusConfig[clusterData['dominantSeverity']]!['max']!, // ⭐ CHANGED
      );

      await Supabase.instance.client
          .from('heatmap_clusters')
          .update({
            'current_radius': adjustedRadius,
            'dominant_severity': clusterData['dominantSeverity'],
            'intensity': clusterData['intensity'],
            'active_crime_count': activeCrimeCount,
            'last_recalculated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clusterId);
    } catch (e) {
      print('Error updating single cluster: $e');
    }
  }

  // ============================================
  // REFRESH SETTINGS (call after admin updates)
  // ============================================
  Future<void> refreshHeatmapSettings() async {
    _heatmapSettings.clearCache();
    await _loadHeatmapSettings();

    // Recalculate heatmap with new settings
    await _calculateHeatmap();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Heatmap settings updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================
  // MODIFIED: Add crime and recalculate cluster properties
  // ============================================

  Future<void> _addCrimeToExistingCluster(
    String clusterId,
    Map<String, dynamic> crime,
  ) async {
    try {
      // Check if crime already exists in cluster
      final existingLink = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select()
          .eq('cluster_id', clusterId)
          .eq('hotspot_id', crime['id'])
          .maybeSingle();

      if (existingLink != null) {
        // Crime already in cluster, just update its active status
        final isActive = _isWithinHeatmapTimeWindow(crime);

        await Supabase.instance.client
            .from('heatmap_cluster_crimes')
            .update({'is_still_active': isActive})
            .eq('cluster_id', clusterId)
            .eq('hotspot_id', crime['id']);

        print('Updated existing crime ${crime['id']} in cluster $clusterId');
        return;
      }

      // Add new crime to cluster
      final isActive = _isWithinHeatmapTimeWindow(crime);
      final isRenewal = !isActive; // If crime is outside window, it's renewal

      await Supabase.instance.client.from('heatmap_cluster_crimes').insert({
        'cluster_id': clusterId,
        'hotspot_id': crime['id'],
        'is_still_active': isActive,
        'was_renewal_trigger': isRenewal,
      });

      // ⭐ NEW: Fetch ALL crimes in this cluster to recalculate properties
      final clusterCrimesResponse = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('hotspot_id')
          .eq('cluster_id', clusterId);

      final allHotspotIds = (clusterCrimesResponse as List)
          .map((link) => link['hotspot_id'])
          .toList();

      final allCrimesResponse = await Supabase.instance.client
          .from('hotspot')
          .select('''
          id,
          type_id,
          location,
          time,
          status,
          active_status,
          created_by,
          reported_by,
          created_at,
          crime_type: type_id (id, name, level, category, description)
        ''')
          .inFilter('id', allHotspotIds);

      final allCrimes = (allCrimesResponse as List)
          .map((c) => _formatCrimeForHeatmap(c))
          .toList();

      // Get only active crimes for property calculation
      final activeCrimes = allCrimes
          .where((c) => _isWithinHeatmapTimeWindow(c))
          .toList();

      if (activeCrimes.isEmpty) {
        print(
          '⚠️ No active crimes in cluster after addition, this should not happen',
        );
        return;
      }

      // Recalculate cluster properties with ALL active crimes
      final clusterData = _calculateClusterProperties(activeCrimes);

      final reductionFactor = activeCrimes.length / allCrimes.length;

      // Get current cluster radius from database
      final currentClusterData = await Supabase.instance.client
          .from('heatmap_clusters')
          .select('current_radius')
          .eq('id', clusterId)
          .single();

      final currentRadius = currentClusterData['current_radius'].toDouble();

      // Allow radius to expand beyond current radius if new crimes justify it
      final calculatedRadius = clusterData['radius'] * reductionFactor;
      final newRadius = calculatedRadius.clamp(
        SEVERITY_RADIUS_CONFIG[clusterData['dominantSeverity']]!['min']!,
        SEVERITY_RADIUS_CONFIG[clusterData['dominantSeverity']]!['max']!,
      );

      // Take the LARGER of current radius or newly calculated radius
      final finalRadius = newRadius > currentRadius ? newRadius : currentRadius;

      await Supabase.instance.client
          .from('heatmap_clusters')
          .update({
            'center_lat': clusterData['center'].latitude,
            'center_lng': clusterData['center'].longitude,
            'current_radius': finalRadius, // Changed from newRadius
            'dominant_severity': clusterData['dominantSeverity'],
            'intensity': clusterData['intensity'],
            'active_crime_count': activeCrimes.length,
            'total_crime_count': allCrimes.length,
            'last_crime_at': crime['time'],
            'last_recalculated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clusterId);

      print('✅ Added crime ${crime['id']} to cluster $clusterId');
      print(
        '   Updated: ${activeCrimes.length} active/${allCrimes.length} total, radius: ${finalRadius.toStringAsFixed(0)}m',
      );
    } catch (e) {
      print('Error adding crime to cluster: $e');
    }
  }

  // ============================================
  // CHECK AND CREATE NEW CLUSTER
  // ============================================

  Future<void> _checkAndCreateNewCluster(
    Map<String, dynamic> primaryCrime,
    List<Map<String, dynamic>> allCrimes,
  ) async {
    try {
      final primaryPoint = LatLng(
        primaryCrime['location']['coordinates'][1].toDouble(),
        primaryCrime['location']['coordinates'][0].toDouble(),
      );

      // Find nearby crimes within merge distance
      final nearbyCrimes = allCrimes.where((crime) {
        if (crime['id'] == primaryCrime['id']) return true;

        final crimePoint = LatLng(
          crime['location']['coordinates'][1].toDouble(),
          crime['location']['coordinates'][0].toDouble(),
        );

        final distance = _calculateDistance(primaryPoint, crimePoint);
        return distance <= _clusterMergeDistance; // ⭐ CHANGED
      }).toList();

      final activeCrimes = nearbyCrimes
          .where((c) => _isWithinHeatmapTimeWindow(c))
          .toList();

      final criticalCount = nearbyCrimes
          .where((c) => c['crime_type']['level'] == 'critical')
          .length;
      final highCount = nearbyCrimes
          .where((c) => c['crime_type']['level'] == 'high')
          .length;

      bool canFormCluster = false;

      if (nearbyCrimes.length >= _minCrimesForCluster) {
        // ⭐ CHANGED
        canFormCluster = true;
      } else if (criticalCount >= 1 && nearbyCrimes.length >= 2) {
        canFormCluster = true;
      } else if (highCount >= 2) {
        canFormCluster = true;
      }

      if (!canFormCluster) {
        print(
          '⚠️ Not enough crimes to form cluster (${nearbyCrimes.length} crimes found)',
        );
        return; // Not enough crimes to form cluster
      }

      // Check if these crimes already belong to another cluster
      final crimeIds = nearbyCrimes.map((c) => c['id']).toList();
      final existingLinks = await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .select('cluster_id')
          .inFilter('hotspot_id', crimeIds);

      if ((existingLinks as List).isNotEmpty) {
        print(
          '⚠️ Crimes already belong to existing clusters, skipping new cluster creation',
        );
        return;
      }

      // ⭐ CHANGED: Calculate cluster properties with ALL crimes
      // but track which ones are currently active
      final clusterData = _calculateClusterProperties(nearbyCrimes);

      // ⭐ NEW: Determine cluster status based on active crime count
      final clusterStatus = activeCrimes.isEmpty ? 'inactive' : 'active';
      final now = DateTime.now();

      // Create new persistent cluster in database
      final clusterResponse = await Supabase.instance.client
          .from('heatmap_clusters')
          .insert({
            'center_lat': clusterData['center'].latitude,
            'center_lng': clusterData['center'].longitude,
            'current_radius': clusterData['radius'],
            'dominant_severity': clusterData['dominantSeverity'],
            'intensity': clusterData['intensity'],
            'active_crime_count': activeCrimes.length,
            'total_crime_count': nearbyCrimes.length,
            'status': clusterStatus, // ⭐ Set initial status
            'first_crime_at': nearbyCrimes
                .map((c) => DateTime.parse(c['time']))
                .reduce((a, b) => a.isBefore(b) ? a : b)
                .toIso8601String(),
            'last_crime_at': nearbyCrimes
                .map((c) => DateTime.parse(c['time']))
                .reduce((a, b) => a.isAfter(b) ? a : b)
                .toIso8601String(),
            'deactivated_at': clusterStatus == 'inactive'
                ? now.toIso8601String()
                : null, // ⭐ Set if inactive
          })
          .select()
          .single();

      final clusterId = clusterResponse['id'];

      // ⭐ CHANGED: Link all crimes with proper is_still_active status
      final crimeLinks = nearbyCrimes
          .map(
            (crime) => {
              'cluster_id': clusterId,
              'hotspot_id': crime['id'],
              'is_still_active': _isWithinHeatmapTimeWindow(
                crime,
              ), // ⭐ Mark historical crimes as inactive
              'was_renewal_trigger': false,
            },
          )
          .toList();

      await Supabase.instance.client
          .from('heatmap_cluster_crimes')
          .insert(crimeLinks);

      print(
        '✅ Created $clusterStatus cluster $clusterId with ${nearbyCrimes.length} crimes (${activeCrimes.length} active)',
      );
    } catch (e) {
      print('Error creating new cluster: $e');
    }
  }

  // ============================================
  // CALCULATE CLUSTER PROPERTIES
  // ============================================

  Map<String, dynamic> _calculateClusterProperties(
    List<Map<String, dynamic>> crimes,
  ) {
    double totalLat = 0;
    double totalLng = 0;
    double totalWeight = 0;
    final breakdown = <String, int>{
      'critical': 0,
      'high': 0,
      'medium': 0,
      'low': 0,
    };
    double intensity = 0.0;

    String dominantSeverity = 'low';
    int maxSeverityCount = 0;

    for (final crime in crimes) {
      final coords = crime['location']['coordinates'];
      final point = LatLng(coords[1].toDouble(), coords[0].toDouble());
      final level = crime['crime_type']['level'] ?? 'low';
      final weight = _severityWeights[level] ?? 0.25;

      totalLat += point.latitude * weight;
      totalLng += point.longitude * weight;
      totalWeight += weight;
      intensity += weight;

      breakdown[level] = (breakdown[level] ?? 0) + 1;

      if (breakdown[level]! > maxSeverityCount) {
        maxSeverityCount = breakdown[level]!;
        dominantSeverity = level;
      }

      if (level == 'critical') {
        dominantSeverity = 'critical';
      }
    }

    final center = LatLng(totalLat / totalWeight, totalLng / totalWeight);

    // Calculate radius
    double maxDistance = 0;
    for (final crime in crimes) {
      final coords = crime['location']['coordinates'];
      final point = LatLng(coords[1].toDouble(), coords[0].toDouble());
      final distance = _calculateDistance(center, point);
      if (distance > maxDistance) maxDistance = distance;
    }

    final config = SEVERITY_RADIUS_CONFIG[dominantSeverity]!;
    final baseRadius = config['base']!;
    final countMultiplier = crimes.length * config['countMultiplier']!;
    final intensityMultiplier = intensity * config['intensityMultiplier']!;

    final calculatedRadius =
        maxDistance + baseRadius + countMultiplier + intensityMultiplier;
    final radius = calculatedRadius.clamp(config['min']!, config['max']!);

    return {
      'center': center,
      'radius': radius,
      'intensity': intensity,
      'dominantSeverity': dominantSeverity,
      'breakdown': breakdown,
    };
  }

  // ============================================
  // CONVERT PERSISTENT CLUSTER TO DISPLAY CLUSTER
  // ============================================

  HeatmapCluster _convertPersistentToDisplayCluster(
    Map<String, dynamic> persistentCluster,
  ) {
    final crimes = persistentCluster['crimes'] as List<Map<String, dynamic>>;

    // Separate active and inactive crimes
    crimes.where((c) => c['is_still_active_in_cluster'] == true).toList();

    // Build breakdown from ALL crimes (for historical reference)
    final breakdown = <String, int>{
      'critical': 0,
      'high': 0,
      'medium': 0,
      'low': 0,
    };

    for (final crime in crimes) {
      final level = crime['crime_type']['level'] ?? 'low';
      breakdown[level] = (breakdown[level] ?? 0) + 1;
    }

    // Get top crime types from ALL crimes
    final crimeTypeCount = <String, int>{};
    for (final crime in crimes) {
      final crimeType = crime['crime_type']['name'] ?? 'Unknown';
      crimeTypeCount[crimeType] = (crimeTypeCount[crimeType] ?? 0) + 1;
    }

    final sortedTypes = crimeTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = sortedTypes.take(3).map((e) => e.key).toList();

    return HeatmapCluster(
      center: LatLng(
        persistentCluster['center_lat'],
        persistentCluster['center_lng'],
      ),
      radius: persistentCluster['current_radius'].toDouble(),
      intensity: persistentCluster['intensity'].toDouble(),
      crimeCount: crimes.length, // Total crimes (historical + active)
      crimeBreakdown: breakdown,
      topCrimeTypes: topTypes,
      crimes: crimes, // ALL crimes (for historical reference)
      dominantSeverity: persistentCluster['dominant_severity'],
    );
  }

  // ============================================
  // SEVERITY-BASED RADIUS RANGES
  // ============================================
  static const Map<String, Map<String, double>> SEVERITY_RADIUS_CONFIG = {
    'critical': {
      'base': 400.0, // Larger base for serious crimes
      'min': 500.0, // 500m minimum danger zone
      'max': 2500.0, // 2.5km maximum (terrorism, kidnapping zones)
      'countMultiplier': 30.0,
      'intensityMultiplier': 80.0,
    },
    'high': {
      'base': 300.0,
      'min': 400.0, // 400m minimum
      'max': 1800.0, // 1.8km maximum (gang territories, robbery zones)
      'countMultiplier': 25.0,
      'intensityMultiplier': 60.0,
    },
    'medium': {
      'base': 250.0,
      'min': 300.0, // 300m minimum
      'max': 1200.0, // 1.2km maximum (theft, burglary areas)
      'countMultiplier': 20.0,
      'intensityMultiplier': 50.0,
    },
    'low': {
      'base': 200.0,
      'min': 250.0, // 250m minimum
      'max': 800.0, // 800m maximum (disturbances, minor crimes)
      'countMultiplier': 15.0,
      'intensityMultiplier': 40.0,
    },
  };

  // Calculate distance between two points (Haversine formula)

  // ============================================
  // HEATMAP VISUALIZATION
  // ============================================

  // Color gradient for heatmap - UPDATED for better color distribution
  Color _getHeatmapColor(double intensity) {
    // Normalize intensity to 0-1 range for better color distribution
    final normalized = (intensity / 5.0).clamp(
      0.0,
      1.0,
    ); // Assuming max intensity ~5

    if (normalized < 0.25) {
      return Color.lerp(Colors.yellow, Colors.orange, normalized * 4)!;
    } else if (normalized < 0.5) {
      return Color.lerp(
        Colors.orange,
        Colors.deepOrange,
        (normalized - 0.25) * 4,
      )!;
    } else if (normalized < 0.75) {
      return Color.lerp(Colors.deepOrange, Colors.red, (normalized - 0.5) * 4)!;
    } else {
      return Color.lerp(
        Colors.red,
        Colors.red.shade900,
        (normalized - 0.75) * 4,
      )!;
    }
  }

  Widget _buildHeatmapLayer() {
    if (!_showHeatmap || _heatmapClusters.isEmpty) {
      return const SizedBox.shrink();
    }

    // ⭐ UPDATED: Even more conservative scaling across ALL zoom levels
    double fillOpacity;
    double borderOpacity;
    double radiusMultiplier;
    double borderWidth;
    bool useTripleLayer = false;

    if (_currentZoom < 8.0) {
      // Very far zoom: REDUCED from 4.0 to 3.0
      fillOpacity = 0.55;
      borderOpacity = 0.75;
      radiusMultiplier = 3.0; // Was 4.0, now 3x
      borderWidth = 4;
      useTripleLayer = true;
    } else if (_currentZoom < 10.0) {
      // Far zoom: REDUCED from 3.0 to 2.2
      fillOpacity = 0.5;
      borderOpacity = 0.7;
      radiusMultiplier = 2.2; // Was 3.0, now 2.2x
      borderWidth = 3.5;
      useTripleLayer = true;
    } else if (_currentZoom < 12.5) {
      // Medium zoom: REDUCED from 1.8 to 1.4
      fillOpacity = 0.45;
      borderOpacity = 0.65;
      radiusMultiplier = 1.4; // Was 1.8, now 1.4x
      borderWidth = 3;
    } else if (_currentZoom < 13.0) {
      // Very close zoom: REDUCED from 1.0 to 0.85
      fillOpacity = 0.35;
      borderOpacity = 0.55;
      radiusMultiplier = 0.85; // Was 1.0, now 0.85x (15% smaller)
      borderWidth = 2;
    } else {
      // Super close zoom: NEW - even smaller
      fillOpacity = 0.3;
      borderOpacity = 0.5;
      radiusMultiplier = 0.7; // 30% smaller than base
      borderWidth = 2;
    }

    return Stack(
      children: [
        // Outer glow layer - FURTHER REDUCED
        if (useTripleLayer)
          CircleLayer(
            circles: _heatmapClusters.map((cluster) {
              final color = _getHeatmapColor(cluster.intensity);
              return CircleMarker(
                point: cluster.center,
                radius:
                    cluster.radius * radiusMultiplier * 1.3, // Was 1.5, now 1.3
                color: color.withOpacity(
                  fillOpacity * 0.2,
                ), // Was 0.25, now 0.2
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
                useRadiusInMeter: true,
              );
            }).toList(),
          ),

        // Middle glow layer - FURTHER REDUCED
        if (useTripleLayer)
          CircleLayer(
            circles: _heatmapClusters.map((cluster) {
              final color = _getHeatmapColor(cluster.intensity);
              return CircleMarker(
                point: cluster.center,
                radius:
                    cluster.radius *
                    radiusMultiplier *
                    1.15, // Was 1.25, now 1.15
                color: color.withOpacity(
                  fillOpacity * 0.35,
                ), // Was 0.4, now 0.35
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
                useRadiusInMeter: true,
              );
            }).toList(),
          ),

        // Main heatmap layer
        CircleLayer(
          circles: _heatmapClusters.map((cluster) {
            final color = _getHeatmapColor(cluster.intensity);

            return CircleMarker(
              point: cluster.center,
              radius: cluster.radius * radiusMultiplier,
              color: color.withOpacity(fillOpacity),
              borderColor: color.withOpacity(borderOpacity),
              borderStrokeWidth: borderWidth,
              useRadiusInMeter: true,
            );
          }).toList(),
        ),
      ],
    );
  }

  // Build heatmap markers (for interaction)
  Widget _buildHeatmapMarkers() {
    if (!_showHeatmap || _heatmapClusters.isEmpty || _currentZoom < 13.0) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: _heatmapClusters.map((cluster) {
        final color = _getHeatmapColor(cluster.intensity);

        return Marker(
          point: cluster.center,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showHeatmapDetails(cluster),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(
                  '${cluster.crimeCount}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // FIXED: Heatmap details with proper parsing
  // ============================================

  // ============================================
  // MODIFIED: Heatmap details with historical crimes
  // ============================================

  void _showHeatmapDetails(HeatmapCluster cluster) {
    // Find the corresponding persistent cluster
    Map<String, dynamic>? persistentCluster;

    for (final pc in _persistentClusters) {
      final pcCenter = LatLng(pc['center_lat'], pc['center_lng']);
      if (_calculateDistance(cluster.center, pcCenter) < 10.0) {
        // Within 10m
        persistentCluster = pc;
        break;
      }
    }

    final activeCrimeCount =
        persistentCluster?['active_crime_count'] ?? cluster.crimeCount;
    final totalCrimeCount =
        persistentCluster?['total_crime_count'] ?? cluster.crimeCount;

    // Separate active and historical crimes
    final activeCrimes = cluster.crimes
        .where(
          (c) =>
              c['is_still_active_in_cluster'] == true ||
              _isWithinHeatmapTimeWindow(c),
        )
        .toList();

    final historicalCrimes = cluster.crimes
        .where(
          (c) =>
              c['is_still_active_in_cluster'] == false &&
              !_isWithinHeatmapTimeWindow(c),
        )
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 340,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.whatshot,
                      color: _getHeatmapColor(cluster.intensity),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Crime Hotspot',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active vs Total crimes
                      Text(
                        '$activeCrimeCount active crime${activeCrimeCount != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (historicalCrimes.isNotEmpty)
                        Text(
                          '$totalCrimeCount total (${historicalCrimes.length} historical)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Within ${cluster.radius.round()}m radius',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Crime Severity Breakdown
                      const Text(
                        'Crime Severity Breakdown:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...cluster.crimeBreakdown.entries
                          .where((e) => e.value > 0)
                          .map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${entry.key.toUpperCase()}:'),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                      // Active Crimes Section
                      if (activeCrimes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Recent Crimes:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildCrimeList(activeCrimes, isActive: true),
                      ],

                      // Historical Crimes Section
                      if (historicalCrimes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Past Incidents:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.history,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._buildCrimeList(historicalCrimes, isActive: false),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // HELPER: Build crime list for dialog
  // ============================================

  List<Widget> _buildCrimeList(
    List<Map<String, dynamic>> crimes, {
    required bool isActive,
  }) {
    // Group by crime type
    final groupedCrimes = <String, List<Map<String, dynamic>>>{};

    for (final crime in crimes) {
      final crimeType = crime['crime_type']['name'] ?? 'Unknown';
      if (!groupedCrimes.containsKey(crimeType)) {
        groupedCrimes[crimeType] = [];
      }
      groupedCrimes[crimeType]!.add(crime);
    }

    // Sort groups by count (descending)
    final sortedTypes = groupedCrimes.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return sortedTypes.map((entry) {
      final crimeType = entry.key;
      final crimesOfType = entry.value;

      // Sort by time (most recent first)
      crimesOfType.sort((a, b) {
        final timeA = parseStoredDateTime(a['time']);
        final timeB = parseStoredDateTime(b['time']);
        return timeB.compareTo(timeA);
      });

      final mostRecentTime = parseStoredDateTime(crimesOfType.first['time']);
      final timeAgo = _getTimeAgo(mostRecentTime, compact: true);

      final crimeLevel = crimesOfType.first['crime_type']['level'] ?? 'unknown';
      final levelCapitalized =
          crimeLevel[0].toUpperCase() + crimeLevel.substring(1);

      final count = crimesOfType.length;
      final wasRenewalTrigger = crimesOfType.any(
        (c) => c['was_renewal_trigger'] == true,
      );

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.red.shade50 : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: wasRenewalTrigger
              ? Border.all(color: Colors.orange, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '• $crimeType${count > 1 ? ' ($count)' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.red.shade900
                              : Colors.grey[700],
                        ),
                      ),
                      if (wasRenewalTrigger) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.refresh, size: 14, color: Colors.orange),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '($levelCapitalized)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.red.shade700 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.red.shade700 : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<List<LocationSuggestion>> _searchLocations(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      // Enhanced coordinate parsing - supports multiple formats
      final coordinates = _parseCoordinates(query);

      if (coordinates != null && coordinates.isValid) {
        // Return a direct coordinate suggestion
        return [
          LocationSuggestion(
            displayName:
                'Go to exact location (${coordinates.lat.toStringAsFixed(4)}, ${coordinates.lon.toStringAsFixed(4)})',
            lat: coordinates.lat,
            lon: coordinates.lon,
            isInZamboanga: LocationSuggestion._isInZamboangaCity(
              coordinates.lat,
              coordinates.lon,
            ),
          ),
        ];
      }

      // Enhanced query processing with local knowledge
      final processedQueries = _processQueryWithLocalKnowledge(query);

      // Zamboanga City bounding box coordinates
      final boundingBox = '121.9,6.8,122.3,7.0'; // left,bottom,right,top

      List<LocationSuggestion> allResults = [];
      final Set<String> seenLocations = {}; // Avoid duplicates

      final headers = {
        'User-Agent': 'ZamboangaLocationApp/1.0 (zamboanga@app.com)',
        'Accept': 'application/json',
        'Accept-Language': 'en,tl',
      };

      // Search with multiple processed queries
      for (final searchQuery in processedQueries) {
        print('Searching for: $searchQuery'); // Debug log

        final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
            .replace(
              queryParameters: {
                'format': 'json',
                'q': searchQuery,
                'limit': '8',
                'countrycodes': 'ph',
                'bounded': searchQuery.contains('Zamboanga') ? '0' : '1',
                'viewbox': boundingBox,
                'addressdetails': '1',
                'dedupe': '1',
                'extratags': '1',
              },
            );

        try {
          final response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);

            for (final item in data) {
              try {
                final suggestion = LocationSuggestion.fromJson(item);
                final key =
                    '${suggestion.lat.toStringAsFixed(6)},${suggestion.lon.toStringAsFixed(6)}';

                if (!seenLocations.contains(key)) {
                  seenLocations.add(key);
                  allResults.add(suggestion);
                }
              } catch (e) {
                print('Error parsing location item: $e');
              }
            }
          }
        } catch (e) {
          print('Error with query "$searchQuery": $e');
          continue; // Try next query
        }
      }

      if (allResults.isEmpty) return [];

      // Enhanced sorting with local preference
      allResults.sort((a, b) {
        // Check if either matches the original query closely
        final aMatches = _matchesOriginalQuery(a.displayName, query);
        final bMatches = _matchesOriginalQuery(b.displayName, query);

        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;

        // Check if either is an establishment
        final aIsEst = LocationSuggestion._isEstablishment({}, a.displayName);
        final bIsEst = LocationSuggestion._isEstablishment({}, b.displayName);

        if (aIsEst && !bIsEst) return -1;
        if (!aIsEst && bIsEst) return 1;

        // Then prioritize Zamboanga locations
        if (a.isInZamboanga && !b.isInZamboanga) return -1;
        if (!a.isInZamboanga && b.isInZamboanga) return 1;

        // Finally by relevance
        return a.displayName.length.compareTo(b.displayName.length);
      });

      return allResults.take(15).toList();
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        _showSnackBar('Search temporarily unavailable');
      }
      return [];
    }
  }

  // Helper method to parse coordinates from various formats
  CoordinateParseResult? _parseCoordinates(String input) {
    // Remove extra whitespace
    final cleaned = input.trim();

    // Try to extract numbers from the input
    // Matches formats like:
    // - "6.9214, 122.0790"
    // - "(6.9214, 122.0790)"
    // - "6.9214 122.0790"
    // - "lat: 6.9214, lon: 122.0790"
    // - "6.9214°N, 122.0790°E"

    final RegExp coordRegex = RegExp(r'[-+]?\d+\.?\d*', multiLine: false);

    final matches = coordRegex.allMatches(cleaned).toList();

    if (matches.length >= 2) {
      try {
        final lat = double.parse(matches[0].group(0)!);
        final lon = double.parse(matches[1].group(0)!);

        // Validate coordinate ranges
        if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
          return CoordinateParseResult(lat: lat, lon: lon, isValid: true);
        }
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // Local knowledge system for Zamboanga City
  List<String> _processQueryWithLocalKnowledge(String query) {
    final lowerQuery = query.toLowerCase().trim();
    final List<String> searchQueries = [];

    // Zamboanga City specific mappings
    final Map<String, List<String>> localKnowledge = {
      // Universities and Schools
      'wmsu': [
        'Western Mindanao State University',
        'Western Mindanao State University Zamboanga',
      ],
      'western mindanao': ['Western Mindanao State University'],
      'ateneo': ['Ateneo de Zamboanga University', 'Ateneo de Zamboanga'],
      'liceo': ['Liceo de Cagayan University Zamboanga', 'Liceo Zamboanga'],
      'clsu': ['Claret School of Zamboanga'],
      'notre dame': ['Notre Dame of Zamboanga University'],

      // Barangays
      'putik': [
        'Putik Zamboanga City',
        'Barangay Putik',
        'Putik Barangay Zamboanga',
      ],
      'tetuan': ['Tetuan Zamboanga City', 'Barangay Tetuan'],
      'tugbungan': ['Tugbungan Zamboanga City', 'Barangay Tugbungan'],
      'sta catalina': ['Santa Catalina Zamboanga', 'Barangay Santa Catalina'],
      'santa catalina': ['Santa Catalina Zamboanga', 'Barangay Santa Catalina'],
      'tumaga': ['Tumaga Zamboanga City', 'Barangay Tumaga'],
      'campo islam': ['Campo Islam Zamboanga', 'Barangay Campo Islam'],
      'rio hondo': ['Rio Hondo Zamboanga', 'Barangay Rio Hondo'],
      'la paz': ['La Paz Zamboanga City', 'Barangay La Paz'],
      'divisoria': ['Divisoria Zamboanga City', 'Barangay Divisoria'],

      // Schools
      'putik elementary': [
        'Putik Elementary School Zamboanga',
        'Putik Elementary Zamboanga City',
      ],
      'don pablo lorenzo': ['Don Pablo Lorenzo Memorial High School'],
      'zamboanga city high': ['Zamboanga City High School'],

      // Hospitals
      'zamboanga medical': [
        'Zamboanga Medical Center',
        'Zamboanga Medical Center Hospital',
      ],
      'brent hospital': ['Brent Hospital Zamboanga'],
      'veterans memorial': ['Veterans Memorial Medical Center Zamboanga'],

      // Shopping Centers
      'kcc mall': ['KCC Mall of Zamboanga', 'KCC Mall Zamboanga City'],
      'southway mall': ['Southway Square Mall Zamboanga'],
      'mindpro': ['Mindpro Citimall Zamboanga'],

      // Areas/Districts
      'downtown': ['Downtown Zamboanga City'],
      'canelar': ['Canelar Zamboanga City', 'Barangay Canelar'],
      'pasonanca': ['Pasonanca Zamboanga City'],
      'guiwan': ['Guiwan Zamboanga City', 'Barangay Guiwan'],

      // Transportation
      'port': ['Port of Zamboanga', 'Zamboanga Port'],
      'airport': ['Zamboanga Airport', 'Zamboanga International Airport'],
    };

    // Check for exact matches first
    if (localKnowledge.containsKey(lowerQuery)) {
      searchQueries.addAll(localKnowledge[lowerQuery]!);
    }

    // Check for partial matches
    for (final key in localKnowledge.keys) {
      if (lowerQuery.contains(key) || key.contains(lowerQuery)) {
        searchQueries.addAll(localKnowledge[key]!);
      }
    }

    // Add original query variations
    if (!query.toLowerCase().contains('zamboanga')) {
      searchQueries.addAll([
        '$query Zamboanga City',
        '$query, Zamboanga City, Philippines',
        'Barangay $query Zamboanga', // Try as barangay
      ]);
    }

    // Always include the original query
    searchQueries.insert(0, query);

    // Remove duplicates while preserving order
    final seen = <String>{};
    return searchQueries.where((q) => seen.add(q.toLowerCase())).toList();
  }

  // Helper to check if result closely matches original query
  bool _matchesOriginalQuery(String displayName, String originalQuery) {
    final lowerDisplay = displayName.toLowerCase();
    final lowerQuery = originalQuery.toLowerCase();

    // Check for key terms from original query
    final queryWords = lowerQuery.split(RegExp(r'\s+'));
    final matchingWords = queryWords
        .where((word) => word.length > 2 && lowerDisplay.contains(word))
        .length;

    return matchingWords >= (queryWords.length * 0.6); // 60% word match
  }

  bool _destinationFromSearch = false;

  // Updated _onSuggestionSelected method
  void _onSuggestionSelected(LocationSuggestion suggestion) {
    final newPosition = LatLng(suggestion.lat, suggestion.lon);
    if (mounted) {
      setState(() {
        _currentTab = MainTab.map;
        _destination = newPosition; // Sets red marker for search result
        _destinationFromSearch = true;
        _selectedHotspot = null;
        _selectedSafeSpot = null;
        _selectedSavePoint = null;
      });
      _mapController.move(newPosition, 16.0);
      _searchController.text = suggestion.displayName;
    }
  }

  void _showSafeSpotDetails(Map<String, dynamic> safeSpot) {
    if (mounted) {
      SafeSpotDetails.showSafeSpotDetails(
        context: context,
        safeSpot: safeSpot,
        userProfile: _userProfile,
        isAdmin: _hasAdminPermissions,
        onUpdate: () => _loadSafeSpots(),
        onGetSafeRoute: _getSafeRoute,
      );
    }
  }

  _shouldNonAdminOfficerSeeHotspot(PostgrestMap response) {}

  Future<void> _loadUnreadChatCount() async {
    if (_userProfile == null) {
      print('⚠️ Cannot load unread count - no user profile');
      return;
    }

    try {
      print('📊 Loading unread chat count...');
      final chatService = ChatService();
      final userId = _userProfile!['id'] as String;

      // Get all joined channels
      final channels = await chatService.getJoinedChannels(userId);
      print('   Found ${channels.length} joined channels');

      int totalUnread = 0;
      for (final channel in channels) {
        final unread = await chatService.getUnreadCount(channel.id, userId);
        print('   Channel "${channel.name}": $unread unread');
        totalUnread += unread;
      }

      print('✅ Total unread messages: $totalUnread');

      if (mounted) {
        setState(() {
          _unreadChatCount = totalUnread;
        });
      }
    } catch (e) {
      print('❌ Error loading unread chat count: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void _setupChatRealtimeSubscription() {
    if (_userProfile == null) {
      print('⚠️ Cannot setup chat subscription - no user profile');
      return;
    }

    print('🔔 Setting up chat realtime subscription');
    final chatService = ChatService();

    // Subscribe to all chat messages to update unread count
    _chatUpdatesSubscription = chatService.subscribeToAllMessages(() {
      print('🆕 New message detected! Reloading unread count...');
      _loadUnreadChatCount();
    });

    print('✅ Chat subscription setup complete');
  }

  // ============================================
  // ⭐ UPDATED: Handle real-time settings changes with debouncing
  // ============================================
  void _onHeatmapSettingsChanged(Map<String, dynamic> newSettings) async {
    if (!mounted) return;

    print('🔄 Heatmap settings changed, debouncing update...');

    // ⭐ Cancel previous timer if exists
    _settingsUpdateDebouncer?.cancel();

    // ⭐ Wait for 1 second of no updates before processing
    _settingsUpdateDebouncer = Timer(
      const Duration(milliseconds: 1000),
      () async {
        if (!mounted) return;

        print('🔄 Processing batched settings update...');

        setState(() {
          // Update all dynamic settings
          _clusterMergeDistance =
              newSettings['cluster_merge_distance']?.toDouble() ?? 500.0;
          _minCrimesForCluster = newSettings['min_crimes_for_cluster'] ?? 3;
          _proximityAlertDistance =
              newSettings['proximity_alert_distance']?.toDouble() ?? 500.0;

          _severityTimeWindows = {
            'critical': newSettings['time_window_critical'] ?? 120,
            'high': newSettings['time_window_high'] ?? 90,
            'medium': newSettings['time_window_medium'] ?? 60,
            'low': newSettings['time_window_low'] ?? 30,
          };

          _severityWeights = {
            'critical': newSettings['weight_critical']?.toDouble() ?? 1.0,
            'high': newSettings['weight_high']?.toDouble() ?? 0.75,
            'medium': newSettings['weight_medium']?.toDouble() ?? 0.5,
            'low': newSettings['weight_low']?.toDouble() ?? 0.25,
          };

          _severityRadiusConfig = {
            'critical': {
              'base': newSettings['radius_critical_base']?.toDouble() ?? 400.0,
              'min': newSettings['radius_critical_min']?.toDouble() ?? 500.0,
              'max': newSettings['radius_critical_max']?.toDouble() ?? 2500.0,
              'countMultiplier':
                  newSettings['radius_critical_count_multiplier']?.toDouble() ??
                  30.0,
              'intensityMultiplier':
                  newSettings['radius_critical_intensity_multiplier']
                      ?.toDouble() ??
                  80.0,
            },
            'high': {
              'base': newSettings['radius_high_base']?.toDouble() ?? 300.0,
              'min': newSettings['radius_high_min']?.toDouble() ?? 400.0,
              'max': newSettings['radius_high_max']?.toDouble() ?? 1800.0,
              'countMultiplier':
                  newSettings['radius_high_count_multiplier']?.toDouble() ??
                  25.0,
              'intensityMultiplier':
                  newSettings['radius_high_intensity_multiplier']?.toDouble() ??
                  60.0,
            },
            'medium': {
              'base': newSettings['radius_medium_base']?.toDouble() ?? 250.0,
              'min': newSettings['radius_medium_min']?.toDouble() ?? 300.0,
              'max': newSettings['radius_medium_max']?.toDouble() ?? 1200.0,
              'countMultiplier':
                  newSettings['radius_medium_count_multiplier']?.toDouble() ??
                  20.0,
              'intensityMultiplier':
                  newSettings['radius_medium_intensity_multiplier']
                      ?.toDouble() ??
                  50.0,
            },
            'low': {
              'base': newSettings['radius_low_base']?.toDouble() ?? 200.0,
              'min': newSettings['radius_low_min']?.toDouble() ?? 250.0,
              'max': newSettings['radius_low_max']?.toDouble() ?? 800.0,
              'countMultiplier':
                  newSettings['radius_low_count_multiplier']?.toDouble() ??
                  15.0,
              'intensityMultiplier':
                  newSettings['radius_low_intensity_multiplier']?.toDouble() ??
                  40.0,
            },
          };
        });

        print('✅ Settings updated in memory');
        print('   Cluster merge distance: $_clusterMergeDistance m');
        print('   Min crimes for cluster: $_minCrimesForCluster');
        print('   Proximity alert distance: $_proximityAlertDistance m');

        // Recalculate heatmap with new settings
        await _calculateHeatmap();

        // ⭐ Show notification ONCE after all updates
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Heatmap settings updated by administrator',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF6366F1),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _updateHotspotStatus(int hotspotId, String newStatus) async {
    try {
      final updateData = {
        'active_status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'last_updated_by': _userProfile?['id'],
      };

      // If setting to inactive, clear the expiration time
      if (newStatus == 'inactive') {
        updateData['expires_at'] = null;
      }

      await Supabase.instance.client
          .from('hotspot')
          .update(updateData)
          .eq('id', hotspotId);

      await _loadHotspots();
      if (mounted) {
        Navigator.pop(context); // Close the details modal
        _showSnackBar(
          'Status updated to ${newStatus == 'active' ? 'Active' : 'Inactive'}',
        );
      }
    } catch (e) {
      print('Error updating status: $e');
      if (mounted) {
        _showSnackBar('Error updating status: $e');
      }
    }
  }
}

class CoordinateParseResult {
  final double lat;
  final double lon;
  final bool isValid;

  CoordinateParseResult({
    required this.lat,
    required this.lon,
    required this.isValid,
  });
}

class HeatmapCluster {
  final LatLng center; // Weighted center of the cluster
  final double radius; // Actual radius covering all crimes
  final double intensity; // 0.0 to 1.0
  final int crimeCount;
  final Map<String, int> crimeBreakdown;
  final List<String> topCrimeTypes;
  final List<Map<String, dynamic>> crimes; // Individual crimes in this cluster
  final String
  dominantSeverity; // ADD THIS LINE - Store the dominant severity level

  HeatmapCluster({
    required this.center,
    required this.radius,
    required this.intensity,
    required this.crimeCount,
    required this.crimeBreakdown,
    required this.topCrimeTypes,
    required this.crimes,
    required this.dominantSeverity, // Now it matches the field above
  });
}

extension on MapController {}

class PersistentCluster {
  final String id;
  final LatLng center;
  final double currentRadius;
  final String dominantSeverity;
  final double intensity;
  final int activeCrimeCount;
  final int totalCrimeCount;
  final String status;
  final DateTime firstCrimeAt;
  final DateTime lastCrimeAt;
  final List<Map<String, dynamic>> allCrimes; // Historical + active

  PersistentCluster({
    required this.id,
    required this.center,
    required this.currentRadius,
    required this.dominantSeverity,
    required this.intensity,
    required this.activeCrimeCount,
    required this.totalCrimeCount,
    required this.status,
    required this.firstCrimeAt,
    required this.lastCrimeAt,
    required this.allCrimes,
  });

  factory PersistentCluster.fromDatabase(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> crimes,
  ) {
    return PersistentCluster(
      id: data['id'],
      center: LatLng(data['center_lat'], data['center_lng']),
      currentRadius: data['current_radius'].toDouble(),
      dominantSeverity: data['dominant_severity'],
      intensity: data['intensity'].toDouble(),
      activeCrimeCount: data['active_crime_count'],
      totalCrimeCount: data['total_crime_count'],
      status: data['status'],
      firstCrimeAt: DateTime.parse(data['first_crime_at']),
      lastCrimeAt: DateTime.parse(data['last_crime_at']),
      allCrimes: crimes,
    );
  }
}

class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lon;
  final String? originalDisplayName;
  final bool isInZamboanga;

  LocationSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.originalDisplayName,
    this.isInZamboanga = false,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString() ?? 'Unknown location';
    final lat = double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0;

    // Check if coordinates are within Zamboanga City bounds
    final isInZamboanga = _isInZamboangaCity(lat, lon);

    // Smart formatting: only enhance if it's a basic address, preserve establishments
    String formattedName = displayName;
    final address = json['address'] as Map<String, dynamic>?;

    // Check if this is likely an establishment/POI vs just an address
    final isEstablishment = _isEstablishment(json, displayName);

    if (!isEstablishment && address != null && isInZamboanga) {
      // Only format basic addresses, not establishments
      final List<String> nameParts = [];

      // For basic addresses, prioritize local components
      if (address['house_number'] != null && address['road'] != null) {
        nameParts.add('${address['house_number']} ${address['road']}');
      } else if (address['road'] != null) {
        nameParts.add(address['road'].toString());
      }

      if (address['suburb'] != null) {
        nameParts.add(address['suburb'].toString());
      } else if (address['neighbourhood'] != null) {
        nameParts.add(address['neighbourhood'].toString());
      }

      if (nameParts.isNotEmpty) {
        formattedName = '${nameParts.join(', ')}, Zamboanga City';
      }
    } else if (isInZamboanga &&
        !displayName.toLowerCase().contains('zamboanga')) {
      // For establishments, just add Zamboanga context if missing
      final parts = displayName.split(',');
      if (parts.length > 2) {
        // Keep the establishment name and main location, add Zamboanga context
        formattedName = '${parts[0]}, ${parts[1]}, Zamboanga City';
      } else {
        formattedName = '$displayName, Zamboanga City';
      }
    }

    return LocationSuggestion(
      displayName: formattedName,
      lat: lat,
      lon: lon,
      originalDisplayName: displayName,
      isInZamboanga: isInZamboanga,
    );
  }

  // Helper to detect if this is an establishment/POI vs basic address
  static bool _isEstablishment(Map<String, dynamic> json, String displayName) {
    // Check OSM tags that indicate establishments
    final tags = json['extratags'] as Map<String, dynamic>?;
    if (tags != null) {
      if (tags.containsKey('amenity') ||
          tags.containsKey('shop') ||
          tags.containsKey('office') ||
          tags.containsKey('tourism') ||
          tags.containsKey('leisure') ||
          tags.containsKey('name')) {
        return true;
      }
    }

    // Check display name for establishment keywords
    final lowerDisplayName = displayName.toLowerCase();
    final establishmentKeywords = [
      // Educational institutions
      'university', 'college', 'school', 'academy', 'institute', 'campus',
      'elementary', 'high school', 'secondary',
      'western mindanao', 'wmsu', 'ateneo', 'liceo', 'notre dame', 'claret',
      'zamboanga city high', 'don pablo lorenzo',

      // Medical facilities
      'hospital', 'clinic', 'medical center', 'health center', 'pharmacy',
      'zamboanga medical', 'brent hospital', 'veterans memorial',

      // Commercial establishments
      'mall', 'market', 'plaza', 'shopping', 'store', 'shop', 'supermarket',
      'kcc mall', 'southway', 'mindpro', 'citimall',

      // Religious places
      'church', 'mosque', 'temple', 'cathedral', 'chapel',

      // Transportation
      'airport', 'port', 'terminal', 'station',

      // Hospitality
      'hotel', 'resort', 'inn', 'lodge', 'restaurant', 'cafe',

      // Government and services
      'city hall', 'municipal', 'barangay hall', 'office', 'building', 'tower',
      'bank', 'atm',

      // Entertainment and recreation
      'park', 'plaza', 'gym', 'sports', 'recreation', 'theater', 'cinema',

      // Gas stations and utilities
      'gas station', 'petron', 'shell', 'caltex',
    ];

    return establishmentKeywords.any(
      (keyword) => lowerDisplayName.contains(keyword),
    );
  }

  // Helper function to check if coordinates are within Zamboanga City
  static bool _isInZamboangaCity(double lat, double lon) {
    // Zamboanga City approximate boundaries
    const double minLat = 6.8;
    const double maxLat = 7.0;
    const double minLon = 121.9;
    const double maxLon = 122.3;

    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  @override
  String toString() {
    return 'LocationSuggestion{displayName: $displayName, lat: $lat, lon: $lon, isInZamboanga: $isInZamboanga}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationSuggestion &&
        other.displayName == displayName &&
        other.lat == lat &&
        other.lon == lon;
  }

  @override
  int get hashCode {
    return displayName.hashCode ^ lat.hashCode ^ lon.hashCode;
  }
}
