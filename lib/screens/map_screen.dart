import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/auth/login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
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
  final _authService = AuthService(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
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
        });
      }
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

  void _showLocationOptions(LatLng position) {
    setState(() => _destination = position);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_polylinePoints.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: const Text('Cancel Directions', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _clearDirections();
                },
              ),
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Get Directions'),
              onTap: () {
                Navigator.pop(context);
                _getDirections(position);
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
                title: const Text('Save as Point of Interest'),
                onTap: () => _savePointOfInterest(position),
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

  Future<void> _savePointOfInterest(LatLng position) async {
    _showSnackBar('Point of interest saved (Admin feature)');
    Navigator.pop(context);
  }

  Future<void> _shareLocation(LatLng position) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      Navigator.pop(context);
    } else {
      _showSnackBar('Could not launch maps');
    }
  }

@override
Widget build(BuildContext context) {
  final isWeb = MediaQuery.of(context).size.width > 600;
  
  return Scaffold(
    appBar: AppBar(
      title: _buildSearchBar(isWeb: isWeb),
      leading: _userProfile == null 
          ? IconButton(
              icon: const Icon(Icons.login),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            )
          : null,
      actions: [
        if (_userProfile != null && _isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => _showSnackBar('Admin features enabled'),
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
    drawer: _userProfile != null ? _buildDrawer() : null,
  );
}

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'liveLocation',
          onPressed: _toggleLiveLocation,
          backgroundColor: _isLiveLocationActive ? Colors.blue : Colors.grey,
          mini: true,
          child: Icon(
            _isLiveLocationActive ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'myLocation',
          onPressed: _getCurrentLocation,
          child: const Icon(Icons.my_location),
        ),
        if (_showClearButton) ...[
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'clearRoute',
            onPressed: _clearDirections,
            backgroundColor: Colors.red,
            mini: true,
            child: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }

Widget _buildDrawer() {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(
            '${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}',
            style: const TextStyle(fontSize: 18),
          ),
          accountEmail: Text(_userProfile?['email'] ?? ''),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              _userProfile?['first_name']?.toString().substring(0, 1) ?? 'U',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Profile'),
          onTap: () {
            Navigator.pop(context);
            _showProfileDialog();
          },
        ),
        if (_isAdmin) ...[
          const Divider(),
          const ListTile(
            leading: Icon(Icons.admin_panel_settings, color: Colors.blue),
            title: Text('Admin Tools', style: TextStyle(color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: const Text('Manage Points of Interest'),
            onTap: () => _showSnackBar('POI Management (Admin)'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User Management'),
            onTap: () => _showSnackBar('User Management (Admin)'),
          ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: _showLogoutConfirmation,
        ),
      ],
    ),
  );
}

Future<void> _showLogoutConfirmation() async {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileItem('Name', 
                '${_userProfile?['first_name']} ${_userProfile?['middle_name'] ?? ''} ${_userProfile?['last_name']} ${_userProfile?['ext_name'] ?? ''}'),
              _buildProfileItem('Email', _userProfile?['email']),
              _buildProfileItem('Username', _userProfile?['username']),
              _buildProfileItem('Birthday', 
                _userProfile?['bday'] != null 
                  ? DateFormat('MMM d, y').format(DateTime.parse(_userProfile?['bday'])) 
                  : 'Not specified'),
              _buildProfileItem('Gender', _userProfile?['gender'] ?? 'Not specified'),
              _buildProfileItem('Role', _userProfile?['role'] ?? 'user'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            value ?? 'Not available',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _currentPosition ?? const LatLng(14.5995, 120.9842),
        zoom: 15.0,
        onTap: (tapPosition, latLng) {
          FocusScope.of(context).unfocus();
          _showLocationOptions(latLng);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.zecure',
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
      ],
    );
  }

Widget _buildSearchBar({bool isWeb = false}) {
  return Container(
    width: isWeb ? MediaQuery.of(context).size.width * 0.5 : double.infinity,
    height: 40, // Explicit height to control the container size
    margin: const EdgeInsets.symmetric(vertical: 4), // Reduced vertical margin
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
        height: 38, // Slightly less than container height
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search location...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
            isDense: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 8, right: 8), // Adjusted icon padding
              child: Icon(Icons.search, size: 20), // Smaller icon
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20), // Smaller clear icon
                    padding: EdgeInsets.zero, // Remove default padding
                    constraints: const BoxConstraints(), // Remove default constraints
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