import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
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
import 'package:zecure/main.dart';
import 'package:zecure/screens/auth/register_screen.dart';
import 'package:zecure/screens/welcome_message_first_timer.dart';
import 'package:zecure/screens/welcome_message_screen.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zecure/screens/profile_screen.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/desktop/report_hotspot_form_desktop.dart' show ReportHotspotFormDesktop;
import 'package:zecure/desktop/hotspot_filter_dialog_desktop.dart';
import 'package:zecure/desktop/location_options_dialog_desktop.dart';
import 'package:zecure/services/photo_upload_service.dart';
import 'package:zecure/services/pulsing_hotspot_marker.dart';
import 'package:zecure/screens/hotlines_screen.dart';
import 'package:zecure/desktop/desktop_sidebar.dart';
import 'package:zecure/services/safe_spot_details.dart';
import 'package:zecure/services/safe_spot_form.dart';
import 'package:zecure/services/safe_spot_service.dart';









class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MainTab { map, notifications, profile }
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



 
  TravelMode _selectedTravelMode = TravelMode.driving;
  bool _showTravelModeSelector = false;
  bool _showMapTypeSelector = false;


  


  //MAP ROTATION
  double _currentMapRotation = 0.0;
  bool _isRotationLocked = false;
  bool _showRotationFeedback = false;

  

  // Side bar for Desktop
  bool _isSidebarVisible = true;

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

// SAFE SPOT 
List<Map<String, dynamic>> _safeSpots = [];
RealtimeChannel? _safeSpotsChannel;
bool _showSafeSpots = true;

@override
void initState() {
  super.initState();
  
  // Add auth state listener
  Supabase.instance.client.auth.onAuthStateChange.listen((event) {
    if (event.session != null && mounted) {
      print('User logged in, loading profile and setting up real-time');
      _loadUserProfile().then((_) {
        // Reset filters for the logged-in user
        final filterService = Provider.of<HotspotFilterService>(context, listen: false);
        filterService.resetFiltersForUser(_userProfile?['id']?.toString());
        
        // Setup real-time after profile is loaded
        _setupNotificationsRealtime();
        _loadNotifications();
      });
    } else if (mounted) {
      print('User logged out, cleaning up');
      setState(() {
        _userProfile = null;
        _isAdmin = false;
        _hotspots = [];
        _notifications = [];
        _unreadNotificationCount = 0;
      });
      
      // Reset filters for guest user (no login)
      final filterService = Provider.of<HotspotFilterService>(context, listen: false);
      filterService.resetFiltersForUser(null);
      
      // Unsubscribe from channels
      _notificationsChannel?.unsubscribe();
      _hotspotsChannel?.unsubscribe();
      _safeSpotsChannel?.unsubscribe(); 
    }
  });

  // Initial profile load
  _loadUserProfile().then((_) {
    // Reset filters for the current user (if any)
    final filterService = Provider.of<HotspotFilterService>(context, listen: false);
    filterService.resetFiltersForUser(_userProfile?['id']?.toString());
  });
  
  _loadHotspots();
  _setupRealtimeSubscription();
  _loadSafeSpots();
  _setupSafeSpotsRealtime();
  
  // Only setup notifications if user is already logged in
  if (_userProfile != null) {
    _setupNotificationsRealtime();
    _loadNotifications();
  }

  Timer.periodic(const Duration(hours: 1), (_) => _cleanupOrphanedNotifications());
  Timer.periodic(const Duration(minutes: 2), (_) => _checkRealtimeConnection());
  
  // Start live location with error handling
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await _getCurrentLocation();
      _startLiveLocation();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error starting location: ${e.toString()}');
      }
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showWelcomeModal();
  });
}

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
  
  // Enhanced safe spots cleanup
  if (_safeSpotsChannel != null) {
    print('Unsubscribing from safe spots real-time channel...');
    _safeSpotsChannel!.unsubscribe();
    _safeSpotsChannel = null;
  }
  
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
      isAdmin: _isAdmin,
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
        setState(() {
          _safeSpots.insert(0, response); // Add to beginning like hotspots
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
      setState(() {
        _safeSpots.insert(0, payload.newRecord);
      });
    }
  }
}

