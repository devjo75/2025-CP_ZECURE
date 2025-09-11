import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/desktop/hotlines_desktop.dart';
import 'package:zecure/desktop/quick_access_desktop.dart';
import 'package:zecure/main.dart';
import 'package:zecure/screens/auth/register_screen.dart';
import 'package:zecure/screens/quick_access_screen.dart';
import 'package:zecure/screens/welcome_message_first_timer.dart';
import 'package:zecure/screens/welcome_message_screen.dart';
import 'package:zecure/screens/hotlines_screen.dart';
import 'package:zecure/screens/profile_screen.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:zecure/desktop/report_hotspot_form_desktop.dart' show ReportHotspotFormDesktop;
import 'package:zecure/desktop/hotspot_filter_dialog_desktop.dart';
import 'package:zecure/desktop/location_options_dialog_desktop.dart';
import 'package:zecure/desktop/desktop_sidebar.dart';
import 'package:zecure/services/photo_upload_service.dart';
import 'package:zecure/services/pulsing_hotspot_marker.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/services/safe_spot_details.dart';
import 'package:zecure/services/safe_spot_form.dart';
import 'package:zecure/services/safe_spot_service.dart';









class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();

  
}

enum MainTab { map, quickAccess, notifications, profile }
enum TravelMode { walking, driving, cycling }
enum MapType { standard, satellite, terrain, topographic, dark }

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final _authService = AuthService(Supabase.instance.client);
  MapType _currentMapType = MapType.standard;

  Map<MapType, Map<String, dynamic>> get mapConfigurations => {
    MapType.standard: {
      'name': 'Standard',
      'urlTemplate': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'fallbackUrl': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors',
    },


    MapType.terrain: {
      'name': 'Terrain',
      'urlTemplate': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      'fallbackUrl': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenTopoMap (CC-BY-SA)',
    },

  MapType.satellite: {
    'name': 'Satellite',
    'urlTemplate': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'fallbackUrl': 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'attribution': '© Esri, Maxar, Earthstar Geographics',
  },

  MapType.topographic: {
    'name': 'Topographic',
    'urlTemplate': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    'fallbackUrl': 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    'attribution': '© Esri, HERE, Garmin, SafeGraph, METI/NASA, USGS',
  },

  
    MapType.dark: {
      'name': 'Dark',
      'urlTemplate': 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      'fallbackUrl': 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      'attribution': '© CartoDB',
    },
    
  };


bool _markersLoaded = false;
int _maxMarkersToShow = 50; // Progressive loading
Timer? _deferredLoadTimer;

 
  TravelMode _selectedTravelMode = TravelMode.driving;
  bool _showTravelModeSelector = false;
  bool _showMapTypeSelector = false;


  //MAP ZOOM FOR LABEL
  double _currentZoom = 15.0;

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


  // ADD: New variables for route tracking
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
  static const double _alertDistanceMeters = 500.0;

  
  // Directions state
  double _distance = 0;
  String _duration = '';

  // Live tracking state
  StreamSubscription<Position>? _positionStream;
  bool _hotspotsChannelConnected = false;
  bool _notificationsChannelConnected = false;
  Timer? _reconnectionTimer;

  bool _showClearButton = false;

  // User state
Map<String, dynamic>? _userProfile;
bool _isAdmin = false;
bool _isOfficer = false;
// Helper getter for admin or officer permissions
bool get _hasAdminPermissions => _isAdmin || _isOfficer;
MainTab _currentTab = MainTab.map;
late ProfileScreen _profileScreen;


  // HOTSPOT
  List<Map<String, dynamic>> _hotspots = [];
  Map<String, dynamic>? _selectedHotspot;
  RealtimeChannel? _hotspotsChannel;

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

// NEW: Progressive marker loading based on zoom level
List<Map<String, dynamic>> get _visibleHotspots {
  if (!_markersLoaded) return []; // Don't show markers until loaded

  if (_currentZoom < 10.0) {
    // Very zoomed out: show only critical hotspots
    return _hotspots
        .where((h) =>
            h['crime_type']?['level'] == 'critical' &&
            h['status'] == 'approved' &&
            h['active_status'] == 'active')
        .take(20)
        .toList();
  } else if (_currentZoom < 13.0) {
    // Medium zoom: show critical and high priority hotspots
    return _hotspots
        .where((h) =>
            ['critical', 'high'].contains(h['crime_type']?['level']) &&
            h['status'] == 'approved' &&
            h['active_status'] == 'active')
        .take(_maxMarkersToShow)
        .toList();
  } else {
    // Close zoom: show all hotspots, including rejected and inactive, with limit
    return _hotspots
        .where((h) {
          final status = h['status'] ?? 'approved';
          final activeStatus = h['active_status'] ?? 'active';
          final currentUserId = _userProfile?['id'];
          final createdBy = h['created_by'];
          final reportedBy = h['reported_by'];
          final isOwnHotspot = currentUserId != null &&
              (currentUserId == createdBy || currentUserId == reportedBy);

          // Include all hotspots (approved, pending, rejected, active, inactive)
          // Admins see all, users see approved/active, own hotspots, or pending
return _hasAdminPermissions ||
    status == 'approved' ||
    status == 'pending' ||
    (status == 'rejected' && isOwnHotspot) ||
    activeStatus == 'active' ||
    (activeStatus == 'inactive' && isOwnHotspot);
        })
        .take(_maxMarkersToShow * 2)
        .toList();
  }
}

// NEW: Progressive safe spots loading
List<Map<String, dynamic>> get _visibleSafeSpots {
  if (!_markersLoaded || !_showSafeSpots) return [];
  
  if (_currentZoom < 12.0) {
    // Only show verified safe spots when zoomed out
    return _safeSpots.where((s) => s['verified'] == true).take(30).toList();
  } else {
    // Show all relevant safe spots when zoomed in
return _safeSpots.where((safeSpot) {
  final status = safeSpot['status'] ?? 'pending';
  final currentUserId = _userProfile?['id'];
  final createdBy = safeSpot['created_by'];
  final isOwnSpot = currentUserId != null && currentUserId == createdBy;
  
  if (status == 'approved') return true;
  if (status == 'pending' && currentUserId != null) return true;
  if (isOwnSpot && status == 'rejected') return true;
  if (_hasAdminPermissions) return true;
  return false;
}).toList();
  }
}

List<Map<String, dynamic>> _getFilteredNotifications() {
  switch (_notificationFilter) {
    case 'Unread':
      return _notifications.where((n) => !n['is_read']).toList();
    case 'Critical':
      return _notifications.where((notification) {
        if (notification['type'] == 'report' && notification['hotspot_id'] != null) {
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
        if (notification['type'] == 'report' && notification['hotspot_id'] != null) {
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
        if (notification['type'] == 'report' && notification['hotspot_id'] != null) {
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
        if (notification['type'] == 'report' && notification['hotspot_id'] != null) {
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
        return ['safe_spot_report', 'safe_spot_approval', 'safe_spot_rejection'].contains(notification['type']);
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
        
        _loadUserProfile().then((_) {
          _isLoadingProfile = false;
          if (mounted) {
            final filterService = Provider.of<HotspotFilterService>(context, listen: false);
            filterService.resetFiltersForUser(_userProfile?['id']?.toString());
            
            // Only setup notifications if not already done
            if (_notificationsChannel == null) {
              _deferredLoadTimer = Timer(Duration(milliseconds: 1000), () {
                if (mounted) {
                  _setupNotificationsRealtime();
                  _loadNotifications();
                }
              });
            }
          }
        }).catchError((e) {
          _isLoadingProfile = false;
          print('Error loading profile: $e');
        });
      } else if (event.session == null && mounted) {
        print('User logged out, cleaning up');
        _isLoadingProfile = false;
        setState(() {
          _userProfile = null;
          _isAdmin = false;
          _isOfficer = false;
          _hotspots = [];
          _notifications = [];
          _unreadNotificationCount = 0;
        });
        
        final filterService = Provider.of<HotspotFilterService>(context, listen: false);
        filterService.resetFiltersForUser(null);
        
        _cleanupChannels();
      }
    });
  }

  // Start location immediately (but don't block)
  _getCurrentLocationAsync();
}

// Helper method to clean up channels safely
void _cleanupChannels() {
  _notificationsChannel?.unsubscribe();
  _notificationsChannel = null;
  _hotspotsChannel?.unsubscribe();
  _hotspotsChannel = null;
  _safeSpotsChannel?.unsubscribe();
  _safeSpotsChannel = null;
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
            _mapController.move(_currentPosition!, 15.0);
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
  Timer(Duration(milliseconds: 500), () { // Much shorter delay
    if (mounted) {
      _showWelcomeModal();
    }
  });
  
  // Load user profile first (lightweight) - only if not already loaded
  if (_userProfile == null && !_isLoadingProfile) {
    await _loadUserProfile();
    if (!mounted) return;
    
    // Reset filters
    final filterService = Provider.of<HotspotFilterService>(context, listen: false);
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
  
  // Mark markers as loaded
  setState(() {
    _markersLoaded = true;
  });
  
  // Setup periodic tasks with initial delays (REDUCED FREQUENCY)
  _setupPeriodicTasksOptimized();
  
  // DELAY location services startup to prevent early proximity checking
  _deferredLoadTimer = Timer(Duration(milliseconds: 2000), () {
    if (mounted) {
      print('Starting location services...');
      _startLiveLocationDeferred();
    }
  });
  
  print('Deferred initialization completed.');
}

// NEW: Setup periodic tasks with optimized intervals - MUCH LESS AGGRESSIVE
void _setupPeriodicTasksOptimized() {
  // Cleanup orphaned notifications (much less frequent initially)
  Timer(Duration(minutes: 10), () { // Increased from 5 minutes
    if (mounted) {
      Timer.periodic(const Duration(hours: 2), (_) => _cleanupOrphanedNotifications()); // Increased from 1 hour
    }
  });
  
  // Connection check (much less frequent initially)
  Timer(Duration(minutes: 5), () { // Increased from 1 minute
    if (mounted) {
      Timer.periodic(const Duration(minutes: 5), (_) => _checkRealtimeConnection()); // Increased from 2 minutes
    }
  });
}

// NEW: Setup periodic tasks with optimized intervals

// NEW: Deferred location services startup
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
  _deferredLoadTimer?.cancel(); // NEW: Clean up deferred timer
  
  if (_safeSpotsChannel != null) {
    print('Unsubscribing from safe spots real-time channel...');
    _safeSpotsChannel!.unsubscribe();
    _safeSpotsChannel = null;
  }

    for (final timer in _updateTimers.values) {
    timer.cancel();
  }
  _updateTimers.clear();
  _updateDebounceTimer?.cancel();
  _processedUpdateIds.clear();
  
  super.dispose();
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
      final oldIds = _processedUpdateIds.take(_processedUpdateIds.length - 50).toList();
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
      });

      _showUpdateMessage(_safeSpots.firstWhere((s) => s['id'] == spotId, orElse: () => {}), response, payload.newRecord['status']);
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

void _showUpdateMessage(Map<String, dynamic> previousSafeSpot, Map<String, dynamic> response, String? previousStatus) {
  final newStatus = response['status'] ?? 'pending';
  final typeName = response['safe_spot_types']['name'];

  print('Message check - Previous status: $previousStatus, New status: $newStatus');

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
  } else if (previousStatus == newStatus) {
    // Check if it's an edit (content changed but status stayed same)
    final previousName = previousSafeSpot.isNotEmpty ? previousSafeSpot['name'] : '';
    final newName = response['name'] ?? '';
    final previousDescription = previousSafeSpot.isNotEmpty ? previousSafeSpot['description'] : '';
    final newDescription = response['description'] ?? '';
    final previousTypeId = previousSafeSpot.isNotEmpty ? previousSafeSpot['type_id'] : null;
    final newTypeId = response['type_id'];

    bool isEdit = (previousName != newName || 
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
    final relatedNotifications = _notifications.where((notification) => 
      notification['safe_spot_id'] == deletedSafeSpotId
    ).toList();
    
    // Update unread count for any unread notifications that will be removed
    for (final notification in relatedNotifications) {
      if (!(notification['is_read'] ?? false)) {
        _unreadNotificationCount = (_unreadNotificationCount - 1).clamp(0, double.infinity).toInt();
      }
    }
    
    // Remove the notifications
    _notifications.removeWhere((notification) => 
      notification['safe_spot_id'] == deletedSafeSpotId
    );
    
    // Clear selection if the deleted safe spot was selected
    if (_selectedSafeSpot != null && _selectedSafeSpot!['id'] == deletedSafeSpotId) {
      _selectedSafeSpot = null;
    }
    
    print('Safe spot deleted via real-time: $deletedSafeSpotId');
    print('Related notifications removed: ${relatedNotifications.length}');
    print('Updated unread count: $_unreadNotificationCount');
    
    // Show notification
    if (deletedSafeSpot.isNotEmpty) {
      final typeName = deletedSafeSpot['safe_spot_types']?['name'] ?? 'Safe spot';
      _showSnackBar('$typeName deleted');
    }
  });
}

void _handleSafeSpotUpvoteChange(PostgresChangePayload payload) {
  if (!mounted) return;
  
  // Get the safe spot ID from the upvote record
  final safeSpotId = payload.newRecord['safe_spot_id'] ?? payload.oldRecord['safe_spot_id'];
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
          .select('first_name, role, created_at')
          .eq('id', user.id)
          .single();
      
      final role = response['role'];
      final isAdmin = role == 'admin';
      final isOfficer = role == 'officer';
      final firstName = response['first_name'];
      final createdAt = DateTime.parse(response['created_at']);
      final isNewUser = DateTime.now().difference(createdAt).inMinutes < 5;
      
      if (isNewUser) {
        showFirstTimeWelcomeModal(
          context,
          userName: firstName,
        );
      } else {
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
  });
}

// NEW: Lightweight marker builder for distant zoom levels


