// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:zecure/auth/login_screen.dart';
import 'package:zecure/screens/admin_dashboard.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

enum PasswordButtonState { normal, changing, changed }

enum SaveButtonState { normal, saving, saved }

enum ProfilePictureState { normal, uploading, success, error }

class ProfileScreen {
  final AuthService _authService;
  Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final bool hasAdminPermissions;
  final VoidCallback? onProfileUpdated; // ✅ ADD THIS
  final LatLng? currentLocation;
  final ScrollController _scrollController = ScrollController();
  SaveButtonState _saveButtonState = SaveButtonState.normal;
  Timer? _buttonStateTimer;
  final ScrollController _profileViewScrollController = ScrollController();

  ProfileScreen(
    this._authService,
    this.userProfile,
    this.isAdmin,
    this.hasAdminPermissions, {
    this.onProfileUpdated, // ✅ ADD THIS
    this.currentLocation,
  });
  ProfilePictureState _profilePictureState = ProfilePictureState.normal;
  Timer? _profilePictureStateTimer;
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers and state
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _extNameController;
  late TextEditingController _contactNumberController;
  String? _selectedGender;
  DateTime? _selectedBirthday;
  bool _isEditingProfile = false;
  final _profileFormKey = GlobalKey<FormState>();

  // ignore: unnecessary_getters_setters
  bool get isEditingProfile => _isEditingProfile;
  set isEditingProfile(bool value) => _isEditingProfile = value;

  bool get _hasAnyChanges =>
      _hasProfileChanges() ||
      (_hasEmailChanges() && userProfile?['registration_type'] == 'simple');

  //PROFILE PAGE TO ALWAYS START FROM THE TOP
  bool _shouldScrollToTop = false;

  // Add these after your existing controllers and state variables
  List<Map<String, dynamic>> _policeRanks = [];
  List<Map<String, dynamic>> _policeStations = [];
  int? _selectedPoliceRankId;
  int? _selectedPoliceStationId;

  bool _forceEmailVerification = false;
  bool _isVerifyingCurrentEmail = false;
  //SWITCH TAB PERSONAL INFO AND POLICE INFO
  int _selectedTab = 0;

  void resetTab() {
    _selectedTab = 0;
  }

  // Email editing and verification state

  late TextEditingController _emailController;
  String? _pendingEmailChange; // Keep this for the modal
  Timer? _emailResendTimer; // Keep this for the modal
  int _emailResendCountdown = 60;
  bool _canResendEmailOTP = false;
  bool _isUpdatingEmail = false;
  bool _isEmailFieldReadOnly = false;
  StateSetter? _currentModalSetState;

  // Change Password Modal State
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  PasswordButtonState _passwordButtonState = PasswordButtonState.normal;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  Timer? _passwordButtonStateTimer;

  Future<List<Map<String, dynamic>>>? _studentParentsFuture;
  Future<List<Map<String, dynamic>>>? _parentStudentsFuture;
  Future<List<Map<String, dynamic>>>? _pendingRequestsFuture;

  void initControllers() {
    _firstNameController = TextEditingController(
      text: userProfile?['first_name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: userProfile?['last_name'] ?? '',
    );
    _middleNameController = TextEditingController(
      text: userProfile?['middle_name'] ?? '',
    );
    _extNameController = TextEditingController(
      text: userProfile?['ext_name'] ?? '',
    );
    _emailController = TextEditingController(text: userProfile?['email'] ?? '');
    _selectedGender = userProfile?['gender'];
    _selectedBirthday = userProfile?['bday'] != null
        ? DateTime.parse(userProfile?['bday'])
        : null;
    _selectedPoliceRankId = userProfile?['police_rank_id'];
    _selectedPoliceStationId = userProfile?['police_station_id'];

    String contactNumber = userProfile?['contact_number'] ?? '';
    if (contactNumber.isEmpty) {
      contactNumber = '+63';
    }
    _contactNumberController = TextEditingController(text: contactNumber);

    if (userProfile?['role'] == 'officer') {
      _loadPoliceData();
    }
    if (userProfile?['role'] == 'officer' || userProfile?['role'] == 'admin') {
      _loadLocationSharingState();
    }

    // ✅ ADD THIS: Initialize relationship data
    _initializeRelationshipData();
  }

  void disposeControllers() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _extNameController.dispose();
    _contactNumberController.dispose();
    _scrollController.dispose();
    _profileViewScrollController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _profilePictureStateTimer?.cancel();
    _buttonStateTimer?.cancel();
    _emailResendTimer?.cancel();
    _locationSharingTimer?.cancel();
  }

  /// Initialize relationship data based on user type
  void _initializeRelationshipData() {
    if (userProfile == null) return;

    if (userProfile!['user_type'] == 'wmsu_student') {
      _studentParentsFuture = _loadStudentParents();
      _pendingRequestsFuture = _loadPendingParentRequests();
    } else if (userProfile!['user_type'] == 'wmsu_parent') {
      _parentStudentsFuture = _loadParentStudents();
    }
  }

  /// Refresh relationship data (call this after actions like accept/reject/send)
  void _refreshRelationships() {
    if (userProfile == null) return;

    if (userProfile!['user_type'] == 'wmsu_student') {
      _studentParentsFuture = _loadStudentParents();
      _pendingRequestsFuture = _loadPendingParentRequests();
    } else if (userProfile!['user_type'] == 'wmsu_parent') {
      _parentStudentsFuture = _loadParentStudents();
    }
  }

  bool _hasEmailChanges() {
    if (userProfile?['registration_type'] != 'simple') return false;

    final currentEmail = userProfile?['email'] ?? '';
    final newEmail = _emailController.text.trim();

    // Return true if email actually changed OR if user wants to verify current email
    return newEmail != currentEmail || _forceEmailVerification;
  }

  // ignore: unused_element
  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final today = DateTime.now();
    int age = today.year - birthDate.year;

    // Check if birthday hasn't occurred this year yet
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  bool _hasProfileChanges() {
    return _firstNameController.text != (userProfile?['first_name'] ?? '') ||
        _lastNameController.text != (userProfile?['last_name'] ?? '') ||
        _middleNameController.text != (userProfile?['middle_name'] ?? '') ||
        _extNameController.text != (userProfile?['ext_name'] ?? '') ||
        _selectedGender != userProfile?['gender'] ||
        _contactNumberController.text !=
            (userProfile?['contact_number'] ?? '') ||
        (_selectedBirthday?.toIso8601String().split('T')[0] !=
            (userProfile?['bday'] != null
                ? DateTime.parse(
                    userProfile!['bday'],
                  ).toIso8601String().split('T')[0]
                : null)) ||
        _selectedPoliceRankId != userProfile?['police_rank_id'] ||
        _selectedPoliceStationId != userProfile?['police_station_id'];
  }

  // In your ProfileScreen class, add this method:
  void resetSaveButtonState() {
    _saveButtonState = SaveButtonState.normal;
  }

  bool _isLocationSharing = false;
  Timer? _locationSharingTimer;

  // ✅ ADD THIS GETTER/SETTER PAIR RIGHT AFTER _isLocationSharing
  bool get isLocationSharing => _isLocationSharing;

  void updateLocationSharingState(bool value) {
    _isLocationSharing = value;
  }

  Future<void> _loadLocationSharingState() async {
    if (userProfile?['id'] == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_sharing_location')
          .eq('id', userProfile!['id'])
          .single();

      _isLocationSharing = response['is_sharing_location'] ?? false;
    } catch (e) {
      print('Error loading location sharing state: $e');
    }
  }

