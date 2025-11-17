// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrimeTypesPage extends StatefulWidget {
  const CrimeTypesPage({super.key});

  @override
  State<CrimeTypesPage> createState() => _CrimeTypesPageState();
}

class _CrimeTypesPageState extends State<CrimeTypesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLevel = 'All Levels';
  String _selectedCategory = 'All Categories';
  final String _sortBy = 'name';
  final bool _sortAscending = true;

  List<Map<String, dynamic>> _crimeTypesData = [];
  List<Map<String, dynamic>> _filteredCrimeTypesData = [];
  List<String> _availableLevels = ['All Levels'];
  List<String> _availableCategories = ['All Categories'];
  bool _isLoading = true;
  bool _showFilters = false;

  final Set<String> _expandedCards = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCrimeTypes();
    _searchController.addListener(_filterCrimeTypes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCrimeTypes() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('crime_type')
          .select()
          .order('name', ascending: true);

      setState(() {
        _crimeTypesData = List<Map<String, dynamic>>.from(response);
        _filteredCrimeTypesData = _crimeTypesData;
        _extractFilterOptions();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading crime types: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading crime types: $e')),
        );
      }
    }
  }

  void _extractFilterOptions() {
    final levels = <String>{'All Levels'};
    final categories = <String>{'All Categories'};

    for (var crimeType in _crimeTypesData) {
      if (crimeType['level'] != null) {
        levels.add(crimeType['level']);
      }
      if (crimeType['category'] != null &&
          crimeType['category'].toString().isNotEmpty) {
        categories.add(crimeType['category']);
      }
    }

    setState(() {
      _availableLevels = levels.toList()..sort();
      _availableCategories = categories.toList()..sort();
    });
  }

  void _filterCrimeTypes() {
    List<Map<String, dynamic>> filtered = _crimeTypesData;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((crimeType) {
        final name = (crimeType['name'] ?? '').toString().toLowerCase();
        final description = (crimeType['description'] ?? '')
            .toString()
            .toLowerCase();
        final category = (crimeType['category'] ?? '').toString().toLowerCase();
        return name.contains(searchLower) ||
            description.contains(searchLower) ||
            category.contains(searchLower);
      }).toList();
    }

    // Level filter
    if (_selectedLevel != 'All Levels') {
      filtered = filtered
          .where((crimeType) => crimeType['level'] == _selectedLevel)
          .toList();
    }

    // Category filter
    if (_selectedCategory != 'All Categories') {
      filtered = filtered
          .where((crimeType) => crimeType['category'] == _selectedCategory)
          .toList();
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
        case 'level':
          final levelOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
          compare = (levelOrder[a['level']] ?? 4).compareTo(
            levelOrder[b['level']] ?? 4,
          );
          break;
        case 'category':
          compare = (a['category'] ?? '').toString().compareTo(
            (b['category'] ?? '').toString(),
          );
          break;
      }
      return _sortAscending ? compare : -compare;
    });

    setState(() {
      _filteredCrimeTypesData = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedLevel = 'All Levels';
      _selectedCategory = 'All Categories';
      _filterCrimeTypes();
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? crimeType}) {
    final isEdit = crimeType != null;
    final nameController = TextEditingController(
      text: crimeType?['name'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: crimeType?['description'] ?? '',
    );
    final categoryController = TextEditingController(
      text: crimeType?['category'] ?? '',
    );
    String selectedLevel = crimeType?['level'] ?? 'low';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Crime Type' : 'Add Crime Type'),
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
                      hintText: 'Enter unique crime type name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Level *',
                      border: OutlineInputBorder(),
                    ),
                    items: ['critical', 'high', 'medium', 'low'].map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getLevelColor(level),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(level.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedLevel = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Violent Crime, Property Crime',
                    ),
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
                if (!isEdit || crimeType['name'] != trimmedName) {
                  final isDuplicate = _crimeTypesData.any(
                    (ct) =>
                        ct['name'].toString().toLowerCase() ==
                            trimmedName.toLowerCase() &&
                        ct['id'] != crimeType?['id'],
                  );

                  if (isDuplicate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Crime type "$trimmedName" already exists',
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
                    'level': selectedLevel,
                    'category': categoryController.text.trim().isEmpty
                        ? null
                        : categoryController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  };

                  if (isEdit) {
                    await Supabase.instance.client
                        .from('crime_type')
                        .update(data)
                        .eq('id', crimeType['id']);
                  } else {
                    await Supabase.instance.client
                        .from('crime_type')
                        .insert(data);
                  }

                  Navigator.pop(context);
                  _loadCrimeTypes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Crime type updated successfully'
                            : 'Crime type added successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  String errorMessage = 'Error: $e';

                  // Handle specific error cases
                  if (e.toString().contains('duplicate key') ||
                      e.toString().contains('unique constraint')) {
                    errorMessage =
                        'Crime type name already exists. Please use a different name.';
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

  void _showDeleteDialog(Map<String, dynamic> crimeType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Crime Type'),
        content: Text(
          'Are you sure you want to delete "${crimeType['name']}"?\n\n'
          'This action cannot be undone and may affect related reports.',
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
                    .from('crime_type')
                    .delete()
                    .eq('id', crimeType['id']);

                Navigator.pop(context);
                _loadCrimeTypes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Crime type deleted successfully'),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting crime type: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
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
                          'Search crime types by name, category, or description...',
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

              // Level Filter
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
                    value: _selectedLevel,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    isExpanded: true,
                    items: _availableLevels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(
                          level,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLevel = value;
                          _filterCrimeTypes();
                        });
                      }
                    },
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
                    items: _availableCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                          _filterCrimeTypes();
                        });
                      }
                    },
                  ),
                ),
              ),

              // Clear Filters
              if (_searchController.text.isNotEmpty ||
                  _selectedLevel != 'All Levels' ||
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

              // Add Crime Type Button
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Crime Type'),
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
                : _filteredCrimeTypesData.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 64,
                          color: Color(0xFF9CA3AF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No crime types found',
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
                              'Level',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontSize: 14,
                              ),
                            ),
                          ),
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
                        rows: _filteredCrimeTypesData.map((crimeType) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  crimeType['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getLevelColor(
                                      crimeType['level'],
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getLevelColor(crimeType['level']),
                                    ),
                                  ),
                                  child: Text(
                                    (crimeType['level'] ?? '').toUpperCase(),
                                    style: TextStyle(
                                      color: _getLevelColor(crimeType['level']),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  crimeType['category'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  crimeType['description'] ?? 'No description',
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
                                        crimeType: crimeType,
                                      ),
                                      tooltip: 'Edit',
                                      color: const Color(0xFF3B82F6),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () =>
                                          _showDeleteDialog(crimeType),
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
                          hintText: 'Search crime types...',
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
                      color: _showFilters
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showFilters
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      icon: Icon(
                        Icons.tune,
                        color: _showFilters
                            ? Colors.white
                            : const Color(0xFF6B7280),
                        size: 20,
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
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Add Crime Type',
                    ),
                  ),
                ],
              ),

              // Filters
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showFilters ? 60 : 0,
                child: _showFilters
                    ? Container(
                        margin: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedLevel,
                                  underline: const SizedBox(),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                  ),
                                  isExpanded: true,
                                  items: _availableLevels.map((level) {
                                    return DropdownMenuItem(
                                      value: level,
                                      child: Text(
                                        level,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedLevel = value;
                                        _filterCrimeTypes();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  underline: const SizedBox(),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                  ),
                                  isExpanded: true,
                                  items: _availableCategories.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedCategory = value;
                                        _filterCrimeTypes();
                                      });
                                    }
                                  },
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
        ),

        // Crime Types List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCrimeTypesData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No crime types found',
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
                  itemCount: _filteredCrimeTypesData.length,
                  itemBuilder: (context, index) {
                    return _buildCrimeTypeCard(_filteredCrimeTypesData[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCrimeTypeCard(Map<String, dynamic> crimeType) {
    final crimeTypeId = crimeType['id'].toString();
    final isExpanded = _expandedCards.contains(crimeTypeId);

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
                  _expandedCards.remove(crimeTypeId);
                } else {
                  _expandedCards.add(crimeTypeId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Level Indicator
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getLevelColor(crimeType['level']),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor(
                              crimeType['level'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getLevelColor(
                                crimeType['level'],
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            (crimeType['level'] ?? '').toUpperCase(),
                            style: TextStyle(
                              color: _getLevelColor(crimeType['level']),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Crime Type Name
                        Text(
                          crimeType['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Category
                        if (crimeType['category'] != null)
                          Text(
                            crimeType['category'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
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
                            _showAddEditDialog(crimeType: crimeType),
                        tooltip: 'Edit',
                        color: const Color(0xFF3B82F6),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _showDeleteDialog(crimeType),
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
                        if (crimeType['description'] != null &&
                            crimeType['description'].toString().isNotEmpty)
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
                                  crimeType['description'],
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
