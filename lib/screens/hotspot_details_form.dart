import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:zecure/services/crime_hotspot_model.dart';

// ============================================
// DESKTOP DIALOG - Hotspot Details Form
// ============================================

class HotspotDetailsFormDialog extends StatefulWidget {
  final GeometryType geometryType;
  final List<LatLng>? polygonPoints;
  final LatLng? center;
  final double? radius;
  final Map<String, dynamic>? userProfile;
  final Function(Map<String, dynamic> hotspotData) onSave;

  const HotspotDetailsFormDialog({
    super.key,
    required this.geometryType,
    this.polygonPoints,
    this.center,
    this.radius,
    required this.userProfile,
    required this.onSave,
  });

  @override
  State<HotspotDetailsFormDialog> createState() =>
      _HotspotDetailsFormDialogState();
}

class _HotspotDetailsFormDialogState extends State<HotspotDetailsFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  RiskAssessment _riskAssessment = RiskAssessment.high;
  HotspotVisibility _visibility = HotspotVisibility.public;
  bool _isSaving = false;

  bool get _isAdmin {
    final role = widget.userProfile?['role'] as String?;
    return role == 'admin';
  }

  // ✅ ADD: Get allowed visibility options
  List<HotspotVisibility> get _allowedVisibilityOptions {
    if (_isAdmin) {
      return HotspotVisibility.values; // Admin sees all
    } else {
      // Officer/Tanod only see public and police_only
      return [HotspotVisibility.public, HotspotVisibility.policeOnly];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> hotspotData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'geometry_type': widget.geometryType.value,
      'detection_type': 'manual',
      'risk_assessment': _riskAssessment.value,
      'visibility': _visibility.value,
      'police_notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      'status': 'active',
    };

    // Add geometry-specific data
    if (widget.geometryType == GeometryType.circle) {
      hotspotData['center_lat'] = widget.center!.latitude;
      hotspotData['center_lng'] = widget.center!.longitude;
      hotspotData['radius_meters'] = widget.radius;
    } else {
      hotspotData['polygon_coordinates'] = widget.polygonPoints!
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList();
    }

    await widget.onSave(hotspotData);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.geometryType == GeometryType.circle
                          ? Icons.circle_outlined
                          : Icons.pentagon_outlined,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hotspot Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Fill in information about this danger zone',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 16),
                      _buildRiskDropdown(),
                      const SizedBox(height: 16),
                      _buildVisibilityDropdown(),
                      const SizedBox(height: 16),
                      _buildNotesField(),
                      const SizedBox(height: 20),
                      _buildGeometryInfoCard(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            _buildFooterButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Hotspot Name *',
        hintText: 'e.g., Downtown Plaza Zone',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a name';
        }
        if (value.trim().length < 3) {
          return 'Name must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: 'Describe the area or crime patterns',
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      maxLines: 3,
    );
  }

  Widget _buildRiskDropdown() {
    return DropdownButtonFormField<RiskAssessment>(
      value: _riskAssessment,
      decoration: InputDecoration(
        labelText: 'Risk Level *',
        prefixIcon: const Icon(Icons.warning_amber_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: RiskAssessment.values.map((risk) {
        return DropdownMenuItem(
          value: risk,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getRiskColor(risk),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(risk.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _riskAssessment = value);
        }
      },
    );
  }

  Widget _buildVisibilityDropdown() {
    return DropdownButtonFormField<HotspotVisibility>(
      value: _visibility,
      decoration: InputDecoration(
        labelText: 'Visibility *',
        prefixIcon: const Icon(Icons.visibility_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: _allowedVisibilityOptions.map((visibility) {
        return DropdownMenuItem(
          value: visibility,
          child: Row(
            children: [
              Icon(
                _getVisibilityIcon(visibility),
                size: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(visibility.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _visibility = value);
        }
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: 'Police Notes',
        hintText: 'Internal notes (not visible to public)',
        prefixIcon: const Icon(Icons.note_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      maxLines: 2,
    );
  }

  Widget _buildGeometryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.geometryType == GeometryType.circle
                  ? 'Circular zone: ${widget.radius!.toInt()}m radius'
                  : 'Polygon zone: ${widget.polygonPoints!.length} boundary points',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Creating...' : 'Create Hotspot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(RiskAssessment risk) {
    switch (risk) {
      case RiskAssessment.extreme:
        return Colors.red.shade700;
      case RiskAssessment.high:
        return Colors.orange.shade600;
      case RiskAssessment.moderate:
        return Colors.yellow.shade700;
      case RiskAssessment.low:
        return Colors.green.shade600;
    }
  }

  IconData _getVisibilityIcon(HotspotVisibility visibility) {
    switch (visibility) {
      case HotspotVisibility.public:
        return Icons.public;
      case HotspotVisibility.policeOnly:
        return Icons.shield_outlined;
      case HotspotVisibility.adminOnly:
        return Icons.admin_panel_settings_outlined;
    }
  }
}

// ============================================
// MOBILE BOTTOM SHEET - Hotspot Details Form
// ============================================

class HotspotDetailsFormSheet extends StatefulWidget {
  final GeometryType geometryType;
  final List<LatLng>? polygonPoints;
  final LatLng? center;
  final double? radius;
  final Map<String, dynamic>? userProfile;
  final Function(Map<String, dynamic> hotspotData) onSave;

  const HotspotDetailsFormSheet({
    super.key,
    required this.geometryType,
    this.polygonPoints,
    this.center,
    this.radius,
    required this.userProfile,
    required this.onSave,
  });

  @override
  State<HotspotDetailsFormSheet> createState() =>
      _HotspotDetailsFormSheetState();
}

class _HotspotDetailsFormSheetState extends State<HotspotDetailsFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  RiskAssessment _riskAssessment = RiskAssessment.high;
  HotspotVisibility _visibility = HotspotVisibility.public;
  bool _isSaving = false;

  bool get _isAdmin {
    final role = widget.userProfile?['role'] as String?;
    return role == 'admin';
  }

  // ✅ ADD: Get allowed visibility options
  List<HotspotVisibility> get _allowedVisibilityOptions {
    if (_isAdmin) {
      return HotspotVisibility.values;
    } else {
      return [HotspotVisibility.public, HotspotVisibility.policeOnly];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> hotspotData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'geometry_type': widget.geometryType.value,
      'detection_type': 'manual',
      'risk_assessment': _riskAssessment.value,
      'visibility': _visibility.value,
      'police_notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      'status': 'active',
    };

    // Add geometry-specific data
    if (widget.geometryType == GeometryType.circle) {
      hotspotData['center_lat'] = widget.center!.latitude;
      hotspotData['center_lng'] = widget.center!.longitude;
      hotspotData['radius_meters'] = widget.radius;
    } else {
      hotspotData['polygon_coordinates'] = widget.polygonPoints!
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList();
    }

    await widget.onSave(hotspotData);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.8, 0.95],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                _buildMobileHeader(),

                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameField(),
                          const SizedBox(height: 16),
                          _buildDescriptionField(),
                          const SizedBox(height: 16),
                          _buildRiskDropdown(),
                          const SizedBox(height: 16),
                          _buildVisibilityDropdown(),
                          const SizedBox(height: 16),
                          _buildNotesField(),
                          const SizedBox(height: 20),
                          _buildGeometryInfoCard(),
                          const SizedBox(height: 80), // Space for fixed button
                        ],
                      ),
                    ),
                  ),
                ),

                // Fixed action buttons
                _buildMobileActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.geometryType == GeometryType.circle
                  ? Icons.circle_outlined
                  : Icons.pentagon_outlined,
              color: Colors.red.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hotspot Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Fill in information about this zone',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Hotspot Name *',
        hintText: 'e.g., Downtown Plaza Zone',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a name';
        }
        if (value.trim().length < 3) {
          return 'Name must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: 'Describe the area or crime patterns',
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      maxLines: 3,
    );
  }

  Widget _buildRiskDropdown() {
    return DropdownButtonFormField<RiskAssessment>(
      value: _riskAssessment,
      decoration: InputDecoration(
        labelText: 'Risk Level *',
        prefixIcon: const Icon(Icons.warning_amber_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: RiskAssessment.values.map((risk) {
        return DropdownMenuItem(
          value: risk,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getRiskColor(risk),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(risk.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _riskAssessment = value);
        }
      },
    );
  }

  Widget _buildVisibilityDropdown() {
    return DropdownButtonFormField<HotspotVisibility>(
      value: _visibility,
      decoration: InputDecoration(
        labelText: 'Visibility *',
        prefixIcon: const Icon(Icons.visibility_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: _allowedVisibilityOptions.map((visibility) {
        return DropdownMenuItem(
          value: visibility,
          child: Row(
            children: [
              Icon(
                _getVisibilityIcon(visibility),
                size: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(visibility.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _visibility = value);
        }
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: 'Police Notes',
        hintText: 'Internal notes (not visible to public)',
        prefixIcon: const Icon(Icons.note_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      maxLines: 2,
    );
  }

  Widget _buildGeometryInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.geometryType == GeometryType.circle
                  ? 'Circular zone: ${widget.radius!.toInt()}m radius'
                  : 'Polygon zone: ${widget.polygonPoints!.length} boundary points',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 20),
                label: Text(_isSaving ? 'Creating...' : 'Create Hotspot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(RiskAssessment risk) {
    switch (risk) {
      case RiskAssessment.extreme:
        return Colors.red.shade700;
      case RiskAssessment.high:
        return Colors.orange.shade600;
      case RiskAssessment.moderate:
        return Colors.yellow.shade700;
      case RiskAssessment.low:
        return Colors.green.shade600;
    }
  }

  IconData _getVisibilityIcon(HotspotVisibility visibility) {
    switch (visibility) {
      case HotspotVisibility.public:
        return Icons.public;
      case HotspotVisibility.policeOnly:
        return Icons.shield_outlined;
      case HotspotVisibility.adminOnly:
        return Icons.admin_panel_settings_outlined;
    }
  }
}
