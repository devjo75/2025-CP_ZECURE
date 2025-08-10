import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zecure/screens/profile_screen.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/desktop/report_hotspot_form_desktop.dart' show ReportHotspotFormDesktop;
import 'package:zecure/desktop/hotspot_filter_dialog_desktop.dart';
import 'package:zecure/desktop/location_options_dialog_desktop.dart';
import 'package:zecure/desktop/add_hotspot_form_desktop.dart';
import 'package:zecure/desktop/hotspot_details_desktop.dart';
import 'package:zecure/desktop/edit_hotspot_form_desktop.dart';
import 'package:zecure/services/pulsing_hotspot_marker.dart';







class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MainTab { map, notifications, profile }

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final _authService = AuthService(Supabase.instance.client);

 


  // Location state
  LatLng? _currentPosition;
  LatLng? _destination;
  bool _isLoading = true;
  List<LatLng> _polylinePoints = [];

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

  // Hotspot state
  List<Map<String, dynamic>> _hotspots = [];
  // ignore: unused_field
  Map<String, dynamic>? _selectedHotspot;
  RealtimeChannel? _hotspotsChannel;

  // NOTIFICATIONS
List<Map<String, dynamic>> _notifications = [];
RealtimeChannel? _notificationsChannel;
int _unreadNotificationCount = 0;
// Add notification to enum


@override
void initState() {
  super.initState();
  
  // Add auth state listener
  Supabase.instance.client.auth.onAuthStateChange.listen((event) {
    if (event.session != null && mounted) {
      print('User logged in, loading profile and setting up real-time');
      _loadUserProfile().then((_) {
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
      // Unsubscribe from channels
      _notificationsChannel?.unsubscribe();
      _hotspotsChannel?.unsubscribe();
    }
  });

  _loadUserProfile();
  _loadHotspots();
  _setupRealtimeSubscription();
  
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
}

@override
void dispose() {
  _positionStream?.cancel();
  _searchController.dispose();
  _profileScreen.disposeControllers();
  _hotspotsChannel?.unsubscribe();
  _notificationsChannel?.unsubscribe();
  _reconnectionTimer?.cancel(); // Add this line
  super.dispose();
}


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
  // Show loading initially
  if (mounted) {
    setState(() {
      _isLoading = true;
    });
  }

  _positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    ),
  ).listen(
    (Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _polylinePoints.add(_currentPosition!);
          _isLoading = false; // Hide loading when we get the first position
        });
        _mapController.move(_currentPosition!, _mapController.zoom);
      }
    },
    onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Location error: ${error.toString()}');
      }
    },
  );
}