// Main method to check proximity to active hotspots
void _checkProximityToHotspots() {
  if (_currentPosition == null || !mounted) {
    print('DEBUG: Cannot check proximity - position: $_currentPosition, mounted: $mounted');
    return;
  }

  print('DEBUG: Checking proximity from position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
  print('DEBUG: Total hotspots to check: ${_hotspots.length}');
  
  final nearbyHotspots = <Map<String, dynamic>>[];
  
  for (final hotspot in _hotspots) {
    // Only check active, approved hotspots
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    final crimeTypeName = hotspot['crime_type']?['name'] ?? 'Unknown';
    final crimeLevel = hotspot['crime_type']?['level'] ?? 'medium';
    
    print('DEBUG: Checking hotspot ${hotspot['id']} ($crimeTypeName - $crimeLevel) - status: $status, active: $activeStatus');
    
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
    final alertDistance = _alertDistanceMeters;
    
    print('DEBUG: Hotspot ${hotspot['id']} ($crimeTypeName - $crimeLevel) distance: ${distance.toStringAsFixed(1)}m (threshold: ${alertDistance.toStringAsFixed(0)}m)');
    
    if (distance <= alertDistance) {
      print('DEBUG: ✅ Hotspot ${hotspot['id']} ($crimeTypeName) is within range! Adding to nearby list.');
      nearbyHotspots.add({
        ...hotspot,
        'distance': distance,
      });
    } else {
      print('DEBUG: ❌ Hotspot ${hotspot['id']} ($crimeTypeName) is too far (${distance.toStringAsFixed(1)}m > ${alertDistance.toStringAsFixed(0)}m)');
    }
  }

  print('DEBUG: Found ${nearbyHotspots.length} nearby hotspots');

  // Sort by distance (closest first)
  nearbyHotspots.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

  // Always update state based on what we found
  final hasNearbyHotspots = nearbyHotspots.isNotEmpty;
  final previousAlertState = _showProximityAlert;
  
  if (mounted) {
    setState(() {
      _nearbyHotspots = nearbyHotspots;
      _showProximityAlert = hasNearbyHotspots;
    });
    
    // Log state changes
    if (_showProximityAlert != previousAlertState) {
      if (_showProximityAlert) {
        final closestDistance = nearbyHotspots.first['distance'] as double;
        print('DEBUG: 🚨 ALERT ACTIVATED - ${nearbyHotspots.length} crimes nearby (closest: ${closestDistance.toStringAsFixed(1)}m)');
        HapticFeedback.lightImpact(); // Haptic feedback when alert appears
      } else {
        print('DEBUG: ✅ ALERT CLEARED - moved away from danger zone');
      }
    }
    
    print('DEBUG: Updated state - showAlert: $_showProximityAlert, nearbyCount: ${_nearbyHotspots.length}');
  }
}

// Helper method to compare lists


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
      .channel('notifications_realtime_${DateTime.now().millisecondsSinceEpoch}') // Unique channel name
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
        } else if (status == 'CHANNEL_ERROR' || status == 'CLOSED' || error != null) {
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
  
  print('Handling notification insert for current user: ${newNotification['title']}');
  
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
    
    print('New notification added. Total: ${_notifications.length}, Unread: $_unreadNotificationCount');
    
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
          _unreadNotificationCount = (_unreadNotificationCount - 1).clamp(0, double.infinity).toInt();
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
        _unreadNotificationCount = (_unreadNotificationCount - 1).clamp(0, double.infinity).toInt();
      }
    }
  });
  
  print('Notification deleted. Total: ${_notifications.length}, Unread: $_unreadNotificationCount');
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
        _unreadNotificationCount = _notifications.where((n) => !(n['is_read'] ?? false)).length;
      });
      
      print('Notifications loaded. Total: ${_notifications.length}, Unread: $_unreadNotificationCount');
    }
  } catch (e) {
    print('Error loading notifications: $e');
    if (mounted) {
      _showSnackBar('Error loading notifications: ${e.toString()}');
    }
  }
}

// Update your duplicate removal to handle safe spot notifications
List<Map<String, dynamic>> _removeDuplicateNotifications(List<dynamic> notifications) {
  final uniqueKeys = <String>{};
  final uniqueNotifications = <Map<String, dynamic>>[];
  
  for (final notification in notifications.cast<Map<String, dynamic>>()) {
    // Create unique key based on notification type and related IDs
    String key;
    if (notification['safe_spot_id'] != null) {
      key = '${notification['safe_spot_id']}_${notification['user_id']}_${notification['type']}';
    } else if (notification['hotspot_id'] != null) {
      key = '${notification['hotspot_id']}_${notification['user_id']}_${notification['type']}';
    } else {
      key = '${notification['id']}_${notification['user_id']}_${notification['type']}';
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
        _unreadNotificationCount = (_unreadNotificationCount - 1).clamp(0, double.infinity).toInt();
      });
    }
    
    print('Notification marked as read. Unread count: $_unreadNotificationCount');
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
  _isAdmin,           // Admin-only privileges
  _hasAdminPermissions // Admin + Officer privileges
);
          _profileScreen.initControllers();
        });
        
        print('User profile loaded: ${_userProfile!['id']}');
        
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



void _setupRealtimeSubscription() {
  _hotspotsChannel?.unsubscribe();
  _hotspotsChannelConnected = false;

  _hotspotsChannel = Supabase.instance.client
      .channel('hotspots_realtime_${DateTime.now().millisecondsSinceEpoch}') // Unique channel name
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
        print('Hotspots channel status: $status, error: $error');
        
        if (status == 'SUBSCRIBED') {
          print('Successfully connected to hotspots channel');
          setState(() => _hotspotsChannelConnected = true);
        } else if (status == 'CHANNEL_ERROR' || status == 'CLOSED') {
          print('Error with hotspots channel: $error');
          setState(() => _hotspotsChannelConnected = false);
          
          // Attempt to reconnect after delay
          _reconnectionTimer?.cancel();
          _reconnectionTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              print('Attempting to reconnect hotspots channel...');
              _setupRealtimeSubscription();
            }
          });
        }
      });
}

void _handleHotspotInsert(PostgresChangePayload payload) async {
  if (!mounted) return;
  
  try {
    // Fetch the complete hotspot data with proper crime type info
    final response = await Supabase.instance.client
        .from('hotspot')
        .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
        .eq('id', payload.newRecord['id'])
        .single();

    if (mounted) {
      setState(() {
        // Ensure proper crime_type structure
        final crimeType = response['crime_type'] ?? {};
        _hotspots.add({
          ...response,
          'crime_type': {
            'id': crimeType['id'] ?? response['type_id'],
            'name': crimeType['name'] ?? 'Unknown',
            'level': crimeType['level'] ?? 'unknown',
            'category': crimeType['category'] ?? 'General',
            'description': crimeType['description'],
          }
        });
      });
    }
  } catch (e) {
    print('Error in _handleHotspotInsert: $e');
    if (mounted) {
      setState(() {
        _hotspots.add({
          ...payload.newRecord,
          'crime_type': {
            'id': payload.newRecord['type_id'],
            'name': 'Unknown',
            'level': 'unknown',
            'category': 'General',
            'description': null
          }
        });
      });
    }
  }
}

