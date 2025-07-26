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

enum MainTab { map, profile }

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

  MainTab _currentTab = MainTab.map;
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _extNameController;
  late TextEditingController _passwordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _extNameController = TextEditingController();
    _passwordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    // Dispose controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _extNameController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    
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
          
          // Initialize form fields with user data
          _firstNameController.text = response['first_name'] ?? '';
          _lastNameController.text = response['last_name'] ?? '';
          _middleNameController.text = response['middle_name'] ?? '';
          _extNameController.text = response['ext_name'] ?? '';
          _selectedGender = response['gender'];
          _selectedBirthday = response['bday'] != null 
              ? DateTime.parse(response['bday']) 
              : null;
        });
      }
    }
  }

Future<void> _updateProfile() async {
  if (!_profileFormKey.currentState!.validate()) return;

  try {
    // Update password if new password is provided
    if (_newPasswordController.text.isNotEmpty) {
      await _authService.updatePassword(
        currentPassword: _passwordController.text,
        newPassword: _newPasswordController.text,
      );
    }

    // Update user profile data
    final updateData = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'middle_name': _middleNameController.text.isEmpty ? null : _middleNameController.text,
      'ext_name': _extNameController.text.isEmpty ? null : _extNameController.text,
      'gender': _selectedGender,
      'bday': _selectedBirthday?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await Supabase.instance.client
        .from('users')
        .update(updateData)
        .eq('id', _userProfile!['id'] as Object);

    if (mounted) {
      setState(() {
        _isEditingProfile = false;
      });
      // Clear password fields
      _passwordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      
      // Show success message (don't close edit dialog yet)
      _showSuccessDialog('Profile updated successfully!', onOkPressed: () {
        // After clicking OK:
        // 1. Close the edit dialog
        Navigator.of(context).pop(); 
        // 2. Show the profile view dialog
        _showProfileDialog();
      });
      
      _loadUserProfile(); // Refresh profile data
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('Error updating profile: ${e.toString()}');
    }
  }
}

void _showSuccessDialog(String message, {VoidCallback? onOkPressed}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Success'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the success dialog
            if (onOkPressed != null) {
              onOkPressed(); // Execute the callback
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
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
    setState(() {
      _currentTab = MainTab.map;
      _destination = position;
    });
    
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
    return Scaffold(
appBar: AppBar(
  automaticallyImplyLeading: false, // This removes the back button
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
    if (_userProfile != null && _isAdmin)
      IconButton(
        icon: const Icon(Icons.admin_panel_settings),
        onPressed: () => _showSnackBar('Admin features enabled'),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _isEditingProfile 
            ? _buildEditProfileForm()
            : _buildProfileView(),
      ),
    ).then((_) {
      // When the dialog is closed, switch back to map tab if not editing
      if (!_isEditingProfile) {
        setState(() => _currentTab = MainTab.map);
      }
    });
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 30,
                  child: Text(
                    _userProfile?['first_name']?.toString().substring(0, 1) ?? 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userProfile?['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          _userProfile?['role']?.toUpperCase() ?? 'USER',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: _isAdmin ? Colors.blue : Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                _buildProfileInfoItem(
                  icon: Icons.person_outline,
                  label: 'Username',
                  value: _userProfile?['username'] ?? 'Not set',
                ),
                _buildProfileInfoItem(
                  icon: Icons.cake_outlined,
                  label: 'Birthday',
                  value: _userProfile?['bday'] != null
                      ? DateFormat('MMMM d, y').format(
                          DateTime.parse(_userProfile?['bday']))
                      : 'Not specified',
                ),
                _buildProfileInfoItem(
                  icon: Icons.transgender,
                  label: 'Gender',
                  value: _userProfile?['gender'] ?? 'Not specified',
                ),
                if (_userProfile?['middle_name'] != null)
                  _buildProfileInfoItem(
                    icon: Icons.perm_identity,
                    label: 'Middle Name',
                    value: _userProfile?['middle_name'],
                  ),
                if (_userProfile?['ext_name'] != null)
                  _buildProfileInfoItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Extension Name',
                    value: _userProfile?['ext_name'],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _isEditingProfile = true);
                      Navigator.pop(context);
                      _showProfileDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'EDIT PROFILE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showSnackBar('Admin features'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                      child: const Text(
                        'ADMIN DASHBOARD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _profileFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _middleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Middle Name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _extNameController,
                        decoration: const InputDecoration(
                          labelText: 'Extension Name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'LGBTQ+', 'Other']
                            .map((gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedGender = value),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(
                          _selectedBirthday == null
                              ? 'Select Birthday'
                              : 'Birthday: ${DateFormat('MMM d, y').format(_selectedBirthday!)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedBirthday ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _selectedBirthday = date);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Leave blank to keep current password',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Current Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (_newPasswordController.text.isNotEmpty &&
                              (value?.isEmpty ?? true)) {
                            return 'Required to change password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (_newPasswordController.text.isNotEmpty &&
                              value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () {
          // Reset editing state
          setState(() {
            _isEditingProfile = false;
          });
          
          // Clear password fields
          _passwordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          
          // Close edit dialog and show profile view
          Navigator.of(context).pop();
          _showProfileDialog();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey.shade400),
        ),
        child: const Text('CANCEL'),
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: ElevatedButton(
        onPressed: _updateProfile,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('SAVE CHANGES'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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