  //TOGGLE LOCATION SHARING
  bool _isTogglingLocationSharing = false;
  Future<void> _toggleLocationSharing(
    BuildContext context,
    StateSetter setState,
  ) async {
    if (userProfile?['id'] == null) return;

    if (_isTogglingLocationSharing) return;

    setState(() {
      _isTogglingLocationSharing = true;
    });

    try {
      final newState = !_isLocationSharing;

      // ✅ Use the location passed from MapScreen (already available!)
      final locationToUse = newState ? currentLocation : null;

      await Supabase.instance.client
          .from('users')
          .update({
            'is_sharing_location': newState,
            'current_latitude': locationToUse?.latitude,
            'current_longitude': locationToUse?.longitude,
            'last_location_update': newState
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', userProfile!['id']);

      setState(() {
        _isLocationSharing = newState;
        _isTogglingLocationSharing = false;
      });

      if (onProfileUpdated != null) {
        onProfileUpdated!();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState
                  ? 'Location sharing enabled'
                  : 'Location sharing disabled',
            ),
            backgroundColor: newState ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isTogglingLocationSharing = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLocationSharingToggle(
    BuildContext context,
    StateSetter setStateHeader, {
    bool isMobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isLocationSharing
            ? Colors.green.withOpacity(0.15)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLocationSharing
              ? Colors.green
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isTogglingLocationSharing
              ? null // Disable tap while loading
              : () => _toggleLocationSharing(context, setStateHeader),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 12,
              vertical: isMobile ? 12 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Show loading spinner or icon
                if (_isTogglingLocationSharing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isLocationSharing ? Colors.green : Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(
                    _isLocationSharing ? Icons.my_location : Icons.location_off,
                    size: 18,
                    color: _isLocationSharing ? Colors.green : Colors.white,
                  ),
                if (!isMobile) ...[
                  const SizedBox(width: 6),
                  Text(
                    _isTogglingLocationSharing
                        ? 'Updating...'
                        : (_isLocationSharing ? 'Sharing' : 'Share Location'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isLocationSharing ? Colors.green : Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Icon-only version for desktop (keeping same method name but with iconOnly parameter)
  Widget _buildLocationSharingIconOnly(
    BuildContext context,
    StateSetter setStateHeader,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _isLocationSharing
            ? Colors.green.withOpacity(0.15)
            : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLocationSharing
              ? Colors.green
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isTogglingLocationSharing
              ? null // Disable tap while loading
              : () => _toggleLocationSharing(context, setStateHeader),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: _isTogglingLocationSharing
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isLocationSharing ? Colors.green : Colors.white,
                      ),
                    )
                  : Icon(
                      _isLocationSharing
                          ? Icons.my_location
                          : Icons.location_off,
                      size: 18,
                      color: _isLocationSharing ? Colors.green : Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  //PROFILE PICTURE METHOD
  Future<void> _uploadProfilePicture(
    BuildContext context, {
    Function(VoidCallback)? onStateChange,
  }) async {
    try {
      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        if (kDebugMode) {
          print(
            'Image picker returned null - user cancelled or error occurred',
          );
        }
        return;
      }

      if (kDebugMode) {
        print('Image picked: ${image.path}');
        print('Image name: ${image.name}');
      }

      // Set uploading state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.uploading;
      });

      final userId = userProfile!['id'] as String;
      final fileExtension = path.extension(image.path).toLowerCase();
      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = '$userId/$fileName';

      // Get clean extension without dot for content type
      final cleanExtension = fileExtension.replaceAll('.', '');

      if (kDebugMode) {
        print('File path: $filePath');
        print('Extension: $fileExtension');
        print('Clean extension: $cleanExtension');
      }

      // Delete old profile picture if exists
      final oldPicturePath = userProfile?['profile_picture_path'];
      if (oldPicturePath != null && oldPicturePath.isNotEmpty) {
        try {
          if (kDebugMode) {
            print('Deleting old picture: $oldPicturePath');
          }
          await Supabase.instance.client.storage
              .from('profile-pictures')
              .remove([oldPicturePath]);
          if (kDebugMode) {
            print('Old picture deleted successfully');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error deleting old profile picture: $e');
          }
        }
      }

      // Upload new profile picture
      if (kDebugMode) {
        print('Reading image bytes...');
      }
      final bytes = await image.readAsBytes();
      if (kDebugMode) {
        print('Bytes read: ${bytes.length} bytes');
        print('Uploading to Supabase...');
        print('Content type will be: image/$cleanExtension');
      }

      // Map common extensions to proper MIME types
      String contentType;
      switch (cleanExtension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'image/jpeg'; // Default fallback
      }

      if (kDebugMode) {
        print('Final content type: $contentType');
      }

      await Supabase.instance.client.storage
          .from('profile-pictures')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      if (kDebugMode) {
        print('Upload successful');
      }

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('profile-pictures')
          .getPublicUrl(filePath);

      // Update user profile in database
      final response = await Supabase.instance.client
          .from('users')
          .update({
            'profile_picture_url': publicUrl,
            'profile_picture_path': filePath,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      // Update local profile
      userProfile = response;
      onProfileUpdated?.call();

      // Set success state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.success;
      });

      // Reset to normal after 2 seconds
      _profilePictureStateTimer?.cancel();
      _profilePictureStateTimer = Timer(const Duration(seconds: 2), () {
        onStateChange?.call(() {
          _profilePictureState = ProfilePictureState.normal;
        });
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('========================================');
        print('Error uploading profile picture: $e');
        print('Stack trace: $stackTrace');
        print('========================================');
      }

      // Set error state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.error;
      });

      // Show error dialog on desktop for better debugging
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upload Error'),
              content: Text('Failed to upload: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }

      // Reset to normal after 2 seconds
      _profilePictureStateTimer?.cancel();
      _profilePictureStateTimer = Timer(const Duration(seconds: 2), () {
        onStateChange?.call(() {
          _profilePictureState = ProfilePictureState.normal;
        });
      });
    }
  }

  // Add this method to handle profile picture removal
  Future<void> _removeProfilePicture(
    BuildContext context, {
    Function(VoidCallback)? onStateChange,
  }) async {
    try {
      // Set uploading state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.uploading;
      });

      final userId = userProfile!['id'] as String;
      final oldPicturePath = userProfile?['profile_picture_path'];

      if (oldPicturePath != null && oldPicturePath.isNotEmpty) {
        // Delete from storage
        await Supabase.instance.client.storage.from('profile-pictures').remove([
          oldPicturePath,
        ]);
      }

      // Update user profile in database
      final response = await Supabase.instance.client
          .from('users')
          .update({
            'profile_picture_url': null,
            'profile_picture_path': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      // Update local profile
      userProfile = response;
      onProfileUpdated?.call();

      // Set success state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.success;
      });

      // Reset to normal after 2 seconds
      _profilePictureStateTimer?.cancel();
      _profilePictureStateTimer = Timer(const Duration(seconds: 2), () {
        onStateChange?.call(() {
          _profilePictureState = ProfilePictureState.normal;
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error removing profile picture: $e');
      }

      // Set error state
      onStateChange?.call(() {
        _profilePictureState = ProfilePictureState.error;
      });

      // Reset to normal after 2 seconds
      _profilePictureStateTimer?.cancel();
      _profilePictureStateTimer = Timer(const Duration(seconds: 2), () {
        onStateChange?.call(() {
          _profilePictureState = ProfilePictureState.normal;
        });
      });
    }
  }

  // MOBILE: Bottom sheet for mobile devices
  void _showProfilePictureOptionsMobile(
    BuildContext context, {
    Function(VoidCallback)? onStateChange,
  }) {
    final hasProfilePicture = userProfile?['profile_picture_url'] != null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Center(
          // Centers modal vertically and horizontally
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 24,
            ),
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            content: Container(
              width:
                  MediaQuery.of(context).size.width * 0.85, // Responsive width
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 28),

                  // Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.grey.shade700,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    'Profile Photo',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      hasProfilePicture
                          ? 'Update or remove your photo'
                          : 'Add a profile photo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        // Upload/Change button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _uploadProfilePicture(
                                context,
                                onStateChange: onStateChange,
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                43,
                                68,
                                105,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              hasProfilePicture
                                  ? 'Change Photo'
                                  : 'Upload Photo',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        if (hasProfilePicture) ...[
                          const SizedBox(height: 10),
                          // Remove button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeProfilePicture(
                                  context,
                                  onStateChange: onStateChange,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Remove Photo',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Cancel button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // DESKTOP: Minimal modern modal
  void _showProfilePictureOptionsDesktop(
    BuildContext context, {
    required bool isSidebarVisible,
    Function(VoidCallback)? onStateChange,
  }) {
    final hasProfilePicture = userProfile?['profile_picture_url'] != null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        Widget dialogContent = AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          content: Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),

                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.grey.shade700,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'Profile Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    hasProfilePicture
                        ? 'Update or remove your photo'
                        : 'Add a profile photo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Upload/Change Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _uploadProfilePicture(
                              context,
                              onStateChange: onStateChange,
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              43,
                              68,
                              105,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            hasProfilePicture ? 'Change Photo' : 'Upload Photo',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      if (hasProfilePicture) ...[
                        const SizedBox(height: 10),
                        // Remove Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeProfilePicture(
                                context,
                                onStateChange: onStateChange,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Remove Photo',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );

        // Position modal centered within profile view
        final profileLeft = isSidebarVisible ? 245.0 : 45.0;
        final profileWidth = 450.0;
        final modalWidth = 280.0;
        final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

        return Stack(
          children: [
            Positioned(left: centeredLeft, top: 260, child: dialogContent),
          ],
        );
      },
    );
  }

  // MOBILE AVATAR - Uses bottom sheet
  Widget _buildMobileProfileAvatar({
    required BuildContext context,
    bool isEditable = false,
    Function(VoidCallback)? onStateChange,
  }) {
    final hasProfilePicture = userProfile?['profile_picture_url'] != null;

    Color borderColor;
    switch (_profilePictureState) {
      case ProfilePictureState.success:
        borderColor = Colors.green;
        break;
      case ProfilePictureState.error:
        borderColor = Colors.red;
        break;
      case ProfilePictureState.uploading:
        borderColor = Colors.blue;
        break;
      default:
        borderColor = Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: isEditable
          ? () => _showProfilePictureOptionsMobile(
              context,
              onStateChange: onStateChange,
            )
          : null,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: _profilePictureState != ProfilePictureState.normal
                      ? 4
                      : 0,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 50,
                child: _profilePictureState == ProfilePictureState.uploading
                    ? const CircularProgressIndicator()
                    : hasProfilePicture
                    ? ClipOval(
                        child: Image.network(
                          userProfile!['profile_picture_url'],
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 47,
                              child: Icon(
                                _getGenderIcon(userProfile?['gender']),
                                size: 50,
                                color: Colors.grey.shade700,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 47,
                        child: Icon(
                          _getGenderIcon(userProfile?['gender']),
                          size: 50,
                          color: Colors.grey.shade700,
                        ),
                      ),
              ),
            ),
          ),
          if (isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt, // Changed to camera icon
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // DESKTOP AVATAR - Uses centered modal
  Widget _buildDesktopProfileAvatar({
    required BuildContext context,
    required bool isSidebarVisible,
    bool isEditable = false,
    Function(VoidCallback)? onStateChange,
  }) {
    final hasProfilePicture = userProfile?['profile_picture_url'] != null;

    Color borderColor;
    switch (_profilePictureState) {
      case ProfilePictureState.success:
        borderColor = Colors.green;
        break;
      case ProfilePictureState.error:
        borderColor = Colors.red;
        break;
      case ProfilePictureState.uploading:
        borderColor = Colors.blue;
        break;
      default:
        borderColor = Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: isEditable
          ? () => _showProfilePictureOptionsDesktop(
              context,
              isSidebarVisible: isSidebarVisible,
              onStateChange: onStateChange,
            )
          : null,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: _profilePictureState != ProfilePictureState.normal
                      ? 4
                      : 0,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 50,
                child: _profilePictureState == ProfilePictureState.uploading
                    ? const CircularProgressIndicator()
                    : hasProfilePicture
                    ? ClipOval(
                        child: Image.network(
                          userProfile!['profile_picture_url'],
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 47,
                              child: Icon(
                                _getGenderIcon(userProfile?['gender']),
                                size: 50,
                                color: Colors.grey.shade700,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 47,
                        child: Icon(
                          _getGenderIcon(userProfile?['gender']),
                          size: 50,
                          color: Colors.grey.shade700,
                        ),
                      ),
              ),
            ),
          ),
          if (isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  hasProfilePicture ? Icons.edit : Icons.camera_alt,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Updated updateProfile method with consistent button states for both desktop and mobile

  Future<void> updateProfile(
    BuildContext context, {
    required VoidCallback onSuccess,
    Function(VoidCallback)? onStateChange,
    required bool isSidebarVisible,
  }) async {
    if (!_profileFormKey.currentState!.validate()) return;

    try {
      bool hasProfileChanges = _hasProfileChanges();
      bool hasEmailChanges =
          _hasEmailChanges() && userProfile?['registration_type'] == 'simple';

      // Set saving state for both desktop and mobile
      onStateChange?.call(() {
        _saveButtonState = SaveButtonState.saving;
      });

      // Update profile data
      if (hasProfileChanges) {
        final updateData = {
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'middle_name': _middleNameController.text.isEmpty
              ? null
              : _middleNameController.text,
          'ext_name': _extNameController.text.isEmpty
              ? null
              : _extNameController.text,
          'gender': _selectedGender,
          'bday': _selectedBirthday?.toIso8601String(),
          'contact_number': _contactNumberController.text.isEmpty
              ? null
              : _contactNumberController.text,
          'police_rank_id': _selectedPoliceRankId,
          'police_station_id': _selectedPoliceStationId,
          'updated_at': DateTime.now().toIso8601String(),
        };
        final response = await Supabase.instance.client
            .from('users')
            .update(updateData)
            .eq('id', userProfile!['id'] as Object)
            .select()
            .single();
        userProfile = response;
        onProfileUpdated?.call();
        print('✅ Profile updated - parent notified');
      }

      // Handle email verification if needed
      if (hasEmailChanges) {
        final currentEmail = userProfile?['email'] ?? '';
        final newEmail = _emailController.text.trim();

        // Determine if this is a change or verification of existing email
        final isEmailChange = newEmail != currentEmail;
        final isVerifyingCurrentEmail =
            _forceEmailVerification && !isEmailChange;

        // Show loading state
        onStateChange?.call(() {
          _isUpdatingEmail = true;
          _saveButtonState = SaveButtonState.saving;
        });

        try {
          if (isVerifyingCurrentEmail) {
            // User wants to verify their current email
            await _authService.sendVerificationToCurrentEmail();
            _pendingEmailChange = currentEmail;
            _isVerifyingCurrentEmail = true;
          } else if (isEmailChange) {
            // Email is being changed to a new one
            await _authService.updateEmailWithVerification(newEmail: newEmail);
            _pendingEmailChange = newEmail;
            _isVerifyingCurrentEmail = false;
          }

          _startEmailResendTimer();

          // Reset UI state after successful email operation start
          onStateChange?.call(() {
            _forceEmailVerification = false;
            _handleEmailMutualExclusivity();
            _isUpdatingEmail = false;
            _saveButtonState = SaveButtonState.normal;
          });

          // Show email verification modal
          _showEmailVerificationModal(
            context,
            onSuccess,
            profileChanged: hasProfileChanges,
            isSidebarVisible: isSidebarVisible,
            onStateChange: onStateChange,
          );
        } catch (e) {
          // Reset checkbox state but KEEP the saving button state initially
          onStateChange?.call(() {
            _forceEmailVerification = false;
            _handleEmailMutualExclusivity();
            _isUpdatingEmail = false;
            // DON'T reset _saveButtonState yet - keep it as "saving"
          });

          String errorMessage =
              'Email verification failed: The registered address may be invalid or inactive. Please enter a new valid email to verify.';

          // Show email error with smart callback handling
          bool isSnackBarDismissed = false;

          _showSnackBarWithCallback(
            context,
            errorMessage,
            isError: true,
            duration: const Duration(seconds: 4),
            isSidebarVisible: isSidebarVisible,
            onDismissed: () {
              if (!isSnackBarDismissed) {
                isSnackBarDismissed = true;

                if (hasProfileChanges) {
                  // SnackBar dismissed, show "saved" state and navigate
                  if (context.mounted) {
                    onStateChange?.call(() {
                      _saveButtonState = SaveButtonState.saved;
                    });

                    // After showing "saved" for 1.5 seconds, navigate
                    _buttonStateTimer?.cancel();
                    _buttonStateTimer = Timer(
                      const Duration(milliseconds: 1500),
                      () {
                        _shouldScrollToTop = true;
                        _isEditingProfile = false;
                        onSuccess(); // Navigate - button stays as "SAVED"
                      },
                    );
                  }
                } else {
                  // No profile changes, just reset button
                  if (onStateChange != null) {
                    onStateChange(() {
                      _saveButtonState = SaveButtonState.normal;
                    });
                  }
                }
              }
            },
          );
          return; // Important: return here to prevent further execution
        }
      } else {
        // No email verification needed - show success for profile changes
        if (hasProfileChanges) {
          // Show saved state for both desktop and mobile
          onStateChange?.call(() {
            _saveButtonState = SaveButtonState.saved;
          });

          _buttonStateTimer?.cancel();
          _buttonStateTimer = Timer(const Duration(seconds: 1), () {
            // Navigate to profile view - button stays as "SAVED"
            _shouldScrollToTop = true;
            _isEditingProfile = false;
            onSuccess(); // This triggers navigation to profile view
          });
        }
      }
    } catch (e) {
      // Reset button state on error
      onStateChange?.call(() {
        _saveButtonState = SaveButtonState.normal;
      });
      _showSnackBar(
        context,
        'Error updating profile: ${e.toString()}',
        isError: true,
        isSidebarVisible: isSidebarVisible, // Add this line
      );
    }
  }

  void _handleEmailMutualExclusivity() {
    final currentEmail = userProfile?['email'] ?? '';

    // If checkbox is checked, make email field readonly with original email
    if (_forceEmailVerification) {
      _emailController.text = currentEmail;
      _isEmailFieldReadOnly = true;
    } else {
      _isEmailFieldReadOnly = false;
    }
  }

  bool _shouldUseDesktopLayout(BuildContext context) {
    final isDesktopPlatform =
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.windows ||
        kIsWeb;

    final screenWidth = MediaQuery.of(context).size.width;

    // Only use desktop layout if it's a desktop platform AND has enough width
    // Use a reasonable breakpoint (e.g., 1024px) to determine if sidebar layout should be used
    return isDesktopPlatform && screenWidth >= 1024;
  }

  // Updated _showSnackBarWithCallback method
  void _showSnackBarWithCallback(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration? duration,
    bool isError = false,
    bool isWarning = false,
    bool isSuccess = false,
    VoidCallback? onDismissed,
    required bool isSidebarVisible,
  }) {
    // Determine colors and icon based on type
    Color bgColor;
    Color txColor;
    IconData snackIcon;

    if (isSuccess) {
      bgColor = Colors.green.shade600;
      txColor = Colors.white;
      snackIcon = Icons.check_circle_rounded;
    } else if (isWarning) {
      bgColor = Colors.orange.shade600;
      txColor = Colors.white;
      snackIcon = Icons.warning_rounded;
    } else if (isError) {
      bgColor = Colors.red.shade600;
      txColor = Colors.white;
      snackIcon = Icons.error_rounded;
    } else {
      bgColor = backgroundColor ?? Colors.blue.shade600;
      txColor = textColor ?? Colors.white;
      snackIcon = icon ?? Icons.info_rounded;
    }

    // Use responsive helper instead of fixed platform check
    final useDesktopLayout = _shouldUseDesktopLayout(context);

    // Calculate margins
    EdgeInsets snackBarMargin;
    if (useDesktopLayout) {
      // Desktop layout with enough space - match the profile container positioning
      final profileLeft = isSidebarVisible ? 285.0 : 80.0;
      final profileWidth = 450.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final rightMargin = screenWidth - profileLeft - profileWidth;

      snackBarMargin = EdgeInsets.only(
        left: profileLeft,
        right: rightMargin,
        bottom: 16,
        top: 16,
      );
    } else {
      // Mobile or narrow desktop - use centered margins
      snackBarMargin = const EdgeInsets.all(16);
    }

    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(snackIcon, color: txColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: txColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child: Text(
                  'DISMISS',
                  style: GoogleFonts.poppins(
                    color: txColor.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: bgColor,
      duration: duration ?? const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: snackBarMargin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((_) {
      onDismissed?.call();
    });
  }

  // Updated _showSnackBar method
  void _showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration? duration,
    bool isError = false,
    bool isWarning = false,
    bool isSuccess = false,
    required bool isSidebarVisible,
  }) {
    // Determine colors and icon based on type
    Color bgColor;
    Color txColor;
    IconData snackIcon;

    if (isSuccess) {
      bgColor = Colors.green.shade600;
      txColor = Colors.white;
      snackIcon = Icons.check_circle_rounded;
    } else if (isWarning) {
      bgColor = Colors.orange.shade600;
      txColor = Colors.white;
      snackIcon = Icons.warning_rounded;
    } else if (isError) {
      bgColor = Colors.red.shade600;
      txColor = Colors.white;
      snackIcon = Icons.error_rounded;
    } else {
      bgColor = backgroundColor ?? Colors.blue.shade600;
      txColor = textColor ?? Colors.white;
      snackIcon = icon ?? Icons.info_rounded;
    }

    // Use responsive helper instead of fixed platform check
    final useDesktopLayout = _shouldUseDesktopLayout(context);

    // Calculate margins
    EdgeInsets snackBarMargin;
    if (useDesktopLayout) {
      // Desktop layout - match the profile container positioning
      final profileLeft = isSidebarVisible ? 285.0 : 80.0;
      final profileWidth = 450.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final rightMargin = screenWidth - profileLeft - profileWidth;

      snackBarMargin = EdgeInsets.only(
        left: profileLeft,
        right: rightMargin,
        bottom: 16,
        top: 16,
      );
    } else {
      // Mobile or narrow desktop - use centered margins
      snackBarMargin = const EdgeInsets.all(16);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(snackIcon, color: txColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.poppins(
                      color: txColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: Text(
                    'DISMISS',
                    style: GoogleFonts.poppins(
                      color: txColor.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: snackBarMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
    );
  }

  // EMAIL VERIFICATION STARTS HERE
  void _showEmailVerificationModal(
    BuildContext context,
    VoidCallback onSuccess, {
    bool profileChanged = false,
    required bool isSidebarVisible,
    Function(VoidCallback)? onStateChange,
  }) {
    final List<TextEditingController> otpControllers = List.generate(
      6,
      (_) => TextEditingController(),
    );
    final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

    final useDesktopLayout = _shouldUseDesktopLayout(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: useDesktopLayout ? Colors.black.withOpacity(0.3) : null,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (_pendingEmailChange != null && _currentModalSetState == null) {
              // Only restart timer if it's not already running with a modal callback
              _startEmailResendTimer(modalSetState: setModalState);
            }
            Widget dialogContent = AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: useDesktopLayout ? 40 : 16,
                vertical: 24,
              ),
              content: Container(
                width: useDesktopLayout
                    ? 450
                    : double.maxFinite, // Match profile view width
                constraints: BoxConstraints(
                  maxWidth: useDesktopLayout
                      ? 450
                      : MediaQuery.of(context).size.width -
                            32, // Match profile view
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header section with gradient background
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(useDesktopLayout ? 32 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade500,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mark_email_read_rounded,
                                size: useDesktopLayout ? 40 : 32,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: useDesktopLayout ? 16 : 12),
                            Text(
                              'Verify New Email',
                              style: GoogleFonts.poppins(
                                fontSize: useDesktopLayout ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content section
                      Container(
                        padding: EdgeInsets.all(useDesktopLayout ? 32 : 20),
                        child: Column(
                          children: [
                            Text(
                              'Enter the 6-digit code sent to:',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: useDesktopLayout ? 15 : 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pendingEmailChange ?? '',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: useDesktopLayout ? 16 : 14,
                                color: Colors.blue.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: useDesktopLayout ? 20 : 16),
                            Container(
                              padding: EdgeInsets.all(
                                useDesktopLayout ? 16 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Check your spam folder if you don\'t see the email. The code expires in 10 minutes.',
                                      style: GoogleFonts.poppins(
                                        fontSize: useDesktopLayout ? 13 : 12,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: useDesktopLayout ? 32 : 24),

                            // OTP Input Fields
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: useDesktopLayout ? 8 : 8,
                              children: List.generate(6, (index) {
                                final fieldSize = useDesktopLayout
                                    ? 40.0
                                    : MediaQuery.of(context).size.width < 360
                                    ? 35.0
                                    : 40.0;

                                return Container(
                                  width: fieldSize,
                                  height: fieldSize + 8,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: TextFormField(
                                    controller: otpControllers[index],
                                    focusNode: otpFocusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: GoogleFonts.poppins(
                                      fontSize: useDesktopLayout
                                          ? 22
                                          : MediaQuery.of(context).size.width <
                                                360
                                          ? 16
                                          : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        otpFocusNodes[index + 1].requestFocus();
                                      } else if (value.isEmpty && index > 0) {
                                        otpFocusNodes[index - 1].requestFocus();
                                      }
                                    },
                                  ),
                                );
                              }),
                            ),

                            SizedBox(height: useDesktopLayout ? 32 : 24),

                            // Action buttons
                            useDesktopLayout ||
                                    MediaQuery.of(context).size.width > 400
                                ? Row(
                                    children: [
                                      // Skip button - UPDATED LOGIC
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            // Clean up controllers
                                            for (var controller
                                                in otpControllers) {
                                              controller.dispose();
                                            }
                                            for (var focusNode
                                                in otpFocusNodes) {
                                              focusNode.dispose();
                                            }
                                            _currentModalSetState = null;
                                            _emailResendTimer?.cancel();
                                            _pendingEmailChange = null;

                                            Navigator.of(context).pop();

                                            // Only show success if other changes were made
                                            if (profileChanged) {
                                              // Show saved state briefly
                                              if (onStateChange != null) {
                                                onStateChange(() {
                                                  _saveButtonState =
                                                      SaveButtonState.saved;
                                                });

                                                _buttonStateTimer?.cancel();
                                                _buttonStateTimer = Timer(
                                                  const Duration(seconds: 1),
                                                  () {
                                                    _isEditingProfile = false;
                                                    onSuccess();

                                                    onStateChange(() {
                                                      _saveButtonState =
                                                          SaveButtonState
                                                              .normal;
                                                    });
                                                  },
                                                );
                                              }
                                            } else {
                                              // No other changes were made, just exit edit mode
                                              _isEditingProfile = false;
                                              onSuccess();
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.grey.shade600,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          child: Text(
                                            'Skip for Now',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Verify button
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _verifyEmailChangeFromModal(
                                                context,
                                                otpControllers,
                                                otpFocusNodes,
                                                onSuccess,
                                                setModalState,
                                                isSidebarVisible:
                                                    isSidebarVisible, // Pass the parameter
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 4,
                                            shadowColor: Colors.blue.shade200,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.verified_rounded,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Verify Email',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _verifyEmailChangeFromModal(
                                                context,
                                                otpControllers,
                                                otpFocusNodes,
                                                onSuccess,
                                                setModalState,
                                                isSidebarVisible:
                                                    isSidebarVisible, // Pass the parameter
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 4,
                                            shadowColor: Colors.blue.shade200,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.verified_rounded,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Verify Email',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            // Clean up controllers
                                            for (var controller
                                                in otpControllers) {
                                              controller.dispose();
                                            }
                                            for (var focusNode
                                                in otpFocusNodes) {
                                              focusNode.dispose();
                                            }
                                            _currentModalSetState = null;
                                            _emailResendTimer?.cancel();
                                            _pendingEmailChange = null;

                                            Navigator.of(context).pop();

                                            // Only show success if other changes were made
                                            if (profileChanged) {
                                              // Show saved state briefly
                                              if (onStateChange != null) {
                                                onStateChange(() {
                                                  _saveButtonState =
                                                      SaveButtonState.saved;
                                                });

                                                _buttonStateTimer?.cancel();
                                                _buttonStateTimer = Timer(
                                                  const Duration(seconds: 1),
                                                  () {
                                                    _isEditingProfile = false;
                                                    onSuccess();

                                                    onStateChange(() {
                                                      _saveButtonState =
                                                          SaveButtonState
                                                              .normal;
                                                    });
                                                  },
                                                );
                                              }
                                            } else {
                                              // No other changes were made, just exit edit mode
                                              _isEditingProfile = false;
                                              onSuccess();
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.grey.shade600,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          child: Text(
                                            'Skip for Now',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                            SizedBox(height: useDesktopLayout ? 20 : 16),

                            // Resend section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _canResendEmailOTP
                                      ? () => _resendEmailChangeOTP(
                                          context,
                                          setModalState,
                                          isSidebarVisible: isSidebarVisible,
                                        )
                                      : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: _canResendEmailOTP
                                            ? Colors.blue.shade600
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _canResendEmailOTP
                                            ? 'Resend Code'
                                            : 'Resend in ${_emailResendCountdown}s',
                                        style: GoogleFonts.poppins(
                                          color: _canResendEmailOTP
                                              ? Colors.blue.shade600
                                              : Colors.grey.shade400,
                                          fontWeight: FontWeight.w500,
                                          fontSize: useDesktopLayout ? 14 : 13,
                                        ),
                                      ),
                                    ],
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
            );

            if (useDesktopLayout) {
              // Center the modal within the profile view area
              final profileLeft = isSidebarVisible ? 285.0 : 80.0;
              final profileWidth = 450.0;
              final modalWidth = 450.0;
              final centeredLeft =
                  profileLeft + (profileWidth - modalWidth) / 2;

              return Stack(
                children: [
                  Positioned(
                    left: centeredLeft, // Center within profile view
                    top: 150, // Position lower to center vertically in profile
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: dialogContent,
                    ),
                  ),
                ],
              );
            } else {
              return dialogContent;
            }
          },
        );
      },
    );
  }

  Future<void> _verifyEmailChangeFromModal(
    BuildContext context,
    List<TextEditingController> otpControllers,
    List<FocusNode> otpFocusNodes,
    VoidCallback onSuccess,
    StateSetter setModalState, {
    required bool isSidebarVisible,
  }) async {
    final otp = otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showSnackBar(
        context,
        'Please enter the complete 6-digit code',
        isSidebarVisible: isSidebarVisible,
      );
      return;
    }

    try {
      // Show loading state in modal
      setModalState(() {
        // You can add a loading state here if needed
      });

      if (_isVerifyingCurrentEmail) {
        // Use the new method for verifying current email (reauthentication flow)
        await _authService.verifyCurrentEmailOTP(
          email: _pendingEmailChange!,
          otp: otp,
        );

        // For current email verification, only update registration_type
        userProfile?['registration_type'] = 'verified';

        // Try to sync with database (non-blocking for current email verification)
        try {
          await Supabase.instance.client
              .from('users')
              .update({
                'registration_type': 'verified',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userProfile!['id'] as Object);
        } catch (dbError) {
          print('Database sync error (non-critical): $dbError');
        }
      } else {
        // THIS IS THE KEY FIX: Use the proper Supabase Auth method for email changes
        await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.emailChange,
          email: _pendingEmailChange!,
          token: otp,
        );

        // IMPORTANT: After successful auth verification, update local profile
        userProfile?['email'] = _pendingEmailChange;
        userProfile?['registration_type'] = 'verified';

        // Update the email controller to reflect the change
        _emailController.text = _pendingEmailChange!;

        // Try to sync with database (non-blocking but should succeed since auth succeeded)
        try {
          await Supabase.instance.client
              .from('users')
              .update({
                'email': _pendingEmailChange!,
                'registration_type': 'verified',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userProfile!['id'] as Object);
        } catch (dbError) {
          print('Database sync error (non-critical): $dbError');
          // This error is non-critical since the auth email change was successful
        }
      }

      // Clean up controllers and close modal
      for (var controller in otpControllers) {
        controller.dispose();
      }
      for (var focusNode in otpFocusNodes) {
        focusNode.dispose();
      }
      _emailResendTimer?.cancel();

      // Store values before clearing
      final pendingEmail = _pendingEmailChange!;
      final wasVerifyingCurrentEmail = _isVerifyingCurrentEmail;

      // Clean up state
      _pendingEmailChange = null;
      _isVerifyingCurrentEmail = false;

      // Close the verification modal first
      Navigator.of(context).pop();

      // Add a small delay to ensure the modal is fully closed
      await Future.delayed(const Duration(milliseconds: 100));

      // Show success dialog with appropriate message
      String successMessage;
      if (wasVerifyingCurrentEmail) {
        successMessage =
            'Email verification successful!\n\nYour email address has been verified.';
      } else {
        successMessage =
            'Email updated and verified successfully!\n\nYour new email address: $pendingEmail';
      }

      _showEmailVerificationSuccessDialog(
        context,
        pendingEmail,
        onOkPressed: () {
          // Close the success dialog first
          Navigator.of(context).pop();

          // Add delay to ensure dialog is fully closed before state changes
          Future.delayed(const Duration(milliseconds: 200), () {
            if (context.mounted) {
              _shouldScrollToTop = true;
              _isEditingProfile = false;
              onSuccess(); // This should trigger UI rebuild
            }
          });
        },
        isSidebarVisible: isSidebarVisible,
        customMessage: successMessage,
      );
    } catch (e) {
      print('Email verification error: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');

      // Reset loading state in modal
      setModalState(() {
        // Reset any loading indicators
      });

      // Simple, single error message for all verification failures
      _showErrorDialog(
        context,
        'Invalid or expired verification code. Please check your code and try again.',
        isSidebarVisible: isSidebarVisible,
      );
    }
  }

  void _showEmailVerificationSuccessDialog(
    BuildContext context,
    String verifiedEmail, {
    VoidCallback? onOkPressed,
    required bool isSidebarVisible,
    String? customMessage,
  }) {
    final useDesktopLayout = _shouldUseDesktopLayout(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: useDesktopLayout ? Colors.black.withOpacity(0.3) : null,
      builder: (context) {
        Widget dialogContent = AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: useDesktopLayout ? 40 : 16,
            vertical: 24,
          ),
          content: Container(
            width: useDesktopLayout
                ? 450
                : double.maxFinite, // Match profile view width
            constraints: BoxConstraints(
              maxWidth: useDesktopLayout
                  ? 450
                  : MediaQuery.of(context).size.width -
                        32, // Match profile view
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section with success gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(useDesktopLayout ? 32 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade600, Colors.green.shade500],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Success icon with animation-like effect
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: useDesktopLayout ? 48 : 40,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: useDesktopLayout ? 16 : 12),
                      Text(
                        'Email Verified Successfully!',
                        style: GoogleFonts.poppins(
                          fontSize: useDesktopLayout ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Content section
                Container(
                  padding: EdgeInsets.all(useDesktopLayout ? 32 : 24),
                  child: Column(
                    children: [
                      // Success message
                      Text(
                        customMessage ??
                            'Your email has been successfully updated to:',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: useDesktopLayout ? 15 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          verifiedEmail,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: useDesktopLayout ? 16 : 14,
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: useDesktopLayout ? 24 : 20),

                      // Success details
                      Container(
                        padding: EdgeInsets.all(useDesktopLayout ? 16 : 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your profile has been updated with the new verified email address.',
                                style: GoogleFonts.poppins(
                                  fontSize: useDesktopLayout ? 13 : 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: useDesktopLayout ? 32 : 24),

                      // OK button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (onOkPressed != null) {
                              // Add a small delay to ensure dialog is fully closed
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  onOkPressed();
                                },
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.green.shade200,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Continue',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
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
          ),
        );

        if (useDesktopLayout) {
          // Center the modal within the profile view area
          final profileLeft = isSidebarVisible ? 285.0 : 80.0;
          final profileWidth = 450.0;
          final modalWidth = 450.0;
          final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

          return Stack(
            children: [
              Positioned(
                left: centeredLeft, // Center within profile view
                top: 200, // Position lower to center vertically in profile
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: dialogContent,
                ),
              ),
            ],
          );
        } else {
          return dialogContent;
        }
      },
    );
  }

  // 2. Add a method to refresh user profile from database
  Future<void> refreshUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      userProfile = response;

      // Update controllers with fresh data
      _emailController.text = userProfile?['email'] ?? '';
    } catch (e) {
      print('Error refreshing user profile: $e');
    }
  }

  void _showErrorDialog(
    BuildContext context,
    String message, {
    required bool isSidebarVisible,
  }) {
    final useDesktopLayout = _shouldUseDesktopLayout(context);

    showDialog(
      context: context,
      barrierColor: useDesktopLayout ? Colors.black.withOpacity(0.3) : null,
      builder: (context) {
        Widget dialogContent = AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: useDesktopLayout ? 40 : 16,
            vertical: 24,
          ),
          content: Container(
            width: useDesktopLayout ? 400 : double.maxFinite,
            constraints: BoxConstraints(
              maxWidth: useDesktopLayout
                  ? 400
                  : MediaQuery.of(context).size.width - 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(useDesktopLayout ? 24 : 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Error',
                        style: GoogleFonts.poppins(
                          fontSize: useDesktopLayout ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(useDesktopLayout ? 24 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: GoogleFonts.poppins(
                          fontSize: useDesktopLayout ? 14 : 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: useDesktopLayout ? 24 : 20),

                      // OK Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'OK',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (useDesktopLayout) {
          // Center the modal within the profile view area (same as email verification modal)
          final profileLeft = isSidebarVisible ? 285.0 : 80.0;
          final profileWidth = 450.0;
          final modalWidth = 400.0;
          final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

          return Stack(
            children: [
              Positioned(
                left: centeredLeft, // Center within profile view
                top: 250, // Position to center vertically in profile
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: dialogContent,
                ),
              ),
            ],
          );
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: dialogContent,
          );
        }
      },
    );
  }

  Future<void> _resendEmailChangeOTP(
    BuildContext context,
    StateSetter setModalState, {
    required bool isSidebarVisible,
  }) async {
    try {
      if (_isVerifyingCurrentEmail) {
        // Use the new resend method for current email verification
        await _authService.resendReauthenticationOTP(
          email: _pendingEmailChange!,
        );
      } else {
        // Use existing method for email changes
        await _authService.resendEmailChangeOTP(email: _pendingEmailChange!);
      }

      // Start timer with modal setState callback
      _startEmailResendTimer(modalSetState: setModalState);

      // Update modal immediately
      setModalState(() {});

      _showSnackBar(
        context,
        'Verification code sent again!',
        isSuccess: true,
        isSidebarVisible: isSidebarVisible,
      );
    } catch (e) {
      _showSnackBar(
        context,
        'Failed to resend code. Please try again.',
        isError: true,
        isSidebarVisible: isSidebarVisible,
      );
    }
  }

  void _startEmailResendTimer({StateSetter? modalSetState}) {
    _canResendEmailOTP = false;
    _emailResendCountdown = 60;
    _currentModalSetState = modalSetState; // Store the modal's setState

    _emailResendTimer?.cancel(); // Cancel any existing timer
    _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailResendCountdown > 0) {
        _emailResendCountdown--;
        // Update the modal UI every second
        _currentModalSetState?.call(() {});
      } else {
        _canResendEmailOTP = true;
        _currentModalSetState?.call(() {}); // Final update
        _currentModalSetState = null; // Clear the reference
        timer.cancel();
      }
    });
  }

  //PROFILE PAGE TO ALWAYS START FROM THE TOP
  void setShouldScrollToTop(bool value) {
    _shouldScrollToTop = value;
  }

  Future<void> _loadPoliceData() async {
    try {
      final ranksResponse = await Supabase.instance.client
          .from('police_ranks')
          .select('*')
          .order('rank_level');
      _policeRanks = List<Map<String, dynamic>>.from(ranksResponse);

      final stationsResponse = await Supabase.instance.client
          .from('police_stations')
          .select('*')
          .order('station_number');
      _policeStations = List<Map<String, dynamic>>.from(stationsResponse);
    } catch (e) {
      print('Error loading police data: $e');
    }
  }

  //PROFILE VIEW MOBILE
  Widget buildProfileView(
    BuildContext context,
    bool isDesktopOrWeb,
    VoidCallback onEditPressed,
  ) {
    // Only scroll to top when explicitly requested (when returning from edit mode)
    if (_shouldScrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_profileViewScrollController.hasClients) {
          _profileViewScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _shouldScrollToTop = false; // Reset the flag
    }

    return SingleChildScrollView(
      controller: _profileViewScrollController,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section with background image and edit button
          StatefulBuilder(
            builder: (context, setStateHeader) {
              return Container(
                width: double.infinity,
                height: 280,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/DARK.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // Center the main content to ensure badge alignment
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Profile avatar
                          _buildMobileProfileAvatar(
                            context: context,
                            isEditable: true,
                            onStateChange: setStateHeader,
                          ),
                          const SizedBox(height: 16),
                          // Full name
                          Text(
                            '${userProfile?['first_name'] ?? ''}'
                            '${userProfile?['middle_name'] != null ? ' ${userProfile?['middle_name']}' : ''}'
                            ' ${userProfile?['last_name'] ?? ''}'
                            '${userProfile?['ext_name'] != null ? ' ${userProfile?['ext_name']}' : ''}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Role badge
                          if (userProfile?['role'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A6B8A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: userProfile?['role'] == 'officer'
                                          ? Colors.green
                                          : Colors.lightBlueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    userProfile?['role']?.toUpperCase() ??
                                        'USER',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                    // Top Right Buttons Column (stacked vertically)
                    Positioned(
                      top: 20,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit Profile Button (top)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: onEditPressed,
                              icon: const Icon(Icons.edit, size: 20),
                              color: const Color.fromARGB(255, 43, 68, 105),
                              tooltip: 'Edit Profile',
                            ),
                          ),

                          // Location Sharing Toggle (below edit button)
                          if (userProfile?['role'] == 'officer' ||
                              userProfile?['role'] == 'admin') ...[
                            const SizedBox(height: 8),
                            _buildLocationSharingToggle(
                              context,
                              setStateHeader,
                              isMobile: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ✅ UPDATED - Tabs section with WMSU user types
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  // Tab Headers
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Personal Info Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: _selectedTab == 0
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade300,
                                    width: _selectedTab == 0 ? 2 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Personal Info',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _selectedTab == 0
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Police Info Tab (Officers only)
                        if (userProfile?['role'] == 'officer')
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 1
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                      width: _selectedTab == 1 ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Police Info',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // ✅ Student Info Tab
                        if (userProfile?['user_type'] == 'wmsu_student')
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 1
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                      width: _selectedTab == 1 ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Student Info',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // ✅ Parent Info Tab
                        if (userProfile?['user_type'] == 'wmsu_parent')
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 1
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                      width: _selectedTab == 1 ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Parent Info',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // ✅ Employee Info Tab
                        if (userProfile?['user_type'] == 'wmsu_employee')
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTab == 1
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                      width: _selectedTab == 1 ? 2 : 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Employee Info',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedTab == 1
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _selectedTab == 1
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Content
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _selectedTab == 0
                          ? _buildPersonalInfoItems(context)
                          : (userProfile?['role'] == 'officer'
                                ? _buildPoliceInfoItems(context)
                                : (userProfile?['user_type'] == 'wmsu_student'
                                      ? _buildMobileStudentInfoItems(context)
                                      : (userProfile?['user_type'] ==
                                                'wmsu_parent'
                                            ? _buildMobileParentInfoItems(
                                                context,
                                              )
                                            : _buildMobileEmployeeInfoItems(
                                                context,
                                              )))),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 30),

          // Admin dashboard button
          if (hasAdminPermissions) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color.fromARGB(255, 43, 68, 105),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'System Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color.fromARGB(255, 43, 68, 105),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Change Password Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => showChangePasswordModal(context),
                icon: Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Colors.grey.shade800,
                ),
                label: Text(
                  'Change Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Logout Button
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutConfirmation(context),
                icon: const Icon(Icons.logout, size: 20, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 43, 68, 105),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ STEP 2: ADD MOBILE STUDENT INFO ITEMS
  List<Widget> _buildMobileStudentInfoItems(BuildContext context) {
    return [
      _buildCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.school_outlined,
        label: 'Education Level',
        value: userProfile?['wmsu_education_level'] ?? 'Not set',
        hasValue: userProfile?['wmsu_education_level'] != null,
      ),
      if (userProfile?['wmsu_education_level'] != 'elementary')
        _buildCleanInfoItem(
          context,
          icon: Icons.calendar_today_outlined,
          label: 'Year Level',
          value: userProfile?['wmsu_year_level'] ?? 'Not set',
          hasValue: userProfile?['wmsu_year_level'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'college')
        _buildCleanInfoItem(
          context,
          icon: Icons.business_outlined,
          label: 'College',
          value: userProfile?['wmsu_college'] ?? 'Not set',
          hasValue: userProfile?['wmsu_college'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'college')
        _buildCleanInfoItem(
          context,
          icon: Icons.work_outline,
          label: 'Department',
          value: userProfile?['wmsu_department'] ?? 'Not set',
          hasValue: userProfile?['wmsu_department'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'senior_high')
        _buildCleanInfoItem(
          context,
          icon: Icons.route_outlined,
          label: 'Track/Strand',
          value: userProfile?['wmsu_track_strand'] ?? 'Not set',
          hasValue: userProfile?['wmsu_track_strand'] != null,
        ),
      _buildCleanInfoItem(
        context,
        icon: Icons.class_outlined,
        label: 'Section',
        value: userProfile?['wmsu_section'] ?? 'Not set',
        hasValue: userProfile?['wmsu_section'] != null,
      ),

      // ✅ Connected Parents Section
      _buildMobileConnectedParentsSection(context),

      // ✅ Pending Requests Section
      _buildMobilePendingRequestsSection(context),
    ];
  }

  // ✅ STEP 3: ADD MOBILE PARENT INFO ITEMS
  List<Widget> _buildMobileParentInfoItems(BuildContext context) {
    return [
      _buildCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'User Type',
        value: 'WMSU Parent',
        hasValue: true,
      ),

      // ✅ Connected Students Section
      _buildMobileConnectedStudentsSection(context),

      // ✅ Send Request Button
      _buildMobileSendRequestButton(context),
    ];
  }

  // ✅ STEP 4: ADD MOBILE EMPLOYEE INFO ITEMS
  List<Widget> _buildMobileEmployeeInfoItems(BuildContext context) {
    return [
      _buildCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.business_outlined,
        label: 'College/Office',
        value: userProfile?['wmsu_college'] ?? 'Not set',
        hasValue: userProfile?['wmsu_college'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.work_outline,
        label: 'Department',
        value: userProfile?['wmsu_department'] ?? 'Not set',
        hasValue: userProfile?['wmsu_department'] != null,
        isLast: true,
      ),
    ];
  }

  // ==========================================
  // MOBILE PROFILE VIEW - PART 2
  // Widget Implementations for Connections
  // ==========================================

  // ✅ STEP 5: MOBILE CONNECTED PARENTS SECTION (FOR STUDENTS)
  Widget _buildMobileConnectedParentsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _studentParentsFuture, // ✅ Use cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.hourglass_empty,
            label: 'My Parents/Guardians',
            value: 'Loading...',
            hasValue: false,
          );
        }

        final parents = snapshot.data ?? [];

        if (parents.isEmpty) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.family_restroom_outlined,
            label: 'My Parents/Guardians',
            value: 'No connections yet',
            hasValue: false,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.family_restroom_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Parents/Guardians',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...parents.map(
                (parent) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent['parent_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${parent['relationship_type']?.toString().toUpperCase()} ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
        );
      },
    );
  }

  // ✅ STEP 6: MOBILE PENDING REQUESTS SECTION (FOR STUDENTS)
  Widget _buildMobilePendingRequestsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pendingRequestsFuture, // ✅ Use cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.pending_outlined,
            label: 'Pending Requests',
            value: 'Loading...',
            hasValue: false,
            isLast: true,
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.check_circle_outline,
            label: 'Pending Requests',
            value: 'No pending requests',
            hasValue: false,
            isLast: true,
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pending_outlined,
                      size: 20,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pending Requests (${requests.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...requests.map(
                (request) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request['parent_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Wants to connect as ${request['relationship_type']?.toString().toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (request['notes'] != null &&
                                    request['notes'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Note: ${request['notes']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                Text(
                                  'Sent: ${_formatRequestTime(request['requested_at'])}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _respondToRequest(
                                context,
                                request['request_id'],
                                true,
                              ),
                              icon: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _respondToRequest(
                                context,
                                request['request_id'],
                                false,
                              ),
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              label: Text(
                                'Reject',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(color: Colors.red.shade700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ STEP 7: MOBILE CONNECTED STUDENTS SECTION (FOR PARENTS)
  Widget _buildMobileConnectedStudentsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _parentStudentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.hourglass_empty,
            label: 'My Children',
            value: 'Loading...',
            hasValue: false,
          );
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return _buildCleanInfoItem(
            context,
            icon: Icons.family_restroom_outlined,
            label: 'My Children',
            value: 'No children connected yet',
            hasValue: false,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.family_restroom,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Children',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...students.map(
                (student) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Show custom label if exists, otherwise student name
                            Text(
                              student['custom_label']?.toString().isNotEmpty ==
                                      true
                                  ? student['custom_label']
                                  : student['student_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            // ✅ Show student name below if custom label is set
                            if (student['custom_label']
                                    ?.toString()
                                    .isNotEmpty ==
                                true)
                              Text(
                                student['student_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            // Show relationship type and WMSU ID
                            Text(
                              '${student['relationship_type']?.toString().toUpperCase()} • ${student['student_wmsu_id'] ?? 'No ID'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ✅ Add edit icon button
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () => _showEditLabelDialogMobile(
                          context,
                          student['student_id'],
                          student['student_name'],
                          student['custom_label'],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit label',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ STEP 8: MOBILE SEND REQUEST BUTTON (FOR PARENTS)
  Widget _buildMobileSendRequestButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _showMobileSendRequestDialog(context),
          icon: const Icon(Icons.favorite, size: 20, color: Colors.white),
          label: const Text(
            'Connect with My Child',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 43, 68, 105),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  // ✅ STEP 9: MOBILE SEND REQUEST DIALOG
  void _showMobileSendRequestDialog(BuildContext context) {
    final TextEditingController wmsuIdController = TextEditingController();
    String? selectedRelationship = 'mother';
    final TextEditingController notesController = TextEditingController();
    String? wmsuIdError;
    bool isSubmitting = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isSubmitting,
      enableDrag: !isSubmitting,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B4469),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Connect with Your Child',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your child will need to accept the connection',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Student WMSU ID Field
                        Text(
                          'Student WMSU ID',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: wmsuIdController,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            hintText: 'Enter student ID number',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: wmsuIdError != null
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                            filled: true,
                            fillColor: isSubmitting
                                ? Colors.grey.shade100
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorText: wmsuIdError,
                          ),
                          onChanged: (value) {
                            if (wmsuIdError != null) {
                              setModalState(() => wmsuIdError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Relationship Dropdown
                        Text(
                          'Relationship Type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedRelationship,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isSubmitting
                                ? Colors.grey.shade100
                                : Colors.grey.shade50,
                            prefixIcon: Icon(
                              Icons.family_restroom_outlined,
                              color: Colors.grey.shade600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'mother',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.woman,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Mother'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'father',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.man,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Father'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'guardian',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Guardian'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.more_horiz,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Other'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  setModalState(
                                    () => selectedRelationship = value,
                                  );
                                },
                        ),
                        const SizedBox(height: 20),

                        // Notes Field
                        Text(
                          'Notes (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText:
                                'Add any additional information (optional)',
                            filled: true,
                            fillColor: isSubmitting
                                ? Colors.grey.shade100
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Send Request Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isSubmitting || isSuccess
                                ? null
                                : () async {
                                    final wmsuId = wmsuIdController.text.trim();
                                    if (wmsuId.isEmpty) {
                                      setModalState(() {
                                        wmsuIdError = 'Please enter student ID';
                                      });
                                      return;
                                    }

                                    setModalState(() => isSubmitting = true);

                                    await _sendParentRequest(
                                      context,
                                      wmsuId,
                                      selectedRelationship!,
                                      notesController.text.trim(),
                                    );

                                    if (context.mounted) {
                                      setModalState(() {
                                        isSubmitting = false;
                                        isSuccess = true;
                                      });

                                      await Future.delayed(
                                        const Duration(milliseconds: 800),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSuccess
                                  ? Colors.green
                                  : const Color(0xFF2B4469),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: isSuccess
                                  ? Colors.green
                                  : const Color(0xFF2B4469),
                            ),
                            child: isSubmitting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'SENDING REQUEST...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  )
                                : isSuccess
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'REQUEST SENT!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'SEND REQUEST',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isSubmitting
                                    ? Colors.grey.shade400
                                    : const Color(0xFF2B4469),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSubmitting
                                    ? Colors.grey.shade400
                                    : const Color(0xFF2B4469),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) async {
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

    if (shouldLogout == true && context.mounted) {
      _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    print('🚪 Starting logout process from profile page...');

    // ✅ STEP 1: Get current user ID before signing out
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      try {
        // ✅ STEP 2: Turn off location sharing IMMEDIATELY
        await Supabase.instance.client
            .from('users')
            .update({
              'is_sharing_location': false,
              'current_latitude': null,
              'current_longitude': null,
              'last_location_update': null,
            })
            .eq('id', currentUser.id);

        print('✅ Location sharing disabled for user ${currentUser.id}');

        // ✅ STEP 3: Wait a moment for real-time to propagate
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('❌ Error disabling location sharing: $e');
      }
    }

    // ✅ STEP 4: Sign out
    await _authService.signOut();

    print('✅ Logout complete from profile page');

    if (context.mounted) {
      // Navigate and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Personal info items
  List<Widget> _buildPersonalInfoItems(BuildContext context) {
    return [
      _buildCleanInfoItem(
        context,
        icon: Icons.email_outlined,
        label: 'Email',
        value: userProfile?['email'] ?? 'Add an email',
        hasValue: userProfile?['email'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: userProfile?['contact_number'] ?? 'Add a phone number',
        hasValue: userProfile?['contact_number'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.cake_outlined,
        label: 'Birthday',
        value: userProfile?['bday'] != null
            ? DateFormat(
                'MMMM d, y',
              ).format(DateTime.parse(userProfile?['bday']))
            : 'Add a birthday',
        hasValue: userProfile?['bday'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'Gender',
        value: userProfile?['gender'] ?? 'Add gender',
        hasValue: userProfile?['gender'] != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'Username',
        value: userProfile?['username'] ?? 'Add username',
        hasValue: userProfile?['username'] != null,
        isLast: true,
      ),
    ];
  }

  // Police info items
  List<Widget> _buildPoliceInfoItems(BuildContext context) {
    return [
      _buildCleanInfoItem(
        context,
        icon: Icons.military_tech_outlined,
        label: 'Police Rank',
        value:
            _getPoliceRankName(userProfile?['police_rank_id']) ??
            'Not assigned',
        hasValue: _getPoliceRankName(userProfile?['police_rank_id']) != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: Icons.location_on_outlined,
        label: 'Assigned Station',
        value:
            _getPoliceStationName(userProfile?['police_station_id']) ??
            'Not assigned',
        hasValue:
            _getPoliceStationName(userProfile?['police_station_id']) != null,
      ),
      _buildCleanInfoItem(
        context,
        icon: isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.work_outline,
        label: 'Role',
        value: userProfile?['role']?.toUpperCase() ?? 'USER',
        hasValue: true,
        isLast: true,
      ),
    ];
  }

  // Clean info item widget matching the image design
  Widget _buildCleanInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool hasValue,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: hasValue ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //EDIT PROFILE MOBILE
  Widget buildEditProfileForm(
    BuildContext context,
    bool isDesktopOrWeb,
    VoidCallback onCancel, {
    required VoidCallback onSuccess,
  }) {
    // Only scroll to top when explicitly requested (when entering edit mode)
    if (_shouldScrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _shouldScrollToTop = false; // Reset the flag
    }

    return StatefulBuilder(
      builder: (context, setState) {
        // FIX 1: Initialize isSidebarVisible properly with null check and default value
        bool isSidebarVisible =
            false; // Initialize with a default value instead of leaving it uninitialized

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) {
              // Set flag to scroll to top when returning to profile view
              _shouldScrollToTop = true;
              onCancel();
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/LIGHT.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3)),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktopOrWeb ? 20.0 : 20.0,
                    vertical: isDesktopOrWeb ? 24.0 : 20.0,
                  ),
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDesktopOrWeb) ...[
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: onCancel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Personal Information Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                // Header with icon
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Personal Information',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // FIX 2: Add null checks for userProfile access
                                if ((userProfile?['registration_type'] ?? '') ==
                                    'simple') ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: (_isEmailFieldReadOnly)
                                          ? Colors.grey.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (_isEmailFieldReadOnly)
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: _emailController,
                                      readOnly:
                                          _isEmailFieldReadOnly, // FIX 3: Add null check with default
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (value) {
                                        setState(() {
                                          // If user starts typing and checkbox is checked, uncheck it
                                          if ((_forceEmailVerification) &&
                                              value.trim() !=
                                                  (userProfile?['email'] ??
                                                      '')) {
                                            _forceEmailVerification = false;
                                            _isEmailFieldReadOnly = false;
                                          }
                                        });
                                      },
                                      decoration: InputDecoration(
                                        label: (_isEmailFieldReadOnly)
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Email',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.verified,
                                                    size: 16,
                                                    color:
                                                        Colors.green.shade600,
                                                  ),
                                                ],
                                              )
                                            : null,
                                        labelText: (_isEmailFieldReadOnly)
                                            ? null
                                            : 'Email',
                                        labelStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: (_isEmailFieldReadOnly)
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade700,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        prefixIcon: Icon(
                                          (_isEmailFieldReadOnly)
                                              ? Icons.lock_outline
                                              : Icons.email_outlined,
                                          size: 20,
                                          color: (_isEmailFieldReadOnly)
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: (_isEmailFieldReadOnly)
                                            ? Colors.grey.shade600
                                            : Colors.black87,
                                      ),
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return 'Required';
                                        }
                                        if (!value!.contains('@')) {
                                          return 'Invalid email';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _forceEmailVerification =
                                              !(_forceEmailVerification); // FIX 4: Add null check
                                          _handleEmailMutualExclusivity();
                                        });
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: Checkbox(
                                              value:
                                                  _forceEmailVerification, // FIX 5: Add null check with default
                                              onChanged: (value) {
                                                setState(() {
                                                  _forceEmailVerification =
                                                      value ?? false;
                                                  _handleEmailMutualExclusivity();
                                                });
                                              },
                                              activeColor:
                                                  Colors.orange.shade600,
                                              checkColor: Colors.white,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              (_forceEmailVerification)
                                                  ? 'Keep current email and send verification to: ${userProfile?['email'] ?? ''}'
                                                  : 'Email verification required. Change your email above or check this box to keep current email, then click Save to send verification.',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // VERIFIED EMAIL SECTION - Add null checks here too
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Email',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.verified,
                                                    size: 16,
                                                    color:
                                                        Colors.green.shade600,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                userProfile?['email'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
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
                                          Icons.verified_outlined,
                                          size: 16,
                                          color: Colors.green.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Your email address has been verified and cannot be changed.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                // Continue with rest of form fields...
                                _buildEnhancedTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  icon: Icons.person_outline,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildEnhancedTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  icon: Icons.person_outline,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildEnhancedTextField(
                                  controller: _middleNameController,
                                  label: 'Middle Name (optional)',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),
                                _buildEnhancedTextField(
                                  controller: _extNameController,
                                  label: 'Extension Name (optional)',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),
                                // Birthday Selector with null checks
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _selectedBirthday ?? DateTime.now(),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        _selectedBirthday = date;
                                        setState(() {});
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.cake_outlined,
                                              size: 20,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              _selectedBirthday == null
                                                  ? 'Select Birthday'
                                                  : 'Birthday: ${DateFormat('MMM d, y').format(_selectedBirthday!)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                color: _selectedBirthday == null
                                                    ? Colors.grey.shade500
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Gender Dropdown
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedGender,
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    items:
                                        ['Male', 'Female', 'LGBTQ+', 'Others']
                                            .map(
                                              (gender) => DropdownMenuItem(
                                                value: gender,
                                                child: Text(
                                                  gender,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) =>
                                        _selectedGender = value,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.black87,
                                    ),
                                    dropdownColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildEnhancedTextField(
                                  controller: _contactNumberController,
                                  label: 'Contact Number',
                                  icon: Icons.phone_outlined,
                                  hintText: '+63 9123456789',
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    if (!value.startsWith('+63')) {
                                      _contactNumberController.text = '+63';
                                      _contactNumberController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: _contactNumberController
                                                  .text
                                                  .length,
                                            ),
                                          );
                                    }

                                    if (value.length > 13) {
                                      _contactNumberController.text = value
                                          .substring(0, 13);
                                      _contactNumberController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: _contactNumberController
                                                  .text
                                                  .length,
                                            ),
                                          );
                                    }
                                  },
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      if (!value.startsWith('+63') ||
                                          value.length != 13) {
                                        return 'Must be in format +63xxxxxxxxxx (11 digits total)';
                                      }
                                      String digits = value.substring(3);
                                      if (!RegExp(
                                        r'^\d{10}$',
                                      ).hasMatch(digits)) {
                                        return 'Please enter valid digits after +63';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Police Information Card (shown only for officers)
                        if ((userProfile?['role'] ?? '') == 'officer') ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.local_police,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        'Police Information',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  FutureBuilder<void>(
                                    future: _policeRanks.isEmpty
                                        ? _loadPoliceData()
                                        : null,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Loading ranks...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: DropdownButtonFormField<int>(
                                          value: _selectedPoliceRankId,
                                          decoration: InputDecoration(
                                            labelText: 'Police Rank',
                                            labelStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 16,
                                                ),
                                            prefixIcon: Container(
                                              margin: const EdgeInsets.only(
                                                right: 16,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.military_tech_outlined,
                                                size: 20,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                          isExpanded: true,
                                          items: _policeRanks
                                              .map(
                                                (rank) => DropdownMenuItem<int>(
                                                  value: rank['id'],
                                                  child: Text(
                                                    rank['new_rank'] ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedPoliceRankId = value;
                                            });
                                          },
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black87,
                                          ),
                                          dropdownColor: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  FutureBuilder<void>(
                                    future: _policeStations.isEmpty
                                        ? _loadPoliceData()
                                        : null,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Loading stations...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: DropdownButtonFormField<int>(
                                          value: _selectedPoliceStationId,
                                          decoration: InputDecoration(
                                            labelText: 'Assigned Station',
                                            labelStyle: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 16,
                                                ),
                                            prefixIcon: Container(
                                              margin: const EdgeInsets.only(
                                                right: 16,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.location_on_outlined,
                                                size: 20,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                          items: _policeStations
                                              .map(
                                                (station) =>
                                                    DropdownMenuItem<int>(
                                                      value: station['id'],
                                                      child: Text(
                                                        station['name'] ??
                                                            'Unknown',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedPoliceStationId = value;
                                            });
                                          },
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black87,
                                          ),
                                          dropdownColor: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: onCancel,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.white.withOpacity(
                                      0.95,
                                    ),
                                    foregroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed:
                                      (_isUpdatingEmail || !_hasAnyChanges)
                                      ? null
                                      : () => updateProfile(
                                          context,
                                          onSuccess: onSuccess,
                                          onStateChange: setState,
                                          isSidebarVisible: isSidebarVisible,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getSaveButtonColor(
                                      context,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _buildSaveButtonContent(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isDesktopOrWeb) const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for enhanced text fields
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
        validator: validator,
      ),
    );
  }

  //PROFILE VIEW DESKTOP
  Widget buildDesktopProfileView(
    BuildContext context,
    VoidCallback onEditPressed, {
    VoidCallback? onClosePressed,
    required bool isSidebarVisible,
  }) {
    // Scroll to top when requested
    if (_shouldScrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_profileViewScrollController.hasClients) {
          _profileViewScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _shouldScrollToTop = false;
    }

    return Positioned(
      left: isSidebarVisible ? 5 : 20,
      top: 100,
      child: GestureDetector(
        onTap: () {},
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withOpacity(0.3),
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
                // Header section
                StatefulBuilder(
                  builder: (context, setStateHeader) {
                    return Container(
                      width: double.infinity,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/DARK.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Close button (Top Left)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed: onClosePressed ?? () {},
                              ),
                            ),
                          ),
                          // Top Right Buttons - Column layout for vertical stacking on desktop
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit Profile Button
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: onEditPressed,
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: const Color.fromARGB(
                                      255,
                                      43,
                                      68,
                                      105,
                                    ),
                                    tooltip: 'Edit Profile',
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Location Sharing Toggle (only for officer/admin)
                                // Using icon-only version for desktop
                                if (userProfile?['role'] == 'officer' ||
                                    userProfile?['role'] == 'admin')
                                  _buildLocationSharingIconOnly(
                                    context,
                                    setStateHeader,
                                  ),
                              ],
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                // Profile avatar
                                _buildDesktopProfileAvatar(
                                  context: context,
                                  isSidebarVisible: isSidebarVisible,
                                  isEditable: true,
                                  onStateChange: setStateHeader,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    '${userProfile?['first_name'] ?? ''}'
                                    '${userProfile?['middle_name'] != null ? ' ${userProfile?['middle_name']}' : ''}'
                                    ' ${userProfile?['last_name'] ?? ''}'
                                    '${userProfile?['ext_name'] != null ? ' ${userProfile?['ext_name']}' : ''}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.2,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (userProfile?['role'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A6B8A),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color:
                                                userProfile?['role'] ==
                                                    'officer'
                                                ? Colors.green
                                                : Colors.lightBlueAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          userProfile?['role']?.toUpperCase() ??
                                              'USER',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setStateLocal) {
                      // ← Renamed to make it clearer
                      return Column(
                        children: [
                          // Tab Headers
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                // Personal Info Tab
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setStateLocal(() => _selectedTab = 0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: _selectedTab == 0
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey.shade300,
                                            width: _selectedTab == 0 ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Personal Info',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: _selectedTab == 0
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: _selectedTab == 0
                                              ? Colors.black87
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Police Info Tab (Officers only)
                                if (userProfile?['role'] == 'officer')
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setStateLocal(() => _selectedTab = 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey.shade300,
                                              width: _selectedTab == 1 ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Police Info',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: _selectedTab == 1
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: _selectedTab == 1
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // ✅ Student Info Tab
                                if (userProfile?['user_type'] == 'wmsu_student')
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setStateLocal(() => _selectedTab = 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey.shade300,
                                              width: _selectedTab == 1 ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Student Info',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: _selectedTab == 1
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: _selectedTab == 1
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // ✅ Parent Info Tab
                                if (userProfile?['user_type'] == 'wmsu_parent')
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setStateLocal(() => _selectedTab = 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey.shade300,
                                              width: _selectedTab == 1 ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Parent Info',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: _selectedTab == 1
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: _selectedTab == 1
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // ✅ Employee Info Tab
                                if (userProfile?['user_type'] ==
                                    'wmsu_employee')
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setStateLocal(() => _selectedTab = 1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _selectedTab == 1
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.grey.shade300,
                                              width: _selectedTab == 1 ? 2 : 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Employee Info',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: _selectedTab == 1
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: _selectedTab == 1
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _profileViewScrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: _selectedTab == 0
                                          ? _buildDesktopPersonalInfoItems(
                                              context,
                                            )
                                          : (userProfile?['role'] == 'officer'
                                                ? _buildDesktopPoliceInfoItems(
                                                    context,
                                                  )
                                                : (userProfile?['user_type'] ==
                                                          'wmsu_student'
                                                      ? _buildDesktopStudentInfoItems(
                                                          context,
                                                        )
                                                      : (userProfile?['user_type'] ==
                                                                'wmsu_parent'
                                                            ? _buildDesktopParentInfoItems(
                                                                context,
                                                                isSidebarVisible,
                                                              )
                                                            : _buildDesktopEmployeeInfoItems(
                                                                context,
                                                              )))),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  // System Dashboard Button
                                  if (hasAdminPermissions) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AdminDashboardScreen(),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color.fromARGB(
                                              255,
                                              43,
                                              68,
                                              105,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'System Dashboard',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color.fromARGB(
                                              255,
                                              43,
                                              68,
                                              105,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  // Change Password Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          showChangePasswordModalDesktop(
                                            context,
                                            isSidebarVisible: isSidebarVisible,
                                          ),
                                      icon: Icon(
                                        Icons.lock_outline,
                                        size: 20,
                                        color: Colors.grey.shade800,
                                      ),
                                      label: Text(
                                        'Change Password',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.grey.shade800,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Logout Button
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showLogoutConfirmation(context),
                                      icon: const Icon(
                                        Icons.logout,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          43,
                                          68,
                                          105,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Desktop Personal info items - matching mobile clean design
  List<Widget> _buildDesktopPersonalInfoItems(BuildContext context) {
    return [
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.email_outlined,
        label: 'Email',
        value: userProfile?['email'] ?? 'Add an email',
        hasValue: userProfile?['email'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: userProfile?['contact_number'] ?? 'Add a phone number',
        hasValue: userProfile?['contact_number'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.cake_outlined,
        label: 'Birthday',
        value: userProfile?['bday'] != null
            ? DateFormat(
                'MMMM d, y',
              ).format(DateTime.parse(userProfile?['bday']))
            : 'Add a birthday',
        hasValue: userProfile?['bday'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'Gender',
        value: userProfile?['gender'] ?? 'Add gender',
        hasValue: userProfile?['gender'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'Username',
        value: userProfile?['username'] ?? 'Add username',
        hasValue: userProfile?['username'] != null,
        isLast: true,
      ),
    ];
  }

  // Desktop Police info items - matching mobile clean design
  List<Widget> _buildDesktopPoliceInfoItems(BuildContext context) {
    return [
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.military_tech_outlined,
        label: 'Police Rank',
        value:
            _getPoliceRankName(userProfile?['police_rank_id']) ??
            'Not assigned',
        hasValue: _getPoliceRankName(userProfile?['police_rank_id']) != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.location_on_outlined,
        label: 'Assigned Station',
        value:
            _getPoliceStationName(userProfile?['police_station_id']) ??
            'Not assigned',
        hasValue:
            _getPoliceStationName(userProfile?['police_station_id']) != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.work_outline,
        label: 'Role',
        value: userProfile?['role']?.toUpperCase() ?? 'USER',
        hasValue: true,
        isLast: true,
      ),
    ];
  }

  // Clean info item widget for desktop - exactly matching mobile design
  Widget _buildDesktopCleanInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool hasValue,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: hasValue ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //EDIT PROFILE DESKTOP
  Widget buildDesktopEditProfileForm(
    BuildContext context,
    VoidCallback onCancel, {
    required VoidCallback onSuccess,
    required bool isSidebarVisible,
    required Function(VoidCallback)
    onStateChange, // Add callback for state changes
  }) {
    if (_shouldScrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _shouldScrollToTop = false;
    }

    return Positioned(
      left: isSidebarVisible ? 5 : 20, // Match QuickAccessDesktopScreen
      top: 100,
      child: GestureDetector(
        onTap: () {}, // Prevent propagation to overlay
        child: Material(
          elevation: 16, // Match QuickAccessDesktopScreen
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withOpacity(0.3),
          child: Container(
            width: 450, // Match QuickAccessDesktopScreen
            height: 800, // Match QuickAccessDesktopScreen
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              image: const DecorationImage(
                image: AssetImage('assets/images/LIGHT.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _shouldScrollToTop = true;
                              onCancel();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Personal Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (userProfile?['registration_type'] ==
                                  'simple') ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: _isEmailFieldReadOnly
                                        ? Colors.grey.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isEmailFieldReadOnly
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _emailController,
                                    readOnly: _isEmailFieldReadOnly,
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) {
                                      onStateChange(() {
                                        if (_forceEmailVerification &&
                                            value.trim() !=
                                                (userProfile?['email'] ?? '')) {
                                          _forceEmailVerification = false;
                                          _isEmailFieldReadOnly = false;
                                        }
                                      });
                                    },
                                    decoration: InputDecoration(
                                      label: _isEmailFieldReadOnly
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Email',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.verified,
                                                  size: 16,
                                                  color: Colors.green.shade600,
                                                ),
                                              ],
                                            )
                                          : null,
                                      labelText: _isEmailFieldReadOnly
                                          ? null
                                          : 'Email',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _isEmailFieldReadOnly
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade700,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                      prefixIcon: Icon(
                                        _isEmailFieldReadOnly
                                            ? Icons.lock_outline
                                            : Icons.email_outlined,
                                        size: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _isEmailFieldReadOnly
                                          ? Colors.grey.shade600
                                          : Colors.black87,
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      if (!value!.contains('@')) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      onStateChange(() {
                                        _forceEmailVerification =
                                            !_forceEmailVerification;
                                        _handleEmailMutualExclusivity();
                                      });
                                    },
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: Checkbox(
                                            value: _forceEmailVerification,
                                            onChanged: (value) {
                                              onStateChange(() {
                                                _forceEmailVerification =
                                                    value ?? false;
                                                _handleEmailMutualExclusivity();
                                              });
                                            },
                                            activeColor: Colors.orange.shade600,
                                            checkColor: Colors.white,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _forceEmailVerification
                                                ? 'Keep current email and send verification to: ${userProfile?['email'] ?? ''}'
                                                : 'Email verification required. Change your email above or check this box to keep current email, then click Save to send verification.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Email',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.verified,
                                                  size: 16,
                                                  color: Colors.green.shade600,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              userProfile?['email'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
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
                                        Icons.verified_outlined,
                                        size: 16,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Your email address has been verified and cannot be changed.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                icon: Icons.person_outline,
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                icon: Icons.person_outline,
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _middleNameController,
                                label: 'Middle Name (optional)',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _extNameController,
                                label: 'Extension Name (optional)',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _selectedBirthday ?? DateTime.now(),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      onStateChange(() {
                                        _selectedBirthday = date;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.cake_outlined,
                                            size: 20,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            _selectedBirthday == null
                                                ? 'Select Birthday'
                                                : 'Birthday: ${DateFormat('MMM d, y').format(_selectedBirthday!)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: _selectedBirthday == null
                                                  ? Colors.grey.shade500
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  decoration: InputDecoration(
                                    labelText: 'Gender',
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(right: 16),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  items: ['Male', 'Female', 'LGBTQ+', 'Others']
                                      .map(
                                        (gender) => DropdownMenuItem(
                                          value: gender,
                                          child: Text(
                                            gender,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    onStateChange(() {
                                      _selectedGender = value;
                                    });
                                  },
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                  dropdownColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _contactNumberController,
                                label: 'Contact Number',
                                icon: Icons.phone_outlined,
                                hintText: '+63 9123456789',
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (!value.startsWith('+63')) {
                                    _contactNumberController.text = '+63';
                                    _contactNumberController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: _contactNumberController
                                                .text
                                                .length,
                                          ),
                                        );
                                  }
                                  if (value.length > 13) {
                                    _contactNumberController.text = value
                                        .substring(0, 13);
                                    _contactNumberController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: _contactNumberController
                                                .text
                                                .length,
                                          ),
                                        );
                                  }
                                },
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (!value.startsWith('+63') ||
                                        value.length != 13) {
                                      return 'Must be in format +63xxxxxxxxxx (11 digits total)';
                                    }
                                    String digits = value.substring(3);
                                    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
                                      return 'Please enter valid digits after +63';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (userProfile?['role'] == 'officer') ...[
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.local_police,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Police Information',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                FutureBuilder<void>(
                                  future: _policeRanks.isEmpty
                                      ? _loadPoliceData()
                                      : null,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Loading ranks...',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButtonFormField<int>(
                                        value: _selectedPoliceRankId,
                                        decoration: InputDecoration(
                                          labelText: 'Police Rank',
                                          labelStyle: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.only(
                                              right: 16,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.military_tech_outlined,
                                              size: 20,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        isExpanded: true,
                                        items: _policeRanks
                                            .map(
                                              (rank) => DropdownMenuItem<int>(
                                                value: rank['id'],
                                                child: Text(
                                                  rank['new_rank'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          onStateChange(() {
                                            _selectedPoliceRankId = value;
                                          });
                                        },
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                        ),
                                        dropdownColor: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                FutureBuilder<void>(
                                  future: _policeStations.isEmpty
                                      ? _loadPoliceData()
                                      : null,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Loading stations...',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButtonFormField<int>(
                                        value: _selectedPoliceStationId,
                                        decoration: InputDecoration(
                                          labelText: 'Assigned Station',
                                          labelStyle: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.only(
                                              right: 16,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.location_on_outlined,
                                              size: 20,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        items: _policeStations
                                            .map(
                                              (
                                                station,
                                              ) => DropdownMenuItem<int>(
                                                value: station['id'],
                                                child: Text(
                                                  station['name'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          onStateChange(() {
                                            _selectedPoliceStationId = value;
                                          });
                                        },
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                        ),
                                        dropdownColor: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () {
                                  _shouldScrollToTop = true;
                                  onCancel();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.95,
                                  ),
                                  foregroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                ),
                                child: Text(
                                  'CANCEL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isUpdatingEmail || !_hasAnyChanges)
                                    ? null
                                    : () => updateProfile(
                                        context,
                                        onSuccess: onSuccess,
                                        onStateChange: onStateChange,
                                        isSidebarVisible: isSidebarVisible,
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getSaveButtonColor(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _buildSaveButtonContent(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add these helper methods for the save button
  Color _getSaveButtonColor(BuildContext context) {
    switch (_saveButtonState) {
      case SaveButtonState.saved:
        return Colors.green;

      case SaveButtonState.saving:
      case SaveButtonState.normal:
        return const Color.fromARGB(255, 43, 68, 105);
    }
  }

  Widget _buildSaveButtonContent() {
    switch (_saveButtonState) {
      case SaveButtonState.saving:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'SAVING..',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        );
      case SaveButtonState.saved:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              'SAVED',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        );

      case SaveButtonState.normal:
        return _isUpdatingEmail
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SENDING..',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Text(
                'SAVE',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              );
    }
  }

  // Keep the existing helper methods unchanged

  String? _getPoliceRankName(int? rankId) {
    if (rankId == null) return null;

    // If data not loaded yet, return a placeholder or fetch it
    if (_policeRanks.isEmpty) {
      return 'Loading...'; // or fetch the specific rank from database
    }

    final rank = _policeRanks.firstWhere(
      (r) => r['id'] == rankId,
      orElse: () => {},
    );

    if (rank.isEmpty) return 'Unknown Rank';

    final newRank = rank['new_rank']?.toString();
    final oldRank = rank['old_rank']?.toString();

    if (newRank != null && oldRank != null) {
      return '$newRank ($oldRank)';
    } else if (newRank != null) {
      return newRank;
    } else if (oldRank != null) {
      return oldRank;
    } else {
      return 'Unknown Rank';
    }
  }

  String? _getPoliceStationName(int? stationId) {
    if (stationId == null) return null;

    // If data not loaded yet, return a placeholder or fetch it
    if (_policeStations.isEmpty) {
      return 'Loading...'; // or fetch the specific station from database
    }

    final station = _policeStations.firstWhere(
      (s) => s['id'] == stationId,
      orElse: () => {},
    );
    return station.isNotEmpty ? station['name'] : 'Unknown Station';
  }

  //CHANGE PASSWORD MOBILE
  void showChangePasswordModal(BuildContext context) {
    // Reset controllers and errors
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _obscureCurrentPassword = true;
    _obscureNewPassword = true;
    _obscureConfirmPassword = true;
    _passwordButtonState = PasswordButtonState.normal;
    _currentPasswordError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;

    showDialog(
      context: context,
      barrierDismissible: _passwordButtonState != PasswordButtonState.changing,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.of(context).size.width *
                0.025, // 2.5% padding = 95% width
            vertical: 20,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(
              maxWidth: 500,
            ), // Max width for larger screens
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2B4469),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed:
                            _passwordButtonState == PasswordButtonState.changing
                            ? null
                            : () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Password must be at least 6 characters long',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Current Password
                        _buildPasswordField(
                          context: context,
                          controller: _currentPasswordController,
                          label: 'Current Password',
                          obscureText: _obscureCurrentPassword,
                          errorText: _currentPasswordError,
                          onToggleVisibility: () {
                            setModalState(() {
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                          onChanged: (value) {
                            if (_currentPasswordError != null) {
                              setModalState(() {
                                _currentPasswordError = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // New Password
                        _buildPasswordField(
                          context: context,
                          controller: _newPasswordController,
                          label: 'New Password',
                          obscureText: _obscureNewPassword,
                          errorText: _newPasswordError,
                          onToggleVisibility: () {
                            setModalState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            });
                          },
                          onChanged: (value) {
                            if (_newPasswordError != null) {
                              setModalState(() {
                                _newPasswordError = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // Confirm Password
                        _buildPasswordField(
                          context: context,
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          obscureText: _obscureConfirmPassword,
                          errorText: _confirmPasswordError,
                          onToggleVisibility: () {
                            setModalState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          onChanged: (value) {
                            if (_confirmPasswordError != null) {
                              setModalState(() {
                                _confirmPasswordError = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 30),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                _passwordButtonState !=
                                    PasswordButtonState.normal
                                ? null
                                : () => _handleChangePassword(
                                    context,
                                    setModalState,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPasswordButtonColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              disabledBackgroundColor:
                                  _getPasswordButtonColor(),
                            ),
                            child: _buildPasswordButtonContent(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed:
                                _passwordButtonState ==
                                    PasswordButtonState.changing
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    _passwordButtonState ==
                                        PasswordButtonState.changing
                                    ? Colors.grey.shade400
                                    : const Color(0xFF2B4469),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    _passwordButtonState ==
                                        PasswordButtonState.changing
                                    ? Colors.grey.shade400
                                    : const Color(0xFF2B4469),
                              ),
                            ),
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
      ),
    );
  }

  // Helper method for button color
  Color _getPasswordButtonColor() {
    switch (_passwordButtonState) {
      case PasswordButtonState.changed:
        return Colors.grey.shade500;
      case PasswordButtonState.changing:
      case PasswordButtonState.normal:
        return const Color(0xFF2B4469);
    }
  }

  // Helper method for button content
  Widget _buildPasswordButtonContent() {
    switch (_passwordButtonState) {
      case PasswordButtonState.changing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'CHANGING...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        );

      case PasswordButtonState.changed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'CHANGED',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        );

      case PasswordButtonState.normal:
        return const Text(
          'CHANGE PASSWORD',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        );
    }
  }

  // Add this helper method for password fields with inline error display:
  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? errorText,
    Function(String)? onChanged,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: hasError ? Colors.red.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.red.shade400 : Colors.grey.shade200,
              width: hasError ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red.shade700 : Colors.grey.shade700,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                size: 20,
                color: hasError ? Colors.red.shade600 : Colors.grey.shade600,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: hasError ? Colors.red.shade600 : Colors.grey.shade600,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Add this method to handle password change with inline validation:
  Future<void> _handleChangePassword(
    BuildContext context,
    StateSetter setModalState,
  ) async {
    // Clear all errors first
    setModalState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    bool hasError = false;

    // Validate current password
    if (_currentPasswordController.text.isEmpty) {
      setModalState(() {
        _currentPasswordError = 'Current password is required';
      });
      hasError = true;
    }

    // Validate new password
    if (_newPasswordController.text.isEmpty) {
      setModalState(() {
        _newPasswordError = 'New password is required';
      });
      hasError = true;
    } else if (_newPasswordController.text.length < 6) {
      setModalState(() {
        _newPasswordError = 'Password must be at least 6 characters';
      });
      hasError = true;
    }

    // Validate confirm password
    if (_confirmPasswordController.text.isEmpty) {
      setModalState(() {
        _confirmPasswordError = 'Please confirm your new password';
      });
      hasError = true;
    } else if (_confirmPasswordController.text.length < 6) {
      setModalState(() {
        _confirmPasswordError = 'Password must be at least 6 characters';
      });
      hasError = true;
    }

    // Check if passwords match
    if (!hasError &&
        _newPasswordController.text != _confirmPasswordController.text) {
      setModalState(() {
        _newPasswordError = 'Passwords do not match';
        _confirmPasswordError = 'Passwords do not match';
      });
      hasError = true;
    }

    // Check if new password is same as current password
    if (!hasError &&
        _currentPasswordController.text == _newPasswordController.text) {
      setModalState(() {
        _newPasswordError =
            'New password must be different from current password';
      });
      hasError = true;
    }

    if (hasError) return;

    setModalState(() => _passwordButtonState = PasswordButtonState.changing);

    try {
      await _authService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!context.mounted) return;

      // Show changed state briefly
      setModalState(() {
        _passwordButtonState = PasswordButtonState.changed;
      });

      // Wait 1 second then close modal
      _passwordButtonStateTimer?.cancel();
      _passwordButtonStateTimer = Timer(const Duration(seconds: 1), () {
        if (context.mounted) {
          Navigator.pop(context);
        }
        _passwordButtonState = PasswordButtonState.normal;
      });
    } on AuthException catch (e) {
      if (!context.mounted) return;

      // Handle specific auth errors
      setModalState(() {
        _passwordButtonState = PasswordButtonState.normal;
        if (e.message.toLowerCase().contains('current password')) {
          _currentPasswordError = e.message;
        } else {
          _newPasswordError = e.message;
        }
      });
    } catch (e) {
      if (!context.mounted) return;

      setModalState(() {
        _passwordButtonState = PasswordButtonState.normal;
        _currentPasswordError = 'Failed to change password. Please try again.';
      });
    }
  }

  void showChangePasswordModalDesktop(
    BuildContext context, {
    required bool isSidebarVisible,
  }) {
    // Reset controllers and errors
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _obscureCurrentPassword = true;
    _obscureNewPassword = true;
    _obscureConfirmPassword = true;
    _passwordButtonState = PasswordButtonState.normal;
    _currentPasswordError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;

    showDialog(
      context: context,
      barrierDismissible: _passwordButtonState != PasswordButtonState.changing,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Calculate position based on profile view location (same as error dialog)
          final profileLeft = isSidebarVisible ? 310.0 : 110.0;
          final profileWidth = 400.0;
          final modalWidth = 400.0;
          final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

          return Stack(
            children: [
              Positioned(
                left: centeredLeft,
                top: 250,
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B4469),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Change Password',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    _passwordButtonState ==
                                        PasswordButtonState.changing
                                    ? null
                                    : () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 500),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Info Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Password must be at least 6 characters long',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Current Password
                                _buildPasswordField(
                                  context: context,
                                  controller: _currentPasswordController,
                                  label: 'Current Password',
                                  obscureText: _obscureCurrentPassword,
                                  errorText: _currentPasswordError,
                                  onToggleVisibility: () {
                                    setModalState(() {
                                      _obscureCurrentPassword =
                                          !_obscureCurrentPassword;
                                    });
                                  },
                                  onChanged: (value) {
                                    if (_currentPasswordError != null) {
                                      setModalState(() {
                                        _currentPasswordError = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                // New Password
                                _buildPasswordField(
                                  context: context,
                                  controller: _newPasswordController,
                                  label: 'New Password',
                                  obscureText: _obscureNewPassword,
                                  errorText: _newPasswordError,
                                  onToggleVisibility: () {
                                    setModalState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
                                  onChanged: (value) {
                                    if (_newPasswordError != null) {
                                      setModalState(() {
                                        _newPasswordError = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Confirm Password
                                _buildPasswordField(
                                  context: context,
                                  controller: _confirmPasswordController,
                                  label: 'Confirm New Password',
                                  obscureText: _obscureConfirmPassword,
                                  errorText: _confirmPasswordError,
                                  onToggleVisibility: () {
                                    setModalState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  onChanged: (value) {
                                    if (_confirmPasswordError != null) {
                                      setModalState(() {
                                        _confirmPasswordError = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 30),
                                // Change Password Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed:
                                        _passwordButtonState !=
                                            PasswordButtonState.normal
                                        ? null
                                        : () => _handleChangePassword(
                                            context,
                                            setModalState,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _getPasswordButtonColor(),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      disabledBackgroundColor:
                                          _getPasswordButtonColor(),
                                    ),
                                    child: _buildPasswordButtonContent(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Cancel Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed:
                                        _passwordButtonState ==
                                            PasswordButtonState.changing
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color:
                                            _passwordButtonState ==
                                                PasswordButtonState.changing
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'CANCEL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color:
                                            _passwordButtonState ==
                                                PasswordButtonState.changing
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                    ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ 2. UPDATE _buildDesktopStudentInfoItems to include pending requests section
  List<Widget> _buildDesktopStudentInfoItems(BuildContext context) {
    return [
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.school_outlined,
        label: 'Education Level',
        value: userProfile?['wmsu_education_level'] ?? 'Not set',
        hasValue: userProfile?['wmsu_education_level'] != null,
      ),
      if (userProfile?['wmsu_education_level'] != 'elementary')
        _buildDesktopCleanInfoItem(
          context,
          icon: Icons.calendar_today_outlined,
          label: 'Year Level',
          value: userProfile?['wmsu_year_level'] ?? 'Not set',
          hasValue: userProfile?['wmsu_year_level'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'college')
        _buildDesktopCleanInfoItem(
          context,
          icon: Icons.business_outlined,
          label: 'College',
          value: userProfile?['wmsu_college'] ?? 'Not set',
          hasValue: userProfile?['wmsu_college'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'college')
        _buildDesktopCleanInfoItem(
          context,
          icon: Icons.work_outline,
          label: 'Department',
          value: userProfile?['wmsu_department'] ?? 'Not set',
          hasValue: userProfile?['wmsu_department'] != null,
        ),
      if (userProfile?['wmsu_education_level'] == 'senior_high')
        _buildDesktopCleanInfoItem(
          context,
          icon: Icons.route_outlined,
          label: 'Track/Strand',
          value: userProfile?['wmsu_track_strand'] ?? 'Not set',
          hasValue: userProfile?['wmsu_track_strand'] != null,
        ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.class_outlined,
        label: 'Section',
        value: userProfile?['wmsu_section'] ?? 'Not set',
        hasValue: userProfile?['wmsu_section'] != null,
      ),

      // ✅ NEW: Connected Parents Section
      _buildConnectedParentsSection(context),

      // ✅ NEW: Pending Parent Requests Section
      _buildPendingRequestsSection(context),
    ];
  }

  // ✅ 3. ADD CONNECTED PARENTS SECTION FOR STUDENTS
  Widget _buildConnectedParentsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _studentParentsFuture, // ✅ Use cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.hourglass_empty,
            label: 'Connected Parents',
            value: 'Loading...',
            hasValue: false,
          );
        }

        final parents = snapshot.data ?? [];

        if (parents.isEmpty) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.family_restroom_outlined,
            label: 'Connected Parents',
            value: 'No connections yet',
            hasValue: false,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.family_restroom_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Connected Parents',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...parents.map(
                (parent) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent['parent_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${parent['relationship_type']?.toString().toUpperCase()} ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
        );
      },
    );
  }

  // ✅ 4. ADD PENDING REQUESTS SECTION FOR STUDENTS
  Widget _buildPendingRequestsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pendingRequestsFuture, // ✅ Use cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.pending_outlined,
            label: 'Pending Requests',
            value: 'Loading...',
            hasValue: false,
            isLast: true,
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.check_circle_outline,
            label: 'Pending Requests',
            value: 'No pending requests',
            hasValue: false,
            isLast: true,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pending_outlined,
                      size: 20,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Pending Requests (${requests.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...requests.map(
                (request) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request['parent_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Wants to connect as ${request['relationship_type']?.toString().toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (request['notes'] != null &&
                                    request['notes'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Note: ${request['notes']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                Text(
                                  'Sent: ${_formatRequestTime(request['requested_at'])}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _respondToRequest(
                                context,
                                request['request_id'],
                                true,
                              ),
                              icon: const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _respondToRequest(
                                context,
                                request['request_id'],
                                false,
                              ),
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red.shade700,
                              ),
                              label: Text(
                                'Reject',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadStudentParents() async {
    if (userProfile?['id'] == null) return [];

    try {
      final response = await Supabase.instance.client.rpc(
        'get_student_parents',
        params: {'student_uuid': userProfile!['id']},
      );

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading student parents: $e');
      }
      return [];
    }
  }

  // Load pending parent requests for student
  Future<List<Map<String, dynamic>>> _loadPendingParentRequests() async {
    if (userProfile?['id'] == null) return [];

    try {
      final response = await Supabase.instance.client.rpc(
        'get_pending_parent_requests',
        params: {'student_uuid': userProfile!['id']},
      );

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading pending requests: $e');
      }
      return [];
    }
  }

  // Format request timestamp
  String _formatRequestTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final DateTime dateTime = DateTime.parse(timestamp.toString());
      final Duration difference = DateTime.now().difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, y').format(dateTime);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Respond to parent request
  Future<void> _respondToRequest(
    BuildContext context,
    String requestId,
    bool accept,
  ) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'respond_to_parent_request',
        params: {
          'p_request_id': requestId,
          'p_student_id': userProfile!['id'],
          'p_accept': accept,
        },
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Parent connection accepted!' : 'Request rejected',
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );

        // ✅ Refresh the data
        _refreshRelationships();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to respond'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Widget> _buildDesktopParentInfoItems(
    BuildContext context,
    bool isSidebarVisible,
  ) {
    return [
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.person_outline,
        label: 'User Type',
        value: 'WMSU Parent',
        hasValue: true,
      ),

      // Connected Students Section
      _buildConnectedStudentsSection(context, isSidebarVisible),

      // Fixed Send Request Button
      _buildSendRequestButton(
        context,
        isSidebarVisible,
      ), // ✅ Pass isSidebarVisible
    ];
  }

  // ✅ Add this class variable at the top of ProfileScreen class

  Widget _buildConnectedStudentsSection(
    BuildContext context,
    bool isSidebarVisible,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _parentStudentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.hourglass_empty,
            label: 'My Children',
            value: 'Loading...',
            hasValue: false,
          );
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return _buildDesktopCleanInfoItem(
            context,
            icon: Icons.family_restroom_outlined,
            label: 'My Children',
            value: 'No children connected yet',
            hasValue: false,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.family_restroom,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Children',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...students.map(
                (student) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Show custom label if exists, otherwise student name
                            Text(
                              student['custom_label']?.toString().isNotEmpty ==
                                      true
                                  ? student['custom_label']
                                  : student['student_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            // ✅ Show student name below if custom label is set
                            if (student['custom_label']
                                    ?.toString()
                                    .isNotEmpty ==
                                true)
                              Text(
                                student['student_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            // ✅ Show relationship type and WMSU ID (removed from main display)
                            Text(
                              '${student['relationship_type']?.toString().toUpperCase()} • ${student['student_wmsu_id'] ?? 'No ID'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ✅ Add edit icon button
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () => _showEditLabelDialogDesktop(
                          context,
                          student['student_id'],
                          student['student_name'],
                          student['custom_label'],
                          isSidebarVisible: isSidebarVisible,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit label',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendRequestButton(BuildContext context, bool isSidebarVisible) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _showSendRequestDialog(
            context,
            isSidebarVisible: isSidebarVisible,
          ),
          icon: const Icon(Icons.person_add, size: 20, color: Colors.white),
          label: const Text(
            'Connect with Your Child',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 43, 68, 105),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  // Load parent's connected students
  Future<List<Map<String, dynamic>>> _loadParentStudents() async {
    if (userProfile?['id'] == null) return [];

    try {
      final response = await Supabase.instance.client.rpc(
        'get_parent_students',
        params: {'parent_uuid': userProfile!['id']},
      );

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading parent students: $e');
      }
      return [];
    }
  }

  void _showSendRequestDialog(
    BuildContext context, {
    required bool isSidebarVisible,
  }) {
    final TextEditingController wmsuIdController = TextEditingController();
    String? selectedRelationship = 'mother';
    final TextEditingController notesController = TextEditingController();

    // Add validation error states
    String? wmsuIdError;
    bool isSubmitting = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Calculate position based on profile view location (same as change password)
          final profileLeft = isSidebarVisible ? 284.0 : 84.0;
          final profileWidth = 450.0;
          final modalWidth = 420.0;
          final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

          return Stack(
            children: [
              Positioned(
                left: centeredLeft,
                top: 170,
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Container(
                    width: 420,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B4469),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Connect with Your Child',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 600),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Info Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.green.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Your child will need to accept the connection',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Student WMSU ID Field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Student WMSU ID',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: wmsuIdController,
                                      enabled: !isSubmitting,
                                      decoration: InputDecoration(
                                        hintText: 'Enter student ID number',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          color: wmsuIdError != null
                                              ? Colors.red
                                              : Colors.grey.shade600,
                                        ),
                                        filled: true,
                                        fillColor: isSubmitting
                                            ? Colors.grey.shade100
                                            : Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: wmsuIdError != null
                                                ? Colors.red
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: wmsuIdError != null
                                                ? Colors.red
                                                : const Color(0xFF2B4469),
                                            width: 2,
                                          ),
                                        ),
                                        errorText: wmsuIdError,
                                        errorStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (wmsuIdError != null) {
                                          setModalState(() {
                                            wmsuIdError = null;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Relationship Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Relationship Type',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: selectedRelationship,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isSubmitting
                                            ? Colors.grey.shade100
                                            : Colors.grey.shade50,
                                        prefixIcon: Icon(
                                          Icons.family_restroom_outlined,
                                          color: Colors.grey.shade600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2B4469),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'mother',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.woman,
                                                size: 18,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Mother'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'father',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.man,
                                                size: 18,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Father'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'guardian',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.shield_outlined,
                                                size: 18,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Guardian'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'other',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.more_horiz,
                                                size: 18,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Other'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: isSubmitting
                                          ? null
                                          : (value) {
                                              setModalState(() {
                                                selectedRelationship = value;
                                              });
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Notes Field
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notes (Optional)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: notesController,
                                      enabled: !isSubmitting,
                                      maxLines: 3,
                                      maxLength: 200,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Add any additional information (optional)',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                        filled: true,
                                        fillColor: isSubmitting
                                            ? Colors.grey.shade100
                                            : Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2B4469),
                                            width: 2,
                                          ),
                                        ),
                                        counterStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),

                                // Send Request Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isSubmitting || isSuccess
                                        ? null
                                        : () async {
                                            final wmsuId = wmsuIdController.text
                                                .trim();
                                            if (wmsuId.isEmpty) {
                                              setModalState(() {
                                                wmsuIdError =
                                                    'Please enter student ID';
                                              });
                                              return;
                                            }

                                            // Start submitting
                                            setModalState(() {
                                              isSubmitting = true;
                                              wmsuIdError = null;
                                            });

                                            // Send request
                                            await _sendParentRequest(
                                              context,
                                              wmsuId,
                                              selectedRelationship!,
                                              notesController.text.trim(),
                                            );

                                            // Show success state briefly
                                            if (context.mounted) {
                                              setModalState(() {
                                                isSubmitting = false;
                                                isSuccess = true;
                                              });

                                              // Auto-close after showing success
                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 800,
                                                ),
                                              );
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSuccess
                                          ? Colors.green
                                          : const Color(0xFF2B4469),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      disabledBackgroundColor: isSuccess
                                          ? Colors.green
                                          : const Color(0xFF2B4469),
                                    ),
                                    child: isSubmitting
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'SENDING REQUEST...',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                ),
                                              ),
                                            ],
                                          )
                                        : isSuccess
                                        ? const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'REQUEST SENT!',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.send,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'SEND REQUEST',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Cancel Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isSubmitting
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'CANCEL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isSubmitting
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                    ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ Update _sendParentRequest to increment the notifier
  Future<void> _sendParentRequest(
    BuildContext context,
    String studentWmsuId,
    String relationship,
    String notes,
  ) async {
    try {
      final studentResponse = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('wmsu_id_number', studentWmsuId)
          .eq('user_type', 'wmsu_student')
          .maybeSingle();

      if (studentResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student not found with that WMSU ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await Supabase.instance.client.rpc(
        'send_parent_request',
        params: {
          'p_parent_id': userProfile!['id'],
          'p_student_id': studentResponse['id'],
          'p_relationship_type': relationship,
          'p_notes': notes.isEmpty ? null : notes,
        },
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ Refresh the data
        _refreshRelationships();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Widget> _buildDesktopEmployeeInfoItems(BuildContext context) {
    return [
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.badge_outlined,
        label: 'WMSU ID Number',
        value: userProfile?['wmsu_id_number'] ?? 'Not assigned',
        hasValue: userProfile?['wmsu_id_number'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.business_outlined,
        label: 'College/Office',
        value: userProfile?['wmsu_college'] ?? 'Not set',
        hasValue: userProfile?['wmsu_college'] != null,
      ),
      _buildDesktopCleanInfoItem(
        context,
        icon: Icons.work_outline,
        label: 'Department',
        value: userProfile?['wmsu_department'] ?? 'Not set',
        hasValue: userProfile?['wmsu_department'] != null,
        isLast: true,
      ),
    ];
  }

  void _showEditLabelDialogDesktop(
    BuildContext context,
    String studentId,
    String studentName,
    String? currentLabel, {
    required bool isSidebarVisible,
  }) {
    final TextEditingController labelController = TextEditingController(
      text: currentLabel ?? '',
    );
    bool isSaving = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Calculate position (same as send request modal)
          final profileLeft = isSidebarVisible ? 284.0 : 84.0;
          final profileWidth = 450.0;
          final modalWidth = 420.0;
          final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;

          return Stack(
            children: [
              Positioned(
                left: centeredLeft,
                top: 200,
                child: Material(
                  elevation: 16,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Colors.black.withOpacity(0.3),
                  child: Container(
                    width: 420,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B4469),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.label_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Set Custom Label',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 500),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Info Banner
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Setting label for:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            Text(
                                              studentName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Custom Label Field
                                Text(
                                  'Custom Label',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: labelController,
                                  enabled: !isSaving,
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                    hintText:
                                        'e.g., My Son, My Daughter, My Eldest',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.label,
                                      color: Colors.grey.shade600,
                                    ),
                                    filled: true,
                                    fillColor: isSaving
                                        ? Colors.grey.shade100
                                        : Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2B4469),
                                        width: 2,
                                      ),
                                    ),
                                    helperText:
                                        'Leave empty to use student\'s name',
                                    helperStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Quick Suggestions
                                Text(
                                  'Quick Suggestions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      [
                                        'My Son',
                                        'My Daughter',
                                        'My Eldest',
                                        'My Youngest',
                                        'My Child',
                                      ].map((suggestion) {
                                        return InkWell(
                                          onTap: isSaving
                                              ? null
                                              : () {
                                                  setModalState(() {
                                                    labelController.text =
                                                        suggestion;
                                                  });
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.blue.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              suggestion,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                                const SizedBox(height: 30),

                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isSaving || isSuccess
                                        ? null
                                        : () async {
                                            setModalState(
                                              () => isSaving = true,
                                            );

                                            await _updateStudentLabel(
                                              context,
                                              studentId,
                                              labelController.text.trim(),
                                            );

                                            if (context.mounted) {
                                              setModalState(() {
                                                isSaving = false;
                                                isSuccess = true;
                                              });

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 500,
                                                ),
                                              );
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSuccess
                                          ? Colors.green
                                          : const Color(0xFF2B4469),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      disabledBackgroundColor: isSuccess
                                          ? Colors.green
                                          : const Color(0xFF2B4469),
                                    ),
                                    child: isSaving
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'SAVING...',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                ),
                                              ),
                                            ],
                                          )
                                        : isSuccess
                                        ? const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'SAVED!',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.save,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'SAVE LABEL',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Cancel Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isSaving
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'CANCEL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isSaving
                                            ? Colors.grey.shade400
                                            : const Color(0xFF2B4469),
                                      ),
                                    ),
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
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ MOBILE VERSION - Bottom Sheet with 90-95% width
  void _showEditLabelDialogMobile(
    BuildContext context,
    String studentId,
    String studentName,
    String? currentLabel,
  ) {
    final TextEditingController labelController = TextEditingController(
      text: currentLabel ?? '',
    );
    bool isSaving = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isSaving,
      enableDrag: !isSaving,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Get screen width
          final screenWidth = MediaQuery.of(context).size.width;
          final containerWidth = screenWidth * 0.95; // 95% of screen width

          return Center(
            child: Container(
              width: containerWidth,
              height: MediaQuery.of(context).size.height * 0.75,
              margin: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2B4469),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.label_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Set Custom Label',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Setting label for:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        studentName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Custom Label Field
                          Text(
                            'Custom Label',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: labelController,
                            enabled: !isSaving,
                            maxLength: 50,
                            decoration: InputDecoration(
                              hintText: 'e.g., My Son, My Daughter, My Eldest',
                              prefixIcon: Icon(
                                Icons.label,
                                color: Colors.grey.shade600,
                              ),
                              filled: true,
                              fillColor: isSaving
                                  ? Colors.grey.shade100
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'Leave empty to use student\'s name',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Suggestions
                          Text(
                            'Quick Suggestions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                [
                                  'My Son',
                                  'My Daughter',
                                  'My Eldest',
                                  'My Youngest',
                                  'My Child',
                                ].map((suggestion) {
                                  return InkWell(
                                    onTap: isSaving
                                        ? null
                                        : () {
                                            setModalState(() {
                                              labelController.text = suggestion;
                                            });
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        suggestion,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 30),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isSaving || isSuccess
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);

                                      await _updateStudentLabel(
                                        context,
                                        studentId,
                                        labelController.text.trim(),
                                      );

                                      if (context.mounted) {
                                        setModalState(() {
                                          isSaving = false;
                                          isSuccess = true;
                                        });

                                        await Future.delayed(
                                          const Duration(milliseconds: 500),
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSuccess
                                    ? Colors.green
                                    : const Color(0xFF2B4469),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: isSuccess
                                    ? Colors.green
                                    : const Color(0xFF2B4469),
                              ),
                              child: isSaving
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'SAVING...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : isSuccess
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'SAVED!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'SAVE LABEL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cancel Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isSaving
                                      ? Colors.grey.shade400
                                      : const Color(0xFF2B4469),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSaving
                                      ? Colors.grey.shade400
                                      : const Color(0xFF2B4469),
                                ),
                              ),
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
      ),
    );
  }

  // ✅ UPDATE: Modified _updateStudentLabel to trigger setState for real-time update
  Future<void> _updateStudentLabel(
    BuildContext context,
    String studentId,
    String customLabel,
  ) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'update_student_custom_label',
        params: {
          'p_parent_id': userProfile!['id'],
          'p_student_id': studentId,
          'p_custom_label': customLabel,
        },
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        // ✅ Refresh relationships immediately for real-time update
        _refreshRelationships();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              customLabel.isEmpty
                  ? 'Label removed'
                  : 'Label updated to "$customLabel"',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to update label'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// Helper function to get gender-specific icon
IconData _getGenderIcon(String? gender) {
  if (gender == null) return Icons.person; // Default neutral icon

  switch (gender.toLowerCase()) {
    case 'male':
    case 'm':
      return Icons.man;
    case 'female':
    case 'f':
      return Icons.woman;
    default:
      return Icons.person; // Default for any other values or non-binary
  }
}
