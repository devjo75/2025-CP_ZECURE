// ignore_for_file: use_build_context_synchronously, prefer_final_fields, avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/services/heatmap_settings_service.dart';

class HeatmapSettingsPage extends StatefulWidget {
  const HeatmapSettingsPage({super.key});

  @override
  State<HeatmapSettingsPage> createState() => _HeatmapSettingsPageState();
}

class _HeatmapSettingsPageState extends State<HeatmapSettingsPage> {
  final HeatmapSettingsService _settingsService = HeatmapSettingsService();

  List<Map<String, dynamic>> _allSettings = [];
  List<Map<String, dynamic>> _filteredSettings = [];
  bool _isLoading = true;
  String _selectedCategory = 'All Categories';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All Categories',
    'distance',
    'threshold',
    'time_window',
    'radius',
  ];

  Map<String, String> _categoryLabels = {
    'distance': 'Distance Settings',
    'threshold': 'Threshold & Weights',
    'time_window': 'Time Windows',
    'radius': 'Radius Configuration',
  };

  Map<String, IconData> _categoryIcons = {
    'distance': Icons.straighten,
    'threshold': Icons.tune,
    'time_window': Icons.schedule,
    'radius': Icons.circle_outlined,
  };

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadSettings();
    _searchController.addListener(_filterSettings);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('heatmap_settings')
          .select()
          .order('category', ascending: true)
          .order('setting_key', ascending: true);

      setState(() {
        _allSettings = List<Map<String, dynamic>>.from(response);
        _filteredSettings = _allSettings;
        _isLoading = false;
      });

      print('✅ Loaded ${_allSettings.length} heatmap settings');
    } catch (e) {
      print('❌ Error loading settings: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterSettings() {
    List<Map<String, dynamic>> filtered = _allSettings;

    // Category filter
    if (_selectedCategory != 'All Categories') {
      filtered = filtered
          .where((setting) => setting['category'] == _selectedCategory)
          .toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((setting) {
        final key = (setting['setting_key'] ?? '').toString().toLowerCase();
        final description = (setting['description'] ?? '')
            .toString()
            .toLowerCase();
        return key.contains(searchLower) || description.contains(searchLower);
      }).toList();
    }

    setState(() {
      _filteredSettings = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All Categories';
      _filterSettings();
    });
  }

  void _showEditDialog(Map<String, dynamic> setting) {
    final valueController = TextEditingController(
      text: setting['setting_value'].toString(),
    );
    final descriptionController = TextEditingController(
      text: setting['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _categoryIcons[setting['category']] ?? Icons.settings,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Edit Setting', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Setting Key (Read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          setting['setting_key'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcons[setting['category']] ?? Icons.settings,
                        size: 14,
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _categoryLabels[setting['category']] ??
                            setting['category'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Value Input
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: 'Value *',
                    border: const OutlineInputBorder(),
                    hintText: 'Enter numeric value',
                    prefixIcon: const Icon(Icons.pin, size: 20),
                    suffixText: _getUnitLabel(setting['setting_key']),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
                const SizedBox(height: 16),

                // Description Input
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description, size: 20),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE047)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFFCA8A04),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changes will affect heatmap calculations immediately',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final value = valueController.text.trim();

              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Value is required')),
                );
                return;
              }

              // Validate numeric value
              final numericValue = double.tryParse(value);
              if (numericValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }

              // Validate based on setting type
              if (!_validateValue(setting['setting_key'], numericValue)) {
                return;
              }

              try {
                await Supabase.instance.client
                    .from('heatmap_settings')
                    .update({
                      'setting_value': value,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'updated_by': _currentUserId,
                    })
                    .eq('id', setting['id']);

                // Clear cache
                _settingsService.clearCache();

                Navigator.pop(context);
                _loadSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Setting updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating setting: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String _getUnitLabel(String settingKey) {
    if (settingKey.contains('distance') ||
        settingKey.contains('radius') ||
        settingKey.contains('proximity')) {
      return 'meters';
    } else if (settingKey.contains('time_window')) {
      return 'days';
    } else if (settingKey.contains('weight')) {
      return '(0.0 - 1.0)';
    } else if (settingKey.contains('multiplier')) {
      return 'factor';
    }
    return '';
  }

  bool _validateValue(String settingKey, double value) {
    // Distance and radius must be positive
    if (settingKey.contains('distance') ||
        settingKey.contains('radius') ||
        settingKey.contains('proximity')) {
      if (value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distance/Radius must be greater than 0'),
          ),
        );
        return false;
      }
      if (value > 10000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distance/Radius seems too large (max: 10km)'),
          ),
        );
        return false;
      }
    }

    // Time windows must be positive integers
    if (settingKey.contains('time_window')) {
      if (value <= 0 || value > 365) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time window must be between 1-365 days'),
          ),
        );
        return false;
      }
    }

    // Weights must be between 0 and 1
    if (settingKey.contains('weight')) {
      if (value < 0 || value > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight must be between 0.0 and 1.0')),
        );
        return false;
      }
    }

    // Min crimes must be at least 2
    if (settingKey.contains('min_crimes')) {
      if (value < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum crimes must be at least 2')),
        );
        return false;
      }
    }

    // Radius min must be less than max
    if (settingKey.contains('_min')) {
      final severity = _getSeverityFromKey(settingKey);
      final maxKey = 'radius_${severity}_max';
      final maxSetting = _allSettings.firstWhere(
        (s) => s['setting_key'] == maxKey,
        orElse: () => {},
      );
      if (maxSetting.isNotEmpty) {
        final maxValue = double.parse(maxSetting['setting_value'].toString());
        if (value >= maxValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Min radius must be less than max radius'),
            ),
          );
          return false;
        }
      }
    }

    return true;
  }

  String _getSeverityFromKey(String key) {
    if (key.contains('critical')) return 'critical';
    if (key.contains('high')) return 'high';
    if (key.contains('medium')) return 'medium';
    if (key.contains('low')) return 'low';
    return '';
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 12),
            Text('Reset All Settings'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset all heatmap settings to default values?\n\n'
          'This action cannot be undone and will affect the entire system immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                // Reset to default values (you can customize these)
                final defaultUpdates = [
                  {'key': 'cluster_merge_distance', 'value': '500'},
                  {'key': 'min_crimes_for_cluster', 'value': '3'},
                  {'key': 'proximity_alert_distance', 'value': '500'},
                  {'key': 'time_window_critical', 'value': '120'},
                  {'key': 'time_window_high', 'value': '90'},
                  {'key': 'time_window_medium', 'value': '60'},
                  {'key': 'time_window_low', 'value': '30'},
                  {'key': 'weight_critical', 'value': '1.0'},
                  {'key': 'weight_high', 'value': '0.75'},
                  {'key': 'weight_medium', 'value': '0.5'},
                  {'key': 'weight_low', 'value': '0.25'},
                ];

                for (final update in defaultUpdates) {
                  await Supabase.instance.client
                      .from('heatmap_settings')
                      .update({
                        'setting_value': update['value'],
                        'updated_by': _currentUserId,
                      })
                      .eq('setting_key', update['key'] as Object);
                }

                _settingsService.clearCache();

                Navigator.pop(context);
                _loadSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All settings reset to defaults'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error resetting settings: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'distance':
        return const Color(0xFF10B981);
      case 'threshold':
        return const Color(0xFF6366F1);
      case 'time_window':
        return const Color(0xFFF59E0B);
      case 'radius':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 768) {
          return _buildDesktopView();
        } else {
          return _buildMobileView();
        }
      },
    );
  }

  Widget _buildDesktopView() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Search Bar
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search settings...',
                      hintStyle: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Category Filter
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    isExpanded: true,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category == 'All Categories'
                              ? category
                              : _categoryLabels[category] ?? category,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          _filterSettings();
                        });
                      }
                    },
                  ),
                ),
              ),

              // Clear Filters
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All Categories')
                Container(
                  margin: const EdgeInsets.only(left: 16),
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: IconButton(
                    onPressed: _clearFilters,
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    tooltip: 'Clear Filters',
                  ),
                ),

              const SizedBox(width: 16),

              // Reset All Button
              ElevatedButton.icon(
                onPressed: _showResetDialog,
                icon: const Icon(Icons.restore, size: 20),
                label: const Text('Reset to Defaults'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: Container(
            width: double.infinity,
            color: const Color(0xFFFAFAFA),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSettings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 64,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No settings found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 56,
                        dataRowHeight: 72,
                        horizontalMargin: 24,
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF5F7FA),
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Category',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Setting Key',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Value',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Description',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        rows: _filteredSettings.map((setting) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      setting['category'],
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _getCategoryColor(
                                        setting['category'],
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _categoryIcons[setting['category']] ??
                                            Icons.settings,
                                        size: 14,
                                        color: _getCategoryColor(
                                          setting['category'],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _categoryLabels[setting['category']] ??
                                            setting['category'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getCategoryColor(
                                            setting['category'],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  setting['setting_key'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${setting['setting_value']} ${_getUnitLabel(setting['setting_key'])}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  setting['description'] ?? 'No description',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showEditDialog(setting),
                                  tooltip: 'Edit',
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search settings...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _showResetDialog,
                      icon: const Icon(
                        Icons.restore,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Reset to Defaults',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Filter
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  isExpanded: true,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category == 'All Categories'
                            ? category
                            : _categoryLabels[category] ?? category,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                        _filterSettings();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Settings List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSettings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No settings found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSettings.length,
                  itemBuilder: (context, index) {
                    return _buildSettingCard(_filteredSettings[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingCard(Map<String, dynamic> setting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEditDialog(setting),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getCategoryColor(
                    setting['category'],
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getCategoryColor(
                      setting['category'],
                    ).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _categoryIcons[setting['category']] ?? Icons.settings,
                      size: 14,
                      color: _getCategoryColor(setting['category']),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _categoryLabels[setting['category']] ??
                          setting['category'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(setting['category']),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Setting Key
              Text(
                setting['setting_key'] ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),

              // Value
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${setting['setting_value']} ${_getUnitLabel(setting['setting_key'])}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit, size: 20, color: const Color(0xFF6366F1)),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              if (setting['description'] != null &&
                  setting['description'].toString().isNotEmpty)
                Text(
                  setting['description'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
