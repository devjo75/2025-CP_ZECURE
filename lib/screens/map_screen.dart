import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zecure/screens/profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum MainTab { map, profile }

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
  bool _isLiveLocationActive = false;
  bool _showClearButton = false;

  // User state
  Map<String, dynamic>? _userProfile;
  bool _isAdmin = false;
  MainTab _currentTab = MainTab.map;
  late ProfileScreen _profileScreen;

  // Hotspot state
  List<Map<String, dynamic>> _hotspots = [];
  Map<String, dynamic>? _selectedHotspot;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadHotspots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _profileScreen.disposeControllers();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
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

  Future<void> _loadHotspots() async {
    final response = await Supabase.instance.client
        .from('hotspot')
        .select('''
          *,
          crime_type: type_id (id, name, level)
        ''');

    if (mounted) {
      setState(() {
        _hotspots = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
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
        _showSnackBar('Error getting location: ${e.toString()}');
      }
    }
  }

  void _startLiveLocation() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          if (_isLiveLocationActive) {
            _polylinePoints.add(_currentPosition!);
          }
        });
        _mapController.move(_currentPosition!, _mapController.zoom);
      }
    });
    setState(() {
      _isLiveLocationActive = true;
    });
    _showSnackBar('Live tracking enabled');
  }

  void _stopLiveLocation() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isLiveLocationActive = false;
    });
    _showSnackBar('Live tracking disabled');
  }

  void _toggleLiveLocation() {
    if (_isLiveLocationActive) {
      _stopLiveLocation();
    } else {
      _startLiveLocation();
    }
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
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentPosition!.longitude},${_currentPosition!.latitude};'
        '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      ));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];

        setState(() {
          _distance = route['distance'] / 1000;
          _duration = _formatDuration(route['duration']);
          _polylinePoints = (route['geometry']['coordinates'] as List)
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();
          _destination = destination;
          _showClearButton = true;
        });
        _mapController.fitBounds(
          LatLngBounds(_currentPosition!, destination),
          options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
        );
      }
    } catch (e) {
      _showSnackBar('Failed to get directions: ${e.toString()}');
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
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

void _showLocationOptions(LatLng position) async {
  setState(() {
    _currentTab = MainTab.map;
    _destination = position;
  });

  // Get location name using reverse geocoding
  String locationName = "Loading location...";
  try {
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1')
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      locationName = data['display_name'] ?? 
                    "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
    }
  } catch (e) {
    locationName = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
  }

  showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display the location name
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              locationName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(),
          if (_polylinePoints.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text('Cancel Route', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _clearDirections();
              },
            ),
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
          if (_isAdmin)
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: const Text('Add Hotspot'),
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
              ),
            ),
        ],
      ),
    ),
  );
}

// Helper methods for safe route calculation
double _calculateDistance(LatLng point1, LatLng point2) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Meter, point1, point2);
}

Future<List<LatLng>> _getRouteFromAPI(LatLng start, LatLng end) async {
  final response = await http.get(Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${start.longitude},${start.latitude};'
    '${end.longitude},${end.latitude}?overview=full&geometries=geojson',
  ));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final route = data['routes'][0];
    return (route['geometry']['coordinates'] as List)
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
  }
  throw Exception('Failed to get route');
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
  
  final response = await http.get(Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${start.longitude},${start.latitude};'
    '$waypointsStr;'
    '${end.longitude},${end.latitude}?overview=full&geometries=geojson',
  ));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final route = data['routes'][0];
    return (route['geometry']['coordinates'] as List)
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
  }
  throw Exception('Failed to get route with waypoints');
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

