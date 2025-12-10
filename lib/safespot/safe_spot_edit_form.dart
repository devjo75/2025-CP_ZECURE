// ============================================
// UPDATED: safe_spot_edit_form.dart
// Restricts certain types to authorized users only
// ============================================

import 'package:flutter/material.dart';
import 'safe_spot_service.dart';

class SafeSpotEditForm {
  static void showEditForm({
    required BuildContext context,
    required Map<String, dynamic> safeSpot,
    required Map<String, dynamic>? userProfile,
    required VoidCallback onUpdate,
  }) {
    // Check if user can edit this safe spot
    if (!_canUserEditSafeSpot(safeSpot, userProfile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot edit this safe spot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if it's desktop/web
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // Show centered dialog for desktop/web
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SafeSpotEditModal(
              safeSpot: safeSpot,
              userProfile: userProfile,
              onUpdate: onUpdate,
              isDesktop: true,
            ),
          ),
        ),
      );
    } else {
      // Show bottom sheet for mobile
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        builder: (context) => SafeSpotEditModal(
          safeSpot: safeSpot,
          userProfile: userProfile,
          onUpdate: onUpdate,
          isDesktop: false,
        ),
      );
    }
  }

  static bool _canUserEditSafeSpot(
    Map<String, dynamic> safeSpot,
    Map<String, dynamic>? userProfile,
  ) {
    if (userProfile == null) return false;

    final userRole = userProfile['role'];
    final isAdminOrOfficer =
        userRole == 'admin' || userRole == 'officer' || userRole == 'tanod';
    final isOwner = safeSpot['created_by'] == userProfile['id'];
    final status = safeSpot['status'] ?? 'pending';

    // Admin, Officer, or Tanod can edit all safe spots
    if (isAdminOrOfficer) return true;

    // Regular users can only edit their own pending safe spots
    return isOwner && status == 'pending';
  }
}

class SafeSpotEditModal extends StatefulWidget {
  final Map<String, dynamic> safeSpot;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onUpdate;
  final bool isDesktop;

  const SafeSpotEditModal({
    super.key,
    required this.safeSpot,
    required this.userProfile,
    required this.onUpdate,
    required this.isDesktop,
  });

  @override
  State<SafeSpotEditModal> createState() => _SafeSpotEditModalState();
}

class _SafeSpotEditModalState extends State<SafeSpotEditModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _filteredSafeSpotTypes =
      []; // ✅ NEW: Filtered types
  String? _selectedTypeName;
  int? _selectedTypeId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // ✅ NEW: Check if user is authorized for restricted types
  bool get isAuthorizedUser {
    final role = widget.userProfile?['role'];
    return role == 'admin' || role == 'officer' || role == 'tanod';
  }

  bool get isAdminOrOfficer {
    final role = widget.userProfile?['role'];
    return role == 'admin' || role == 'officer';
  }

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadSafeSpotTypes();
  }

  void _initializeForm() {
    // Initialize form with current safe spot data
    _nameController.text = widget.safeSpot['name'] ?? '';
    _descriptionController.text = widget.safeSpot['description'] ?? '';

    // Set current type
    final currentType = widget.safeSpot['safe_spot_types'];
    if (currentType != null) {
      _selectedTypeName = currentType['name'];
      _selectedTypeId = currentType['id'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ✅ NEW: Check if a type is restricted
  bool _isRestrictedType(Map<String, dynamic> type) {
    final typeName = type['name'].toString().toLowerCase();
    return typeName.contains('police station') ||
        typeName.contains('security checkpoint');
  }

  Future<void> _loadSafeSpotTypes() async {
    try {
      print('Loading safe spot types...');
      final safeSpotTypes = await SafeSpotService.getSafeSpotTypes();
      print('Loaded ${safeSpotTypes.length} safe spot types: $safeSpotTypes');

      if (mounted) {
        // ✅ Filter types based on user role
        final filteredTypes = safeSpotTypes.where((type) {
          // If user is authorized, show all types
          if (isAuthorizedUser) return true;

          // Otherwise, hide restricted types
          return !_isRestrictedType(type);
        }).toList();

        print(
          'Filtered to ${filteredTypes.length} types for user role: ${widget.userProfile?['role']}',
        );

        setState(() {
          _filteredSafeSpotTypes = filteredTypes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading safe spot types: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading safe spot types: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedTypeId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = widget.userProfile?['id'];
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is missing or invalid');
      }

      await SafeSpotService.updateSafeSpot(
        safeSpotId: widget.safeSpot['id'],
        typeId: _selectedTypeId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        userId: userId,
      );

      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context); // Close the edit modal
        Navigator.pop(context); // Close the details modal too

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safe spot updated successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update safe spot: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'local_police':
        return Icons.local_police;
      case 'account_balance':
        return Icons.account_balance;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'shopping_mall':
        return Icons.store;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'security':
        return Icons.security;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'church':
        return Icons.church;
      case 'community':
        return Icons.group;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        constraints: widget.isDesktop
            ? null
            : BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.95,
                minHeight: MediaQuery.of(context).size.height * 0.2,
              ),
        decoration: widget.isDesktop
            ? null
            : const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isDesktop)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_location,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Safe Spot',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Update safe spot information',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _filteredSafeSpotTypes
                        .isEmpty // ✅ UPDATED
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No safe spot types available.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInfoTile(
                              'Location',
                              '${widget.safeSpot['location']['coordinates'][1].toStringAsFixed(6)}, ${widget.safeSpot['location']['coordinates'][0].toStringAsFixed(6)}',
                              Icons.location_on,
                            ),

                            const SizedBox(height: 16),

                            // ✅ UPDATED: Dropdown with filtered types
                            DropdownButtonFormField<String>(
                              value: _selectedTypeName,
                              decoration: const InputDecoration(
                                labelText: 'Safe Spot Type',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              isExpanded: true,
                              items: _filteredSafeSpotTypes.map((type) {
                                // ✅ Use filtered
                                return DropdownMenuItem<String>(
                                  value: type['name'],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getIconFromString(type['icon']),
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          type['name'],
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        final selected =
                                            _filteredSafeSpotTypes // ✅ Use filtered
                                                .firstWhere(
                                                  (t) => t['name'] == value,
                                                );
                                        setState(() {
                                          _selectedTypeName = value;
                                          _selectedTypeId = selected['id'];
                                        });
                                      }
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a safe spot type';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Safe Spot Name',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., Central Police Station',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              enabled: !_isSubmitting,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a name';
                                }
                                if (value.trim().length < 3) {
                                  return 'Name must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (Optional)',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Additional details about this safe spot...',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              maxLines: 3,
                              enabled: !_isSubmitting,
                            ),
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isAdminOrOfficer
                                          ? 'Admin/Officer: You can edit this safe spot at any time.'
                                          : 'You can only edit this safe spot while it\'s pending approval.',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update Safe Spot',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),

                            SizedBox(
                              height:
                                  MediaQuery.of(context).viewInsets.bottom + 16,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String title,
    String content,
    IconData icon, {
    Widget? trailing,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
