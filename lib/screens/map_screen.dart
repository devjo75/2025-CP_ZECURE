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
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/desktop/report_hotspot_form_desktop.dart' show ReportHotspotFormDesktop;
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/auth/login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zecure/screens/profile_screen.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/desktop/hotspot_filter_dialog_desktop.dart';
import 'package:zecure/desktop/location_options_dialog_desktop.dart';
import 'package:zecure/desktop/add_hotspot_form_desktop.dart';
import 'package:zecure/desktop/hotspot_details_desktop.dart';
import 'package:zecure/desktop/edit_hotspot_form_desktop.dart';





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

  bool _showAdditionalButtons = false;


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
  // ignore: unused_field
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

  void _toggleAdditionalButtons() {
  setState(() {
    _showAdditionalButtons = !_showAdditionalButtons;
  });
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
                        'Filter Hotspots',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
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
                        Colors.yellow,
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
                      if (_userProfile != null) ...[
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
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                  title: const Text('Report Hotspot'),
                  subtitle: const Text('Submit for admin approval'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportHotspotForm(position);
                  },
                ),
              if (_isAdmin)
                ListTile(
                  leading: const Icon(Icons.add_location_alt),
                  title: const Text('Add Hotspot'),
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
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  List<Map<String, dynamic>> crimeTypes = [
    {'id': 1, 'name': 'Theft', 'level': 'medium'},
    {'id': 2, 'name': 'Assault', 'level': 'high'},
    {'id': 3, 'name': 'Vandalism', 'level': 'low'},
    {'id': 4, 'name': 'Burglary', 'level': 'high'},
    {'id': 5, 'name': 'Homicide', 'level': 'critical'},
  ];

  if (crimeTypes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No crime types available.')),
    );
    return;
  }

  String selectedCrimeType = crimeTypes[0]['name'];
  int selectedCrimeId = crimeTypes[0]['id'];

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
          _showSnackBar('Hotspot added successfully');
        }
      } catch (e) {
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
            selectedCrimeType = value;
            selectedCrimeId = crimeTypes.firstWhere((c) => c['name'] == value)['id'];
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
                        child: Text(crimeType['name']),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        selectedCrimeType = newValue;
                        selectedCrimeId = crimeTypes.firstWhere(
                          (crime) => crime['name'] == newValue,
                        )['id'];
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
}





void _showReportHotspotForm(LatLng position) async {
  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  try {
    final crimeTypesResponse = await Supabase.instance.client
        .from('crime_type')
        .select('*')
        .order('name');

    if (crimeTypesResponse.isEmpty) {
      _showSnackBar('No crime types available');
      return;
    }

    final crimeTypes = List<Map<String, dynamic>>.from(crimeTypesResponse);
    String selectedCrimeType = crimeTypes[0]['name'];
    int selectedCrimeId = crimeTypes[0]['id'];

    final now = DateTime.now();
    dateController.text = DateFormat('yyyy-MM-dd').format(now);
    timeController.text = DateFormat('HH:mm').format(now);

    if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
      // Desktop dialog view
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ReportHotspotFormDesktop(
            position: position,
            crimeTypes: crimeTypes,
            onSubmit: (crimeId, description, pos, dateTime) async {
              try {
                await _reportHotspot(crimeId, description, pos, dateTime);
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Hotspot reported successfully. Waiting for admin approval.');
                }
              } catch (e) {
                if (mounted) _showSnackBar('Failed to report hotspot: $e');
              }
            },
            onCancel: () {},
          ),
        ),
      );
      return;
    }

    // Mobile bottom sheet view
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 16.0,
              right: 16.0,
              top: 16.0,
            ),
            child: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
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
                            child: Text(crimeType['name']),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedCrimeType = newValue;
                              selectedCrimeId = crimeTypes.firstWhere(
                                (crime) => crime['name'] == newValue,
                              )['id'];
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
                            dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
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
                                '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
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
                                  Navigator.pop(context);
                                  _showSnackBar(
                                      'Hotspot reported successfully. Waiting for admin approval.');
                                }
                              } catch (e) {
                                if (mounted) {
                                  _showSnackBar(
                                      'Failed to report hotspot: ${e.toString()}');
                                }
                              }
                            }
                          },
                          child: const Text('Submit Report'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  } catch (e) {
    if (mounted) {
      _showSnackBar('Error loading crime types: ${e.toString()}');
    }
  }
}