void _handleSafeSpotUpdate(PostgresChangePayload payload) async {
  if (!mounted) return;
  
  print('=== SAFE SPOT UPDATE DEBUG ===');
  print('Payload new record: ${payload.newRecord}');
  
  try {
    final spotId = payload.newRecord['id'] as String;
    
    // Get the previous safe spot data
    final previousSafeSpot = _safeSpots.firstWhere(
      (s) => s['id'] == spotId,
      orElse: () => {},
    );
    
    print('Previous status: ${previousSafeSpot['status']}');
    print('New status from payload: ${payload.newRecord['status']}');

    // Fetch the updated safe spot data
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
        .eq('id', spotId)
        .single();

    print('Fetched response status: ${response['status']}');

    if (mounted) {
      setState(() {
        // REMOVE any existing instances of this safe spot first
        _safeSpots.removeWhere((s) => s['id'] == spotId);
        
        // Then add the updated one
        _safeSpots.add(response);
        
        // Remove duplicates as a safety measure
        _removeDuplicateSafeSpots();
        
        print('Updated safe spots list. Total count: ${_safeSpots.length}');
      });

      // Show status change messages or edit confirmations
      final previousStatus = previousSafeSpot.isNotEmpty ? previousSafeSpot['status'] ?? 'pending' : 'pending';
      final newStatus = response['status'] ?? 'pending';
      final typeName = response['safe_spot_types']['name'];

      print('Status comparison: $previousStatus -> $newStatus');

      // Check if it's a regular update (edit) vs status change
      final previousName = previousSafeSpot.isNotEmpty ? previousSafeSpot['name'] : '';
      final newName = response['name'] ?? '';
      final previousDescription = previousSafeSpot.isNotEmpty ? previousSafeSpot['description'] : '';
      final newDescription = response['description'] ?? '';
      final previousTypeId = previousSafeSpot.isNotEmpty ? previousSafeSpot['type_id'] : null;
      final newTypeId = response['type_id'];

      // Check if it's an edit (content changed but status stayed same)
      bool isEdit = (previousName != newName || 
                    previousDescription != newDescription || 
                    previousTypeId != newTypeId) && 
                   previousStatus == newStatus;

      if (isEdit && newStatus == previousStatus) {
        print('Showing edit confirmation message');
        _showSnackBar('Safe spot updated: $typeName');
      } else if (newStatus != previousStatus) {
        // Status change messages (existing logic)
        if (newStatus == 'approved') {
          print('Showing approved message');
          _showSnackBar('Safe spot approved: $typeName');
        } else if (newStatus == 'rejected') {
          print('Showing rejected message');
          _showSnackBar('Safe spot rejected: $typeName');
        }
      }
    }
  } catch (e) {
    print('❌ Error in _handleSafeSpotUpdate: $e');
    if (mounted) {
      _showSnackBar('Error updating safe spot: ${e.toString()}');
    }
  }
  print('=== END SAFE SPOT UPDATE DEBUG ===\n');
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
  
  // Admins can see everything
  if (_isAdmin) {
    print('Admin can see: true');
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
    
    print('Safe spot deleted via real-time: $deletedSafeSpotId');
    
    // Show notification
    if (deletedSafeSpot.isNotEmpty) {
      final typeName = deletedSafeSpot['safe_spot_types']?['name'] ?? 'Safe spot';
      _showSnackBar('$typeName deleted');
    }
  });
}

void _handleSafeSpotUpvoteChange(PostgresChangePayload payload) async {
  if (!mounted) return;
  
  try {
    final safeSpotId = payload.eventType == PostgresChangeEvent.delete 
        ? payload.oldRecord['safe_spot_id']
        : payload.newRecord['safe_spot_id'];
    
    // Find the safe spot in our local list
    final index = _safeSpots.indexWhere((s) => s['id'] == safeSpotId);
    
    if (index != -1) {
      // Get updated upvote count
      final upvoteCount = await SafeSpotService.getSafeSpotUpvoteCount(safeSpotId);
      
      setState(() {
        _safeSpots[index] = {
          ..._safeSpots[index],
          'upvote_count': upvoteCount,
        };
      });
      
      print('Upvote count updated via real-time: $upvoteCount for safe spot $safeSpotId');
    }
  } catch (e) {
    print('Error in _handleSafeSpotUpvoteChange: $e');
  }
}





