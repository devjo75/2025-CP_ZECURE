import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unused_import
import 'package:google_maps_flutter/google_maps_flutter.dart' hide LatLng;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zecure/services/photo_upload_service.dart';

class ReportHotspotFormDesktop extends StatefulWidget {
  final LatLng position;
  final List<Map<String, dynamic>> crimeTypes;
  final Future<bool> Function(int crimeId, String description, LatLng position, DateTime time, XFile? photo) onSubmit;
  final VoidCallback onCancel;
  final int dailyCount; // Add daily count parameter

  const ReportHotspotFormDesktop({
    super.key,
    required this.position,
    required this.crimeTypes,
    required this.onSubmit,
    required this.onCancel,
    required this.dailyCount, // Add required parameter
  });

  @override
  State<ReportHotspotFormDesktop> createState() => _ReportHotspotFormDesktopState();
}

class _ReportHotspotFormDesktopState extends State<ReportHotspotFormDesktop> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCrimeType;
  late int _selectedCrimeId;
  late TextEditingController _descriptionController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  bool _isSubmitting = false;
  
  // Photo state
  XFile? _selectedPhoto;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _selectedCrimeType = widget.crimeTypes[0]['name'];
    _selectedCrimeId = widget.crimeTypes[0]['id'];

    final now = DateTime.now();
    _descriptionController = TextEditingController();
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(now));
    _timeController = TextEditingController(text: DateFormat('HH:mm').format(now));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // Helper methods for daily counter styling
  Color _getDailyCounterColor(int count) {
    if (count >= 5) return Colors.red.withOpacity(0.1);
    if (count >= 3) return Colors.orange.withOpacity(0.1);
    return Colors.green.withOpacity(0.1);
  }

  Color _getDailyCounterBorderColor(int count) {
    if (count >= 5) return Colors.red.withOpacity(0.3);
    if (count >= 3) return Colors.orange.withOpacity(0.3);
    return Colors.green.withOpacity(0.3);
  }

  Color _getDailyCounterTextColor(int count) {
    if (count >= 5) return Colors.red.shade700;
    if (count >= 3) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initialTime = TimeOfDay.fromDateTime(
      DateTime.tryParse('${_dateController.text} ${_timeController.text}') ?? DateTime.now()
    );
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null && mounted) {
      setState(() {
        _timeController.text =
            '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      });
    }
  }

Widget _buildPhotoSection(XFile? selectedPhoto, bool isUploading, Function(XFile?, bool) onPhotoChanged) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (selectedPhoto != null)
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(
                          selectedPhoto.path,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Text('Error loading image'));
                          },
                        )
                      : Image.file(
                          File(selectedPhoto.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Text('Error loading image'));
                          },
                        ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: () {
                      onPhotoChanged(null, false);
                    },
                  ),
                ),
              ),
            ],
          )
else
  Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: isUploading
              ? null
              : () async {
                  onPhotoChanged(null, true);
                  try {
                    final photo = await PhotoService.pickImage();
                    onPhotoChanged(photo, false);
                  } catch (e) {
                    onPhotoChanged(null, false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error taking photo: $e')),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 20, 92, 151),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          icon: isUploading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: Text(isUploading ? 'Loading...' : 'Take Photo'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: isUploading
              ? null
              : () async {
                  onPhotoChanged(null, true);
                  try {
                    final photo = await PhotoService.pickImageFromGallery();
                    onPhotoChanged(photo, false);
                  } catch (e) {
                    onPhotoChanged(null, false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error selecting photo: $e')),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 20, 92, 151),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          icon: isUploading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library),
          label: Text(isUploading ? 'Loading...' : 'Gallery'),
        ),
      ),
    ],
  ),
      ],
    ),
  );
}

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isSubmitting || _isUploadingPhoto) return;

    setState(() => _isSubmitting = true);
    try {
      final dateTime = DateTime.parse('${_dateController.text} ${_timeController.text}');
      final success = await widget.onSubmit(_selectedCrimeId, _descriptionController.text, widget.position, dateTime, _selectedPhoto);
      
      if (mounted && success) {
        Navigator.pop(context);
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date or time format')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report crime: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

@override
Widget build(BuildContext context) {
  return Container(
    width: 450,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Daily Reports Counter
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _getDailyCounterColor(widget.dailyCount),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getDailyCounterBorderColor(widget.dailyCount),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.today,
                size: 20,
                color: _getDailyCounterTextColor(widget.dailyCount),
              ),
              const SizedBox(width: 8),
              Text(
                'Daily Reports: ${widget.dailyCount}/5',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getDailyCounterTextColor(widget.dailyCount),
                ),
              ),
            ],
          ),
        ),
        
        // Header Title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.report_problem,
                size: 32,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              const Text(
                'Report Crime Incident',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Submit a crime report for admin review',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCrimeType,
                decoration: const InputDecoration(
                  labelText: 'Crime Type',
                  border: OutlineInputBorder(),
                ),
                items: widget.crimeTypes.map((crimeType) {
                  return DropdownMenuItem<String>(
                    value: crimeType['name'],
                    child: Text(
                      '${crimeType['name']} - ${crimeType['category']} (${crimeType['level']})',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (newValue) {
                        if (newValue != null && mounted) {
                          setState(() {
                            _selectedCrimeType = newValue;
                            _selectedCrimeId = widget.crimeTypes.firstWhere((c) => c['name'] == newValue)['id'];
                          });
                        }
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a crime type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              
              // Photo section
              _buildPhotoSection(_selectedPhoto, _isUploadingPhoto, (photo, uploading) {
                setState(() {
                  _selectedPhoto = photo;
                  _isUploadingPhoto = uploading;
                });
              }),
              const SizedBox(height: 16),
              
              // Date and time side by side
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date of Incident',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _isSubmitting ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time of Incident',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _isSubmitting ? null : _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Important notice about false reports
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notice',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daily limit: 5 reports. Avoid reporting same location twice. False reports may result in account restrictions.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isUploadingPhoto) ? null : _submitForm,
                  child: (_isSubmitting || _isUploadingPhoto)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('Submit Report (${5 - widget.dailyCount} remaining)'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}