// Add this method to handle user reports
Future<void> _reportHotspot(
  int typeId, 
  String description, 
  LatLng position, 
  DateTime dateTime
) async {
  final response = await Supabase.instance.client
      .from('hotspot')
      .insert({
        'type_id': typeId,
        'description': description,
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'time': dateTime.toIso8601String(),
        'status': 'pending',
        'created_by': _userProfile?['id'],
        'reported_by': _userProfile?['id'],
      })
      .select('''
        *,
        crime_type: type_id (id, name, level)
      ''');

  if (mounted) {
    setState(() {
      _hotspots.add(response[0]);
    });
  }
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
      if (_showAdditionalButtons) ...[
        Tooltip(
          message: 'Filter Hotspots',
          child: FloatingActionButton(
            heroTag: 'filterHotspots',
            onPressed: () {
              _showHotspotFilterDialog();
              _toggleAdditionalButtons();
            },
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            mini: true,
            child: const Icon(Icons.filter_alt),
          ),
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: _isLiveLocationActive ? 'Live Location On' : 'Live Location Off',
          child: FloatingActionButton(
            heroTag: 'liveLocation',
            onPressed: () {
              _toggleLiveLocation();
              _toggleAdditionalButtons();
            },
            backgroundColor: _isLiveLocationActive ? const Color.fromARGB(255, 25, 210, 133) : Colors.grey.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            mini: true,
            child: Icon(
              _isLiveLocationActive ? Icons.location_searching : Icons.location_disabled,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_showClearButton) ...[
          Tooltip(
            message: 'Clear Route',
            child: FloatingActionButton(
              heroTag: 'clearRoute',
              onPressed: () {
                _clearDirections();
                _toggleAdditionalButtons();
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
          const SizedBox(height: 8),
        ],
      ],
      Tooltip(
        message: 'Show Actions',
        child: FloatingActionButton(
          heroTag: 'mainActionButton',
          onPressed: _toggleAdditionalButtons,
          backgroundColor: Colors.grey.shade300, // Light gray color
          foregroundColor: Colors.black,
          mini: true, // Minimize the button size
          child: const Icon(Icons.menu),
        ),
      ),
      const SizedBox(height: 8),
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
              color: _isLiveLocationActive ? Colors.green : Colors.blue,
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
      // Hotspots layer (appears on top of other markers)
Consumer<HotspotFilterService>(
  builder: (context, filterService, child) {
    return MarkerLayer(
      markers: _hotspots.where((hotspot) {
        final currentUserId = _userProfile?['id'];
        final isAdmin = _isAdmin;
        final status = hotspot['status'] ?? 'approved';
        final createdBy = hotspot['created_by'];
        final reportedBy = hotspot['reported_by'];

        // Admins can see all hotspots based on filter settings
        if (isAdmin) {
          return filterService.shouldShowHotspot(hotspot);
        }
        // Regular users can see approved hotspots based on filter settings
        else if (status == 'approved' && filterService.shouldShowHotspot(hotspot)) {
          return true;
        }
        // Regular users can see their own pending or rejected hotspots if the respective filters are on
        else if (currentUserId != null && (currentUserId == createdBy || currentUserId == reportedBy)) {
          if ((status == 'pending' && filterService.showPending) ||
              (status == 'rejected' && filterService.showRejected)) {
            return true;
          }
        }
        return false;
      }).map((hotspot) {
        // Your existing marker creation logic
        final coords = hotspot['location']['coordinates'];
        final point = LatLng(coords[1], coords[0]);
        final status = hotspot['status'] ?? 'approved';
        final crimeLevel = hotspot['crime_type']['level'];
        Color markerColor;
        IconData markerIcon;

        if (status == 'pending') {
          markerColor = Colors.deepPurple;
          markerIcon = Icons.question_mark;
        } else if (status == 'rejected') {
          markerColor = Colors.grey;
          markerIcon = Icons.block;
        } else {
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
        }

        return Marker(
          point: point,
          width: 40,
          height: 40,
          builder: (ctx) => GestureDetector(
            onTap: () => _showHotspotDetails(hotspot),
            child: Container(
              decoration: BoxDecoration(
                color: markerColor.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                markerIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      }).toList(),
    );
  },
)
,
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
  final isOwner = hotspot['created_by'] == _userProfile?['id'] ||
      hotspot['reported_by'] == _userProfile?['id'];

  // Desktop/Web View
  if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
  showDialog(
  context: context,
  barrierColor: Colors.black.withOpacity(0.3), // Optional dim
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

  // Mobile View (Bottom Sheet)
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
            if (status != 'approved')
              ListTile(
                title: Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    color: status == 'pending' ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: status == 'rejected' && hotspot['rejection_reason'] != null
                    ? Text('Reason: ${hotspot['rejection_reason']}')
                    : null,
              ),
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
      title: const Text('Reject Hotspot'),
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
    await Supabase.instance.client
        .from('hotspot')
        .update({
          'status': approve ? 'approved' : 'rejected',
          'rejection_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
          // If approved, transfer ownership to admin
          if (approve) 'created_by': _userProfile?['id'],
        })
        .eq('id', id);

    await _loadHotspots();
    if (mounted) {
      Navigator.pop(context); // Close details sheet
      _showSnackBar(approve ? 'Hotspot approved' : 'Hotspot rejected');
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('Failed to review hotspot: ${e.toString()}');
    }
  }
}

void _showEditHotspotForm(Map<String, dynamic> hotspot) {
  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController(text: hotspot['description'] ?? '');
  final dateController = TextEditingController(text: DateTime.parse(hotspot['time']).toLocal().toString().split(' ')[0]);
  final timeController = TextEditingController(text: DateFormat('HH:mm').format(DateTime.parse(hotspot['time']).toLocal()));

  List<Map<String, dynamic>> crimeTypes = [
    {'id': 1, 'name': 'Theft', 'level': 'medium'},
    {'id': 2, 'name': 'Assault', 'level': 'high'},
    {'id': 3, 'name': 'Vandalism', 'level': 'low'},
    {'id': 4, 'name': 'Burglary', 'level': 'high'},
    {'id': 5, 'name': 'Homicide', 'level': 'critical'},
  ];

  String selectedCrimeType = hotspot['crime_type']['name'];
  int selectedCrimeId = hotspot['type_id'];

  // Desktop/Web view
  if (kIsWeb || MediaQuery.of(context).size.width >= 800) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: EditHotspotFormDesktop(
          hotspot: hotspot,
          onUpdate: (id, crimeId, description, time) async {
            try {
              await _updateHotspot(id, crimeId, description, time);
              await _loadHotspots();
              if (mounted) {
                Navigator.pop(context);
                _showSnackBar('Hotspot updated successfully');
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update hotspot: $e')),
                );
              }
            }
          },
          onCancel: () {
            _showHotspotDetails(hotspot);
          },
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
                        child: Text(crimeType['name']),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedCrimeType = newValue;
                          selectedCrimeId = crimeTypes.firstWhere((crime) => crime['name'] == newValue)['id'];
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
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
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
                        dateController.text = pickedDate.toString().split(' ')[0];
                      }
                    },
                  ),
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
                              );
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
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the edit form
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
              width: 400, // or any width you want for desktop
              child: _buildSearchBar(isWeb: true),
            )
          : _buildSearchBar(isWeb: false),
      centerTitle: true, // center the title widget
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