// FUNCTION TO CALL WELCOME
void _showWelcomeModal() async {
  final user = Supabase.instance.client.auth.currentUser;
  
  if (user != null) {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('username, role, created_at')
          .eq('id', user.id)
          .single();
      
      final isAdmin = response['role'] == 'admin';
      final userName = response['username'];
      final createdAt = DateTime.parse(response['created_at']);
      final isNewUser = DateTime.now().difference(createdAt).inMinutes < 5; // Created within last 5 minutes
      
      if (isNewUser) {
        // Show first-time welcome modal for new users
        showFirstTimeWelcomeModal(
          context,
          userName: userName,
        );
      } else {
        // Show regular welcome modal for returning users
        showWelcomeModal(
          context,
          userType: isAdmin ? UserType.admin : UserType.user,
          userName: userName,
        );
      }
    } catch (e) {
      // Fallback to regular user welcome
      showWelcomeModal(
        context,
        userType: UserType.user,
      );
    }
  } else {
    // Show guest welcome modal
    showWelcomeModal(
      context,
      userType: UserType.guest,
      onCreateAccount: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
      },
    );
  }
}

void _startProximityMonitoring() {
  _proximityCheckTimer?.cancel();
  _proximityCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
    _checkProximityToHotspots();
  });
}



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
        .select()
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