// ==== FIX 2: Fixed _handleHotspotUpdate for proper user-side color updates ====
void _handleHotspotUpdate(PostgresChangePayload payload) async {
  if (!mounted) return;
  
  try {
    // Get the previous hotspot data
    final previousHotspot = _hotspots.firstWhere(
      (h) => h['id'] == payload.newRecord['id'],
      orElse: () => {},
    );

    // Fetch the updated hotspot data WITH proper crime_type structure
    final response = await Supabase.instance.client
        .from('hotspot')
        .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
        .eq('id', payload.newRecord['id'])
        .single();

    if (mounted) {
      setState(() {
        final index = _hotspots.indexWhere((h) => h['id'] == payload.newRecord['id']);
        
        // Check if non-admin/officer user should see this hotspot
        final shouldShowForNonAdminOfficer = _shouldNonAdminOfficerSeeHotspot(response);
        
        if (index != -1) {
          // Hotspot exists in current list
          if (_hasAdminPermissions || shouldShowForNonAdminOfficer) {
            // Update the existing hotspot with proper crime_type structure
            final crimeType = response['crime_type'] ?? {};
            _hotspots[index] = {
              ...response,
              'crime_type': {
                'id': crimeType['id'] ?? response['type_id'],
                'name': crimeType['name'] ?? 'Unknown',
                'level': crimeType['level'] ?? 'unknown',
                'category': crimeType['category'] ?? 'General',
                'description': crimeType['description'],
              }
            };
          } else {
            // Non-admin/officer user should no longer see this hotspot (e.g., it was rejected)
            _hotspots.removeAt(index);
          }
        } else {
          // Hotspot doesn't exist in current list
          if (_hasAdminPermissions || shouldShowForNonAdminOfficer) {
            // Add it if user should see it
            final crimeType = response['crime_type'] ?? {};
            _hotspots.add({
              ...response,
              'crime_type': {
                'id': crimeType['id'] ?? response['type_id'],
                'name': crimeType['name'] ?? 'Unknown',
                'level': crimeType['level'] ?? 'unknown',
                'category': crimeType['category'] ?? 'General',
                'description': crimeType['description'],
              }
            });
          }
        }
      });

      // Only show messages if status actually changed
      final previousStatus = previousHotspot['status'] ?? 'approved';
      final newStatus = response['status'] ?? 'approved';
      final previousActiveStatus = previousHotspot['active_status'] ?? 'active';
      final newActiveStatus = response['active_status'] ?? 'active';
      final crimeType = response['crime_type']?['name'] ?? 'Unknown';

      if (newStatus != previousStatus) {
        if (newStatus == 'approved') {
          _showSnackBar('Crime report approved: $crimeType');
        } else if (newStatus == 'rejected') {
          _showSnackBar('Crime report rejected: $crimeType');
        }
      }
      
      // Show message for active status changes
      if (newActiveStatus != previousActiveStatus) {
        if (newActiveStatus == 'active') {
          _showSnackBar('Crime Report activated: $crimeType');
        } else {
          _showSnackBar('Crime Report deactivated: $crimeType');
        }
      }
    }
  } catch (e) {
    print('Error fetching updated crime: $e');
    // Try to at least update with basic info if full fetch fails
    if (mounted) {
      setState(() {
        final index = _hotspots.indexWhere((h) => h['id'] == payload.newRecord['id']);
        if (index != -1) {
          _hotspots[index] = {
            ..._hotspots[index],
            ...payload.newRecord,
            'crime_type': _hotspots[index]['crime_type'] ?? {
              'id': payload.newRecord['type_id'],
              'name': 'Unknown',
              'level': 'unknown',
              'category': 'General',
              'description': null
            }
          };
        }
      });
    }
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
        if (existingPhoto != null && !deleteExistingPhoto && newSelectedPhoto == null) ...[
          const Text('Current Photo:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                    icon: const Icon(Icons.delete, color: Colors.white, size: 16),
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
          const Text('New Photo:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                            return const Center(child: Text('Error loading image'));
                          },
                        )
                      : Image.file(
                          File(newSelectedPhoto.path),
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
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
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
                              onDeleteExistingToggle(false); // Reset delete flag
                            }
                          } catch (e) {
                            onPhotoChanged(null, false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error taking photo: $e')),
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
                            final photo = await PhotoService.pickImageFromGallery();
                            onPhotoChanged(photo, false);
                            if (photo != null) {
                              onDeleteExistingToggle(false); // Reset delete flag
                            }
                          } catch (e) {
                            onPhotoChanged(null, false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error selecting photo: $e')),
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
  final isOwnHotspot = currentUserId != null && 
                   (currentUserId == createdBy || currentUserId == reportedBy);
  
  if (isOwnHotspot) {
    return true;
  }
  
  // Public hotspots (approved and active)
  return status == 'approved' && activeStatus == 'active';
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
    final query = Supabase.instance.client
        .from('hotspot')
        .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''');

    // Apply filters based on admin/officer status
    PostgrestFilterBuilder filteredQuery;
    if (!_hasAdminPermissions) {
      print('Filtering hotspots for non-admin/officer user');
      final currentUserId = _userProfile?['id'];
      
      if (currentUserId != null) {
        // For non-admins/officers, show:
        // 1. All approved active hotspots
        // 2. User's own reports (regardless of status and active_status)
        filteredQuery = query.or(
          'and(active_status.eq.active,status.eq.approved),'
          'created_by.eq.$currentUserId,'
          'reported_by.eq.$currentUserId'
        );
      } else {
        // If user ID is null, only show approved active hotspots
        filteredQuery = query
            .eq('active_status', 'active')
            .eq('status', 'approved');
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
            }
          };
        }).toList();
        
        print('Loaded ${_hotspots.length} hotspots');
        if (_hasAdminPermissions) {
          final inactiveCount = _hotspots.where((h) => h['active_status'] == 'inactive').length;
          print('Inactive hotspots count: $inactiveCount');
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

// Alternative safer approach - separate queries for different cases

void _moveToCurrentLocation() {
  if (_currentPosition != null && mounted) {
    // Check if MapController is ready before using it
    try {
      _mapController.move(_currentPosition!, 15.0);
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
            _mapController.move(_currentPosition!, 15.0);
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
      // REMOVE THIS LINE: _mapController.move(_currentPosition!, 15.0);
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

  _positionStream = Geolocator.getPositionStream(
    locationSettings: _locationSettings,
  ).listen(
    (Position position) {
      if (mounted) {
        final newPosition = LatLng(position.latitude, position.longitude);
        
        // Only update if the position has actually changed significantly
        if (_currentPosition == null || 
            _calculateDistance(_currentPosition!, newPosition) > 3) { // 3 meter threshold
          setState(() {
            _currentPosition = newPosition;
            _isLoading = false;
          });
          
          // Update route progress if we have an active route
          if (_hasActiveRoute && _destination != null) {
            _updateRouteProgress();
          }
        }
      }
    },
    onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Only show error if it's not a timeout - filter out timeout messages
        if (!error.toString().contains('TimeoutException') && 
            !error.toString().contains('Time limit reached')) {
          _showSnackBar('Location error: ${error.toString()}');
        }
      }
    },
  );
  
  // START proximity monitoring
  _startProximityMonitoring();
}

void _clearDirections() {
  _routeUpdateTimer?.cancel(); // Stop route updates
  setState(() {
    _routePoints.clear(); // Clear route points instead of polyline points
    _distance = 0;
    _duration = '';
    _destination = null;
    _showClearButton = false;
    _hasActiveRoute = false; // Clear active route flag
  });
}

void _startRouteUpdates() {
  _routeUpdateTimer?.cancel();
  _routeUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (_hasActiveRoute && _destination != null && _currentPosition != null) {
      _updateRouteProgress();
    } else {
      timer.cancel();
    }
  });
}

Future<void> _updateRouteProgress() async {
  if (_currentPosition == null || _destination == null || !_hasActiveRoute) return;
  
  try {
    // Calculate remaining distance and time to destination
    final response = await http.get(
      Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentPosition!.longitude},${_currentPosition!.latitude};'
        '${_destination!.longitude},${_destination!.latitude}?overview=false',
      ),
      headers: {'User-Agent': 'YourAppName/1.0'},
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final distance = _safeParseDouble(route['distance']) ?? 0.0;
        
        if (mounted) {
          setState(() {
          });
          
          // If we're very close to destination (less than 50 meters), consider arrived
          if (distance < 50) {
            _showSnackBar('You have arrived at your destination!');
            _clearDirections();
          }
        }
      }
    }
  } catch (e) {
    // Silently handle errors in background updates
    print('Error updating route progress: $e');
  }
}

Future<void> _getDirections(LatLng destination) async {
  if (_currentPosition == null) return;
  
  try {
    final response = await http.get(
      Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentPosition!.longitude},${_currentPosition!.latitude};'
        '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      ),
      headers: {
        'User-Agent': 'YourAppName/1.0',
      },
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Route request timed out', const Duration(seconds: 15)),
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
          _routePoints = routePoints; // Use _routePoints instead of _polylinePoints
          _destination = destination;
          _showClearButton = true;
          _hasActiveRoute = true; // Set active route flag
        });
        
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(_currentPosition!, destination),
            padding: const EdgeInsets.all(50.0),
          ),
        );
        
        // Start real-time route updates
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
                  
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with toggle
                          Row(
                            children: [
                              Text(
                                isShowingCrimes ? 'Filter Crimes' : 'Safe Spots',
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
                                          filterService.setFilterMode(true); // Show crimes
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isShowingCrimes ? Colors.red.shade600 : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warning_rounded,
                                              size: 16,
                                              color: isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Crimes',
                                              style: TextStyle(
                                                color: isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                                fontWeight: isShowingCrimes ? FontWeight.w600 : FontWeight.normal,
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
                                          filterService.setFilterMode(false); // Show safe spots
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !isShowingCrimes ? Colors.green.shade600 : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield_rounded,
                                              size: 16,
                                              color: !isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Safe Spots',
                                              style: TextStyle(
                                                color: !isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                                fontWeight: !isShowingCrimes ? FontWeight.w600 : FontWeight.normal,
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
                                if (_userProfile?['role'] == 'admin' || _userProfile?['role'] == 'officer' || _userProfile?['role'] == 'user') ...[
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
                              (value) => filterService.togglePoliceStations(),
                            ),
                            _buildFilterToggle(
                              context,
                              'Government Building',
                              Icons.account_balance,
                            const Color.fromARGB(255, 96, 139, 109),
                              filterService.showGovernmentBuildings,
                              (value) => filterService.toggleGovernmentBuildings(),
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
                              (value) => filterService.toggleShoppingMalls(),
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
                              (value) => filterService.toggleSecurityCameras(),
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
                              (value) => filterService.toggleReligiousBuildings(),
                            ),
                            _buildFilterToggle(
                              context,
                              'Community Center',
                              Icons.group,
                             const Color.fromARGB(255, 96, 139, 109),
                              filterService.showCommunityCenters,
                              (value) => filterService.toggleCommunityCenters(),
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
                                (value) => filterService.toggleSafeSpotsPending(),
                              ),
                              _buildFilterToggle(
                                context,
                                'Approved',
                                Icons.check_circle_outline,
                                Colors.green,
                                filterService.showSafeSpotsApproved,
                                (value) => filterService.toggleSafeSpotsApproved(),
                              ),
                              _buildFilterToggle(
                                context,
                                'Rejected',
                                Icons.cancel_outlined,
                                Colors.red,
                                filterService.showSafeSpotsRejected,
                                (value) => filterService.toggleSafeSpotsRejected(),
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
                                (value) => filterService.toggleVerifiedSafeSpots(),
                              ),
                              _buildFilterToggle(
                                context,
                                'Unverified',
                                Icons.help_outline,
                                Colors.grey.shade600,
                                filterService.showUnverifiedSafeSpots,
                                (value) => filterService.toggleUnverifiedSafeSpots(),
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
                                foregroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ],
    ),
  );
}

void _showLocationOptions(LatLng position) async {
  String locationName = "Loading location...";
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  try {
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      locationName = data['display_name'] ??
          "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
    }
  } catch (e) {
    locationName = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
  }

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (context) {
        return LocationOptionsDialogDesktop(
          locationName: locationName,
          isAdmin: _hasAdminPermissions, // Use combined permissions
          userProfile: _userProfile,
          distance: _distance,
          duration: _duration,
          onGetDirections: () => _getDirections(position),
          onGetSafeRoute: () => _getSafeRoute(position),
          onShareLocation: () => _shareLocation(position),
          onReportHotspot: () => _showReportHotspotForm(position),
          onAddHotspot: () => _showAddHotspotForm(position),
          onAddSafeSpot: () => _navigateToSafeSpotForm(position),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  _getDirections(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.safety_check, color: Colors.green),
                title: const Text('Get Safe Route'),
                subtitle: const Text('Avoids reported hotspots'),
                onTap: () {
                  Navigator.pop(context);
                  _getSafeRoute(position);
                },
              ),

              if (!_hasAdminPermissions && _userProfile != null)
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report Crime'),
                  subtitle: const Text('Submit for admin approval'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportHotspotForm(position);
                  },
                ),
              if (_hasAdminPermissions)
                ListTile(
                  leading: const Icon(Icons.add_location_alt),
                  title: const Text('Add Crime Incident'),
                  subtitle: const Text('Immediately published'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddHotspotForm(position);
                  },
                ),

              if (_userProfile != null) // Safe spot option for mobile
                ListTile(
                  leading: const Icon(Icons.safety_check, color: Colors.blue),
                  title: const Text('Add Safe Spot'),
                  subtitle: const Text('Mark this as a safe location'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSafeSpotForm(position);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Location'),
                onTap: () => _shareLocation(position),
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
  const safeDistance = 150.0; // Increased from 100m to 150m for better avoidance
  
  // Filter hotspots to only include active + approved ones
  final activeApprovedHotspots = _hotspots.where((hotspot) {
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    return status == 'approved' && activeStatus == 'active';
  }).toList();
  
  for (final point in route) {
    for (final hotspot in activeApprovedHotspots) {
      final coords = hotspot['location']['coordinates'];
      final hotspotLatLng = LatLng(coords[1], coords[0]);
      if (_calculateDistance(point, hotspotLatLng) < safeDistance) {
        unsafeSegments.add(point);
        break;
      }
    }
  }
  return unsafeSegments;
}

List<LatLng> _generateAlternativeWaypoints(List<LatLng> unsafePoints) {
  final waypoints = <LatLng>[];
  const offset = 0.003; // Reduced from 0.005 to create closer alternatives
  
  // Group nearby unsafe points
  final groupedPoints = _groupNearbyPoints(unsafePoints, 150.0); // Reduced from 200m
  
  for (final pointGroup in groupedPoints) {
    final centerLat = pointGroup.map((p) => p.latitude).reduce((a, b) => a + b) / pointGroup.length;
    final centerLng = pointGroup.map((p) => p.longitude).reduce((a, b) => a + b) / pointGroup.length;
    final center = LatLng(centerLat, centerLng);
    
    // Only add ONE strategic waypoint per unsafe area, not four
    // Choose the waypoint that's most likely to create a reasonable detour
    final strategicWaypoint = _findBestAvoidancePoint(center, offset);
    if (strategicWaypoint != null) {
      waypoints.add(strategicWaypoint);
    }
  }
  
  return waypoints;
}

LatLng? _findBestAvoidancePoint(LatLng center, double offset) {
  // Calculate direction from current position to destination
  if (_currentPosition == null || _destination == null) return null;
  
  final toDestinationLat = _destination!.latitude - _currentPosition!.latitude;
  final toDestinationLng = _destination!.longitude - _currentPosition!.longitude;
  
  // Create waypoint perpendicular to the main route direction
  final perpLat = -toDestinationLng * (offset / 2); // Perpendicular direction
  final perpLng = toDestinationLat * (offset / 2);
  
  // Try both sides and pick the one farther from hotspots
  final option1 = LatLng(center.latitude + perpLat, center.longitude + perpLng);
  final option2 = LatLng(center.latitude - perpLat, center.longitude - perpLng);
  
  // Check which option is safer
  final option1Distance = _getMinDistanceToHotspots(option1);
  final option2Distance = _getMinDistanceToHotspots(option2);
  
  return option1Distance > option2Distance ? option1 : option2;
}

// Helper to get minimum distance to any active hotspot
double _getMinDistanceToHotspots(LatLng point) {
  final activeApprovedHotspots = _hotspots.where((hotspot) {
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    return status == 'approved' && activeStatus == 'active';
  }).toList();
  
  double minDistance = double.infinity;
  for (final hotspot in activeApprovedHotspots) {
    final coords = hotspot['location']['coordinates'];
    final hotspotLatLng = LatLng(coords[1], coords[0]);
    final distance = _calculateDistance(point, hotspotLatLng);
    if (distance < minDistance) {
      minDistance = distance;
    }
  }
  return minDistance;
}

List<List<LatLng>> _groupNearbyPoints(List<LatLng> points, double distanceThreshold) {
  final groups = <List<LatLng>>[];
  final processedPoints = <bool>[];
  
  // Initialize all points as unprocessed
  for (int i = 0; i < points.length; i++) {
    processedPoints.add(false);
  }
  
  for (int i = 0; i < points.length; i++) {
    if (processedPoints[i]) continue;
    
    final group = <LatLng>[points[i]];
    processedPoints[i] = true;
    
    // Find all nearby points and add them to the same group
    for (int j = i + 1; j < points.length; j++) {
      if (!processedPoints[j] && 
          _calculateDistance(points[i], points[j]) < distanceThreshold) {
        group.add(points[j]);
        processedPoints[j] = true;
      }
    }
    
    groups.add(group);
  }
  
  return groups;
}

Future<List<LatLng>> _getRouteWithWaypoints(
  LatLng start, 
  LatLng end, 
  List<LatLng> waypoints
) async {
  final limitedWaypoints = waypoints.take(2).toList();
  
  if (limitedWaypoints.isEmpty) {
    return await _getRouteFromAPI(start, end);
  }
  
  final waypointsStr = limitedWaypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
  final isWeb = kIsWeb;
  
  String apiUrl;
  Uri requestUri;
  
  if (isWeb) {
    // Build the OSRM URL first
    apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
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
    apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '$waypointsStr;'
        '${end.longitude},${end.latitude}?overview=full&geometries=geojson&continue_straight=false&alternatives=false';
    
    requestUri = Uri.parse(apiUrl);
  }

  try {
    final response = await http.get(
      requestUri,
      headers: isWeb ? {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      } : {
        'User-Agent': 'Zecure/1.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

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
    throw Exception('Failed to get safe route with waypoints (${response.statusCode})');
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
  List<LatLng> waypoints
) async {
  final limitedWaypoints = waypoints.take(2).toList();
  final waypointsStr = limitedWaypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
  
  // Try corsproxy.io as fallback
  final apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '$waypointsStr;'
      '${end.longitude},${end.latitude}?overview=full&geometries=geojson&continue_straight=false&alternatives=false';
  
  final requestUri = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(apiUrl)}');
  
  final response = await http.get(
    requestUri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ).timeout(const Duration(seconds: 20));

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
  throw Exception('Failed to get safe route with waypoints (${response.statusCode})');
}

Future<List<LatLng>> _getRouteFromAPI(LatLng start, LatLng end) async {
  final isWeb = kIsWeb;
  
  String apiUrl;
  Uri requestUri;
  
  if (isWeb) {
    // Build the OSRM URL first
    apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    
    // Use CORS proxy with proper encoding
    requestUri = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(apiUrl)}');
  } else {
    // Direct API call for mobile
    apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    
    requestUri = Uri.parse(apiUrl);
  }

  try {
    final response = await http.get(
      requestUri,
      headers: isWeb ? {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      } : {
        'User-Agent': 'Zecure/1.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

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

Future<List<LatLng>> _getRouteFromAPIFallback(LatLng start, LatLng end) async {
  // Try corsproxy.io as fallback
  final apiUrl = 'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}?overview=full&geometries=geojson';
  
  final requestUri = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(apiUrl)}');
  
  final response = await http.get(
    requestUri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ).timeout(const Duration(seconds: 15));

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
  
  // Switch to map tab first
  setState(() {
    _currentTab = MainTab.map;
    _selectedHotspot = null; // Clear hotspot selection
  });
  
  // Move map to show both current position and destination
  _mapController.fitCamera(
    CameraFit.bounds(
      bounds: LatLngBounds(_currentPosition!, destination),
      padding: const EdgeInsets.all(50.0),
    ),
  );
  
  _showSnackBar('Calculating safest route...');

  try {
    // Get regular route first
    final regularRoute = await _getRouteFromAPI(_currentPosition!, destination);
    final unsafeSegments = _findUnsafeSegments(regularRoute);
    
    List<LatLng> finalRoute;
    
    if (unsafeSegments.isEmpty) {
      finalRoute = regularRoute;
      _showSnackBar('Route is already safe!');
    } else {
      // Try multiple strategies for finding safe route
      finalRoute = await _findBestSafeRoute(_currentPosition!, destination, unsafeSegments);
      
      // Verify the final route is actually safer
      final newUnsafeSegments = _findUnsafeSegments(finalRoute);
      if (newUnsafeSegments.isEmpty) {
        _showSnackBar('Safe route found! ');
      } else if (newUnsafeSegments.length < unsafeSegments.length) {
        _showSnackBar('Safer route found! ');
      } else {
        _showSnackBar('Could not find safer route - using regular route.');
        finalRoute = regularRoute; // Use original route if no improvement
      }
    }
    
    final distance = _calculateRouteDistance(finalRoute);
    final duration = _estimateRouteDuration(distance);
    
    setState(() {
      _routePoints = finalRoute;
      _distance = distance / 1000;
      _duration = _formatDuration(duration);
      _destination = destination;
      _showClearButton = true;
      _hasActiveRoute = true;
    });
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(_currentPosition!, destination),
        padding: const EdgeInsets.all(50.0),
      ),
    );
    
    _startRouteUpdates();
  } catch (e) {
    print('Safe route error: $e'); // Debug logging
    _showSnackBar('Error calculating safe route: ${e.toString()}');
    // Fallback to regular directions if safe route fails
    try {
      _getDirections(destination);
    } catch (fallbackError) {
      _showSnackBar('Unable to get any route. Please try again.');
    }
  }
}

Future<List<LatLng>> _findBestSafeRoute(LatLng start, LatLng destination, List<LatLng> unsafeSegments) async {
  // Strategy 1: Try minimal waypoints first
  try {
    final minimalWaypoints = _generateAlternativeWaypoints(unsafeSegments);
    if (minimalWaypoints.length <= 2) { // Only use if we have few waypoints
      final route = await _getRouteWithWaypoints(start, destination, minimalWaypoints);
      final stillUnsafeSegments = _findUnsafeSegments(route);
      if (stillUnsafeSegments.isEmpty || stillUnsafeSegments.length < unsafeSegments.length * 0.5) {
        return route;
      }
    }
  } catch (e) {
    print('Minimal waypoints strategy failed: $e');
  }
  
  // Strategy 2: Direct intermediate points
  try {
    final intermediatePoints = await _findSafeIntermediatePoints(start, destination);
    if (intermediatePoints.length <= 1) { // Prefer single intermediate point
      final route = await _getRouteWithWaypoints(start, destination, intermediatePoints);
      final stillUnsafeSegments = _findUnsafeSegments(route);
      if (stillUnsafeSegments.length < unsafeSegments.length) {
        return route;
      }
    }
  } catch (e) {
    print('Intermediate points strategy failed: $e');
  }
  
  // Strategy 3: If all else fails, use regular route with warning
  return await _getRouteFromAPI(start, destination);
}

Future<List<LatLng>> _findSafeIntermediatePoints(LatLng start, LatLng destination) async {
  final intermediatePoints = <LatLng>[];
  
  // Get active approved hotspots
  final activeApprovedHotspots = _hotspots.where((hotspot) {
    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    return status == 'approved' && activeStatus == 'active';
  }).toList();
  
  // Create a grid of potential waypoints between start and destination
  final latDiff = destination.latitude - start.latitude;
  final lngDiff = destination.longitude - start.longitude;
  
  // Create waypoints at 1/3 and 2/3 of the way
  for (double fraction in [0.33, 0.67]) {
    final baseLat = start.latitude + (latDiff * fraction);
    final baseLng = start.longitude + (lngDiff * fraction);
    
    // Try points in different directions from the base point
    final offsets = [
      [0.01, 0.01],   // Northeast
      [0.01, -0.01],  // Northwest  
      [-0.01, 0.01],  // Southeast
      [-0.01, -0.01], // Southwest
    ];
    
    for (final offset in offsets) {
      final candidatePoint = LatLng(baseLat + offset[0], baseLng + offset[1]);
      
      // Check if this point is far enough from all hotspots
      bool isSafe = true;
      for (final hotspot in activeApprovedHotspots) {
        final coords = hotspot['location']['coordinates'];
        final hotspotLatLng = LatLng(coords[1], coords[0]);
        if (_calculateDistance(candidatePoint, hotspotLatLng) < 300.0) { // 300m buffer
          isSafe = false;
          break;
        }
      }
      
      if (isSafe) {
        intermediatePoints.add(candidatePoint);
        break; // Found a safe point for this fraction, move to next
      }
    }
  }
  
  return intermediatePoints;
}

// Helper to calculate total distance of a route in meters
double _calculateRouteDistance(List<LatLng> route) {
  double totalDistance = 0;
  for (int i = 1; i < route.length; i++) {
    totalDistance += _calculateDistance(route[i-1], route[i]);
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
        averageSpeedKmh = 38.0; // 40 km/h average driving speed (considering traffic, stops, etc.)
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

 
// TRAVEL TIME DURATION
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
                        margin: const EdgeInsets.only(right: 6), // Reduced from 8
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4), // Reduced from 6
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTravelModeIcon(mode),
                              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                              size: 16, // Reduced from 18
                            ),
                            const SizedBox(height: 1), // Reduced from 2
                            Text(
                              _getTravelModeLabel(mode),
                              style: TextStyle(
                                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        
        // Duration display widget - further minimized
        GestureDetector(
          onTap: () {
            setState(() {
              _showTravelModeSelector = !_showTravelModeSelector;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
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
                  _showTravelModeSelector ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 12, // Reduced from 14
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}


//ADD HOTSPOT FOR ADMIN
  void _showAddHotspotForm(LatLng position) async {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

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
      
      // Photo state for this form
      XFile? selectedPhoto;
      bool isUploadingPhoto = false;

      final now = DateTime.now();
      dateController.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      timeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      void onSubmit() async {
        if (formKey.currentState!.validate()) {
          try {
            final dateTime = DateTime(
              int.parse(dateController.text.split('-')[0]),
              int.parse(dateController.text.split('-')[1]),
              int.parse(dateController.text.split('-')[2]),
              int.parse(timeController.text.split(':')[0]),
              int.parse(timeController.text.split(':')[1]),
            );

            // Save hotspot first
            final hotspotId = await _saveHotspot(
              selectedCrimeId.toString(),
              descriptionController.text,
              position,
              dateTime,
            );

            // Upload photo if selected
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
                  _showSnackBar('Crime saved but photo upload failed: ${e.toString()}');
                }
              }
            }

            await _loadHotspots();

            if (mounted) {
              Navigator.pop(context);
              _showSnackBar('Crime reported successfully');
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
        // Desktop dialog - you'll need to update your AddHotspotFormDesktop to include photo
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
                              final selected = crimeTypes.firstWhere((c) => c['name'] == value);
                              selectedCrimeType = value;
                              selectedCrimeId = selected['id'];
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
                        
                        // Photo section
                        _buildPhotoSection(selectedPhoto, isUploadingPhoto, (photo, uploading) {
                          setState(() {
                            selectedPhoto = photo;
                            isUploadingPhoto = uploading;
                          });
                        }),
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
                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: now,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                  );
                                  if (pickedDate != null) {
                                    dateController.text =
                                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                  }
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
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    timeController.text =
                                        "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    actions: [
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ElevatedButton(
        onPressed: isUploadingPhoto ? null : onSubmit,
        child: isUploadingPhoto 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
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


        // MOBILE 
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: Form(
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
                          onChanged: (newValue) {
                            if (newValue != null) {
                              final selected = crimeTypes.firstWhere((crime) => crime['name'] == newValue);
                              selectedCrimeType = newValue;
                              selectedCrimeId = selected['id'];
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
                        
                        // Photo section
                        _buildPhotoSection(selectedPhoto, isUploadingPhoto, (photo, uploading) {
                          setState(() {
                            selectedPhoto = photo;
                            isUploadingPhoto = uploading;
                          });
                        }),
                        const SizedBox(height: 16),
                        
                        TextFormField(
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
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              dateController.text =
                                  "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
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
                          onTap: () async {
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              timeController.text =
                                  "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isUploadingPhoto ? null : onSubmit,
                            child: isUploadingPhoto
                                ? const CircularProgressIndicator()
                                : const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
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

   Widget _buildPhotoSection(XFile? selectedPhoto, bool isUploading, Function(XFile?, bool) onPhotoChanged) {
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
                              return const Center(child: Text('Error loading image'));
                            },
                          )
                        : Image.file(
                            File(selectedPhoto.path),
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
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
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
                                SnackBar(content: Text('Error taking photo: $e')),
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
                              final photo = await PhotoService.pickImageFromGallery();
                              onPhotoChanged(photo, false);
                            } catch (e) {
                              onPhotoChanged(null, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error selecting photo: $e')),
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




// REPORT HOTSPOT FOR REGULAR USERS

void _showReportHotspotForm(LatLng position) async {
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

    if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
      // Desktop dialog view
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ReportHotspotFormDesktop(
            position: position,
            crimeTypes: crimeTypes,
            onSubmit: _reportHotspot,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else {
      // Mobile bottom sheet view
      if (!mounted) return;
      await _showMobileReportForm(position, crimeTypes, now);
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
) async {
  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(now),
  );
  final timeController = TextEditingController(
    text: DateFormat('HH:mm').format(now),
  );

  String selectedCrimeType = crimeTypes[0]['name'];
  int selectedCrimeId = crimeTypes[0]['id'];
  bool isSubmitting = false;
  
  // Photo state
  XFile? selectedPhoto;
  bool isUploadingPhoto = false;

  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Form(
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
                              final selected = crimeTypes.firstWhere((c) => c['name'] == newValue);
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
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  
                  // Photo section
                  _buildPhotoSection(selectedPhoto, isUploadingPhoto, (photo, uploading) {
                    setState(() {
                      selectedPhoto = photo;
                      isUploadingPhoto = uploading;
                    });
                  }),
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
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              dateController.text =
                                  DateFormat('yyyy-MM-dd').format(pickedDate);
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
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              timeController.text =
                                  '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isSubmitting || isUploadingPhoto)
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                setState(() => isSubmitting = true);
                                try {
                                  final dateTime = DateTime.parse(
                                      '${dateController.text} ${timeController.text}');
                                  
                                  await _reportHotspot(
                                    selectedCrimeId,
                                    descriptionController.text,
                                    position,
                                    dateTime,
                                    selectedPhoto, // Pass the photo
                                  );

                                  if (mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => isSubmitting = false);
                                    _showSnackBar(
                                        'Failed to report hotspot: ${e.toString()}');
                                  }
                                }
                              }
                            },
                      child: (isSubmitting || isUploadingPhoto)
                          ? const CircularProgressIndicator()
                          : const Text('Submit Report'),
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

  if (result == true && mounted) {
    _showSnackBar('Crime reported successfully. Waiting for admin approval.');
  }
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
    final descriptionController = TextEditingController(text: hotspot['description'] ?? '');
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.parse(hotspot['time']).toLocal()),
    );
    final timeController = TextEditingController(
      text: DateFormat('HH:mm').format(DateTime.parse(hotspot['time']).toLocal()),
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

    // Desktop/Web view
    if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
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
                            final selected = crimeTypes.firstWhere((c) => c['name'] == value);
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
  final reportedDate = DateTime.parse(hotspot['created_at']).toLocal();
  final maxDate = DateTime(reportedDate.year, reportedDate.month, reportedDate.day);
  
  DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.parse(hotspot['time']).toLocal(),
    firstDate: DateTime(2000),
    lastDate: maxDate, // Restrict to reported date
  );
  if (pickedDate != null) {
    dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
  }
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
    initialTime: TimeOfDay.fromDateTime(DateTime.parse(hotspot['time']).toLocal()),
  );
  if (pickedTime != null) {
    final selectedDate = DateTime.parse(dateController.text);
    final reportedDateTime = DateTime.parse(hotspot['created_at']).toLocal();
    final pickedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    
    // Check if the picked time is after the reported time on the same date
    if (selectedDate.year == reportedDateTime.year &&
        selectedDate.month == reportedDateTime.month &&
        selectedDate.day == reportedDateTime.day &&
        pickedDateTime.isAfter(reportedDateTime)) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Incident time cannot be later than when it was reported (${DateFormat('h:mm a').format(reportedDateTime)})'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    timeController.text = DateFormat('h:mm a').format(pickedDateTime);
  }
},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Active status for admins
                      if (_hasAdminPermissions)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Active Status:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              Row(
                                children: [
                                  Switch(
                                    value: isActiveStatus,
                                    onChanged: (value) {
                                      setState(() {
                                        isActiveStatus = value;
                                        selectedActiveStatus = value ? 'active' : 'inactive';
                                      });
                                    },
                                    activeColor: Colors.green,
                                    inactiveThumbColor: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isActiveStatus ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActiveStatus ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.bold,
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
            actions: [
              ElevatedButton(
                onPressed: isUploadingPhoto
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            final dateTime = DateTime.parse('${dateController.text} ${timeController.text}');
                            
                            // Update hotspot first
                            await _updateHotspot(
                              hotspot['id'],
                              selectedCrimeId,
                              descriptionController.text,
                              dateTime,
                              selectedActiveStatus,
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
                                SnackBar(content: Text('Failed to update crime report: $e')),
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


//MOBILE VIEW
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
        top: 25.0, // Increased top padding for better crime type visibility
      ),
      child: StatefulBuilder(
        builder: (context, setState) {
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
                        final selected = crimeTypes.firstWhere((crime) => crime['name'] == newValue);
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
                  
                  // Date and time fields - Side by side
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
                              initialDate: DateTime.parse(hotspot['time']),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                            }
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
                              initialTime: TimeOfDay.fromDateTime(DateTime.parse(hotspot['time'])),
                            );
                            if (pickedTime != null) {
                              final now = DateTime.now();
                              final formatted = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
                              timeController.text = DateFormat('HH:mm').format(formatted);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.blue.shade50,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: Colors.blue.shade200),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Incident time cannot be later than when it was reported (${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(hotspot['created_at']).toLocal())})',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    ],
  ),
),
                  const SizedBox(height: 16),
                  
                  // Add active status toggle for admins only - Compact Design
                  if (_hasAdminPermissions)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActiveStatus ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActiveStatus ? Colors.green.shade200 : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isActiveStatus ? Icons.check_circle : Icons.cancel,
                                color: isActiveStatus ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Status: ${isActiveStatus ? 'Active' : 'Inactive'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isActiveStatus ? Colors.green.shade700 : Colors.grey.shade700,
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
                                  selectedActiveStatus = value ? 'active' : 'inactive';
                                });
                              },
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.grey,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  
                  // Update and Cancel buttons - Update on left, Cancel on right
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
onPressed: isUploadingPhoto
    ? null
    : () async {
        if (formKey.currentState!.validate()) {
          try {
            final dateTime = DateTime.parse('${dateController.text} ${timeController.text}');
            final reportedDateTime = DateTime.parse(hotspot['created_at']).toLocal();
            
            // Validate incident time is not after reported time
            if (dateTime.isAfter(reportedDateTime)) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[600]),
                        const SizedBox(width: 8),
                        const Text('Invalid Time'),
                      ],
                    ),
                  content: Text(
                    'The incident time cannot be later than when it was reported.\n\n'
                    'Reported: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(reportedDateTime)}\n'
                    'Selected: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(dateTime)}\n\n'
                    'Please select an earlier time.',
                  ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
              return;
            }
            
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
            
            // Continue with update...
            await _updateHotspot(
              hotspot['id'],
              selectedCrimeId,
              descriptionController.text,
              dateTime,
              selectedActiveStatus,
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
              // Close loading dialog
              Navigator.of(context).pop();
              // Close edit dialog
              Navigator.pop(context);
              _showSnackBar('Crime report updated successfully');
            }
            
          } catch (e) {
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
                        Icon(Icons.error, color: Colors.red[600]),
                        const SizedBox(width: 8),
                        const Text('Update Failed'),
                      ],
                    ),
                    content: Text(
                      'Failed to update crime report:\n\n${e.toString()}'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isUploadingPhoto
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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

// REPORT HOTSPOT
Future<void> _reportHotspot(
    int typeId,
    String description,
    LatLng position,
    DateTime dateTime,
    [XFile? photo]
  ) async {
    try {
      final insertData = {
        'type_id': typeId,
        'description': description.trim().isNotEmpty ? description.trim() : null,
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'time': dateTime.toIso8601String(),
        'status': 'pending',
        'created_by': _userProfile?['id'],
        'reported_by': _userProfile?['id'],
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('hotspot')
          .insert(insertData)
          .select('id')
          .single();

      print('Hotspot inserted successfully: ${response['id']}');
      final hotspotId = response['id'] as int;

      // Upload photo if provided
      if (photo != null) {
        try {
          await PhotoService.uploadPhoto(
            imageFile: photo,
            hotspotId: hotspotId,
            userId: _userProfile!['id'],
          );
          print('Photo uploaded successfully for hotspot $hotspotId');
        } catch (e) {
          print('Photo upload failed: $e');
          _showSnackBar('Report saved but photo upload failed: ${e.toString()}');
        }
      }

      // Create admin notifications (existing code)
      if (response['status'] == 'pending') {
        try {
          final admins = await Supabase.instance.client
              .from('users')
              .select('id')
              .eq('role', 'admin');

          if (admins.isNotEmpty) {
            final notifications = admins.map((admin) => {
              'user_id': admin['id'],
              'title': 'New Crime Report',
              'message': 'New crime report awaiting review',
              'type': 'report',
              'hotspot_id': hotspotId,
              'created_at': DateTime.now().toIso8601String(),
              'unique_key': 'report_${hotspotId}_${admin['id']}',
            }).toList();

            await Supabase.instance.client
                .from('notifications')
                .upsert(notifications, onConflict: 'unique_key');
          }
        } catch (notificationError) {
          print('Error creating notifications: $notificationError');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to report hotspot: ${e.toString()}');
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
Future<int?> _saveHotspot(String typeId, String description, LatLng position, DateTime dateTime) async {
  try {
    final insertData = {
      'type_id': int.parse(typeId),
      'description': description.trim().isNotEmpty ? description.trim() : null,
      'location': 'POINT(${position.longitude} ${position.latitude})',
      'time': dateTime.toIso8601String(),
      'created_by': _userProfile?['id'],
      'status': 'approved',
      'active_status': 'active',
    };

    // Insert the hotspot - let real-time handle the rest
    final response = await Supabase.instance.client
        .from('hotspot')
        .insert(insertData)
        .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
        .single();

    print('Crime report added successfully: ${response['id']}');

    // Optional fallback only for UI updates
    await Future.delayed(const Duration(milliseconds: 500));
    
    final hotspotExists = _hotspots.any((h) => h['id'] == response['id']);
    
    if (!hotspotExists) {
      print('Real-time failed, manually adding admin hotspot to UI');
      
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
            }
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


// HOTSPOT DELETE
void _handleHotspotDelete(PostgresChangePayload payload) {
  if (!mounted) return;
  
  final deletedHotspotId = payload.oldRecord['id'];
  
  setState(() {
    // Remove the hotspot from local state
    _hotspots.removeWhere((hotspot) => hotspot['id'] == deletedHotspotId);
    
    // Remove any notifications related to this hotspot
    _notifications.removeWhere((notification) => 
      notification['hotspot_id'] == deletedHotspotId);
    
    // Update unread notifications count
    _unreadNotificationCount = _notifications.where((n) => !n['is_read']).length;
  });
  
  // Show a snackbar if the deleted hotspot was selected
  if (_selectedHotspot != null && _selectedHotspot!['id'] == deletedHotspotId) {
    _showSnackBar('Crime report deleted');
    _selectedHotspot = null;
  }
}


//SHARE LOCATION
  Future<void> _shareLocation(LatLng position) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final geoUrl = 'geo:${position.latitude},${position.longitude}?q=${position.latitude},${position.longitude}';

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
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) {
      _logout();
    }
  }

void _showProfileDialog() {
  final isDesktopOrWeb = Theme.of(context).platform == TargetPlatform.macOS ||
                       Theme.of(context).platform == TargetPlatform.linux ||
                       Theme.of(context).platform == TargetPlatform.windows ||
                       kIsWeb;

  // Only use dialog for desktop/web - mobile now uses the full screen approach
  if (!isDesktopOrWeb) {
    return; // Mobile will handle profile through _buildProfileScreen()
  }

  void toggleEditMode() {
    setState(() {
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
  _isAdmin,           // Admin-only privileges
  _hasAdminPermissions // Admin + Officer privileges
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

  // Desktop/Web dialog view only
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: _profileScreen.isEditingProfile
            ? _profileScreen.buildEditProfileForm(
                context,
                isDesktopOrWeb,
                toggleEditMode,
                onSuccess: handleSuccess,
              )
            : _profileScreen.buildProfileView(context, isDesktopOrWeb, toggleEditMode),
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
      } else if (item['safe_spot_types'] != null) {
        // It's a safe spot
        _selectedSafeSpot = item;
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
  // REMOVED: No more loading screen - map renders immediately
  // The map will show immediately even without location/data
  
  // Check if it's web or a large desktop screen
  final bool isDesktop = MediaQuery.of(context).size.width >= 800;

  return WillPopScope(
    onWillPop: _handleWillPop,
    child: Scaffold(
      // Use desktop or mobile layout depending on screen size
      body: isDesktop ? _buildResponsiveDesktopLayout() : _buildCurrentScreen(isDesktop),
      
      // Show FAB only if map tab is active
      floatingActionButton: _currentTab == MainTab.map 
          ? _buildFloatingActionButtons() 
          : null,

      // Bottom navigation bar - show on mobile OR when desktop sidebar is hidden and user is logged in
      bottomNavigationBar: _buildResponsiveBottomNav(isDesktop),
    ),
  );
}


//  SIDEBAR FOR DESKTOP
Widget _buildResponsiveDesktopLayout() {
  return Stack(
    children: [
      Row(
        children: [
          ResponsiveNavigation(
            currentIndex: _currentTab.index,
            onTap: (index) {
              setState(() {
                _currentTab = MainTab.values[index];
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
          Expanded(
            child: _buildCurrentScreen(true),
          ),
        ],
      ),
      // Modified backdrop overlay - excludes sidebar area
      if (_currentTab == MainTab.notifications || _currentTab == MainTab.quickAccess)
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
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
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
    ],
  );
}


// BOTTOM NAV BARS MAIN WIDGETS
Widget _buildBottomNavBar() {
  return Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: ClipRRect(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab.index,
          onTap: (index) {
            setState(() {
              _currentTab = MainTab.values[index];
              if (_currentTab == MainTab.profile) {
                _profileScreen.isEditingProfile = false;
              }
            });
          },
          items: [
            // Map Tab
            BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentTab == MainTab.map
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentTab == MainTab.map ? Icons.map_rounded : Icons.map_outlined,
                  size: 24,
                ),
              ),
              label: 'Map',
            ),
            
// Direction Tab (UPDATED)
BottomNavigationBarItem(
  icon: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: _currentTab == MainTab.quickAccess
          ? Colors.blue.withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
child: Icon(
  _currentTab == MainTab.quickAccess
      ? Icons.navigation // Active state
      : Icons.navigation_outlined, // Inactive state
  size: 24,
),
  ),
  label: 'Navigation',
),

            
            // Notifications Tab
            BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentTab == MainTab.notifications
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none, // Allow badge to overflow
                  children: [
                    Icon(
                      _currentTab == MainTab.notifications
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      size: 24,
                    ),
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
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
              ),
              label: 'Notifications',
            ),
            
            // Profile Tab
            BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentTab == MainTab.profile
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _currentTab == MainTab.profile ? Icons.person_rounded : Icons.person_outline_rounded,
                  size: 24,
                ),
              ),
              label: 'Profile',
            ),
          ],
          selectedItemColor: Colors.blue.shade600,
          unselectedItemColor: Colors.grey.shade600,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
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



// FOR BACK BUTTON CONFIRMATION TO EXIT
Future<bool> _handleWillPop() async {
  // Check if we're on profile tab and in edit mode
  if (_currentTab == MainTab.profile && _profileScreen.isEditingProfile == true) {
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
  
  // If this is the root route, show exit confirmation
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Exit App?'),
      content: const Text('Do you want to exit the application?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Exit App', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;
  
  return shouldExit;
}

//FLOATING ACTION BUTTONS

Widget _buildFloatingActionButtons() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Map Type Selection Container - MINIMIZED
      if (_showMapTypeSelector) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 7), // Reduced from 8
          padding: const EdgeInsets.all(7), // Reduced from 8
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10), // Reduced from 12
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // Reduced opacity
                blurRadius: 4, // Reduced from 8
                offset: const Offset(0, 1), // Reduced from (0, 2)
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: MapType.values.map((type) {
              final isSelected = type == _currentMapType;
              return GestureDetector(
              onTap: () {
                _switchMapType(type);  // Use your new method
              },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 1), // Reduced from 2
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(7), // Reduced from 8
                    border: isSelected 
                      ? Border.all(color: Colors.blue.shade300, width: 1)
                      : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMapTypeIcon(type),
                        size: 17, // Reduced from 18
                        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7), // Reduced from 8
                      Text(
                        _getMapTypeName(type),
                        style: TextStyle(
                          fontSize: 11, // Reduced from 12
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
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
      
      // Map Type Toggle Button
      Tooltip(
        message: 'Select Map Type',
        child: FloatingActionButton(
          heroTag: 'mapType',
          onPressed: () {
            setState(() {
              _showMapTypeSelector = !_showMapTypeSelector;
            });
          },
          backgroundColor: _showMapTypeSelector ? Colors.blue.shade600 : Colors.white,
          foregroundColor: _showMapTypeSelector ? Colors.white : Colors.grey.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          mini: true,
          child: Icon(_getMapTypeIcon(_currentMapType)),
        ),
      ),
      const SizedBox(height: 4),
      
      // Compass button with modern slide feedback
      Stack(
        clipBehavior: Clip.none,
        children: [
          // Sliding feedback widget
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            right: _showRotationFeedback ? 48 : 20, // Slide from right to left
            top: 8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showRotationFeedback ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isRotationLocked 
                    ? Colors.orange.shade600.withOpacity(0.95)
                    : Colors.green.shade600.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(-1, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRotationLocked ? Icons.lock : Icons.lock_open,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isRotationLocked ? 'Rotate Locked' : 'Rotate Unlocked',
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
          
          // Compass button
          Tooltip(
            message: _isRotationLocked ? 'Unlock Rotation (Double-tap)' : 'Reset Rotation (Double-tap to lock)',
            child: FloatingActionButton(
              heroTag: 'compass',
              onPressed: () {
                // Single tap resets rotation (only when not locked)
                if (!_isRotationLocked) {
                  _mapController.rotate(0);
                  setState(() {
                    _currentMapRotation = 0.0;
                  });
                }
                // Close map type selector when other buttons are pressed
                if (_showMapTypeSelector) {
                  setState(() {
                    _showMapTypeSelector = false;
                  });
                }
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              mini: true,
              child: GestureDetector(
                onDoubleTap: () {
                  // Double tap toggles rotation lock
                  setState(() {
                    _isRotationLocked = !_isRotationLocked;
                    _showRotationFeedback = true;
                  });
                  
                  // Hide feedback after delay
                  Timer(const Duration(milliseconds: 1500), () {
                    if (mounted) {
                      setState(() {
                        _showRotationFeedback = false;
                      });
                    }
                  });
                },
                child: _buildCompass(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      
      // Filter Crimes button (always visible)
      Tooltip(
        message: 'Filter Hotspots',
        child: FloatingActionButton(
          heroTag: 'filterHotspots',
          onPressed: () {
            _showHotspotFilterDialog();
            // Close map type selector when other buttons are pressed
            if (_showMapTypeSelector) {
              setState(() {
                _showMapTypeSelector = false;
              });
            }
          },
          backgroundColor: const Color.fromARGB(255, 107, 109, 109),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          mini: true,
          child: const Icon(Icons.filter_alt),
        ),
      ),
      const SizedBox(height: 4),
      
      // Clear Directions button (only visible when there's a route)
      if (_showClearButton)
        Tooltip(
          message: 'Clear Route',
          child: FloatingActionButton(
            heroTag: 'clearRoute',
            onPressed: () {
              _clearDirections();
              // Close map type selector when other buttons are pressed
              if (_showMapTypeSelector) {
                setState(() {
                  _showMapTypeSelector = false;
                });
              }
            },
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            mini: true,
            child: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ),
      const SizedBox(height: 4),
      
      // My Location button (always visible) - Google Maps style
Tooltip(
  message: 'My Location',
  child: FloatingActionButton(
    heroTag: 'myLocation',
    onPressed: () async {
      setState(() {
        // Close map type selector when other buttons are pressed
        if (_showMapTypeSelector) {
          _showMapTypeSelector = false;
        }
      });
      
      // Use the new safe location method
      _moveToCurrentLocation();
      
      // Optionally refresh location if it's stale
      if (_currentPosition == null) {
        await _getCurrentLocation();
        // Try moving again after getting fresh location
        _moveToCurrentLocation();
      }
    },
    // ... rest of your FAB properties
          backgroundColor: Colors.white,
          foregroundColor: _locationButtonPressed ? Colors.blue.shade600 : Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Icon(
            _locationButtonPressed ? Icons.my_location : Icons.location_searching,
            color: _locationButtonPressed ? Colors.blue.shade600 : Colors.grey.shade600,
          ),
        ),
      ),
    ],
  );
}

// Helper method to get readable names for map types
String _getMapTypeName(MapType type) {
  switch (type) {
    case MapType.standard:
      return 'Standard';
    case MapType.satellite:
      return 'Satellite';
    case MapType.terrain:
      return 'Terrain';
    case MapType.topographic:
      return 'Topographic';
    case MapType.dark:
      return 'Dark Mode';
  }
}



//COMPASS COMPASS

Widget _buildCompass() {
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      // Add a visual indicator when rotation is locked
      border: _isRotationLocked 
        ? Border.all(color: Colors.red, width: 2)
        : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Rotating compass elements (only when not locked)
        Transform.rotate(
          angle: _isRotationLocked ? 0 : -_currentMapRotation * (3.14159 / 180),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass background
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
              ),
              // North arrow - change color when locked
              Icon(
                Icons.navigation,
                color: _isRotationLocked ? Colors.red.shade700 : Colors.red,
                size: 20,
              ),
              // Small 'N' indicator
              Positioned(
                top: 0,
                child: Text(
                  'N',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: _isRotationLocked ? Colors.red.shade700 : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Lock indicator when rotation is locked (stays fixed)
       if (_isRotationLocked)
          Positioned(
            bottom: 2,
            child: Icon(
              Icons.lock,
              color: Colors.red.shade700,
              size: 10,
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
          icon: Icon(
            Icons.filter_list,
            color: Colors.grey[700],
          ),
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
            const PopupMenuItem(value: 'Safe Spots', child: Text('Safe Spots')),      
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
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              itemCount: _getFilteredNotifications().length,
              itemBuilder: (context, index) {
                final notification = _getFilteredNotifications()[index];
                final isUnread = !notification['is_read'];
                final createdAt = DateTime.parse(notification['created_at']).toLocal();
                final isToday = _isToday(createdAt);
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isUnread ? Colors.blue[50] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUnread ? Colors.blue[200]! : Colors.grey[200]!,
                      width: 1,
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
                        if (!notification['is_read']) {
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
                            // Icon with status indicator
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
                                  // Title with priority badge
                                  Row(
                                    children: [
                                      Expanded(
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
                                      _buildPriorityBadge(notification),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 6),
                                  
                                  // Message
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
                                  
                                  // Timestamp
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
                                            : DateFormat('MMM dd, h:mm a').format(createdAt),
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
              },
            ),
          ),
  );
}

//NOTIFICATION DESKTOP VIEW

Widget _buildFloatingNotificationPanel() {
  if (_currentTab != MainTab.notifications) return const SizedBox.shrink();
  
  return Positioned(
    left: _isSidebarVisible ? 285 : 85, // Adjust based on sidebar width
    top: 100,   // Adjust based on your layout
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
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(value: 'Unread', child: Text('Unread')),
                            DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(value: 'Safe Spots', child: Text('Safe Spots')),
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
  return RefreshIndicator(
    onRefresh: _loadNotifications,
    child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _getFilteredNotifications().length,
      itemBuilder: (context, index) {
        final notification = _getFilteredNotifications()[index];
        final isUnread = !notification['is_read'];
        final createdAt = DateTime.parse(notification['created_at']).toLocal();
        final isToday = _isToday(createdAt);
        
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
                          // Title with priority badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['title'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              _buildPriorityBadge(notification),
                            ],
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Message
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
                          
                          // Timestamp
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
                                    : DateFormat('MMM dd, h:mm a').format(createdAt),
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
      },
    ),
  );
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    ),
  );
}

Color _getIconBackgroundColor(Map<String, dynamic> notification) {
  final type = notification['type'];
  
  // Handle safe spot notifications
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
  
  // Handle safe spot notifications
  if (type == 'safe_spot_report') {
    return const Icon(Icons.add_location_alt, color: Colors.blue, size: 18);
  } else if (type == 'safe_spot_approval') {
    return const Icon(Icons.check_circle, color: Colors.green, size: 18);
  } else if (type == 'safe_spot_rejection') {
    return const Icon(Icons.cancel, color: Colors.red, size: 18);
  }
  
  // For report notifications, get the crime level from the related hotspot
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
  
  // Default icons for other notification types
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
        _mapController.move(safeSpotPosition, 15.0);
        
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
        _mapController.move(hotspotPosition, 15.0);
        
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
    _mapController.move(
      _mapController.camera.center, 
      targetZoom
    );
    
    // Show appropriate feedback message

  }
}
  

// Helper method to get max zoom for each map type
int _getMaxZoomForMapType(MapType type) {
  switch (type) {
    case MapType.standard:
      return 19;
    case MapType.terrain:
      return 17; // OpenTopoMap has limited zoom
    case MapType.satellite:
      return 18; // Esri imagery
    case MapType.topographic:
      return 17; // Esri topo
    case MapType.dark:
      return 18; // CartoDB
  }
}

// Helper method to get icon for each map type
IconData _getMapTypeIcon(MapType type) {
  switch (type) {
    case MapType.standard:
      return Icons.map;
    case MapType.satellite:
      return Icons.satellite_alt;
    case MapType.terrain:
      return Icons.terrain;
    case MapType.topographic:
      return Icons.landscape;
    case MapType.dark:
      return Icons.dark_mode;
  }
}




// NEW: Lightweight marker builder for distant zoom levels
Widget _buildSimpleHotspotMarker({
  required Map<String, dynamic> hotspot,
  required Color markerColor,
  required IconData markerIcon,
  required double opacity,
}) {
  return GestureDetector(
    onTap: () {
      setState(() {
        _selectedHotspot = hotspot;
        _selectedSafeSpot = null;
      });
      _showHotspotDetails(hotspot);
    },
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: markerColor.withOpacity(opacity),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(markerIcon, color: Colors.white, size: 12),
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
              initialCenter: _currentPosition ?? const LatLng(14.5995, 120.9842),
              initialZoom: 15.0,
              maxZoom: _getMaxZoomForMapType(_currentMapType).toDouble(),
              minZoom: 3.0,
              // Platform-specific tap behavior
              onTap: (tapPosition, latLng) {
                // FIRST: Check if notification panel is open and close it
                if (_currentTab == MainTab.notifications) {
                  setState(() {
                    _currentTab = MainTab.map; // Close notification panel
                  });
                  return; // Don't process other tap behaviors when closing notifications
                }
                
                // THEN: Continue with existing tap behavior
                FocusScope.of(context).unfocus();
                
                // Clear selections when tapping on empty map
                setState(() {
                  _selectedHotspot = null;
                  _selectedSafeSpot = null; // Clear safe spot selection too
                });
                
                // Desktop/Web: Set destination on single tap
                if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
                  setState(() {
                    _destination = latLng;
                  });
                  _showLocationOptions(latLng);
                }
                // Mobile: Only unfocus (destination set on long press)
              },
              // Long press for mobile devices
              onLongPress: (tapPosition, latLng) {
                // FIRST: Check if notification panel is open and close it
                if (_currentTab == MainTab.notifications) {
                  setState(() {
                    _currentTab = MainTab.map; // Close notification panel
                  });
                  return; // Don't process other behaviors when closing notifications
                }
                
                // THEN: Continue with existing long press behavior
                // Only provide haptic feedback on mobile
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                  HapticFeedback.mediumImpact();
                }
                
                setState(() {
                  _destination = latLng;
                  _selectedHotspot = null;
                  _selectedSafeSpot = null; // Clear selections
                });
                _showLocationOptions(latLng);
              },
              onMapEvent: (MapEvent mapEvent) {
                final maxZoom = _getMaxZoomForMapType(_currentMapType);
                if (mapEvent is MapEventMove && mapEvent.camera.zoom > maxZoom) {
                  _mapController.move(mapEvent.camera.center, maxZoom.toDouble());
                }
                // Track rotation and zoom changes
                if (mapEvent is MapEventRotate || mapEvent is MapEventMove) {
                  setState(() {
                    _currentMapRotation = mapEvent.camera.rotation;
                    _currentZoom = mapEvent.camera.zoom; // Add this to track zoom level
                  });
                }
              },
              interactionOptions: InteractionOptions(
                // Conditionally enable/disable rotation based on lock state
                flags: _isRotationLocked 
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate  // All flags except rotate
                  : InteractiveFlag.all,  // All flags including rotate
              ),
            ),
            children: [
              // Enhanced Tile Layer with dynamic source
              TileLayer(
                urlTemplate: currentConfig['urlTemplate'],
                userAgentPackageName: 'com.example.zecure',
                maxZoom: _getMaxZoomForMapType(_currentMapType).toDouble(),
                fallbackUrl: currentConfig['fallbackUrl'],
                subdomains: _currentMapType == MapType.dark ? ['a', 'b', 'c', 'd'] : const [],
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

              // Enhanced Main markers layer (current position and destination) - MINIMIZED
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 50, // Reduced from 60
                      height: 50, // Reduced from 60
                      child: _buildEnhancedCurrentLocationMarker(),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40, // Reduced from 50
                      height: 40, // Reduced from 50
                      child: _buildEnhancedDestinationMarker(),
                    ),
                ],
              ),
              
// FIXED: Hotspots layer with stable markers and labels
Consumer<HotspotFilterService>(
  builder: (context, filterService, child) {
    final visibleHotspots = _visibleHotspots.where((hotspot) {
      final currentUserId = _userProfile?['id'];
      final hasAdminPermissions = _hasAdminPermissions;
      final status = hotspot['status'] ?? 'approved';
      final activeStatus = hotspot['active_status'] ?? 'active';
      final createdBy = hotspot['created_by'];
      final reportedBy = hotspot['reported_by'];
      final isOwnHotspot = currentUserId != null &&
                       (currentUserId == createdBy || currentUserId == reportedBy);
      
      if (!filterService.shouldShowHotspot(hotspot)) {
        return false;
      }
      
      if (hasAdminPermissions) return true;
      
      if (status == 'approved' && activeStatus == 'active') return true;
      
      if (isOwnHotspot && currentUserId != null) return true;
      
      return false;
    }).toList();

    return MarkerLayer(
      key: ValueKey('hotspots_optimized_${visibleHotspots.length}_${_currentZoom.round()}_${_selectedHotspot?['id']}'),
      markers: visibleHotspots.map((hotspot) {
        final coords = hotspot['location']['coordinates'];
        final point = LatLng(coords[1], coords[0]);
        final status = hotspot['status'] ?? 'approved';
        final activeStatus = hotspot['active_status'] ?? 'active';
        final crimeLevel = hotspot['crime_type']['level'];
        final crimeCategory = hotspot['crime_type']['category'];
        final crimeTypeName = hotspot['crime_type']['name'] ?? 'Unknown Crime';
        final isActive = activeStatus == 'active';
        final isOwnHotspot = _userProfile?['id'] != null &&
                         (_userProfile?['id'] == hotspot['created_by'] ||
                          _userProfile?['id'] == hotspot['reported_by']);
        final isSelected = _selectedHotspot != null && _selectedHotspot!['id'] == hotspot['id'];
        final hotspotId = hotspot['id'].toString();
        
        // Determine marker complexity based on zoom
        final useSimpleMarker = _currentZoom < 13.0;
        
        // Color and icon logic (cached)
        Color markerColor;
        IconData markerIcon;
        double opacity = 1.0;

        if (status == 'pending') {
          markerColor = Colors.deepPurple;
          markerIcon = Icons.hourglass_empty;
        } else if (status == 'rejected') {
          markerColor = Colors.grey;
          markerIcon = Icons.cancel_outlined;
          opacity = isOwnHotspot ? 1.0 : 0.6;
        } else {
          switch (crimeLevel) {
            case 'critical':
              markerColor = const Color.fromARGB(255, 219, 0, 0);
              break;
            case 'high':
              markerColor = const Color.fromARGB(255, 223, 106, 11);
              break;
            case 'medium':
              markerColor = const Color.fromARGB(167, 116, 66, 9);
              break;
            case 'low':
              markerColor = const Color.fromARGB(255, 216, 187, 23);
              break;
            default:
              markerColor = Colors.blue;
          }
          
          switch (crimeCategory?.toLowerCase()) {
            case 'property':
              markerIcon = Icons.home_outlined;
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
          key: ValueKey('hotspot_optimized_$hotspotId\_$status\_$activeStatus\_$isSelected\_$useSimpleMarker'),
          point: point,
          width: useSimpleMarker ? (isSelected ? 30 : 24) : (isSelected ? 120 : 100),
          height: useSimpleMarker ? (isSelected ? 30 : 24) : (isSelected ? 70 : 60),
          child: RepaintBoundary(
            child: useSimpleMarker
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
                  showLabel: _currentZoom >= 14.0,
                ),
          ),
        );
      }).toList(),
    );
  },
),



         
// Safe Spots Marker Layer 
if (_showSafeSpots)
  Consumer<HotspotFilterService>(
    builder: (context, filterService, child) {
      // Filter safe spots based on filter service settings
      final filteredSafeSpots = _visibleSafeSpots.where((safeSpot) {
        return filterService.shouldShowSafeSpot(safeSpot);
      }).toList();

      return MarkerLayer(
        key: ValueKey('safe_spots_filtered_${filteredSafeSpots.length}_${_currentZoom.round()}_${_selectedSafeSpot?['id']}'),
        markers: filteredSafeSpots.asMap().entries.map((entry) {
          final index = entry.key;
          final safeSpot = entry.value;
          final coords = safeSpot['location']['coordinates'];
          final point = LatLng(coords[1], coords[0]);
          final status = safeSpot['status'] ?? 'pending';
          final verified = safeSpot['verified'] ?? false;
          final verifiedByAdmin = safeSpot['verified_by_admin'] ?? false;
          final safeSpotType = safeSpot['safe_spot_types'];
          final safeSpotName = safeSpot['name'] ?? 'Safe Spot';
          final currentUserId = _userProfile?['id'];
          final createdBy = safeSpot['created_by'];
          final isOwnSpot = currentUserId != null && currentUserId == createdBy;
          final safeSpotId = safeSpot['id'].toString();
          final isSelected = _selectedSafeSpot != null && _selectedSafeSpot!['id'] == safeSpot['id'];
          
          // Use simple markers when zoomed out
          final useSimpleMarker = _currentZoom < 13.0;
          
          Color markerColor;
          IconData markerIcon = _getIconFromString(safeSpotType['icon']);
          double opacity = 1.0;
          
          switch (status) {
            case 'pending':
              markerColor = Colors.deepPurple;
              opacity = 0.8;
              break;
            case 'approved':
              markerColor = verified ? Colors.green.shade700 : Colors.green.shade500;
              break;
            case 'rejected':
              markerColor = Colors.grey;
              opacity = isOwnSpot ? 0.7 : 0.4;
              break;
            default:
              markerColor = Colors.blue;
          }
          
return Marker(
  key: ValueKey('safe_spot_filtered_$safeSpotId\_$status\_$verified\_$index\_$isSelected\_$useSimpleMarker'),
  point: point,
  width: useSimpleMarker ? 32 : (isSelected ? 140 : 120),
  height: useSimpleMarker ? 32 : (isSelected ? 60 : 40),
  alignment: Alignment.center,
  child: RepaintBoundary(
    child: useSimpleMarker
      ? GestureDetector(
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: markerColor.withOpacity(opacity),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(markerIcon, color: Colors.white, size: 14),
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
                    showLabel: _currentZoom >= 14.0,
                  ),
            ),
          );
        }).toList(),
      );
    },
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
}) {
  return Transform.rotate(
    angle: -_currentMapRotation * pi / 180, // Counteract map rotation (degrees to radians)
    alignment: Alignment.center,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Main marker (stays in same position regardless of selection)
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
        
        // Crime type label - ONLY the label position adjusts when selected
        if (showLabel)
          Positioned(
            left: isSelected ? 93 : 73,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: showLabel ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (status == 'rejected' || status == 'pending' || !isActive || opacity < 1.0) 
                    ? markerColor.withOpacity(0.9 * opacity) 
                    : markerColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (status == 'rejected' || status == 'pending' || !isActive || opacity < 1.0) 
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
            ),
          ),
      ],
    ),
  );
}

// UPDATED: Safe spot marker with selection indicator
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
    angle: -_currentMapRotation * pi / 180, // Counteract map rotation (degrees to radians)
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
                    child: const Icon(Icons.verified, color: Colors.white, size: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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

// CURRENT LOCATION - MINIMIZED (unchanged)
Widget _buildEnhancedCurrentLocationMarker() {
  return Transform.rotate(
    angle: -_currentMapRotation * pi / 180, // Counteract map rotation (degrees to radians)
    alignment: Alignment.center,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing outer ring (minimized)
        Container(
          width: 55, // Reduced from 65
          height: 55, // Reduced from 65
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.15),
          ),
        ),

        // Second ring for depth (minimized)
        Container(
          width: 38, // Reduced from 48
          height: 38, // Reduced from 48
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.25),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),

        // Main circle background (minimized)
        Container(
          width: 22, // Reduced from 28
          height: 22, // Reduced from 28
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
        ),

        // Human silhouette icon (minimized)
        Icon(
          Icons.person,
          size: 14, // Reduced from 18
          color: _locationButtonPressed ? Colors.white : Colors.blue.shade600,
        ),
      ],
    ),
  );
}

// UPDATED: Destination marker that also rotates with map (optional)
Widget _buildEnhancedDestinationMarker() {
  return Transform.rotate(
    angle: -_currentMapRotation * pi / 180, // Counteract map rotation (degrees to radians)
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









// HOTSPOT DETAILS
void _showHotspotDetails(Map<String, dynamic> hotspot) async {
  // Add null safety at the beginning
  if (hotspot['location'] == null) {
    _showSnackBar('Unable to load hotspot details');
    return;
  }

  final coordinatesArray = hotspot['location']['coordinates']; // This is a List
  if (coordinatesArray == null || coordinatesArray.length < 2) {
    _showSnackBar('Invalid hotspot location data');
    return;
  }

  // Extract lat/lng from the array
  final lng = coordinatesArray[0]; // longitude is at index 0
  final lat = coordinatesArray[1];  // latitude is at index 1
  
  // Create the coordinates string for display
  final coordinatesString = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

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
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
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

  final DateTime time = DateTime.parse(hotspot['time'] ?? DateTime.now().toIso8601String()).toLocal();
  final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(time);
  final status = hotspot['status'] ?? 'approved';
  final activeStatus = hotspot['active_status'] ?? 'active';
  final isOwner = (_userProfile?['id'] != null) && 
      (hotspot['created_by'] == _userProfile!['id'] ||
       hotspot['reported_by'] == _userProfile!['id']);

  // Add null checks for crimeType
  final crimeType = hotspot['crime_type'] ?? {};
  final category = crimeType['category'] ?? 'Unknown Category';

// Fetch officer details
Map<String, String> officerDetails = {};
try {
  final response = await Supabase.instance.client
      .from('hotspot')
      .select('''
        approved_by,
        rejected_by,
        last_updated_by,
        approved_profile:approved_by (first_name, last_name),
        rejected_profile:rejected_by (first_name, last_name),
        updated_profile:last_updated_by (first_name, last_name)
      ''')
      .eq('id', hotspot['id'])
      .single();

  if (response['approved_by'] != null) {
    officerDetails['approved_by'] = 
        '${response['approved_profile']?['first_name'] ?? ''} ${response['approved_profile']?['last_name'] ?? ''}'.trim();
  }
  if (response['rejected_by'] != null) {
    officerDetails['rejected_by'] = 
        '${response['rejected_profile']?['first_name'] ?? ''} ${response['rejected_profile']?['last_name'] ?? ''}'.trim();
  }
  if (response['last_updated_by'] != null) {
    officerDetails['last_updated_by'] = 
        '${response['updated_profile']?['first_name'] ?? ''} ${response['updated_profile']?['last_name'] ?? ''}'.trim();
  }
} catch (e) {
  print('Error fetching officer details: $e');
}


// DESKTOP VIEW FOR HOTSPOT DETAILS
if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                onTap: () => _showFullScreenImage(hotspotPhoto?['photo_url']),
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
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(child: CircularProgressIndicator());
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error, color: Colors.red),
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
                            // Crime details with icons
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type with icon
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.category, size: 18, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Text(
                                                'Type:',
                                                style: TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('${crimeType['name']}'),
                                              const SizedBox(width: 12),
                                              _buildStatusWidget(activeStatus, status),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Category with icon
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.category, size: 18, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Text(
                                                'Category:',
                                                style: TextStyle(fontWeight: FontWeight.w500),
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
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning, size: 18, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Text(
                                                'Level:',
                                                style: TextStyle(fontWeight: FontWeight.w500),
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
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.description, size: 18, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Description:',
                                                style: TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                (hotspot['description'] == null || hotspot['description'].toString().trim().isEmpty)
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
                                  // Location with icon, copy button, and get directions
// Location with icon, copy button on right, and get directions below coordinates
Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.location_pin, size: 18, color: Colors.grey[600]),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              address,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              coordinatesString,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
onPressed: () {
  final lat = hotspot['location']['coordinates'][1];
  final lng = hotspot['location']['coordinates'][0];
  _showDirectionsConfirmation(
    LatLng(lat, lng),
    context,
    () {
      Navigator.pop(context);
      _getDirections(LatLng(lat, lng));
    },
  );
},
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Get Directions'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: fullLocation));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location copied to clipboard')),
          );
        },
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    ],
  ),
),
                                  // Time with icon
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Text(
                                                'Date and Time:',
                                                style: TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formattedTime,
                                                style: TextStyle(color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Show rejection reason for rejected reports
                            if (status == 'rejected' && hotspot['rejection_reason'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 16, bottom: 16),
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
                                        Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
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
                                      hotspot['rejection_reason'].toString().trim().isEmpty
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
                            if (status == 'approved' && !_hasAdminPermissions && isOwner)
                              Container(
                                margin: const EdgeInsets.only(top: 16, bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
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
// Officer details section
if (_hasAdminPermissions || _isOfficer) ...[
  Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (officerDetails['approved_by']?.isNotEmpty ?? false)
          ? Colors.green.shade50
          : (officerDetails['rejected_by']?.isNotEmpty ?? false)
              ? Colors.red.shade50
              : Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (officerDetails['approved_by']?.isNotEmpty ?? false)
            ? Colors.green.shade200
            : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                ? Colors.red.shade200
                : Colors.blue.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person,
              color: (officerDetails['approved_by']?.isNotEmpty ?? false)
                  ? Colors.green.shade600
                  : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                      ? Colors.red.shade600
                      : Colors.blue.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Last Actions:',
              style: TextStyle(
                color: (officerDetails['approved_by']?.isNotEmpty ?? false)
                    ? Colors.green.shade700
                    : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (officerDetails['approved_by']?.isNotEmpty ?? false)
          Text(
            'Approved by: ${officerDetails['approved_by']}',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 4),
        if (officerDetails['rejected_by']?.isNotEmpty ?? false)
          Text(
            'Rejected by: ${officerDetails['rejected_by']}',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 4),
        if (officerDetails['last_updated_by']?.isNotEmpty ?? false)
          Text(
            'Last updated by: ${officerDetails['last_updated_by']}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        if (officerDetails.isEmpty ||
            (officerDetails['approved_by']?.isEmpty ?? true) &&
            (officerDetails['rejected_by']?.isEmpty ?? true) &&
            (officerDetails['last_updated_by']?.isEmpty ?? true))
          Text(
            'No actions recorded',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    ),
  ),
],
                            const SizedBox(height: 20),
                            _buildDesktopActionButtons(hotspot, status, isOwner),
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
  builder: (context) => GestureDetector(
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
        mainAxisSize: MainAxisSize.min, // This makes it auto-size to content
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0), // Reduced horizontal padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo section for mobile - Now clickable
                  if (hotspotPhoto != null) ...[
                    GestureDetector(
                      onTap: () => _showFullScreenImage(hotspotPhoto?['photo_url']),
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        Text('Failed to load image'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Overlay to indicate clickability
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Type: ${crimeType['name']}'),
                                  const SizedBox(width: 6),
                                  _buildStatusWidget(activeStatus, status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: $category',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                'Level: ${crimeType['level']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Description with mini icon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (hotspot['description'] == null || hotspot['description'].toString().trim().isEmpty) 
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_pin, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                coordinatesString,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                  
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton.icon(
                                      onPressed: () {
                                        final lat = hotspot['location']['coordinates'][1];
                                        final lng = hotspot['location']['coordinates'][0];
                                        _showDirectionsConfirmation(
                                          LatLng(lat, lng),
                                          context,
                                          () {
                                            Navigator.pop(context);
                                            _getDirections(LatLng(lat, lng));
                                          },
                                        );
                                      },
                                    icon: const Icon(Icons.directions, size: 16),
                                    label: const Text('Get Directions'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue.shade600,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0), 
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: fullLocation));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location copied to clipboard')),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date and Time:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Show rejection reason for rejected reports
                  if (status == 'rejected' && hotspot['rejection_reason'] != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                              Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
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
                            hotspot['rejection_reason'].toString().trim().isEmpty 
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
                  
                  // Show approval note for approved reports by users (visible only to the report owner, not admin)
                  if (status == 'approved' && !_hasAdminPermissions && isOwner)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
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

// Officer details section
if (_hasAdminPermissions || _isOfficer) ...[
  Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (officerDetails['approved_by']?.isNotEmpty ?? false)
          ? Colors.green.shade50
          : (officerDetails['rejected_by']?.isNotEmpty ?? false)
              ? Colors.red.shade50
              : Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (officerDetails['approved_by']?.isNotEmpty ?? false)
            ? Colors.green.shade200
            : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                ? Colors.red.shade200
                : Colors.blue.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person,
              color: (officerDetails['approved_by']?.isNotEmpty ?? false)
                  ? Colors.green.shade600
                  : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                      ? Colors.red.shade600
                      : Colors.blue.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Last Actions:',
              style: TextStyle(
                color: (officerDetails['approved_by']?.isNotEmpty ?? false)
                    ? Colors.green.shade700
                    : (officerDetails['rejected_by']?.isNotEmpty ?? false)
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (officerDetails['approved_by']?.isNotEmpty ?? false)
          Text(
            'Approved by: ${officerDetails['approved_by']}',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 4),
        if (officerDetails['rejected_by']?.isNotEmpty ?? false)
          Text(
            'Rejected by: ${officerDetails['rejected_by']}',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 4),
        if (officerDetails['last_updated_by']?.isNotEmpty ?? false)
          Text(
            'Last updated by: ${officerDetails['last_updated_by']}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        if (officerDetails.isEmpty ||
            (officerDetails['approved_by']?.isEmpty ?? true) &&
            (officerDetails['rejected_by']?.isEmpty ?? true) &&
            (officerDetails['last_updated_by']?.isEmpty ?? true))
          Text(
            'No actions recorded',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    ),
  ),
],
                  // Mobile action buttons
                  if (_hasAdminPermissions && status == 'pending')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reviewHotspot(hotspot['id'], true),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showRejectDialog(hotspot['id']),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.blueGrey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteHotspot(hotspot['id']),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_hasAdminPermissions && status == 'pending' && isOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.0),
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
                                foregroundColor: const Color.fromARGB(255, 19, 111, 187),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteHotspot(hotspot['id']),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (status == 'rejected')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isOwner)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _deleteHotspot(hotspot['id']),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                          if (_hasAdminPermissions)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _deleteHotspot(hotspot['id']),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_hasAdminPermissions && status == 'approved')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.0),
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
                                foregroundColor: const Color.fromARGB(255, 19, 111, 187),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteHotspot(hotspot['id']),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
  ),
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
                          Text('Failed to load image', style: TextStyle(color: Colors.white)),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                   'Pinch with two fingers to zoom\nDrag to move around',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
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


//DESKTOP ACTION BUTTONS FOR HOTSPOT DETAILS - MODERN DESIGN
Widget _buildDesktopActionButtons(Map<String, dynamic> hotspot, String status, bool isOwner) {
  final buttons = <Widget>[];

 if (_hasAdminPermissions && status == 'pending') {
    buttons.addAll([
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _reviewHotspot(hotspot['id'], true),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
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
          label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
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
          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
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
 } else if (!_hasAdminPermissions && status == 'pending' && isOwner) {
    buttons.addAll([
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showEditHotspotForm(hotspot);
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
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
          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
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
  } else if (status == 'rejected') {
    if (isOwner || _hasAdminPermissions) {
      buttons.add(
        Center(
          child: SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => _deleteHotspot(hotspot['id']),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
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
        ),
      );
    }
} else if (_hasAdminPermissions && status == 'approved') {
    buttons.addAll([
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showEditHotspotForm(hotspot);
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
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
          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
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

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: buttons,
  );
}



void _showDirectionsConfirmation(LatLng coordinates, BuildContext context, VoidCallback onConfirm) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth > 800; // Adjust breakpoint as needed
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24), // Ensures margin from screen edges
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop 
              ? 500 // Fixed width for desktop
              : MediaQuery.of(context).size.width * 0.9, // 90% of screen width for mobile
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Max 80% of screen height
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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



// Add these methods for admin review
void _showRejectDialog(int hotspotId) {
  final reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reject Report'),
      content: TextField(
        controller: reasonController,
        decoration: const InputDecoration(
          labelText: 'Reason for rejection',
          hintText: 'Optional feedback for the user',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _reviewHotspot(hotspotId, false, reasonController.text);
          },
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}



Future<void> _reviewHotspot(int id, bool approve, [String? reason]) async {
  try {
    // First get the hotspot to notify the reporter
    final hotspotResponse = await Supabase.instance.client
        .from('hotspot')
        .select('''
          id,
          created_by,
          reported_by,
          crime_type:type_id(name),
          description,
          status
        ''')
        .eq('id', id)
        .single();

    // Update the hotspot status
    final updateResponse = await Supabase.instance.client
        .from('hotspot')
        .update({
          'status': approve ? 'approved' : 'rejected',
          'active_status': approve ? 'active' : 'inactive',
          'rejection_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
          if (approve) 'created_by': _userProfile?['id'],
          if (approve) 'approved_by': _userProfile?['id'], // Add approved_by
          if (!approve) 'rejected_by': _userProfile?['id'], // Add rejected_by
        })
        .eq('id', id)
        .select('id')
        .single();

    print('Report update response: $updateResponse');

    // Send notification to the reporter
    final reporterId = hotspotResponse['reported_by'] ?? hotspotResponse['created_by'];
    if (reporterId != null) {
      final crimeName = hotspotResponse['crime_type']?['name'] ?? 'Unknown crime';
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
      
      final insertResponse = await Supabase.instance.client
          .from('notifications')
          .insert(notificationData)
          .select();

      print('Notification insert response: $insertResponse');
    }

    if (mounted) {
      Navigator.pop(context);
      _showSnackBar(approve ? 'Report approved' : 'Report rejected and deactivated');
    }
  } catch (e) {
    print('Error in _reviewHotspot: ${e.toString()}');
    if (mounted) {
      _showSnackBar('Failed to review hotspot: ${e.toString()}');
    }
  }
}



//UPDATE HOTSPOT
Future<PostgrestMap> _updateHotspot(int id, int typeId, String description, DateTime dateTime, [String? activeStatus]) async {
  try {
    final updateData = {
      'type_id': typeId,
      'description': description,
      'time': dateTime.toIso8601String(),
      if (activeStatus != null) 'active_status': activeStatus,
      'updated_at': DateTime.now().toIso8601String(),
      'last_updated_by': _userProfile?['id'], // Add last_updated_by
    };

    final response = await Supabase.instance.client
        .from('hotspot')
        .update(updateData)
        .eq('id', id)
        .select('''*, crime_type: type_id (id, name, level, category)''')
        .single();

    if (mounted) {
      await _loadHotspots();
    }

    return response;
  } catch (e) {
    if (mounted) {
      _showSnackBar('Failed to update hotspot: ${e.toString()}');
    }
    print('Update error details: $e');
    rethrow;
  }
}


// DELETE HOTSPOT
Future<void> _deleteHotspot(int id) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Deletion'),
      content: const Text('Are you sure you want to delete this hotspot? This will also delete any associated photos.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
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
    await Supabase.instance.client
        .from('hotspot')
        .delete()
        .eq('id', id);

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

bool get isLargeScreen {
  final mediaQuery = MediaQuery.of(context);
  return mediaQuery.size.width > 600; // Adjust threshold as needed
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
      border: Border.all(
        color: Colors.grey.withOpacity(0.2),
        width: 1,
      ),
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search location...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          sidebarWidth: 285, // Adjust this to match your actual sidebar width
                        ); // Use the modal for desktop
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HotlinesScreen()),
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
                if (_searchController.text.isEmpty)
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}












//ALERT SCREEN MESSAGE
Widget _buildProximityAlert() {
  if (!_showProximityAlert || _nearbyHotspots.isEmpty) {
    return const SizedBox.shrink();
  }

  final closestHotspot = _nearbyHotspots.first;
  final crimeType = closestHotspot['crime_type'];
  final distance = (closestHotspot['distance'] as double).round();
  final level = crimeType['level'] ?? 'unknown';
  
  // Your existing color/icon logic...
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
    // REMOVED: margin from here since it's now handled by parent
    // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    margin: const EdgeInsets.symmetric(vertical: 4), // Keep only vertical margin
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
              // Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  alertIcon,
                  color: textColor,
                  size: 14,
                ),
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

// The floating animation wrapper - FIXED VERSION
Widget _buildAnimatedProximityAlert() {
  if (!_showProximityAlert || _nearbyHotspots.isEmpty) {
    return const SizedBox.shrink();
  }

  return TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 2000),
    tween: Tween(begin: -3.0, end: 3.0),
    curve: Curves.easeInOut,
    builder: (context, translateY, child) {
      return Transform.translate(
        offset: Offset(0, translateY),
        child: _buildProximityAlert(), // This calls the actual alert widget
      );
    },
    onEnd: () {
      // Restart the animation by rebuilding the widget
      if (mounted) {
        setState(() {});
      }
    },
  );
}


// Updated _buildCurrentScreen method
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
                child: Container(
                  width: isDesktop ? 600 : null,
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
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                child: Container(
                  width: isDesktop ? 600 : null,
                  child: _buildAnimatedProximityAlert(),
                ),
              ),
            ),
          ),
          _buildFloatingDurationWidget(),
        ],
      );
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
                      child: Container(
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
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                // REMOVED QuickAccessDesktopScreen from here - it's already rendered in _buildResponsiveDesktopLayout
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
                      child: Container(
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
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
              ],
            )
          : _buildNotificationsScreen();
    case MainTab.profile:
      return _buildProfileScreen();
  }
}



// PROFILE PAGE DESKTOP

Widget _buildProfileScreen() {
  if (_userProfile == null) {
    return const Center(
      child: Text('Please login to view profile'),
    );
  }

  final isDesktopOrWeb =
      Theme.of(context).platform == TargetPlatform.macOS ||
      Theme.of(context).platform == TargetPlatform.linux ||
      Theme.of(context).platform == TargetPlatform.windows ||
      kIsWeb;

  void toggleEditMode() {
    setState(() {
      _profileScreen.setShouldScrollToTop(true);
      _profileScreen.isEditingProfile = !_profileScreen.isEditingProfile;
    });
  }

  void closeProfileAndGoToMap() {
    setState(() {
      _currentTab = MainTab.map; // Switch to map tab
      _profileScreen.isEditingProfile = false; // Ensure edit mode is off
    });
  }

Future<void> refreshProfile() async {
  final user = _authService.currentUser;
  if (user != null) {
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
  _isAdmin,           // Admin-only privileges
  _hasAdminPermissions // Admin + Officer privileges
);
        _profileScreen.initControllers();
      });
    }
  }
}

  void handleSuccess() {
    refreshProfile().then((_) {
      setState(() {
        _profileScreen.setShouldScrollToTop(true);
        _profileScreen.isEditingProfile = false;
      });
    });
  }

  if (isDesktopOrWeb) {
    return Stack(
      children: [
        // Show map as background
        _buildMap(),
        
        // Loading indicator
        if (_isLoading && _currentPosition == null)
          const Center(child: CircularProgressIndicator()),
        
        // Top bar (same as other desktop tabs)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 600,
              child: Row(
                children: [
                  Expanded(child: _buildSearchBar(isWeb: isDesktopOrWeb)),
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
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
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
        
        // Profile modal overlay with GestureDetector
        GestureDetector(
          onTap: closeProfileAndGoToMap, // Close when clicking outside
          child: Container(
            color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent clicks on the profile content from propagating
                child: Container(
                  width: 600, // Match the width of other centered elements
                  child: _profileScreen.isEditingProfile
                      ? _profileScreen.buildDesktopEditProfileForm(
                          context,
                          toggleEditMode,
                          onSuccess: handleSuccess,
                        )
                      : _profileScreen.buildDesktopProfileView(
                          context,
                          toggleEditMode,
                          onClosePressed: closeProfileAndGoToMap,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  return Scaffold(
    body: SafeArea(
      child: _profileScreen.isEditingProfile
          ? _profileScreen.buildEditProfileForm(
              context,
              isDesktopOrWeb,
              toggleEditMode,
              onSuccess: handleSuccess,
            )
          : _profileScreen.buildProfileView(
              context,
              isDesktopOrWeb,
              toggleEditMode,
            ),
    ),
  );
}



Future<List<LocationSuggestion>> _searchLocations(String query) async {
  if (query.isEmpty || query.length < 2) return []; // Minimum 2 characters
  
  try {
    // Add timeout and better error handling
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=10&countrycodes=ph'), // Add country code for better results
      headers: {
        'User-Agent': 'YourAppName/1.0 (contact@yourapp.com)', // Required by Nominatim
      },
    ).timeout(
      const Duration(seconds: 10), // Add timeout
      onTimeout: () => throw TimeoutException('Search request timed out', const Duration(seconds: 10)),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      
      if (data.isEmpty) {
        return [];
      }
      
      return data.map((item) {
        try {
          return LocationSuggestion(
            displayName: item['display_name']?.toString() ?? 'Unknown location',
            lat: double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
            lon: double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
          );
        } catch (e) {
          print('Error parsing location item: $e');
          return null;
        }
      }).where((item) => item != null).cast<LocationSuggestion>().toList();
    } else {
      print('Search API returned status: ${response.statusCode}');
      throw HttpException('Search service temporarily unavailable (${response.statusCode})');
    }
  } on TimeoutException catch (e) {
    print('Search timeout: $e');
    if (mounted) {
      _showSnackBar('Search timeout - please try again');
    }
    return [];
  } on SocketException catch (e) {
    print('Network error during search: $e');
    if (mounted) {
      _showSnackBar('Network error - check your connection');
    }
    return [];
  } catch (e) {
    print('Search error: $e');
    if (mounted) {
      _showSnackBar('Search temporarily unavailable');
    }
    return [];
  }
}

void _onSuggestionSelected(LocationSuggestion suggestion) {
  final newPosition = LatLng(suggestion.lat, suggestion.lon);
  if (mounted) {
    setState(() {
      _currentTab = MainTab.map;
      _destination = newPosition;
    });
    _mapController.move(newPosition, 15.0);
    _searchController.text = suggestion.displayName;
    _showLocationOptions(newPosition);
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
}

extension on MapController {
}

class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  LocationSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name']?.toString() ?? 'Unknown location',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lon: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
    );
  }
}