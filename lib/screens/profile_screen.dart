import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/auth_service.dart';
import 'package:zecure/screens/admin_dashboard.dart';

class ProfileScreen {
  final AuthService _authService;
  Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _profileViewScrollController = ScrollController(); 

  ProfileScreen(this._authService, this.userProfile, this.isAdmin);
  

  // Controllers and state
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _extNameController;
  late TextEditingController _passwordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _contactNumberController;
  String? _selectedGender;
  String? _currentPasswordError;
  DateTime? _selectedBirthday;
  bool _isEditingProfile = false;
  final _profileFormKey = GlobalKey<FormState>();

  // ignore: unnecessary_getters_setters
  bool get isEditingProfile => _isEditingProfile;
  set isEditingProfile(bool value) => _isEditingProfile = value;


//PROFILE PAGE TO ALWAYS START FROM THE TOP
  bool _shouldScrollToTop = false;

  

  void initControllers() {
    _firstNameController = TextEditingController(text: userProfile?['first_name'] ?? '');
    _lastNameController = TextEditingController(text: userProfile?['last_name'] ?? '');
    _middleNameController = TextEditingController(text: userProfile?['middle_name'] ?? '');
    _extNameController = TextEditingController(text: userProfile?['ext_name'] ?? '');
    _passwordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _contactNumberController = TextEditingController(text: userProfile?['contact_number'] ?? '');
    _selectedGender = userProfile?['gender'];
    _selectedBirthday = userProfile?['bday'] != null ? DateTime.parse(userProfile?['bday']) : null;
  }

  void disposeControllers() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _extNameController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _contactNumberController.dispose();
    _scrollController.dispose();
    _profileViewScrollController.dispose();
  }

  bool _hasProfileChanges() {
  return _firstNameController.text != (userProfile?['first_name'] ?? '') ||
         _lastNameController.text != (userProfile?['last_name'] ?? '') ||
         _middleNameController.text != (userProfile?['middle_name'] ?? '') ||
         _extNameController.text != (userProfile?['ext_name'] ?? '') ||
         _selectedGender != userProfile?['gender'] ||
         _contactNumberController.text != (userProfile?['contact_number'] ?? '') ||
         (_selectedBirthday?.toIso8601String().split('T')[0] != 
          (userProfile?['bday'] != null ? DateTime.parse(userProfile!['bday']).toIso8601String().split('T')[0] : null));
}

bool _hasValidPasswordChange() {
  return _passwordController.text.isNotEmpty && 
         _newPasswordController.text.isNotEmpty && 
         _confirmPasswordController.text.isNotEmpty;
}





Future<void> updateProfile(BuildContext context, {required VoidCallback onSuccess}) async {
  // Clear any previous current password error
  _currentPasswordError = null;
  
  if (!_profileFormKey.currentState!.validate()) return;

  bool profileChanged = false;
  bool passwordChanged = false;

  try {
    // Check if there are actual changes to save
    bool hasProfileChanges = _hasProfileChanges();
    bool hasPasswordChanges = _hasValidPasswordChange();
    
    // If no changes at all, show different message
    if (!hasProfileChanges && !hasPasswordChanges) {
      _showInfoDialog(context, 'No changes were made to your profile.');
      return;
    }
    
    // If user filled current password but not new password fields, show error
    if (_passwordController.text.isNotEmpty && !hasPasswordChanges) {
      _showSnackBar(context, 'Please fill in both new password and confirm password to change your password');
      return;
    }

    // Update password if new password is provided
    if (hasPasswordChanges) {
      try {
        await _authService.updatePassword(
          currentPassword: _passwordController.text,
          newPassword: _newPasswordController.text,
        );
        passwordChanged = true;
      } on AuthException catch (e) {
        // Handle wrong current password error
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('invalid_credentials') ||
            e.message.contains('Invalid') ||
            e.message.contains('credentials')) {
          // Set the error and trigger form validation again
          _currentPasswordError = 'Current password is incorrect';
          _profileFormKey.currentState!.validate();
          return;
        }
        rethrow;
      } catch (e) {
        // Handle other types of errors that might indicate wrong password
        if (e.toString().contains('Invalid login credentials') || 
            e.toString().contains('invalid_credentials') ||
            e.toString().contains('Invalid') ||
            e.toString().contains('credentials')) {
          _currentPasswordError = 'Current password is incorrect';
          _profileFormKey.currentState!.validate();
          return;
        }
        rethrow;
      }
    }

    // Update user profile data only if there are changes
    if (hasProfileChanges) {
      final updateData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'middle_name': _middleNameController.text.isEmpty ? null : _middleNameController.text,
        'ext_name': _extNameController.text.isEmpty ? null : _extNameController.text,
        'gender': _selectedGender,
        'bday': _selectedBirthday?.toIso8601String(),
        'contact_number': _contactNumberController.text.isEmpty ? null : _contactNumberController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('users')
          .update(updateData)
          .eq('id', userProfile!['id'] as Object)
          .select()
          .single();

      userProfile = response;
      profileChanged = true;
    }
    
    // Clear password fields and error
    _passwordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _currentPasswordError = null;
    
    // Show appropriate success message based on what was changed
    String successMessage;
    if (profileChanged && passwordChanged) {
      successMessage = 'Profile and password updated successfully!';
    } else if (passwordChanged) {
      successMessage = 'Password updated successfully!';
    } else {
      successMessage = 'Profile updated successfully!';
    }
    
    // Show success message
    _showSuccessDialog(
      context, 
      successMessage,
      onOkPressed: () {
        _isEditingProfile = false;
        onSuccess();
      }
    );
  } catch (e) {
    _showSnackBar(context, 'Error updating profile: ${e.toString()}');
  }
}

  void _showSuccessDialog(BuildContext context, String message, {VoidCallback? onOkPressed}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOkPressed != null) onOkPressed();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          const Text('Info'),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