List<Map<String, dynamic>> _removeDuplicateNotifications(List<dynamic> notifications) {
  final uniqueKeys = <String>{};
  final uniqueNotifications = <Map<String, dynamic>>[];
  
  for (final notification in notifications.cast<Map<String, dynamic>>()) {
    final key = '${notification['hotspot_id']}_${notification['user_id']}_${notification['type']}';
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
          _profileScreen = ProfileScreen(_authService, _userProfile, _isAdmin);
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
        
        // Check if non-admin user should see this hotspot
        final shouldShowForNonAdmin = _shouldNonAdminSeeHotspot(response);
        
        if (index != -1) {
          // Hotspot exists in current list
          if (_isAdmin || shouldShowForNonAdmin) {
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
            // Non-admin user should no longer see this hotspot (e.g., it was rejected)
            _hotspots.removeAt(index);
          }
        } else {
          // Hotspot doesn't exist in current list
          if (_isAdmin || shouldShowForNonAdmin) {
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



bool _shouldNonAdminSeeHotspot(Map<String, dynamic> hotspot) {
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

    // Apply filters based on admin status
    PostgrestFilterBuilder filteredQuery;
    if (!_isAdmin) {
      print('Filtering hotspots for non-admin user');
      final currentUserId = _userProfile?['id'];
      
      if (currentUserId != null) {
        // For non-admins, show:
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
      print('Admin user - loading all hotspots');
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
        if (_isAdmin) {
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
      _mapController.move(_currentPosition!, 15.0);
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
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Consumer<HotspotFilterService>(
            builder: (context, filterService, child) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Crimes',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
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
                        FontAwesomeIcons.exclamationTriangle,  // Better icon for critical
                        const Color.fromARGB(255, 219, 0, 0),
                        filterService.showCritical,
                        (value) => filterService.toggleCritical(),
                      ),
                      _buildFilterToggle(
                        context,
                        'High',
                        Icons.priority_high,  // Better icon for high priority
                        const Color.fromARGB(255, 223, 106, 11),
                        filterService.showHigh,
                        (value) => filterService.toggleHigh(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Medium',
                        Icons.remove,  // Better icon for medium
                        const Color.fromARGB(167, 116, 66, 9),
                        filterService.showMedium,
                        (value) => filterService.toggleMedium(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Low',
                        Icons.low_priority,  // Better icon for low priority
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
                        'Property',
                        Icons.home_outlined,  // Better property icon
                        Colors.blue,
                        filterService.showProperty,
                        (value) => filterService.toggleProperty(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Violent',
                        Icons.priority_high,  // Better violent crime icon
                        Colors.red,
                        filterService.showViolent,
                        (value) => filterService.toggleViolent(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Drug',
                        FontAwesomeIcons.syringe,  // Better drug icon (alternative to FontAwesome)
                        Colors.purple,
                        filterService.showDrug,
                        (value) => filterService.toggleDrug(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Public Order',
                        Icons.balance,  // Better public order icon
                        Colors.orange,
                        filterService.showPublicOrder,
                        (value) => filterService.togglePublicOrder(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Financial',
                        Icons.attach_money,  // Better financial icon
                        Colors.green,
                        filterService.showFinancial,
                        (value) => filterService.toggleFinancial(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Traffic',
                        Icons.traffic,  // Better traffic icon
                        Colors.blueGrey,
                        filterService.showTraffic,
                        (value) => filterService.toggleTraffic(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Alerts',
                        Icons.campaign,  // Better alerts icon
                        Colors.deepPurple,
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
                          Icons.hourglass_empty,  // Better pending icon
                          Colors.amber,
                          filterService.showPending,
                          (value) => filterService.togglePending(),
                        ),
                        _buildFilterToggle(
                          context,
                          'Rejected',
                          Icons.cancel_outlined,  // Better rejected icon
                          Colors.grey,
                          filterService.showRejected,
                          (value) => filterService.toggleRejected(),
                        ),
                        
                        // Active/Inactive filters (only for admin and regular users)
                        if (_userProfile?['role'] == 'admin' || _userProfile?['role'] == 'user') ...[
                          _buildFilterToggle(
                            context,
                            'Active',
                            Icons.check_circle_outline,  // Active icon
                            Colors.green,
                            filterService.showActive,
                            (value) => filterService.toggleActive(),
                          ),
                          _buildFilterToggle(
                            context,
                            'Inactive',
                            Icons.pause_circle_outline,  // Inactive icon
                            Colors.grey,
                            filterService.showInactive,
                            (value) => filterService.toggleInactive(),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
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
          isAdmin: _isAdmin,
          userProfile: _userProfile,
          distance: _distance,
          duration: _duration,
          onGetDirections: () => _getDirections(position),
          onGetSafeRoute: () => _getSafeRoute(position),
          onShareLocation: () => _shareLocation(position),
          onReportHotspot: () => _showReportHotspotForm(position),
          onAddHotspot: () => _showAddHotspotForm(position),
          onAddSafeSpot: () => _navigateToSafeSpotForm(position), // Updated callback
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

              if (!_isAdmin && _userProfile != null)
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report Crime'),
                  subtitle: const Text('Submit for admin approval'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportHotspotForm(position);
                  },
                ),
              if (_isAdmin)
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

Future<void> _getSafeRoute(LatLng destination) async {
  if (_currentPosition == null) return;
  
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
        averageSpeedKmh = 15.0; // 15 km/h cycling speed  
        break;
      case TravelMode.driving:
        averageSpeedKmh = 40.0; // 40 km/h average driving speed (considering traffic, stops, etc.)
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
                                  labelText: 'Date',
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
                                  labelText: 'Time',
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
                            labelText: 'Date',
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
                            labelText: 'Time',
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
                      labelText: 'Date',
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
                      labelText: 'Time',
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
                                labelText: 'Date',
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: timeController,
                              decoration: const InputDecoration(
                                labelText: 'Time',
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
                      const SizedBox(height: 16),
                      
                      // Active status for admins
                      if (_isAdmin)
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
                            labelText: 'Date',
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
                            labelText: 'Time',
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
                  const SizedBox(height: 16),
                  
                  // Add active status toggle for admins only - Compact Design
                  if (_isAdmin)
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
                                        _showSnackBar('Crime report updated successfully');
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to update crime report: ${e.toString()}'),
                                            duration: const Duration(seconds: 5),
                                          ),
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
          _profileScreen = ProfileScreen(_authService, _userProfile, _isAdmin);
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



// BOTTOM NAV BARS MAIN

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


@override
Widget build(BuildContext context) {
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


//  SIDEBAR VIEW FOR DESKTOP
Widget _buildResponsiveDesktopLayout() {
  return Stack(
    children: [
      Row(
        children: [
          // Responsive sidebar - automatically handles desktop/mobile logic
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
          
          // Main content area
          Expanded(
            child: _buildCurrentScreen(true),
          ),
        ],
      ),
      
      // Responsive toggle button
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
    ],
  );
}

// BOTTOM NAV BARS FOR MOBILE VIEW
Widget? _buildResponsiveBottomNav(bool isDesktop) {
  // Only show bottom nav on mobile screens AND when user is logged in
  // Don't show on desktop even when sidebar is hidden
  if (isDesktop || _userProfile == null) {
    return null;
  }

  // Use your existing bottom nav bar design for mobile only
  return _buildBottomNavBar();
}

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
              _locationButtonPressed = true;
              // Close map type selector when other buttons are pressed
              if (_showMapTypeSelector) {
                _showMapTypeSelector = false;
              }
            });
            await _getCurrentLocation();
            // Reset the state after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _locationButtonPressed = false;
                });
              }
            });
          },
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

//COMPASS

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

//NOTIFICATION

Widget _buildNotificationsScreen() {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (_notifications.any((n) => !n['is_read']))
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark all as read',
              style: TextStyle(color: Colors.black),
            ),
          ),
      ],
    ),
    body: _notifications.isEmpty
        ? const Center(child: Text('No notifications yet'))
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: notification['is_read'] ? null : Colors.blue[50],
                  child: ListTile(
                    leading: _getNotificationIcon(notification),
                    title: Text(notification['title']),
                    subtitle: Text(notification['message']),
                    trailing: Text(
                      DateFormat('MMM dd, hh:mm a').format(
                        DateTime.parse(notification['created_at']).toLocal(),
                      ),
                    ),
                    onTap: () {
                      if (!notification['is_read']) {
                        _markAsRead(notification['id']); // Only mark as read if unread
                      }
                      _handleNotificationTap(notification);
                    },
                  ),
                );
              },
            ),
          ),
  );
}

Widget _getNotificationIcon(Map<String, dynamic> notification) {
  final type = notification['type'];
  
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
          return const Icon(Icons.warning_rounded, color: Color.fromARGB(255, 247, 26, 10));
        case 'high':
          return const Icon(Icons.error_rounded, color: Color.fromARGB(255, 223, 106, 11));
        case 'medium':
          return const Icon(Icons.info_rounded, color: Color.fromARGB(155, 202, 130, 49));
        case 'low':
          return const Icon(Icons.info_outline_rounded, color: Color.fromARGB(255, 216, 187, 23));
        default:
          return const Icon(Icons.report, color: Colors.orange);
      }
    }
  }
  
  // Default icons for other notification types
  switch (type) {
    case 'report':
      return const Icon(Icons.report, color: Colors.orange);
    case 'approval':
      return const Icon(Icons.check_circle, color: Colors.green);
    case 'rejection':
      return const Icon(Icons.cancel, color: Colors.red);
    default:
      return const Icon(Icons.notifications, color: Colors.blue);
  }
}