void _clearDirections() {
  setState(() {
    _polylinePoints.clear();
    _distance = 0;
    _duration = '';
    _destination = null;
    _showClearButton = false;
  });
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
      
      // Check if routes exist
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        _showSnackBar('No route found to destination');
        return;
      }
      
      final route = data['routes'][0];
      
      // Safely parse distance and duration with type conversion
      final distance = _safeParseDouble(route['distance']) ?? 0.0;
      final duration = _safeParseDouble(route['duration']) ?? 0.0;
      
      // Safely parse coordinates
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
          _distance = distance / 1000; // Convert to km
          _duration = _formatDuration(duration);
          _polylinePoints = routePoints;
          _destination = destination;
          _showClearButton = true;
        });
        
        _mapController.fitBounds(
          LatLngBounds(_currentPosition!, destination),
          options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
        );
      }
    } else {
      print('Directions API returned status: ${response.statusCode}');
      _showSnackBar('Failed to get directions (${response.statusCode})');
    }
  } on TimeoutException catch (e) {
    print('Directions timeout: $e');
    _showSnackBar('Route request timed out - please try again');
  } on SocketException catch (e) {
    print('Network error during route request: $e');
    _showSnackBar('Network error - check your connection');
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
                        Icons.warning,
                        Colors.red,
                        filterService.showCritical,
                        (value) => filterService.toggleCritical(),
                      ),
                      _buildFilterToggle(
                        context,
                        'High',
                        Icons.error,
                        Colors.orange,
                        filterService.showHigh,
                        (value) => filterService.toggleHigh(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Medium',
                        Icons.info,
                        Colors.amber,
                        filterService.showMedium,
                        (value) => filterService.toggleMedium(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Low',
                        Icons.check_circle,
                        Colors.green,
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
                        Icons.house,
                        Colors.blue,
                        filterService.showProperty,
                        (value) => filterService.toggleProperty(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Violent',
                        Icons.warning,
                        Colors.red,
                        filterService.showViolent,
                        (value) => filterService.toggleViolent(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Drug',
                        Icons.medical_services,
                        Colors.purple,
                        filterService.showDrug,
                        (value) => filterService.toggleDrug(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Public Order',
                        Icons.gavel,
                        Colors.orange,
                        filterService.showPublicOrder,
                        (value) => filterService.togglePublicOrder(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Financial',
                        Icons.attach_money,
                        Colors.green,
                        filterService.showFinancial,
                        (value) => filterService.toggleFinancial(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Traffic',
                        Icons.directions_car,
                        Colors.blueGrey,
                        filterService.showTraffic,
                        (value) => filterService.toggleTraffic(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Alerts',
                        Icons.notification_important,
                        Colors.deepPurple,  // Distinct color for alerts
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
                          Icons.question_mark,
                          Colors.purple,
                          filterService.showPending,
                          (value) => filterService.togglePending(),
                        ),
                        _buildFilterToggle(
                          context,
                          'Rejected',
                          Icons.block,
                          Colors.grey,
                          filterService.showRejected,
                          (value) => filterService.toggleRejected(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                        // Close button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, // White background
                              foregroundColor: Theme.of(context).primaryColor, // Blue text
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
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Location'),
                onTap: () => _shareLocation(position),
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




// Helper methods for safe route calculation
double _calculateDistance(LatLng point1, LatLng point2) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Meter, point1, point2);
}

Future<List<LatLng>> _getRouteFromAPI(LatLng start, LatLng end) async {
  final response = await http.get(
    Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    ),
    headers: {
      'User-Agent': 'YourAppName/1.0',
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

List<LatLng> _findUnsafeSegments(List<LatLng> route) {
  final unsafeSegments = <LatLng>[];
  const safeDistance = 100.0; // 100 meters
  
  for (final point in route) {
    for (final hotspot in _hotspots) {
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
  const offset = 0.002; // ~200m
  
  for (final point in unsafePoints) {
    // Add points around the unsafe segment
    waypoints.add(LatLng(point.latitude + offset, point.longitude));
    waypoints.add(LatLng(point.latitude - offset, point.longitude));
    waypoints.add(LatLng(point.latitude, point.longitude + offset));
    waypoints.add(LatLng(point.latitude, point.longitude - offset));
  }
  
  return waypoints;
}

Future<List<LatLng>> _getRouteWithWaypoints(
  LatLng start, 
  LatLng end, 
  List<LatLng> waypoints
) async {
  // Convert waypoints to string format for API
  final waypointsStr = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
  
  final response = await http.get(
    Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '$waypointsStr;'
      '${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    ),
    headers: {
      'User-Agent': 'YourAppName/1.0',
    },
  ).timeout(const Duration(seconds: 20)); // Longer timeout for complex routes

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('No safe route found');
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
  throw Exception('Failed to get safe route (${response.statusCode})');
}

Future<void> _getSafeRoute(LatLng destination) async {
  if (_currentPosition == null) return;
  
  _showSnackBar('Calculating safest route...');

  try {
    // First get the regular route
    final regularRoute = await _getRouteFromAPI(_currentPosition!, destination);
    
    // Check for unsafe segments near hotspots
    final unsafeSegments = _findUnsafeSegments(regularRoute);
    
    if (unsafeSegments.isEmpty) {
      // Route is already safe
      setState(() {
        _polylinePoints = regularRoute;
        _destination = destination;
        _showClearButton = true;
      });
      _showSnackBar('Route is already safe!');
      return;
    }
    
    // Generate alternative waypoints to avoid hotspots
    final waypoints = _generateAlternativeWaypoints(unsafeSegments);
    final safeRoute = await _getRouteWithWaypoints(_currentPosition!, destination, waypoints);
    
    // Verify the new route is actually safer
    final newUnsafeSegments = _findUnsafeSegments(safeRoute);
    if (newUnsafeSegments.length >= unsafeSegments.length) {
      // New route isn't better - fallback to regular
      _showSnackBar('Could not find safer route - using regular route');
      _getDirections(destination);
      return;
    }
    
    // Calculate distance and duration for the safe route
    final distance = _calculateRouteDistance(safeRoute);
    final duration = _estimateRouteDuration(distance);
    
    setState(() {
      _polylinePoints = safeRoute;
      _distance = distance / 1000; // Convert to km
      _duration = _formatDuration(duration);
      _destination = destination;
      _showClearButton = true;
    });
    
    _mapController.fitBounds(
      LatLngBounds(_currentPosition!, destination),
      options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
    );
    _showSnackBar('Safe route calculated! Avoided ${unsafeSegments.length - newUnsafeSegments.length} hotspots');
  } catch (e) {
    _showSnackBar('Error calculating safe route: ${e.toString()}');
    _getDirections(destination);
  }
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
  const averageSpeed = 50.0 / 3.6; // 50 km/h to m/s
  return distanceMeters / averageSpeed; // duration in seconds
}

void _showAddHotspotForm(LatLng position) async {
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  try {
    // Fetch crime types from Supabase including category
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
    // ignore: unused_local_variable
    String selectedCategory = crimeTypes[0]['category'];

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

          await _saveHotspot(
            selectedCrimeId.toString(),
            descriptionController.text,
            position,
            dateTime,
          );

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
      showDialog(
        context: context,
        builder: (context) {
          return AddHotspotFormDesktop(
            formKey: formKey,
            descriptionController: descriptionController,
            dateController: dateController,
            timeController: timeController,
            crimeTypes: crimeTypes,
            selectedCrimeType: selectedCrimeType,
            onCrimeTypeChanged: (value) {
              final selected = crimeTypes.firstWhere((c) => c['name'] == value);
              selectedCrimeType = value;
              selectedCrimeId = selected['id'];
              selectedCategory = selected['category'];
            },
            onSubmit: onSubmit,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return SingleChildScrollView(
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
      overflow: TextOverflow.ellipsis, // Handles long text gracefully
    ),
  );
}).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          final selected = crimeTypes.firstWhere((crime) => crime['name'] == newValue);
                          selectedCrimeType = newValue;
                          selectedCrimeId = selected['id'];
                          selectedCategory = selected['category'];
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
                        onPressed: onSubmit,
                        child: const Text('Submit'),
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
  // ignore: unused_local_variable
  String selectedCategory = crimeTypes[0]['category'];
  bool isSubmitting = false;

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
      overflow: TextOverflow.ellipsis, // Handles long text gracefully
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
                                selectedCategory = selected['category'];
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
                      onPressed: isSubmitting
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
                      child: isSubmitting
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


void _showEditHotspotForm(Map<String, dynamic> hotspot) async {
  try {
    // Fetch crime types from Supabase including category
    final crimeTypesResponse = await Supabase.instance.client
        .from('crime_type')
        .select('*')
        .order('name');

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
    // ignore: unused_local_variable
    String selectedCategory = hotspot['crime_type']['category'] ?? 'Unknown';
    
    // Add active status variables
    String selectedActiveStatus = hotspot['active_status'] ?? 'active';
    bool isActiveStatus = selectedActiveStatus == 'active';

    // Desktop/Web view
    if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: EditHotspotFormDesktop(
            hotspot: hotspot,
            crimeTypes: crimeTypes,
            onUpdate: (id, crimeId, description, time, activeStatus) async {
              try {
                await _updateHotspot(id, crimeId, description, time, activeStatus);
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
            },
onCancel: () {
  setState(() {
    _selectedHotspot = null;
  });
  Navigator.pop(context);
},
            isAdmin: _isAdmin,
          ),
        ),
      );
      return;
    }

    // Mobile view (bottom sheet)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          left: 16.0,
          right: 16.0,
          top: 16.0,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCrimeType,
                      decoration: const InputDecoration(labelText: 'Crime Type'),
items: crimeTypes.map((crimeType) {
  return DropdownMenuItem<String>(
    value: crimeType['name'],
    child: Text(
      '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
      style: const TextStyle(fontSize: 14),
      overflow: TextOverflow.ellipsis, // Handles long text gracefully
    ),
  );
}).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          final selected = crimeTypes.firstWhere((crime) => crime['name'] == newValue);
                          setState(() {
                            selectedCrimeType = newValue;
                            selectedCrimeId = selected['id'];
                            selectedCategory = selected['category'];
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
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(labelText: 'Date'),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: timeController,
                      decoration: const InputDecoration(labelText: 'Time'),
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
                    const SizedBox(height: 16),
                    // Add active status toggle for admins only
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final dateTime = DateTime.parse('${dateController.text} ${timeController.text}');
                                await _updateHotspot(
                                  hotspot['id'],
                                  selectedCrimeId,
                                  descriptionController.text,
                                  dateTime,
                                  selectedActiveStatus,
                                );
                                await _loadHotspots();
                                if (mounted) {
                                  Navigator.pop(context);
                                  _showSnackBar('Updated crime successfully');
                                }
                              } catch (e) {
                                print('Error updating hotspot: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update hotspot: ${e.toString()}'),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Update'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showHotspotDetails(hotspot);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[500],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  } catch (e) {
    if (mounted) {
      _showSnackBar('Error loading crime types: ${e.toString()}');
    }
  }
}


Future<void> _reportHotspot(
  int typeId,
  String description,
  LatLng position,
  DateTime dateTime,
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

    // Insert the hotspot
    final response = await Supabase.instance.client
        .from('hotspot')
        .insert(insertData)
        .select('''
          *,
          crime_type: type_id (id, name, level, category, description)
        ''')
        .single();

    print('Hotspot inserted successfully: ${response['id']}');

    // Only create notifications if this is a pending report
    if (response['status'] == 'pending') {
      try {
        // Get all admin users
        final admins = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('role', 'admin');

        // Create a single batch insert for all notifications with unique constraint
        if (admins.isNotEmpty) {
          final notifications = admins.map((admin) => {
            'user_id': admin['id'],
            'title': 'New Crime Report',
            'message': 'New ${response['crime_type']['name']} report awaiting review',
            'type': 'report',
            'hotspot_id': response['id'],
            'created_at': DateTime.now().toIso8601String(),
            // Add a unique constraint key to prevent duplicates
            'unique_key': 'report_${response['id']}_${admin['id']}',
          }).toList();

          // Use upsert to prevent duplicates
          await Supabase.instance.client
              .from('notifications')
              .upsert(
                notifications,
                onConflict: 'unique_key', // This requires a unique constraint in your DB
              );
          
          print('Created/updated ${notifications.length} admin notifications');
        }
      } catch (notificationError) {
        print('Error creating notifications: $notificationError');
      }
    }

    // UI fallback if real-time fails
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_hotspots.any((h) => h['id'] == response['id']) && mounted) {
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

// 5. Update _saveHotspot with similar fallback mechanism
Future<void> _saveHotspot(String typeId, String description, LatLng position, DateTime dateTime) async {
  try {
    final insertData = {
      'type_id': int.parse(typeId),
      'description': description.trim().isNotEmpty ? description.trim() : null,
      'location': 'POINT(${position.longitude} ${position.latitude})',
      'time': dateTime.toIso8601String(),
      'created_by': _userProfile?['id'],
      'status': 'approved', // Admin creates are auto-approved
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
  } catch (e) {
    _showSnackBar('Failed to save hotspot: ${e.toString()}');
    print('Error details: $e');
  }
}

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
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

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

    if (isDesktopOrWeb) {
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
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
      ).then((_) {
        if (!_profileScreen.isEditingProfile) {
          setState(() => _currentTab = MainTab.map);
        }
      });
    }
  }





Widget _buildBottomNavBar() {
  return BottomNavigationBar(
    currentIndex: _currentTab.index,
    onTap: (index) {
      setState(() {
        _currentTab = MainTab.values[index];
      });

      if (_currentTab == MainTab.profile) {
        _showProfileDialog();
      } 
      
    },
    items: [
      const BottomNavigationBarItem(
        icon: Icon(Icons.map),
        label: 'Map',
      ),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            const Icon(Icons.notifications),
            if (_unreadNotificationCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
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
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: 'Notifications',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ],
    selectedItemColor: Colors.blue,
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  );
}

Widget _buildFloatingActionButtons() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Filter Crimes button (always visible)
      Tooltip(
        message: 'Filter Hotspots',
        child: FloatingActionButton(
          heroTag: 'filterHotspots',
          onPressed: _showHotspotFilterDialog,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          mini: true,
          child: const Icon(Icons.filter_alt),
        ),
      ),
      const SizedBox(height: 8),
      
      // Clear Directions button (only visible when there's a route)
      if (_showClearButton)
        Tooltip(
          message: 'Clear Route',
          child: FloatingActionButton(
            heroTag: 'clearRoute',
            onPressed: _clearDirections,
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            mini: true,
            child: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ),
      const SizedBox(height: 8),
      
      // My Location button (always visible)
      Tooltip(
        message: 'My Location',
        child: FloatingActionButton(
          heroTag: 'myLocation',
          onPressed: _getCurrentLocation,
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.my_location),
        ),
      ),
    ],
  );
}


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
              style: TextStyle(color: Colors.white),
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
                    leading: _getNotificationIcon(notification['type']),
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

Icon _getNotificationIcon(String type) {
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

  

Widget _buildMap() {
  return FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      center: _currentPosition ?? const LatLng(14.5995, 120.9842),
      zoom: 15.0,
      maxZoom: 19.0,
      minZoom: 3.0,
      onTap: (tapPosition, latLng) {
        FocusScope.of(context).unfocus();
        setState(() {
          _destination = latLng;
        });
        _showLocationOptions(latLng);
      },
      onPositionChanged: (MapPosition position, bool hasGesture) {
        if (hasGesture && position.zoom != null && position.zoom! > 19) {
          _mapController.move(position.center!, 19.0);
        }
      },
      interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.zecure',
        maxZoom: 19,
        fallbackUrl: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      
      // Polyline layer should come before markers to appear underneath
      if (_polylinePoints.isNotEmpty)
        PolylineLayer(
          polylines: [
            Polyline(
              points: _polylinePoints,
              color: Colors.blue,
              strokeWidth: 4,
            ),
          ],
        ),
      
      // Main markers layer (current position and destination)
      MarkerLayer(
        markers: [
          if (_currentPosition != null)
            Marker(
              point: _currentPosition!,
              width: 40,
              height: 40,
              builder: (ctx) => const Icon(
                Icons.location_on,
                color: Colors.red, // Always green since we're always tracking
                size: 40,
              ),
            ),
          if (_destination != null)
            Marker(
              point: _destination!,
              width: 40,
              height: 40,
              builder: (ctx) => const Icon(
                Icons.location_pin,
                color: Colors.blue,
                size: 40,
              ),
            ),
        ],
      ),

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

        // Admin view - show all hotspots based on filters
        if (isAdmin) {
          return filterService.shouldShowHotspot(hotspot);
        }

        // Non-admin view rules:
        // 1. Show active+approved hotspots that match crime type filters
        if (activeStatus == 'active' && 
            status == 'approved' && 
            filterService.shouldShowHotspot(hotspot)) {
          return true;
        }

        // 2. Always show user's own hotspots regardless of status
        if (isOwnHotspot) {
          // Apply filter service settings for pending/rejected if needed
          if (status == 'pending' && !filterService.showPending) return false;
          if (status == 'rejected' && !filterService.showRejected) return false;
          return true;
        }

        return false;
      }).map((hotspot) {
        final coords = hotspot['location']['coordinates'];
        final point = LatLng(coords[1], coords[0]);
        final status = hotspot['status'] ?? 'approved';
        final activeStatus = hotspot['active_status'] ?? 'active';
        final crimeLevel = hotspot['crime_type']['level'];
        final isActive = activeStatus == 'active';
        final isOwnHotspot = _userProfile?['id'] != null && 
                         (_userProfile?['id'] == hotspot['created_by'] || 
                          _userProfile?['id'] == hotspot['reported_by']);
        final isSelected = _selectedHotspot != null && _selectedHotspot!['id'] == hotspot['id'];

        // Determine marker appearance
        Color markerColor;
        IconData markerIcon;
        double opacity = 1.0;

        if (status == 'pending') {
          markerColor = Colors.deepPurple;
          markerIcon = Icons.question_mark;
        } else if (status == 'rejected') {
          markerColor = Colors.grey;
          markerIcon = Icons.block;
          // Make rejected markers semi-transparent unless it's the user's own
          opacity = isOwnHotspot ? 1.0 : 0.6;
        } else {
          // For approved hotspots
          switch (crimeLevel) {
            case 'critical':
              markerColor = Colors.red;
              markerIcon = Icons.warning;
              break;
            case 'high':
              markerColor = Colors.orange;
              markerIcon = Icons.error;
              break;
            case 'medium':
              markerColor = Colors.yellow;
              markerIcon = Icons.info;
              break;
            case 'low':
              markerColor = Colors.green;
              markerIcon = Icons.check_circle;
              break;
            default:
              markerColor = Colors.blue;
              markerIcon = Icons.location_pin;
          }

          // Apply inactive styling
          if (!isActive) {
            markerColor = markerColor.withOpacity(0.3);
          }
        }

        return Marker(
          point: point,
          width: isSelected ? 70 : 60, // Slightly larger when selected
          height: isSelected ? 70 : 60,
          builder: (ctx) => Stack(
            alignment: Alignment.center,
            children: [
              // Highlight ring for selected hotspot
              if (isSelected)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                ),
              // Main marker with pulsing effect
              Opacity(
                opacity: opacity,
                child: PulsingHotspotMarker(
                  markerColor: markerColor, // Keep original color
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





void _showHotspotDetails(Map<String, dynamic> hotspot) async {
  final lat = hotspot['location']['coordinates'][1];
  final lng = hotspot['location']['coordinates'][0];
  final coordinates = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

  String address = "Loading address...";
  String fullLocation = coordinates;

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
  final isOwner = hotspot['created_by'] == _userProfile?['id'] ||
      hotspot['reported_by'] == _userProfile?['id'];
  final crimeType = hotspot['crime_type'];
  final category = crimeType['category'] ?? 'Unknown Category';

  // Desktop/Web View
  if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: HotspotDetailsDesktop(
            hotspot: hotspot,
            userProfile: _userProfile,
            isAdmin: _isAdmin,
            onReview: _reviewHotspot,
            onReject: _showRejectDialog,
            onDelete: _deleteHotspot,
            onEdit: _showEditHotspotForm,
          ),
        ),
      ),
    );
    return;
  }

  // Mobile View (Bottom Sheet) - Updated to show active status for everyone
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Type: ${crimeType['name']}'),
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
            // Show active status for everyone (not just admins)
            ListTile(
              title: Text(
                'Status: ${activeStatus.toUpperCase()}',
                style: TextStyle(
                  color: activeStatus == 'active' ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: activeStatus == 'active' 
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.grey),
            ),
            if (status != 'approved')
              ListTile(
                title: Text(
                  'Review Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    color: status == 'pending' ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: status == 'rejected' && hotspot['rejection_reason'] != null
                    ? Text('Reason: ${hotspot['rejection_reason']}')
                    : null,
              ),
            // ... rest of the existing action buttons remain the same ...
            if (_isAdmin && status == 'pending')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _reviewHotspot(hotspot['id'], true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Approve'),
                    ),
                    ElevatedButton(
                      onPressed: () => _showRejectDialog(hotspot['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: const Text('Reject'),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteHotspot(hotspot['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            if (!_isAdmin && status == 'pending' && isOwner)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditHotspotForm(hotspot);
                      },
                      child: const Text('Edit'),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteHotspot(hotspot['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            if (status == 'rejected')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isOwner)
                      ElevatedButton(
                        onPressed: () => _deleteHotspot(hotspot['id']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('Delete'),
                      ),
                    if (_isAdmin)
                      ElevatedButton(
                        onPressed: () => _deleteHotspot(hotspot['id']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('Delete'),
                      ),
                  ],
                ),
              ),
            if (_isAdmin && status == 'approved')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditHotspotForm(hotspot);
                      },
                      child: const Text('Edit'),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteHotspot(hotspot['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
          ],
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


Future<void> _deleteHotspot(int id) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Deletion'),
      content: const Text('Are you sure you want to delete this hotspot?'),
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

Widget _buildSearchBar({bool isWeb = false}) {
  return Container(
    width: isWeb ? double.infinity : double.infinity, // full width inside SizedBox on desktop
    height: 40,
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TypeAheadField<LocationSuggestion>(
      controller: _searchController,
      suggestionsCallback: _searchLocations,
      itemBuilder: (context, suggestion) => ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(
          suggestion.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onSelected: _onSuggestionSelected,
builder: (context, controller, focusNode) => SizedBox(
  height: 40, // match container height
  child: TextField(
    controller: controller,
    focusNode: focusNode,
    decoration: InputDecoration(
      hintText: 'Search location...',
      border: InputBorder.none,
      contentPadding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      isDense: true,
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 8, right: 8),
        child: Icon(Icons.search, size: 20),
      ),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
            )
          : null,
          ),
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  final isWeb = kIsWeb || MediaQuery.of(context).size.width >= 800;

  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: isWeb
          ? SizedBox(
              width: 400,
              child: _buildSearchBar(isWeb: true),
            )
          : _buildSearchBar(isWeb: false),
      centerTitle: true,
      actions: [
        // Removed notification bell - only show login/logout
        if (_userProfile == null)
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        if (_userProfile != null)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmation,
          ),
      ],
    ),
    body: _buildCurrentScreen(),
    floatingActionButton: _currentTab == MainTab.map ? _buildFloatingActionButtons() : null,
    bottomNavigationBar: _userProfile != null ? _buildBottomNavBar() : null,
  );
}

Widget _buildCurrentScreen() {
  switch (_currentTab) {
    case MainTab.map:
      return Stack(
        children: [
          _buildMap(),
          if (_isLoading && _currentPosition == null)
            const Center(child: CircularProgressIndicator()),
        ],
      );
    case MainTab.notifications:
      return _buildNotificationsScreen();
    case MainTab.profile:
      return Container(); }
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