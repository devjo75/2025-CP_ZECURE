import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'safe_spot_service.dart';

class SafeSpotForm {
  static void showSafeSpotForm({
    required BuildContext context,
    required LatLng position,
    required Map<String, dynamic>? userProfile,
    required VoidCallback onUpdate,
  }) {
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
            child: SafeSpotFormModal(
              position: position,
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
        builder: (context) => SafeSpotFormModal(
          position: position,
          userProfile: userProfile,
          onUpdate: onUpdate,
          isDesktop: false,
        ),
      );
    }
  }
}

class SafeSpotFormModal extends StatefulWidget {
  final LatLng position;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onUpdate;

  const SafeSpotFormModal({
    super.key,
    required this.position,
    required this.userProfile,
    required this.onUpdate,
    required bool isDesktop,
  });

  @override
  State<SafeSpotFormModal> createState() => _SafeSpotFormModalState();
}

class _SafeSpotFormModalState extends State<SafeSpotFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _safeSpotTypes = [];
  String? _selectedTypeName;
  int? _selectedTypeId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get isAdmin {
    return widget.userProfile?['role'] == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadSafeSpotTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeSpotTypes() async {
    try {
      print('Loading safe spot types...');
      final safeSpotTypes = await SafeSpotService.getSafeSpotTypes();
      print('Loaded ${safeSpotTypes.length} safe spot types: $safeSpotTypes');

      if (mounted) {
        setState(() {
          _safeSpotTypes = safeSpotTypes;
          _isLoading = false;

          if (safeSpotTypes.isNotEmpty) {
            _selectedTypeName = safeSpotTypes[0]['name'];
            _selectedTypeId = safeSpotTypes[0]['id'];
            print('Selected type: $_selectedTypeName (ID: $_selectedTypeId)');
          }
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
      await SafeSpotService.createSafeSpot(
        typeId: _selectedTypeId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: widget.position,
        userId: widget.userProfile!['id'],
      );

      if (mounted) {
        Navigator.pop(context); // Close the modal first

        // Different messages for admin vs regular users
        final successMessage = isAdmin
            ? 'Safe spot created successfully! It is now visible to all users.'
            : 'Safe spot submitted successfully! It will be visible after approval.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: Duration(seconds: 3),
          ),
        );

        // Add delay before refreshing to ensure database commit is complete
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onUpdate(); // Call the update callback after delay
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit safe spot: ${e.toString()}'),
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
      onTap: () {}, // Prevents dismissal when tapping content
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
          minHeight: MediaQuery.of(context).size.height * 0.2,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle at the top
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_location,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Safe Spot',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create a new safe spot at this location',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content wrapper
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _safeSpotTypes.isEmpty
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
                            // Location info
                            _buildInfoTile(
                              'Location',
                              '${widget.position.latitude.toStringAsFixed(6)}, ${widget.position.longitude.toStringAsFixed(6)}',
                              Icons.location_on,
                            ),

                            const SizedBox(height: 16),

                            // Safe spot type dropdown
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
                              items: _safeSpotTypes.map((type) {
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
                                        final selected = _safeSpotTypes
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

                            // Name field
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

                            // Description field
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

                            // Info container
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isAdmin
                                          ? 'Your submission will be automatically approved and visible to all users.'
                                          : 'Your submission will be reviewed and needs community upvotes to be approved.',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit button
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
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
                                      'Submit Safe Spot',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),

                            // Add some bottom padding for better UX
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

  // Helper method to build info tiles (similar to SafeSpotDetails)
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