void _handleNotificationTap(Map<String, dynamic> notification) {
  if (notification['hotspot_id'] != null) {
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
                FocusScope.of(context).unfocus();
                
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
                // Only provide haptic feedback on mobile
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
                  HapticFeedback.mediumImpact();
                }
                
                setState(() {
                  _destination = latLng;
                });
                _showLocationOptions(latLng);
              },
              onMapEvent: (MapEvent mapEvent) {
                final maxZoom = _getMaxZoomForMapType(_currentMapType);
                if (mapEvent is MapEventMove && mapEvent.camera.zoom > maxZoom) {
                  _mapController.move(mapEvent.camera.center, maxZoom.toDouble());
                }
                // Track rotation changes
                if (mapEvent is MapEventRotate || mapEvent is MapEventMove) {
                  setState(() {
                    _currentMapRotation = mapEvent.camera.rotation;
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

              // Enhanced Main markers layer (current position and destination)
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: _buildEnhancedCurrentLocationMarker(),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 50,
                      height: 50,
                      child: _buildEnhancedDestinationMarker(),
                    ),
                ],
              ),
              
// Updated filtering logic for your map - replace your existing Consumer<HotspotFilterService> section
Consumer<HotspotFilterService>(
  builder: (context, filterService, child) {
    return MarkerLayer(
      markers: _hotspots.where((hotspot) {
        final currentUserId = _userProfile?['id'];
        final isAdmin = _isAdmin;
        final status = hotspot['status'] ?? 'approved';
        final activeStatus = hotspot['active_status'] ?? 'active';
        final createdBy = hotspot['created_by'];
        final reportedBy = hotspot['reported_by'];
        final isOwnHotspot = currentUserId != null &&
                         (currentUserId == createdBy || currentUserId == reportedBy);
        
        // FIRST: Apply filter service logic to ALL hotspots (including own)
        if (!filterService.shouldShowHotspot(hotspot)) {
          return false;  // Hide if filter says no
        }
        
        // SECOND: Apply visibility rules based on user role
        if (isAdmin) {
          // Admins see everything that passes the filter
          return true;
        }
        
        // For regular users and guests
        if (status == 'approved' && activeStatus == 'active') {
          // Show approved and active hotspots to everyone
          return true;
        }
        
        // Show own pending/rejected hotspots to authenticated users
        if (isOwnHotspot && currentUserId != null) {
          return true;
        }
        
        // Hide everything else
        return false;
      }).map((hotspot) {
        // Your existing marker building code stays the same
        final coords = hotspot['location']['coordinates'];
        final point = LatLng(coords[1], coords[0]);
        final status = hotspot['status'] ?? 'approved';
        final activeStatus = hotspot['active_status'] ?? 'active';
        final crimeLevel = hotspot['crime_type']['level'];
        final crimeCategory = hotspot['crime_type']['category'];
        final isActive = activeStatus == 'active';
        final isOwnHotspot = _userProfile?['id'] != null &&
                         (_userProfile?['id'] == hotspot['created_by'] ||
                          _userProfile?['id'] == hotspot['reported_by']);
        final isSelected = _selectedHotspot != null && _selectedHotspot!['id'] == hotspot['id'];
        
        // Your existing marker color and icon logic stays exactly the same
        Color markerColor;
        IconData markerIcon;
        double opacity = 1.0;
        
        if (status == 'pending') {
          markerColor = Colors.deepPurple;
          markerIcon = Icons.hourglass_empty;
        }
        else if (status == 'rejected') {
          markerColor = Colors.grey;
          markerIcon = Icons.cancel_outlined;
          opacity = isOwnHotspot ? 1.0 : 0.6;
        } else {
  // Set color based on crime level
  switch (crimeLevel) {
    case 'critical':
      markerColor = const Color.fromARGB(255, 221, 0, 0);
      break;
    case 'high':
      markerColor = const Color.fromARGB(255, 241, 92, 23);
      break;
    case 'medium':
      markerColor = const Color.fromARGB(155, 202, 130, 49);
      break;
    case 'low':
      markerColor = const Color.fromARGB(255, 216, 187, 23);
      break;
    default:
      markerColor = Colors.blue;
  }
  
  // UPDATED: Level and Category-based icon selection to match filter dialog
  if (crimeLevel == 'critical') {
    // Critical level always gets triangle with exclamation
    markerIcon = Icons.warning;  // Triangle with exclamation point
  } else if (crimeLevel == 'high') {
    // High level - specific icons per category
    switch (crimeCategory?.toLowerCase()) {
      case 'violent':
        markerIcon = Icons.priority_high;  // ! - exclamation point for violent high
        break;
      case 'drug':
        markerIcon = FontAwesomeIcons.syringe;  // Keep injection icon
        break;
      case 'property':
        markerIcon = Icons.security;  // Property-specific icon for high level
        break;
      case 'traffic':
        markerIcon = Icons.traffic;  // Traffic-specific icon for high level
        break;
      case 'financial':
        markerIcon = Icons.credit_card_off;   // Financial-specific icon for high level
        break;
      case 'public order':
        markerIcon = Icons.gavel;  // Public order icon
        break;
      case 'alert':
        markerIcon = Icons.emergency;  // Emergency icon for high level alerts
        break;
      default:
        markerIcon = Icons.report_problem;  // Default for high level
    }
  } else {
    // For medium/low crimes, use category-based icons that match the filter
    switch (crimeCategory?.toLowerCase()) {
      case 'property':
        markerIcon = Icons.home_outlined;  // Match filter icon
        break;
      case 'violent':
        markerIcon = Icons.priority_high;  // ! - same as high level violent
        break;
      case 'drug':
        markerIcon = FontAwesomeIcons.syringe;  // Keep injection icon
        break;
      case 'public order':
        markerIcon = Icons.balance;  // Match filter icon
        break;
      case 'financial':
        markerIcon = Icons.attach_money;  // Match filter icon
        break;
      case 'traffic':
        markerIcon = Icons.traffic;  // Match filter icon
        break;
      case 'alert':
        markerIcon = Icons.campaign;  // Match filter icon
        break;
      default:
        markerIcon = Icons.location_pin;
    }
  }
  
  if (!isActive) {
    markerColor = markerColor.withOpacity(0.3);
  }
}
        
        return Marker(
          point: point,
          width: isSelected ? 80 : 70,
          height: isSelected ? 80 : 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 90,
                  height: 90,
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
                  pulseScale: isSelected ? 1.2 : 1.0,
                  onTap: () {
                    setState(() {
                      _selectedHotspot = hotspot;
                    });
                    _showHotspotDetails(hotspot);
                  },
                ),
              ),
              if (status == 'pending' || status == 'rejected')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
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
        );
      }).toList(),
    );
  },
),

              // Safe Spots Marker Layer
