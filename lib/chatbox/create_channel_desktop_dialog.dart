import 'package:flutter/material.dart';
import 'chat_service.dart';

/// Desktop-optimized dialog for creating channels
/// Shows as a centered dialog instead of full screen
class CreateChannelDesktopDialog extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const CreateChannelDesktopDialog({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<CreateChannelDesktopDialog> createState() => _CreateChannelDesktopDialogState();
}

class _CreateChannelDesktopDialogState extends State<CreateChannelDesktopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _chatService = ChatService();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _barangayController = TextEditingController();
  
  String _selectedType = 'barangay';
  bool _isPrivate = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final userId = widget.userProfile['id'] as String;

    final channel = await _chatService.createChannel(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      channelType: _selectedType,
      barangay: _selectedType == 'barangay' 
          ? _barangayController.text.trim().toUpperCase()
          : null,
      createdBy: userId,
      isPrivate: _isPrivate,
    );

    setState(() => _isCreating = false);

    if (channel != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Channel "${channel.name}" created!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // ✅ Return true to signal full reload (new channel created)
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create channel. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_circle,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Channel',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Set up a new community discussion channel',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Channel Type Selection
                      const Text(
                        'Channel Type',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactTypeCard(
                              value: 'barangay',
                              title: 'Barangay',
                              icon: '🏘️',
                              subtitle: 'Barangay-specific',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactTypeCard(
                              value: 'city_wide',
                              title: 'City-Wide',
                              icon: '🏙️',
                              subtitle: 'Entire city',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactTypeCard(
                              value: 'custom',
                              title: 'Custom',
                              icon: '💬',
                              subtitle: 'Specific group',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Two-column layout for name and barangay
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: _selectedType == 'barangay' ? 1 : 2,
                            child: _buildTextField(
                              controller: _nameController,
                              label: 'Channel Name',
                              hint: _selectedType == 'barangay' 
                                  ? 'e.g., Safety Updates' 
                                  : 'e.g., Emergency Response',
                              icon: Icons.tag,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (value.trim().length < 3) {
                                  return 'At least 3 characters';
                                }
                                if (value.trim().length > 100) {
                                  return 'Too long (max 100)';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_selectedType == 'barangay') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _barangayController,
                                label: 'Barangay Name',
                                hint: 'e.g., Guiwan',
                                icon: Icons.location_on,
                                validator: (value) {
                                  if (_selectedType == 'barangay') {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description (Optional)',
                        hint: 'What is this channel about?',
                        icon: Icons.description,
                        maxLines: 3,
                        maxLength: 500,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Privacy Setting - Compact
                      _buildCompactPrivacyToggle(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer with actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createChannel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Channel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
  }

  Widget _buildCompactTypeCard({
    required String value,
    required String title,
    required String icon,
    required String subtitle,
  }) {
    final isSelected = _selectedType == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
          if (value != 'barangay') {
            _barangayController.clear();
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue.shade900 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.blue.shade700 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.blue, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPrivacyToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            _isPrivate ? Icons.lock : Icons.lock_open,
            color: _isPrivate ? Colors.orange : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private Channel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPrivate 
                      ? 'Requires approval to join' 
                      : 'Anyone can join',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivate,
            onChanged: (value) {
              setState(() {
                _isPrivate = value;
              });
            },
            activeColor: Colors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the dialog
Future<bool?> showCreateChannelDesktopDialog(
  BuildContext context,
  Map<String, dynamic> userProfile,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreateChannelDesktopDialog(
      userProfile: userProfile,
    ),
  );
}