//PROFILE PAGE TO ALWAYS START FROM THE TOP
  void setShouldScrollToTop(bool value) {
  _shouldScrollToTop = value;
}



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
    controller: _profileViewScrollController, // Use the separate controller
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enhanced header section with gradient - modified as requested
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.8),
                Theme.of(context).primaryColor.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.zero, // Removed border radius
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -50,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 50,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Content - removed top padding
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), // Removed top padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Enhanced avatar with border and shadow
Container(
  margin: const EdgeInsets.only(top: 20), // Add top margin here
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: CircleAvatar(
    backgroundColor: Colors.white,
    radius: 38,
    child: CircleAvatar(
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
      radius: 35,
      child: Text(
        userProfile?['first_name']?.toString().substring(0, 1) ?? 'U',
        style: const TextStyle(
          fontSize: 36,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
),
                    const SizedBox(height: 20),
                    // Name with better typography - properly centered
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        '${userProfile?['first_name'] ?? ''}'
                        '${userProfile?['middle_name'] != null ? ' ${userProfile?['middle_name']}' : ''}'
                        ' ${userProfile?['last_name'] ?? ''}'
                        '${userProfile?['ext_name'] != null ? ' ${userProfile?['ext_name']}' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Email with subtle styling - properly centered
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userProfile?['email'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enhanced role chip - properly centered
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isAdmin) ...[
                              Icon(
                                Icons.admin_panel_settings,
                                size: 18,
                                color: isAdmin ? Colors.blue : Colors.green,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              userProfile?['role']?.toUpperCase() ?? 'USER',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isAdmin ? Colors.blue : Colors.green,
                                letterSpacing: 0.5,
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
        
        // Enhanced information section
        Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileInfoItem(
                      context,
                      icon: Icons.person_outline,
                      label: 'Username',
                      value: userProfile?['username'] ?? 'Not set',
                    ),
                    _buildProfileInfoItem(
                      context,
                      icon: Icons.cake_outlined,
                      label: 'Birthday',
                      value: userProfile?['bday'] != null
                          ? DateFormat('MMMM d, y').format(
                              DateTime.parse(userProfile?['bday']))
                          : 'Not specified',
                    ),
                    _buildProfileInfoItem(
                      context,
                      icon: Icons.transgender,
                      label: 'Gender',
                      value: userProfile?['gender'] ?? 'Not specified',
                    ),
                    _buildProfileInfoItem(
                      context,
                      icon: Icons.phone,
                      label: 'Contact Number',
                      value: userProfile?['contact_number'] ?? 'Not specified',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Enhanced action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Primary edit button with gradient
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onEditPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EDIT PROFILE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isAdmin) ...[
                const SizedBox(height: 16),
                // Admin dashboard button with modern styling
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade300,
                      width: 2,
                    ),
                    color: Colors.blue.shade50,
                  ),
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminDashboardScreen(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ADMIN DASHBOARD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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

// Enhanced _buildProfileInfoItem method
Widget _buildProfileInfoItem(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  bool isLast = false,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey.shade200,
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.blue.shade600,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildEditProfileForm(
  BuildContext context, 
  bool isDesktopOrWeb, 
  VoidCallback onCancel,
  {required VoidCallback onSuccess}
) {
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController, // Add this line
          child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktopOrWeb ? 16.0 : 12.0,  // Reduced from 24/20
                vertical: isDesktopOrWeb ? 24.0 : 20.0,
              ),
              child: Form(
                key: _profileFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDesktopOrWeb) ...[
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onCancel,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  // Enhanced Personal Information Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktopOrWeb ? 20.0 : 16.0,  // Reduced from 28/20
                        vertical: isDesktopOrWeb ? 28.0 : 20.0,
                      ),
                      child: Column(
                        children: [
                          // Header with icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.blue.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Form fields with enhanced styling
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
                          
                          // Enhanced Birthday Selector
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              title: Text(
                                _selectedBirthday == null
                                    ? 'Select Birthday'
                                    : 'Birthday: ${DateFormat('MMM d, y').format(_selectedBirthday!)}',
                                style: TextStyle(
                                  color: _selectedBirthday == null 
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Enhanced Dropdown
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.only(left: 12, right: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.transgender,
                                    size: 20,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ),
                              items: ['Male', 'Female', 'LGBTQ+', 'Others']
                                  .map((gender) => DropdownMenuItem(
                                        value: gender,
                                        child: Text(gender),
                                      ))
                                  .toList(),
                              onChanged: (value) => _selectedGender = value,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedTextField(
                            controller: _contactNumberController,
                            label: 'Contact Number',
                            icon: Icons.phone,
                            hintText: 'e.g. +639123456789',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!RegExp(r'^\+?[\d\s\-]{10,}$').hasMatch(value)) {
                                  return 'Please enter a valid phone number';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Enhanced Password Change Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktopOrWeb ? 20.0 : 16.0,  // Reduced from 28/20
                        vertical: isDesktopOrWeb ? 28.0 : 20.0,
                      ),
                      child: Column(
                        children: [
                          // Header with icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.orange.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Leave blank to keep current password',
                                    style: TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Password fields with enhanced styling
                          _buildEnhancedPasswordField(
                            controller: _passwordController,
                            label: 'Current Password',
                            isVisible: showCurrentPassword,
                            onVisibilityToggle: () {
                              setState(() {
                                showCurrentPassword = !showCurrentPassword;
                              });
                            },
                            errorText: _currentPasswordError,
                            validator: (value) {
                              if (_currentPasswordError != null) {
                                return _currentPasswordError;
                              }
                              if (_newPasswordController.text.isNotEmpty &&
                                  (value?.isEmpty ?? true)) {
                                return 'Required to change password';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (_currentPasswordError != null) {
                                setState(() {
                                  _currentPasswordError = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedPasswordField(
                            controller: _newPasswordController,
                            label: 'New Password',
                            isVisible: showNewPassword,
                            onVisibilityToggle: () {
                              setState(() {
                                showNewPassword = !showNewPassword;
                              });
                            },
                            validator: (value) {
                              if (value?.isNotEmpty ?? false) {
                                if (value == _passwordController.text) {
                                  return 'New password must be different';
                                }
                                if (value!.length < 6) {
                                  return 'Must be at least 6 characters';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildEnhancedPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password',
                            isVisible: showConfirmPassword,
                            onVisibilityToggle: () {
                              setState(() {
                                showConfirmPassword = !showConfirmPassword;
                              });
                            },
                            validator: (value) {
                              if (_newPasswordController.text.isNotEmpty) {
                                if (value?.isEmpty ?? true) {
                                  return 'Please confirm your password';
                                }
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Enhanced Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                          ),
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => updateProfile(context, onSuccess: onSuccess),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'SAVE ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
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
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.blue.shade600,
          ),
        ),
      ),
      validator: validator,
    ),
  );
}

// Helper method for enhanced password fields
Widget _buildEnhancedPasswordField({
  required TextEditingController controller,
  required String label,
  required bool isVisible,
  required VoidCallback onVisibilityToggle,
  String? errorText,
  String? Function(String?)? validator,
  void Function(String)? onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: errorText != null ? Colors.red.shade300 : Colors.grey.shade300,
      ),
    ),
    child: TextFormField(
      controller: controller,
      obscureText: !isVisible,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.lock_outline,
            size: 20,
            color: Colors.orange.shade600,
          ),
        ),
        suffixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade600,
            ),
            onPressed: onVisibilityToggle,
          ),
        ),
      ),
      validator: validator,
    ),
  );
}
}