if (_showSafeSpots)
  MarkerLayer(
    // Use a more specific key that changes when the list actually changes
    key: ValueKey('safe_spots_${_safeSpots.map((s) => '${s['id']}_${s['status']}_${s['verified']}').join('_')}'),
    markers: _safeSpots.asMap().entries.where((entry) {
      final safeSpot = entry.value;
      final status = safeSpot['status'] ?? 'pending';
      final currentUserId = _userProfile?['id'];
      final createdBy = safeSpot['created_by'];
      final isOwnSpot = currentUserId != null && currentUserId == createdBy;
      
      // Show approved safe spots to everyone
      if (status == 'approved') return true;
      
      // Show ALL pending spots to authenticated users (for voting)
      if (status == 'pending' && currentUserId != null) return true;
      
      // Show own rejected spots
      if (isOwnSpot && status == 'rejected') return true;
      
      // Show all to admin
      if (_isAdmin) return true;

      return false;
    }).map((entry) {
      final index = entry.key;
      final safeSpot = entry.value;
      final coords = safeSpot['location']['coordinates'];
      final point = LatLng(coords[1], coords[0]);
      final status = safeSpot['status'] ?? 'pending';
      final verified = safeSpot['verified'] ?? false;
      final safeSpotType = safeSpot['safe_spot_types'];
      final currentUserId = _userProfile?['id'];
      final createdBy = safeSpot['created_by'];
      final isOwnSpot = currentUserId != null && currentUserId == createdBy;
      
      // Log marker color calculation for debugging
      print('Building marker for safe spot ${safeSpot['id']} with status: $status, verified: $verified');
      
      Color markerColor;
      IconData markerIcon = _getIconFromString(safeSpotType['icon']);
      double opacity = 1.0;
      
      switch (status) {
        case 'pending':
          markerColor = Colors.deepPurple;
          opacity = 0.8;
          print('  -> Orange (pending)');
          break;
        case 'approved':
          markerColor = verified ? Colors.green.shade700 : Colors.green.shade500;
          print('  -> Green (approved, verified: $verified)');
          break;
        case 'rejected':
          markerColor = Colors.grey;
          opacity = isOwnSpot ? 0.7 : 0.4;
          print('  -> Grey (rejected)');
          break;
        default:
          markerColor = Colors.blue;
          print('  -> Blue (default)');
      }
      
      return Marker(
        // Use index + id combination to ensure uniqueness
        key: ValueKey('safe_spot_marker_${index}_${safeSpot['id']}_${status}_$verified'),
        point: point,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () {
            SafeSpotDetails.showSafeSpotDetails(
              context: context,
              safeSpot: safeSpot,
              userProfile: _userProfile,
              isAdmin: _isAdmin,
              onUpdate: () {
                print('Manual refresh triggered from details');
                _loadSafeSpots();
              },
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: markerColor.withOpacity(opacity),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  markerIcon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Status indicator for non-approved spots
              if (status != 'approved')
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status == 'pending' ? Colors.orange : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              // Verified indicator for approved spots
              if (status == 'approved' && verified)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 8,
                    ),
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

// Helper method to convert string to IconData - ADD THIS TO YOUR _MapScreenState CLASS
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


// CURRENT LOCATION
Widget _buildEnhancedCurrentLocationMarker() {
  return Stack(
    alignment: Alignment.center,
    children: [
      // Pulsing outer ring
      Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.15),
        ),
      ),

      // Second ring for depth
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.25),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),

      // Main circle background
      Container(
        width: 28,
        height: 28,
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

      // Human silhouette icon
      Icon(
        Icons.person,
        size: 18,
        color: _locationButtonPressed ? Colors.white : Colors.blue.shade600,
      ),
    ],
  );
}



// DESTINATION PIN MARKER
Widget _buildEnhancedDestinationMarker() {
  return const Stack(
    alignment: Alignment.center,
    children: [
      Icon(
        Icons.location_pin,
        color: Colors.white, // Outline
        size: 40,
      ),
      Icon(
        Icons.location_pin,
        color: Colors.red, // Bright red for visibility
        size: 35,
      ),
    ],
  );
}









// HOTSPOT DETAILS
void _showHotspotDetails(Map<String, dynamic> hotspot) async {
  final lat = hotspot['location']['coordinates'][1];
  final lng = hotspot['location']['coordinates'][0];
  final coordinates = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

  String address = "Loading address...";
  String fullLocation = coordinates;

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
      fullLocation = "$address\n$coordinates";
    }
  } catch (e) {
    address = "Could not load address";
    fullLocation = "$address\n$coordinates";
  }

  final DateTime time = DateTime.parse(hotspot['time']).toLocal();
  final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(time);
  final status = hotspot['status'] ?? 'approved';
  final activeStatus = hotspot['active_status'] ?? 'active';
