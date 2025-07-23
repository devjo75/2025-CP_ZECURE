import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
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

  // Location Methods
  Future<void> _getCurrentLocation() async {
    // ignore: unnecessary_null_comparison
    if (!mounted || context == null) return;

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

  // Live Tracking Methods
  void _startLiveLocation() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          if (_isLiveLocationActive) {
            _polylinePoints.add(_currentPosition!); // Record path
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

  // Directions Methods
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

  // UI Helpers
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

  Future<void> _shareLocation(LatLng position) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
      Navigator.pop(context); // Close bottom sheet
    } else {
      _showSnackBar('Could not launch maps');
    }
  }

  // Widget Builders
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: _buildSearchBar(),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Column(
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

  Widget _buildSearchBar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TypeAheadField<LocationSuggestion>(
          controller: _searchController,
          suggestionsCallback: _searchLocations,
          itemBuilder: (context, suggestion) => ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(suggestion.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          onSelected: _onSuggestionSelected,
          builder: (context, controller, focusNode) => TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search location...',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
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

  // Add a factory constructor for safe parsing
  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name']?.toString() ?? 'Unknown location',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lon: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
    );
  }
}