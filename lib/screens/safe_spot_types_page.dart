// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SafeSpotTypesPage extends StatefulWidget {
  const SafeSpotTypesPage({super.key});

  @override
  State<SafeSpotTypesPage> createState() => _SafeSpotTypesPageState();
}

class _SafeSpotTypesPageState extends State<SafeSpotTypesPage> {
  final TextEditingController _searchController = TextEditingController();
  final String _sortBy = 'name';
  final bool _sortAscending = true;

  List<Map<String, dynamic>> _safeSpotTypesData = [];
  List<Map<String, dynamic>> _filteredSafeSpotTypesData = [];
  bool _isLoading = true;

  final Set<String> _expandedCards = <String>{};

  // Available Material Icons for safe spots
  final List<String> _availableIcons = [
    'local_police',
    'account_balance',
    'local_hospital',
    'school',
    'shopping_mall',
    'lightbulb',
    'security',
    'local_fire_department',
    'church',
    'community',
    'place',
    'emergency',
    'health_and_safety',
    'gavel',
    'business',
    'apartment',
    'store',
    'local_pharmacy',
    'fitness_center',
    'park',
  ];

  @override
  void initState() {
    super.initState();
    _loadSafeSpotTypes();
    _searchController.addListener(_filterSafeSpotTypes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeSpotTypes() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('safe_spot_types')
          .select()
          .order('name', ascending: true);

      setState(() {
        _safeSpotTypesData = List<Map<String, dynamic>>.from(response);
        _filteredSafeSpotTypesData = _safeSpotTypesData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading safe spot types: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading safe spot types: $e')),
        );
      }
    }
  }

  void _filterSafeSpotTypes() {
    List<Map<String, dynamic>> filtered = _safeSpotTypesData;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((safeSpotType) {
        final name = (safeSpotType['name'] ?? '').toString().toLowerCase();
        final description = (safeSpotType['description'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(searchLower) || description.contains(searchLower);
      }).toList();
    }

    // Sorting
    filtered.sort((a, b) {
      int compare = 0;
      switch (_sortBy) {
        case 'name':
          compare = (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          );
          break;
      }
      return _sortAscending ? compare : -compare;
    });

    setState(() {
      _filteredSafeSpotTypesData = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _filterSafeSpotTypes();
    });
  }

  IconData _getIconData(String iconName) {
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
        return Icons.groups;
      case 'place':
        return Icons.place;
      case 'emergency':
        return Icons.emergency;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'gavel':
        return Icons.gavel;
      case 'business':
        return Icons.business;
      case 'apartment':
        return Icons.apartment;
      case 'store':
        return Icons.store;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'park':
        return Icons.park;
      default:
        return Icons.place;
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? safeSpotType}) {
    final isEdit = safeSpotType != null;
    final nameController = TextEditingController(
      text: safeSpotType?['name'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: safeSpotType?['description'] ?? '',
    );
    String selectedIcon = safeSpotType?['icon'] ?? 'place';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Safe Spot Type' : 'Add Safe Spot Type'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                      hintText: 'Enter unique safe spot type name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Icon *',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableIcons.map((icon) {
                      return DropdownMenuItem(
                        value: icon,
                        child: Row(
                          children: [
                            Icon(
                              _getIconData(icon),
                              size: 20,
                              color: const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 12),
                            Text(icon),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedIcon = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
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
              onPressed: () async {
                final trimmedName = nameController.text.trim();

                if (trimmedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }

                // Check for duplicate names (only for new entries or if name changed)
                if (!isEdit || safeSpotType['name'] != trimmedName) {
                  final isDuplicate = _safeSpotTypesData.any(
                    (st) =>
                        st['name'].toString().toLowerCase() ==
                            trimmedName.toLowerCase() &&
                        st['id'] != safeSpotType?['id'],
                  );

                  if (isDuplicate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Safe spot type "$trimmedName" already exists',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                try {
                  final data = {
                    'name': trimmedName,
                    'icon': selectedIcon,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  };

                  if (isEdit) {
                    await Supabase.instance.client
                        .from('safe_spot_types')
                        .update(data)
                        .eq('id', safeSpotType['id']);
                  } else {
                    await Supabase.instance.client
                        .from('safe_spot_types')
                        .insert(data);
                  }

                  Navigator.pop(context);
                  _loadSafeSpotTypes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Safe spot type updated successfully'
                            : 'Safe spot type added successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  String errorMessage = 'Error: $e';

                  if (e.toString().contains('duplicate key') ||
                      e.toString().contains('unique constraint')) {
                    errorMessage =
                        'Safe spot type name already exists. Please use a different name.';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> safeSpotType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Safe Spot Type'),
        content: Text(
          'Are you sure you want to delete "${safeSpotType['name']}"?\n\n'
          'This action cannot be undone and may affect related safe spots.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('safe_spot_types')
                    .delete()
                    .eq('id', safeSpotType['id']);

                Navigator.pop(context);
                _loadSafeSpotTypes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Safe spot type deleted successfully'),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting safe spot type: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        // Header with Add Button
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
                      hintText:
                          'Search safe spot types by name or description...',
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

              // Clear Filters
              if (_searchController.text.isNotEmpty)
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

              // Add Safe Spot Type Button
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Safe Spot Type'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
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
                : _filteredSafeSpotTypesData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 64,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No safe spot types found',
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
                              'Icon',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Name',
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
                        rows: _filteredSafeSpotTypesData.map((safeSpotType) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getIconData(
                                      safeSpotType['icon'] ?? 'place',
                                    ),
                                    color: const Color(0xFF6366F1),
                                    size: 24,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  safeSpotType['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  safeSpotType['description'] ??
                                      'No description',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _showAddEditDialog(
                                        safeSpotType: safeSpotType,
                                      ),
                                      tooltip: 'Edit',
                                      color: const Color(0xFF3B82F6),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () =>
                                          _showDeleteDialog(safeSpotType),
                                      tooltip: 'Delete',
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ],
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
          child: Row(
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
                      hintText: 'Search safe spot types...',
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
              const SizedBox(width: 8),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  tooltip: 'Add Safe Spot Type',
                ),
              ),
            ],
          ),
        ),

        // Safe Spot Types List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSafeSpotTypesData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No safe spot types found',
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
                  itemCount: _filteredSafeSpotTypesData.length,
                  itemBuilder: (context, index) {
                    return _buildSafeSpotTypeCard(
                      _filteredSafeSpotTypesData[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSafeSpotTypeCard(Map<String, dynamic> safeSpotType) {
    final safeSpotTypeId = safeSpotType['id'].toString();
    final isExpanded = _expandedCards.contains(safeSpotTypeId);

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
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(safeSpotTypeId);
                } else {
                  _expandedCards.add(safeSpotTypeId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(safeSpotType['icon'] ?? 'place'),
                      color: const Color(0xFF6366F1),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safe Spot Type Name
                        Text(
                          safeSpotType['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Footer
                        Row(
                          children: [
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFF6B7280),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isExpanded ? 'Show less' : 'Show more',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () =>
                            _showAddEditDialog(safeSpotType: safeSpotType),
                        tooltip: 'Edit',
                        color: const Color(0xFF3B82F6),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _showDeleteDialog(safeSpotType),
                        tooltip: 'Delete',
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isExpanded ? null : 0,
            child: isExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Description
                        if (safeSpotType['description'] != null &&
                            safeSpotType['description'].toString().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  safeSpotType['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Text(
                              'No description available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
