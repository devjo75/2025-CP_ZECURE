import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../services/save_point_service.dart';

class AddSavePointScreen {
  static void showAddSavePointForm({
    required BuildContext context,
    required Map<String, dynamic>? userProfile,
    LatLng? initialLocation,
    Map<String, dynamic>? editSavePoint,
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
            child: AddSavePointFormModal(
              userProfile: userProfile,
              initialLocation: initialLocation,
              editSavePoint: editSavePoint,
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
        builder: (context) => AddSavePointFormModal(
          userProfile: userProfile,
          initialLocation: initialLocation,
          editSavePoint: editSavePoint,
          onUpdate: onUpdate,
          isDesktop: false,
        ),
      );
    }
  }
}

class AddSavePointFormModal extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final LatLng? initialLocation;
  final Map<String, dynamic>? editSavePoint;
  final VoidCallback onUpdate;
  final bool isDesktop;

  const AddSavePointFormModal({
    Key? key,
    required this.userProfile,
    this.initialLocation,
    this.editSavePoint,
    required this.onUpdate,
    required this.isDesktop,
  }) : super(key: key);

  @override
  State<AddSavePointFormModal> createState() => _AddSavePointFormModalState();
}

class _AddSavePointFormModalState extends State<AddSavePointFormModal> {
  final SavePointService _savePointService = SavePointService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  LatLng? _selectedLocation;
  String _locationName = '';
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.editSavePoint != null) {
      final editData = widget.editSavePoint!;
      _nameController.text = editData['name'] ?? '';
      _descriptionController.text = editData['description'] ?? '';
      final coords = editData['location']['coordinates'];
      _selectedLocation = LatLng(coords[1], coords[0]);
      _getLocationName(_selectedLocation!);
    } else if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _getLocationName(widget.initialLocation!);
    } else {
      _selectedLocation = const LatLng(14.5995, 120.9842);
      _getLocationName(_selectedLocation!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getLocationName(LatLng location) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _locationName = data['display_name'] ?? 
              "${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}";
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationName = "${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}";
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _saveSavePoint() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      return;
    }

    if (widget.userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final savePointData = {
        'user_id': widget.userProfile!['id'],
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'location': {
          'type': 'Point',
          'coordinates': [_selectedLocation!.longitude, _selectedLocation!.latitude],
        },
      };

      if (widget.editSavePoint != null) {
        await _savePointService.updateSavePoint(
          widget.editSavePoint!['id'],
          savePointData,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save point updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onUpdate();
        }
      } else {
        await _savePointService.createSavePoint(savePointData);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save point created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onUpdate();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving save point: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoTile(String title, String content, IconData icon) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editSavePoint != null;

    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
          minHeight: MediaQuery.of(context).size.height * 0.2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: widget.isDesktop
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle at the top (only for mobile)
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
            
            // Header
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
                      Icons.bookmark_add,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Save Point' : 'Add Save Point',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isEditing
                              ? 'Modify your save point details'
                              : 'Save a new location for quick access',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
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
              child: SingleChildScrollView(
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
                        _isLoadingLocation
                            ? 'Loading location...'
                            : _locationName.isNotEmpty
                                ? _locationName
                                : '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        Icons.location_on,
                      ),
                      
                      const SizedBox(height: 16),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Save Point Name *',
                          hintText: 'e.g., Home, Office, Favorite Restaurant',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        maxLength: 100,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name for your save point';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters long';
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
                          hintText: 'Add any notes about this location',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                        enabled: !_isLoading,
                      ),
                      
                      const SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSavePoint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Save Point' : 'Create Save Point',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      
                      // Add bottom padding for better UX
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
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
}