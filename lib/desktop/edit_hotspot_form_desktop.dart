import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditHotspotFormDesktop extends StatefulWidget {
  final Map<String, dynamic> hotspot;
  final Future<void> Function(int id, int crimeId, String description, DateTime time, String activeStatus) onUpdate;
  final VoidCallback onCancel;
  final bool isAdmin;
  final List<Map<String, dynamic>> crimeTypes; // Now properly included in constructor

  const EditHotspotFormDesktop({
    super.key,
    required this.hotspot,
    required this.onUpdate,
    required this.onCancel,
    required this.isAdmin,
    required this.crimeTypes,
  });

  @override
  State<EditHotspotFormDesktop> createState() => _EditHotspotFormDesktopState();
}

class _EditHotspotFormDesktopState extends State<EditHotspotFormDesktop> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late String _selectedCrimeType;
  late int _selectedCrimeId;
  late String _selectedActiveStatus;
  late bool _isActiveStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.hotspot['description'] ?? '');
    
    final dateTime = DateTime.parse(widget.hotspot['time']).toLocal();
    _dateController = TextEditingController(text: dateTime.toString().split(' ')[0]);
    _timeController = TextEditingController(text: DateFormat('HH:mm').format(dateTime));

    _selectedCrimeType = widget.hotspot['crime_type']['name'];
    _selectedCrimeId = widget.hotspot['type_id'];
    _selectedActiveStatus = widget.hotspot['active_status'] ?? 'active';
    _isActiveStatus = _selectedActiveStatus == 'active';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
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
        _dateController.text = pickedDate.toString().split(' ')[0];
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
        final now = DateTime.now();
        final formatted = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
        _timeController.text = DateFormat('HH:mm').format(formatted);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final dateTime = DateTime.parse('${_dateController.text} ${_timeController.text}');
      await widget.onUpdate(
        widget.hotspot['id'],
        _selectedCrimeId,
        _descriptionController.text,
        dateTime,
        _selectedActiveStatus,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update hotspot: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      child: Form(
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
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _isSubmitting ? null : _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Time',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _isSubmitting ? null : _pickTime,
            ),
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Status:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _isActiveStatus,
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
                                    if (mounted) {
                                      setState(() {
                                        _isActiveStatus = value;
                                        _selectedActiveStatus = value ? 'active' : 'inactive';
                                      });
                                    }
                                  },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isActiveStatus ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: _isActiveStatus ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Update'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (mounted) {
                            Navigator.pop(context);
                            widget.onCancel();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[500],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}