void _showAddHotspotForm(LatLng position) {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // Sample list of crime types - this should ideally come from your database
  List<Map<String, dynamic>> crimeTypes = [
    {'id': 1, 'name': 'Theft', 'level': 'medium'},
    {'id': 2, 'name': 'Assault', 'level': 'high'},
    {'id': 3, 'name': 'Vandalism', 'level': 'low'},
    {'id': 4, 'name': 'Burglary', 'level': 'high'},
    {'id': 5, 'name': 'Homicide', 'level': 'critical'},
  ];

  // Ensure crimeTypes is not empty
  if (crimeTypes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No crime types available.')),
    );
    return;
  }

  // Track both the selected name and ID
  String selectedCrimeType = crimeTypes[0]['name'];
  int selectedCrimeId = crimeTypes[0]['id'];

  final now = DateTime.now();
  _dateController.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  _timeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCrimeType,
              decoration: const InputDecoration(labelText: 'Crime Type'),
              items: crimeTypes.map((crimeType) {
                return DropdownMenuItem<String>(
                  value: crimeType['name'],
                  child: Text(crimeType['name']),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedCrimeType = newValue;
                    // Update the ID when name changes
                    selectedCrimeId = crimeTypes.firstWhere(
                      (crime) => crime['name'] == newValue)['id'];
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
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date'),
              readOnly: true,
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  _dateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                }
              },
            ),
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time'),
              readOnly: true,
              onTap: () async {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  _timeController.text = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    final dateTime = DateTime(
                      int.parse(_dateController.text.split('-')[0]),
                      int.parse(_dateController.text.split('-')[1]),
                      int.parse(_dateController.text.split('-')[2]),
                      int.parse(_timeController.text.split(':')[0]),
                      int.parse(_timeController.text.split(':')[1]),
                    );

                    print('Attempting to save hotspot with:');
                    print('Type ID: $selectedCrimeId');
                    print('Description: ${_descriptionController.text}');
                    print('Position: $position');
                    print('DateTime: $dateTime');
                    print('Created by: ${_userProfile?['id']}');

                    await _saveHotspot(
                      selectedCrimeId.toString(),
                      _descriptionController.text,
                      position,
                      dateTime,
                    );

                    print('Hotspot saved successfully');
                    
                    // Refresh the hotspots list
                    await _loadHotspots();
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _showSnackBar('Hotspot added successfully');
                    }
                  } catch (e) {
                    print('Error saving hotspot: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save hotspot: ${e.toString()}'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    ),
  );
}