final isOwner = (_userProfile?['id'] != null) && 
    (hotspot['created_by'] == _userProfile!['id'] ||
     hotspot['reported_by'] == _userProfile!['id']);
  final crimeType = hotspot['crime_type'];
  final category = crimeType['category'] ?? 'Unknown Category';


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
            child: IntrinsicHeight( // This makes container size fit content
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
                  mainAxisSize: MainAxisSize.min, // Important for proper sizing
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
                            // Photo section - Now clickable
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
                            
                            // Crime details using fixed structure
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type with status
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Type:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text('${crimeType['name']}'),
                                              const SizedBox(width: 12),
                                              _buildStatusWidget(activeStatus, status),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Category
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Category:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(child: Text(category)),
                                      ],
                                    ),
                                  ),
                                  
                                  // Level
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Level:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(child: Text('${crimeType['level']}')),
                                      ],
                                    ),
                                  ),
                                  
                                  // Description
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Description:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          child: Text(
                                            (hotspot['description'] == null || hotspot['description'].toString().trim().isEmpty) 
                                                ? 'No description' 
                                                : hotspot['description'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Location with copy button
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Location:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(address),
                                              const SizedBox(height: 4),
                                              Text(
                                                coordinates,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: fullLocation));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Location copied to clipboard')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Time
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 80,
                                          child: Text('Time:', 
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(child: Text(formattedTime)),
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
                            if (status == 'approved' && !_isAdmin && isOwner)
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
                            
                           // Action buttons - Now better designed and centered
                            const SizedBox(height: 20),
                            _buildDesktopActionButtons(hotspot, status, isOwner),
                            const SizedBox(height: 16), // Small padding at bottom
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
              padding: const EdgeInsets.all(16.0),
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
                  
                  // Updated mobile view with status next to type
                  ListTile(
                    title: Row(
                      children: [
                        Text('Type: ${crimeType['name']}'),
                        const SizedBox(width: 8),
                        _buildStatusWidget(activeStatus, status),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: $category'),
                        Text('Level: ${crimeType['level']}'),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text('Description:'),
                    subtitle: Text(
                      (hotspot['description'] == null || hotspot['description'].toString().trim().isEmpty) 
                          ? 'No description' 
                          : hotspot['description'],
                    ),
                  ),
                  ListTile(
                    title: const Text('Location:'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address),
                        const SizedBox(height: 4),
                        Text(
                          coordinates,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullLocation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location copied to clipboard')),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Time:'),
                    subtitle: Text(formattedTime),
                  ),

                  // Show rejection reason for rejected reports
                  if (status == 'rejected' && hotspot['rejection_reason'] != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  if (status == 'approved' && !_isAdmin && isOwner)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                  // Mobile action buttons
                  if (_isAdmin && status == 'pending')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                  if (!_isAdmin && status == 'pending' && isOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                          if (_isAdmin)
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
                  if (_isAdmin && status == 'approved')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
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



// New helper widget to build status with effects
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
                width: 8,
                height: 8,
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
      if (shouldAnimate) const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor, width: 1),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
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

  if (_isAdmin && status == 'pending') {
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
  } else if (!_isAdmin && status == 'pending' && isOwner) {
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
    if (isOwner || _isAdmin) {
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
  } else if (_isAdmin && status == 'approved') {
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
  final bool isDesktop = isLargeScreen;
  
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
                // Emergency contacts button - ALWAYS visible
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HotlinesScreen()),
                    );
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


Widget _buildCurrentScreen(bool isDesktop) {
  switch (_currentTab) {
    case MainTab.map:
      return Stack(
        children: [
          // Full screen map
          _buildMap(),
          
          // Loading indicator
          if (_isLoading && _currentPosition == null)
            const Center(child: CircularProgressIndicator()),
          
          // Top bar with search + login/logout
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Container(
              // MOBILE: Add horizontal margin for mobile
              margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16), 
              child: Center(
                child: Container(
                  width: isDesktop ? 600 : null, // Desktop: fixed width, Mobile: full available width
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
          
          // Proximity alert with matching width
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: Container(
              // SAME margin as search bar for mobile
              margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16),
              child: Center(
                child: Container(
                  width: isDesktop ? 600 : null, // SAME width constraint as search bar
                  child: _buildAnimatedProximityAlert(),
                ),
              ),
            ),
          ),

          // Floating duration widget at bottom
          _buildFloatingDurationWidget(),
        ],
      );
    case MainTab.notifications:
      return _buildNotificationsScreen();
    case MainTab.profile:
      return _buildProfileScreen();
  }
}


// PROFILE PAGE

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
                _profileScreen = ProfileScreen(_authService, _userProfile, _isAdmin);
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