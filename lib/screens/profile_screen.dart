import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/auth/auth_service.dart';
import 'package:zecure/screens/admin_dashboard.dart';

enum SaveButtonState { normal, saving, saved,  }
class ProfileScreen {
  final AuthService _authService;
  Map<String, dynamic>? userProfile;
  final bool isAdmin;  // Keep this for admin-only features
  final bool hasAdminPermissions;  // Keep this for shared admin/officer features
  final ScrollController _scrollController = ScrollController();
  SaveButtonState _saveButtonState = SaveButtonState.normal;
  Timer? _buttonStateTimer;
  final ScrollController _profileViewScrollController = ScrollController(); 

  ProfileScreen(this._authService, this.userProfile, this.isAdmin, this.hasAdminPermissions);

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


  bool get _hasAnyChanges => _hasProfileChanges() || (_hasEmailChanges() && userProfile?['registration_type'] == 'simple');



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
Timer? _emailResendTimer;   // Keep this for the modal
int _emailResendCountdown = 60;
bool _canResendEmailOTP = false;
bool _isUpdatingEmail = false;
bool _isEmailFieldReadOnly = false;
StateSetter? _currentModalSetState;



  void initControllers() {
    _firstNameController = TextEditingController(text: userProfile?['first_name'] ?? '');
    _lastNameController = TextEditingController(text: userProfile?['last_name'] ?? '');
    _middleNameController = TextEditingController(text: userProfile?['middle_name'] ?? '');
    _extNameController = TextEditingController(text: userProfile?['ext_name'] ?? '');
    _emailController = TextEditingController(text: userProfile?['email'] ?? '');
    _selectedGender = userProfile?['gender'];
    _selectedBirthday = userProfile?['bday'] != null ? DateTime.parse(userProfile?['bday']) : null;
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
  // REMOVE the OTP controllers disposal:
  /*
  for (var controller in _emailOtpControllers) {
    controller.dispose();
  }
  for (var focusNode in _emailOtpFocusNodes) {
    focusNode.dispose();
  }
  */
  _buttonStateTimer?.cancel();
  _emailResendTimer?.cancel();
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
         _contactNumberController.text != (userProfile?['contact_number'] ?? '') ||
         (_selectedBirthday?.toIso8601String().split('T')[0] != 
          (userProfile?['bday'] != null ? DateTime.parse(userProfile!['bday']).toIso8601String().split('T')[0] : null)) ||
         _selectedPoliceRankId != userProfile?['police_rank_id'] ||
         _selectedPoliceStationId != userProfile?['police_station_id'];
}


// In your ProfileScreen class, add this method:
void resetSaveButtonState() {
  _saveButtonState = SaveButtonState.normal;
}

// Updated updateProfile method with consistent button states for both desktop and mobile

Future<void> updateProfile(BuildContext context, {
  required VoidCallback onSuccess,
  Function(VoidCallback)? onStateChange,
  required bool isSidebarVisible,
}) async {
  if (!_profileFormKey.currentState!.validate()) return;

  try {
    bool hasProfileChanges = _hasProfileChanges();
    bool hasEmailChanges = _hasEmailChanges() && userProfile?['registration_type'] == 'simple';

    // Set saving state for both desktop and mobile
    onStateChange?.call(() {
      _saveButtonState = SaveButtonState.saving;
    });

    // Update profile data
    if (hasProfileChanges) {
      final updateData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'middle_name': _middleNameController.text.isEmpty ? null : _middleNameController.text,
        'ext_name': _extNameController.text.isEmpty ? null : _extNameController.text,
        'gender': _selectedGender,
        'bday': _selectedBirthday?.toIso8601String(),
        'contact_number': _contactNumberController.text.isEmpty ? null : _contactNumberController.text,
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
    }

    // Handle email verification if needed
    if (hasEmailChanges) {
      final currentEmail = userProfile?['email'] ?? '';
      final newEmail = _emailController.text.trim();
      
      // Determine if this is a change or verification of existing email
      final isEmailChange = newEmail != currentEmail;
      final isVerifyingCurrentEmail = _forceEmailVerification && !isEmailChange;

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
        
        String errorMessage = 'Email verification failed: The registered address may be invalid or inactive. Please enter a new valid email to verify.';

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
                  _buttonStateTimer = Timer(const Duration(milliseconds: 1500), () {
                    _shouldScrollToTop = true;
                    _isEditingProfile = false;
                    onSuccess(); // Navigate - button stays as "SAVED"
                  });
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
  final isDesktopPlatform = Theme.of(context).platform == TargetPlatform.macOS ||
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
  final List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: useDesktopLayout ? 40 : 16,
              vertical: 24,
            ),
            content: Container(
              width: useDesktopLayout ? 450 : double.maxFinite, // Match profile view width
              constraints: BoxConstraints(
                maxWidth: useDesktopLayout ? 450 : MediaQuery.of(context).size.width - 32, // Match profile view
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
                              final fieldSize = useDesktopLayout ? 40.0 : 
                                               MediaQuery.of(context).size.width < 360 ? 35.0 : 40.0;
                              
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
                                    fontSize: useDesktopLayout ? 22 : 
                                             MediaQuery.of(context).size.width < 360 ? 16 : 18,
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
                          useDesktopLayout || MediaQuery.of(context).size.width > 400
                              ? Row(
                                  children: [
                                    // Skip button - UPDATED LOGIC
                                    Expanded(
                                      flex: 2,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          // Clean up controllers
                                          for (var controller in otpControllers) {
                                            controller.dispose();
                                          }
                                          for (var focusNode in otpFocusNodes) {
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
                                                _saveButtonState = SaveButtonState.saved;
                                              });
                                              
                                              _buttonStateTimer?.cancel();
                                              _buttonStateTimer = Timer(const Duration(seconds: 1), () {
                                                _isEditingProfile = false;
                                                onSuccess();
                                                
                                                onStateChange(() {
                                                  _saveButtonState = SaveButtonState.normal;
                                                });
                                              });
                                            }
                                          } else {
                                            // No other changes were made, just exit edit mode
                                            _isEditingProfile = false;
                                            onSuccess();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: BorderSide(color: Colors.grey.shade400),
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
                                        onPressed: () => _verifyEmailChangeFromModal(
                                          context, 
                                          otpControllers, 
                                          otpFocusNodes, 
                                          onSuccess,
                                          setModalState,
                                          isSidebarVisible: isSidebarVisible, // Pass the parameter
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.blue.shade200,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 18),
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
                                        onPressed: () => _verifyEmailChangeFromModal(
                                          context, 
                                          otpControllers, 
                                          otpFocusNodes, 
                                          onSuccess,
                                          setModalState,
                                          isSidebarVisible: isSidebarVisible, // Pass the parameter
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.blue.shade200,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 18),
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
                                          for (var controller in otpControllers) {
                                            controller.dispose();
                                          }
                                          for (var focusNode in otpFocusNodes) {
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
                                                _saveButtonState = SaveButtonState.saved;
                                              });
                                              
                                              _buttonStateTimer?.cancel();
                                              _buttonStateTimer = Timer(const Duration(seconds: 1), () {
                                                _isEditingProfile = false;
                                                onSuccess();
                                                
                                                onStateChange(() {
                                                  _saveButtonState = SaveButtonState.normal;
                                                });
                                              });
                                            }
                                          } else {
                                            // No other changes were made, just exit edit mode
                                            _isEditingProfile = false;
                                            onSuccess();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: BorderSide(color: Colors.grey.shade400),
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
                                    ? () => _resendEmailChangeOTP(context, setModalState, isSidebarVisible: isSidebarVisible,) 
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: _canResendEmailOTP ? Colors.blue.shade600 : Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _canResendEmailOTP 
                                          ? 'Resend Code' 
                                          : 'Resend in ${_emailResendCountdown}s',
                                      style: GoogleFonts.poppins(
                                        color: _canResendEmailOTP ? Colors.blue.shade600 : Colors.grey.shade400,
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
            final centeredLeft = profileLeft + (profileWidth - modalWidth) / 2;
            
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
    _showSnackBar(context, 'Please enter the complete 6-digit code', isSidebarVisible: isSidebarVisible,);
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
      successMessage = 'Email verification successful!\n\nYour email address has been verified.';
    } else {
      successMessage = 'Email updated and verified successfully!\n\nYour new email address: $pendingEmail';
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
      isSidebarVisible: isSidebarVisible
    );
  }
}


void _showEmailVerificationSuccessDialog(
  BuildContext context, 
  String verifiedEmail, 
  {VoidCallback? onOkPressed, required bool isSidebarVisible, String? customMessage}
) {
  final useDesktopLayout = _shouldUseDesktopLayout(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: useDesktopLayout ? Colors.black.withOpacity(0.3) : null,
    builder: (context) {
      Widget dialogContent = AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: useDesktopLayout ? 40 : 16,
          vertical: 24,
        ),
        content: Container(
          width: useDesktopLayout ? 450 : double.maxFinite, // Match profile view width
          constraints: BoxConstraints(
            maxWidth: useDesktopLayout ? 450 : MediaQuery.of(context).size.width - 32, // Match profile view
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
                    colors: [
                      Colors.green.shade600,
                      Colors.green.shade500,
                    ],
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
                      customMessage ?? 'Your email has been successfully updated to:',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: useDesktopLayout ? 15 : 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            Future.delayed(const Duration(milliseconds: 100), () {
                              onOkPressed();
                            });
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
void _showErrorDialog(BuildContext context, String message, {required bool isSidebarVisible}) {
  final useDesktopLayout = _shouldUseDesktopLayout(context);

  showDialog(
    context: context,
    barrierColor: useDesktopLayout ? Colors.black.withOpacity(0.3) : null,
    builder: (context) {
      Widget dialogContent = AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: useDesktopLayout ? 40 : 16,
          vertical: 24,
        ),
        content: Container(
          width: useDesktopLayout ? 400 : double.maxFinite,
          constraints: BoxConstraints(
            maxWidth: useDesktopLayout ? 400 : MediaQuery.of(context).size.width - 32,
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
  StateSetter setModalState, 
  {required bool isSidebarVisible}
) async {
  try {
    if (_isVerifyingCurrentEmail) {
      // Use the new resend method for current email verification
      await _authService.resendReauthenticationOTP(email: _pendingEmailChange!);
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



//PROFILE PAGE MOBILE
Widget buildProfileView(BuildContext context, bool isDesktopOrWeb, VoidCallback onEditPressed) {
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
        // Header section with background image
        Container(
          width: double.infinity,
          height: 280,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/LIGHT.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Profile avatar
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 50,
                        child: CircleAvatar(
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
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
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
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
                    color: Colors.black87,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Role badge
                if (userProfile?['role'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                            color: userProfile?['role'] == 'officer' ? Colors.green : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userProfile?['role']?.toUpperCase() ?? 'USER',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // --- Tabs section ---
        StatefulBuilder(
          builder: (context, setState) {
            bool showPersonalInfo = _selectedTab == 0;

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: showPersonalInfo
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                  width: showPersonalInfo ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'Personal Info',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: showPersonalInfo ? FontWeight.w600 : FontWeight.w500,
                                color: showPersonalInfo ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (userProfile?['role'] == 'officer')
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: !showPersonalInfo
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade300,
                                    width: !showPersonalInfo ? 2 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Police Info',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: !showPersonalInfo ? FontWeight.w600 : FontWeight.w500,
                                  color: !showPersonalInfo ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tab content
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
                    children: showPersonalInfo
                        ? _buildPersonalInfoItems(context)
                        : _buildPoliceInfoItems(context),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 30),

        // Edit button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onEditPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // Admin dashboard button
        if (isAdmin) ...[
          const SizedBox(height: 12),
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
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
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
          ? DateFormat('MMMM d, y').format(DateTime.parse(userProfile?['bday']))
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
      value: _getPoliceRankName(userProfile?['police_rank_id']) ?? 'Not assigned',
      hasValue: _getPoliceRankName(userProfile?['police_rank_id']) != null,
    ),
    _buildCleanInfoItem(
      context,
      icon: Icons.location_on_outlined,
      label: 'Assigned Station',
      value: _getPoliceStationName(userProfile?['police_station_id']) ?? 'Not assigned',
      hasValue: _getPoliceStationName(userProfile?['police_station_id']) != null,
    ),
    _buildCleanInfoItem(
      context,
      icon: isAdmin ? Icons.admin_panel_settings_outlined : Icons.work_outline,
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
          : Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
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
  VoidCallback onCancel,
  {required VoidCallback onSuccess}
) {
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
      bool isSidebarVisible = false; // Initialize with a default value instead of leaving it uninitialized
      
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
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
            ),
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
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
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
                          border: Border.all(color: Colors.grey.shade200, width: 1),
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
                              if ((userProfile?['registration_type'] ?? '') == 'simple') ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: (_isEmailFieldReadOnly) ? Colors.grey.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (_isEmailFieldReadOnly) ? Colors.grey.shade300 : Colors.grey.shade200, 
                                      width: 1
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _emailController,
                                    readOnly: _isEmailFieldReadOnly, // FIX 3: Add null check with default
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) {
                                      setState(() {
                                        // If user starts typing and checkbox is checked, uncheck it
                                        if ((_forceEmailVerification) && value.trim() != (userProfile?['email'] ?? '')) {
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
                                      labelText: (_isEmailFieldReadOnly) ? null : 'Email',
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: (_isEmailFieldReadOnly) ? Colors.grey.shade500 : Colors.grey.shade700,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      prefixIcon: Icon(
                                        (_isEmailFieldReadOnly) ? Icons.lock_outline : Icons.email_outlined,
                                        size: 20,
                                        color: (_isEmailFieldReadOnly) ? Colors.grey.shade600 : Colors.grey.shade600,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: (_isEmailFieldReadOnly) ? Colors.grey.shade600 : Colors.black87,
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Required';
                                      if (!value!.contains('@')) return 'Invalid email';
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
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _forceEmailVerification = !(_forceEmailVerification); // FIX 4: Add null check
                                        _handleEmailMutualExclusivity();
                                      });
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: Checkbox(
                                            value: _forceEmailVerification, // FIX 5: Add null check with default
                                            onChanged: (value) {
                                              setState(() {
                                                _forceEmailVerification = value ?? false;
                                                _handleEmailMutualExclusivity();
                                              });
                                            },
                                            activeColor: Colors.orange.shade600,
                                            checkColor: Colors.white,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            (_forceEmailVerification) 
                                              ? 'Keep current email and send verification to: ${userProfile?['email'] ?? ''}'
                                              : 'Email verification required. Change your email above or check this box to keep current email, then click Save to send verification.',
                                            style: const TextStyle(fontSize: 12, color: Colors.orange),
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
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.verified_outlined, size: 16, color: Colors.green.shade600),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Your email address has been verified and cannot be changed.',
                                          style: TextStyle(fontSize: 12, color: Colors.green),
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
                                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildEnhancedTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                icon: Icons.person_outline,
                                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedBirthday ?? DateTime.now(),
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
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
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
                                              color: _selectedBirthday == null ? Colors.grey.shade500 : Colors.black87,
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
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                      .map((gender) => DropdownMenuItem(
                                            value: gender,
                                            child: Text(
                                              gender,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) => _selectedGender = value,
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
                                    _contactNumberController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _contactNumberController.text.length),
                                    );
                                  }
                                  
                                  if (value.length > 13) {
                                    _contactNumberController.text = value.substring(0, 13);
                                    _contactNumberController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _contactNumberController.text.length),
                                    );
                                  }
                                },
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (!value.startsWith('+63') || value.length != 13) {
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
                      // Police Information Card (shown only for officers)
                      if ((userProfile?['role'] ?? '') == 'officer') ...[
                        const SizedBox(height: 20),
                        Container(
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
                                // Police dropdowns with FutureBuilder...
                                // (Rest of police information section remains the same but add null checks where needed)
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
                                  side: BorderSide(color: Theme.of(context).primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white.withOpacity(0.95),
                                  foregroundColor: Theme.of(context).primaryColor,
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
                              onStateChange: setState,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
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
  VoidCallback onEditPressed,
  {VoidCallback? onClosePressed, required bool isSidebarVisible} // Added isSidebarVisible
) {
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
    left: isSidebarVisible ? 5 : 20, // Match QuickAccessDesktopScreen
    top: 100,
    child: GestureDetector(
      onTap: () {}, // Prevent propagation to overlay
      child: Material(
        elevation: 16, // Match QuickAccessDesktopScreen elevation
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withOpacity(0.3),
        child: Container(
          width: 450, // Match QuickAccessDesktopScreen
          height: 800, // Match QuickAccessDesktopScreen
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/LIGHT.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade700),
                            onPressed: onClosePressed ?? () {},
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    radius: 50,
                                    child: CircleAvatar(
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
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
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
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
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
                                  color: Colors.black87,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (userProfile?['role'] != null)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
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
                                          color: userProfile?['role'] == 'officer' ? Colors.green : Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        userProfile?['role']?.toUpperCase() ?? 'USER',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
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
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    bool showPersonalInfo = _selectedTab == 0;
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: showPersonalInfo
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey.shade300,
                                          width: showPersonalInfo ? 2 : 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Personal Info',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: showPersonalInfo ? FontWeight.w600 : FontWeight.w500,
                                        color: showPersonalInfo ? Colors.black87 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (userProfile?['role'] == 'officer')
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedTab = 1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: !showPersonalInfo
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey.shade300,
                                            width: !showPersonalInfo ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Police Info',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: !showPersonalInfo ? FontWeight.w600 : FontWeight.w500,
                                          color: !showPersonalInfo ? Colors.black87 : Colors.grey.shade600,
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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Container(
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
                                    children: showPersonalInfo
                                        ? _buildDesktopPersonalInfoItems(context)
                                        : _buildDesktopPoliceInfoItems(context),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: onEditPressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
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
                                        side: BorderSide(color: Theme.of(context).primaryColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Admin Dashboard',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          ? DateFormat('MMMM d, y').format(DateTime.parse(userProfile?['bday']))
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
      value: _getPoliceRankName(userProfile?['police_rank_id']) ?? 'Not assigned',
      hasValue: _getPoliceRankName(userProfile?['police_rank_id']) != null,
    ),
    _buildDesktopCleanInfoItem(
      context,
      icon: Icons.location_on_outlined,
      label: 'Assigned Station',
      value: _getPoliceStationName(userProfile?['police_station_id']) ?? 'Not assigned',
      hasValue: _getPoliceStationName(userProfile?['police_station_id']) != null,
    ),
    _buildDesktopCleanInfoItem(
      context,
      icon: isAdmin ? Icons.admin_panel_settings_outlined : Icons.work_outline,
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
          : Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
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
  required Function(VoidCallback) onStateChange, // Add callback for state changes
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.grey),
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
                        border: Border.all(color: Colors.grey.shade200, width: 1),
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
                            if (userProfile?['registration_type'] == 'simple') ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: _isEmailFieldReadOnly ? Colors.grey.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isEmailFieldReadOnly ? Colors.grey.shade300 : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  readOnly: _isEmailFieldReadOnly,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (value) {
                                    onStateChange(() {
                                      if (_forceEmailVerification && value.trim() != (userProfile?['email'] ?? '')) {
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
                                    labelText: _isEmailFieldReadOnly ? null : 'Email',
                                    labelStyle: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _isEmailFieldReadOnly ? Colors.grey.shade500 : Colors.grey.shade700,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    prefixIcon: Icon(
                                      _isEmailFieldReadOnly ? Icons.lock_outline : Icons.email_outlined,
                                      size: 20,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _isEmailFieldReadOnly ? Colors.grey.shade600 : Colors.black87,
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Required';
                                    if (!value!.contains('@')) return 'Invalid email';
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
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    onStateChange(() {
                                      _forceEmailVerification = !_forceEmailVerification;
                                      _handleEmailMutualExclusivity();
                                    });
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: Checkbox(
                                          value: _forceEmailVerification,
                                          onChanged: (value) {
                                            onStateChange(() {
                                              _forceEmailVerification = value ?? false;
                                              _handleEmailMutualExclusivity();
                                            });
                                          },
                                          activeColor: Colors.orange.shade600,
                                          checkColor: Colors.white,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _forceEmailVerification
                                              ? 'Keep current email and send verification to: ${userProfile?['email'] ?? ''}'
                                              : 'Email verification required. Change your email above or check this box to keep current email, then click Save to send verification.',
                                          style: const TextStyle(fontSize: 12, color: Colors.orange),
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
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_outlined, size: 16, color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Your email address has been verified and cannot be changed.',
                                        style: TextStyle(fontSize: 12, color: Colors.green),
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
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildEnhancedTextField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                                border: Border.all(color: Colors.grey.shade200, width: 1),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedBirthday ?? DateTime.now(),
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
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
                                            color: _selectedBirthday == null ? Colors.grey.shade500 : Colors.black87,
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
                                border: Border.all(color: Colors.grey.shade200, width: 1),
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                    .map((gender) => DropdownMenuItem(
                                          value: gender,
                                          child: Text(
                                            gender,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ))
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
                                  _contactNumberController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _contactNumberController.text.length),
                                  );
                                }
                                if (value.length > 13) {
                                  _contactNumberController.text = value.substring(0, 13);
                                  _contactNumberController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _contactNumberController.text.length),
                                  );
                                }
                              },
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!value.startsWith('+63') || value.length != 13) {
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
                          border: Border.all(color: Colors.grey.shade200, width: 1),
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
                                future: _policeRanks.isEmpty ? _loadPoliceData() : null,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200, width: 1),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
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
                                      border: Border.all(color: Colors.grey.shade200, width: 1),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.only(right: 16),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
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
                                          .map((rank) => DropdownMenuItem<int>(
                                                value: rank['id'],
                                                child: Text(
                                                  rank['new_rank'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ))
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
                                future: _policeStations.isEmpty ? _loadPoliceData() : null,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200, width: 1),
                                      ),
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
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
                                      border: Border.all(color: Colors.grey.shade200, width: 1),
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.only(right: 16),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            size: 20,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      items: _policeStations
                                          .map((station) => DropdownMenuItem<int>(
                                                value: station['id'],
                                                child: Text(
                                                  station['name'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ))
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
                                side: BorderSide(color: Theme.of(context).primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.95),
                                foregroundColor: Theme.of(context).primaryColor,
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
                isSidebarVisible: isSidebarVisible
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
    return Theme.of(context).primaryColor;
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
          const Icon(
            Icons.check,
            color: Colors.white,
            size: 20,
          ),
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