Future<void> _saveHotspot(String typeId, String description, LatLng position, DateTime dateTime) async {
  try {
    final response = await Supabase.instance.client
        .from('hotspot')
        .insert({
          'type_id': int.parse(typeId), // Convert to int
          'description': description,
          'location': 'POINT(${position.longitude} ${position.latitude})',
          'time': dateTime.toIso8601String(),
          'created_by': _userProfile?['id'],
        })
        .select('''
          *,
          crime_type: type_id (id, name, level)
        '''); // Include the crime_type relation in the response

    if (mounted) {
      setState(() {
        _hotspots.add(response[0]);
      });
      _showSnackBar('Hotspot saved successfully');
    }
  } catch (e) {
    _showSnackBar('Failed to save hotspot: ${e.toString()}');
    print('Error details: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _buildSearchBar(isWeb: false),
        actions: [
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
      body: Stack(
        children: [
          _buildMap(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      bottomNavigationBar: _userProfile != null ? _buildBottomNavBar() : null,
    );
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
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
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
        Tooltip(
          message: _isLiveLocationActive ? 'Live Location On' : 'Live Location Off',
          child: FloatingActionButton(
            heroTag: 'liveLocation',
            onPressed: _toggleLiveLocation,
            backgroundColor: _isLiveLocationActive ? const Color.fromARGB(255, 25, 210, 133) : Colors.grey.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            mini: true,
            child: Icon(
              _isLiveLocationActive ? Icons.location_searching : Icons.location_disabled,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
        if (_showClearButton) ...[
          const SizedBox(height: 12),
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
        ],
      ],
    );
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
        // Handle map taps to show location options
        FocusScope.of(context).unfocus();
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
      if (_currentPosition != null)
        MarkerLayer(
          markers: [
            Marker(
              point: _currentPosition!,
              width: 40,
              height: 40,
              builder: (ctx) => Icon(
                Icons.location_on,
                color: _isLiveLocationActive ? Colors.green : Colors.red,
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
      if (_polylinePoints.isNotEmpty)
        PolylineLayer(
          polylines: [
            Polyline(
              points: _polylinePoints,
              color: _isLiveLocationActive ? Colors.green : Colors.blue,
              strokeWidth: 4,
            ),
          ],
        ),
      // Hotspot markers layer - placed on top of everything else
      MarkerLayer(
        markers: _hotspots.map((hotspot) {
          final lat = hotspot['location']['coordinates'][1];
          final lng = hotspot['location']['coordinates'][0];
          final crimeLevel = hotspot['crime_type']['level'];
          Color markerColor;
          switch (crimeLevel) {
            case 'critical':
              markerColor = Colors.red;
              break;
            case 'high':
              markerColor = Colors.orange;
              break;
            case 'medium':
              markerColor = Colors.yellow;
              break;
            case 'low':
              markerColor = Colors.green;
              break;
            default:
              markerColor = Colors.grey;
          }
          return Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            builder: (ctx) => GestureDetector(
              onTap: () {
                _showHotspotDetails(hotspot);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}



void _showHotspotDetails(Map<String, dynamic> hotspot) async {
  // Get coordinates from hotspot
  final lat = hotspot['location']['coordinates'][1];
  final lng = hotspot['location']['coordinates'][0];
  final coordinates = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";
  
  // Initialize location info
  String address = "Loading address...";
  String fullLocation = coordinates;

  // Format the time with AM/PM
  final DateTime time = DateTime.parse(hotspot['time']).toLocal();
  final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(time);

  // Try to get human-readable address
  try {
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1')
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      address = data['display_name'] ?? "Unknown location";
      fullLocation = "$address\n$coordinates";
    }
  } catch (e) {
    print('Error getting location name: $e');
    address = "Could not load address";
    fullLocation = "$address\n$coordinates";
  }

  showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Type: ${hotspot['crime_type']['name']}'),
            subtitle: Text('Level: ${hotspot['crime_type']['level']}'),
          ),
          ListTile(
            title: const Text('Description:'),
            subtitle: Text(hotspot['description'] ?? 'No description'),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
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
            subtitle: Text(formattedTime), // Now shows formatted time with AM/PM
          ),
          if (_isAdmin)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditHotspotForm(hotspot);
                  },
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _deleteHotspot(hotspot['id']),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

void _showEditHotspotForm(Map<String, dynamic> hotspot) {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController(text: hotspot['description'] ?? '');
  final _dateController = TextEditingController(text: DateTime.parse(hotspot['time']).toString().split(' ')[0]);
  final _timeController = TextEditingController(text: DateTime.parse(hotspot['time']).toString().split(' ')[1].substring(0, 5));

  // Sample list of crime types - should match your add form
  List<Map<String, dynamic>> crimeTypes = [
    {'id': 1, 'name': 'Theft', 'level': 'medium'},
    {'id': 2, 'name': 'Assault', 'level': 'high'},
    {'id': 3, 'name': 'Vandalism', 'level': 'low'},
    {'id': 4, 'name': 'Burglary', 'level': 'high'},
    {'id': 5, 'name': 'Homicide', 'level': 'critical'},
  ];

  // Set initial selected crime type based on the hotspot's current type
  String selectedCrimeType = hotspot['crime_type']['name'];
  int selectedCrimeId = hotspot['type_id'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCrimeType,
              decoration: const InputDecoration(labelText: 'Crime Type'),
              items: crimeTypes.map((crimeType) {
                return DropdownMenuItem<String>(
                  value: crimeType['name'],
                  child: Text(crimeType['name']),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedCrimeType = newValue;
                    selectedCrimeId = crimeTypes.firstWhere(
                      (crime) => crime['name'] == newValue)['id'];
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
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            TextFormField(
              controller: _dateController,
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
                  _dateController.text = pickedDate.toString().split(' ')[0];
                }
              },
            ),
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time'),
              readOnly: true,
              onTap: () async {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(DateTime.parse(hotspot['time'])),
                );
                if (pickedTime != null) {
                  _timeController.text = pickedTime.format(context);
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    final dateTime = DateTime.parse('${_dateController.text} ${_timeController.text}');
                    
                    print('Updating hotspot with:');
                    print('Type ID: $selectedCrimeId');
                    print('Description: ${_descriptionController.text}');
                    print('DateTime: $dateTime');

                    await _updateHotspot(
                      hotspot['id'],
                      selectedCrimeId,
                      _descriptionController.text,
                      dateTime,
                    );
                    
                    // Refresh the hotspots list
                    await _loadHotspots();
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _showSnackBar('Hotspot updated successfully');
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
          ],
        ),
      ),
    ),
  );
}

Future<void> _updateHotspot(int id, int typeId, String description, DateTime dateTime) async {
  try {
    await Supabase.instance.client
        .from('hotspot')
        .update({
          'type_id': typeId, // Now using the passed typeId
          'description': description,
          'time': dateTime.toIso8601String(),
        })
        .eq('id', id)
        .select('''
          *,
          crime_type: type_id (id, name, level)
        '''); // Include the relation in response

    if (mounted) {
      _showSnackBar('Hotspot updated successfully');
      _loadHotspots(); // Refresh the list
    }
  } catch (e) {
    _showSnackBar('Failed to update hotspot: ${e.toString()}');
    print('Update error details: $e');
  }
}

  Future<void> _deleteHotspot(int id) async {
    try {
      await Supabase.instance.client
          .from('hotspot')
          .delete()
          .eq('id', id);

      if (mounted) {
        setState(() {
          _hotspots.removeWhere((hotspot) => hotspot['id'] == id);
        });
        _showSnackBar('Hotspot deleted successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to delete hotspot: ${e.toString()}');
    }
  }

  Widget _buildSearchBar({bool isWeb = false}) {
    return Container(
      width: isWeb ? MediaQuery.of(context).size.width * 0.5 : double.infinity,
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
          title: Text(suggestion.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        onSelected: _onSuggestionSelected,
        builder: (context, controller, focusNode) => SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search location...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Future<List<LocationSuggestion>> _searchLocations(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => LocationSuggestion(
          displayName: item['display_name'],
          lat: double.parse(item['lat']),
          lon: double.parse(item['lon']),
        )).toList();
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: ${e.toString()}')),
        );
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
