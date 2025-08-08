import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/auth_service.dart';

class ProfileScreen {
  final AuthService _authService;
  Map<String, dynamic>? userProfile;
  final bool isAdmin;

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

  bool get isEditingProfile => _isEditingProfile;
  set isEditingProfile(bool value) => _isEditingProfile = value;

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

  Widget buildProfileView(BuildContext context, bool isDesktopOrWeb, VoidCallback onEditPressed) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 40,
                  child: Text(
                    userProfile?['first_name']?.toString().substring(0, 1) ?? 'U',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${userProfile?['first_name'] ?? ''}'
                        '${userProfile?['middle_name'] != null ? ' ${userProfile?['middle_name']}' : ''}'
                        ' ${userProfile?['last_name'] ?? ''}'
                        '${userProfile?['ext_name'] != null ? ' ${userProfile?['ext_name']}' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userProfile?['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin) ...[
                              const Icon(
                                Icons.admin_panel_settings,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              userProfile?['role']?.toUpperCase() ?? 'USER',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: isAdmin ? Colors.blue : Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
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
          onPressed: onEditPressed,
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
      if (isAdmin) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showSnackBar(context, 'Admin features'),
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

  Widget _buildProfileInfoItem(
    BuildContext context, {
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

  Widget buildEditProfileForm(
    BuildContext context, 
    bool isDesktopOrWeb, 
    VoidCallback onCancel,
    {required VoidCallback onSuccess}
  ) {
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
// Add this line to track current password error

    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isDesktopOrWeb ? 24.0 : 20.0),
            child: Form(
              key: _profileFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDesktopOrWeb) ...[
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onCancel,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(isDesktopOrWeb ? 24.0 : 16.0),
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
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade600,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: Text(
                                _selectedBirthday == null
                                    ? 'Select Birthday'
                                    : 'Birthday: ${DateFormat('MMM d, y').format(_selectedBirthday!)}',
                                style: TextStyle(
                                  color: _selectedBirthday == null 
                                      ? Colors.grey.shade600
                                      : null,
                                ),
                              ),
                              trailing: const Icon(Icons.calendar_today, size: 20),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Male', 'Female', 'LGBTQ+', 'Others']
                                .map((gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender),
                                    ))
                                .toList(),
                            onChanged: (value) => _selectedGender = value,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. +639123456789',
                            ),
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
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(isDesktopOrWeb ? 24.0 : 16.0),
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
  decoration: InputDecoration(
    labelText: 'Current Password',
    border: const OutlineInputBorder(),
    suffixIcon: IconButton(
      icon: Icon(
        showCurrentPassword
            ? Icons.visibility
            : Icons.visibility_off,
      ),
      onPressed: () {
        setState(() {
          showCurrentPassword = !showCurrentPassword;
        });
      },
    ),
    errorText: _currentPasswordError, // This will show the authentication error
  ),
  obscureText: !showCurrentPassword,
  validator: (value) {
    // Check for authentication error first
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
    // Clear error when user types
    if (_currentPasswordError != null) {
      setState(() {
        _currentPasswordError = null;
      });
    }
  },
),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showNewPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    showNewPassword = !showNewPassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: !showNewPassword,
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
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    showConfirmPassword = !showConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: !showConfirmPassword,
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
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
                          onPressed: () => updateProfile(context, onSuccess: onSuccess),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('SAVE CHANGES'),
                        ),
                      ),
                    ],
                  ),
                  if (isDesktopOrWeb) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}