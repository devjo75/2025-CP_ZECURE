import 'package:flutter/material.dart';
import 'chat_service.dart';

class CreateChannelScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const CreateChannelScreen({super.key, required this.userProfile});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
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

    // DEBUG: Print user info
    print('🔑 User ID: $userId');
    print('👤 User Profile: ${widget.userProfile}');
    print('📝 Channel Name: ${_nameController.text.trim()}');
    print('🏷️ Channel Type: $_selectedType');
    print(
      '🏘️ Barangay: ${_selectedType == 'barangay' ? _barangayController.text.trim() : 'N/A'}',
    );

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

    print('📦 Channel result: ${channel?.toJson()}');

    if (channel != null && mounted) {
      print('✅ Channel created successfully: ${channel.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Channel "${channel.name}" created!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      print('❌ Channel creation failed - returned null');
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Create Channel',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel Type Selection
                const Text(
                  'Channel Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildChannelTypeSelector(),

                const SizedBox(height: 24),

                // Channel Name
                _buildTextField(
                  controller: _nameController,
                  label: 'Channel Name',
                  hint: _selectedType == 'barangay'
                      ? 'e.g., Barangay Guiwan Safety'
                      : 'e.g., Emergency Response Team',
                  icon: Icons.tag,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a channel name';
                    }
                    if (value.trim().length < 3) {
                      return 'Channel name must be at least 3 characters';
                    }
                    if (value.trim().length > 100) {
                      return 'Channel name is too long (max 100 characters)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Barangay Name (only for barangay type)
                if (_selectedType == 'barangay') ...[
                  _buildTextField(
                    controller: _barangayController,
                    label: 'Barangay Name',
                    hint: 'e.g., Guiwan',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (_selectedType == 'barangay') {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter barangay name';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

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

                // Privacy Setting
                _buildPrivacySwitch(),

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createChannel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Channel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTypeOption(
            value: 'barangay',
            title: 'Barangay Channel',
            subtitle: 'For specific barangay discussions',
            icon: '🏘️',
          ),
          Divider(height: 1, color: Colors.grey[200]),
          _buildTypeOption(
            value: 'city_wide',
            title: 'City-Wide Channel',
            subtitle: 'For all Zamboanga City residents',
            icon: '🏙️',
          ),
          Divider(height: 1, color: Colors.grey[200]),
          _buildTypeOption(
            value: 'custom',
            title: 'Custom Channel',
            subtitle: 'For specific communities or groups',
            icon: '💬',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String value,
    required String title,
    required String subtitle,
    required String icon,
  }) {
    final isSelected = _selectedType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
          // Clear barangay field if switching away from barangay type
          if (value != 'barangay') {
            _barangayController.clear();
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade600, size: 24),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.blue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            _isPrivate ? Icons.lock : Icons.lock_open,
            color: _isPrivate ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private Channel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPrivate
                      ? 'Users need approval to join'
                      : 'Anyone can join this channel',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
          ),
        ],
      ),
    );
  }
}
