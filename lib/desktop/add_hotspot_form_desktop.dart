import 'package:flutter/material.dart';

class AddHotspotFormDesktop extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final TextEditingController dateController;
  final TextEditingController timeController;
  final List<Map<String, dynamic>> crimeTypes;
  final String selectedCrimeType;
  final void Function(String) onCrimeTypeChanged;
  final VoidCallback onSubmit;

  const AddHotspotFormDesktop({
    super.key,
    required this.formKey,
    required this.descriptionController,
    required this.dateController,
    required this.timeController,
    required this.crimeTypes,
    required this.selectedCrimeType,
    required this.onCrimeTypeChanged,
    required this.onSubmit,
  });

  @override
  State<AddHotspotFormDesktop> createState() => _AddHotspotFormDesktopState();
}

class _AddHotspotFormDesktopState extends State<AddHotspotFormDesktop> {
  late DateTime now;

  @override
  void initState() {
    super.initState();
    now = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: widget.selectedCrimeType,
                  decoration: const InputDecoration(
                    labelText: 'Crime Type',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.crimeTypes.map((crimeType) {
                    return DropdownMenuItem<String>(
                      value: crimeType['name'],
                      child: Text(crimeType['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) widget.onCrimeTypeChanged(value);
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
                  controller: widget.descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      widget.dateController.text =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      widget.timeController.text =
                          "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onSubmit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
