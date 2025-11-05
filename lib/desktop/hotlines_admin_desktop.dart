import 'package:flutter/material.dart';
import 'package:zecure/desktop/hotlines_desktop.dart';
import 'package:zecure/services/hotline_service.dart';


class HotlinesAdminDesktopModal extends StatefulWidget {
  final bool isSidebarVisible;
  final double sidebarWidth;

  const HotlinesAdminDesktopModal({
    super.key,
    this.isSidebarVisible = true,
    this.sidebarWidth = 280,
  });

  @override
  State<HotlinesAdminDesktopModal> createState() => _HotlinesAdminDesktopModalState();
}

class _HotlinesAdminDesktopModalState extends State<HotlinesAdminDesktopModal> {
  final HotlineService _hotlineService = HotlineService();
  List<Map<String, dynamic>> hotlines = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHotlines();
  }

Future<void> _loadHotlines() async {
  try {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Pass forceRefresh = true for admin modal to always get fresh data
    final data = await _hotlineService.fetchHotlineData(forceRefresh: true);

    setState(() {
      hotlines = data;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      errorMessage = 'Failed to load hotlines: $e';
      isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    final availableWidth = screenSize.width - (widget.isSidebarVisible ? widget.sidebarWidth : 0);
    final modalWidth = 520.0;
    final leftOffset = widget.isSidebarVisible ? widget.sidebarWidth : 0;
    final centerOffset = leftOffset + (availableWidth - modalWidth) / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        Positioned(
          left: centerOffset,
          top: 80,
          child: Container(
            width: modalWidth,
            height: screenSize.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: isLoading
                      ? _buildLoadingState()
                      : errorMessage != null
                          ? _buildErrorState()
                          : _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade500,
                Colors.orange.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Hotlines',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Color(0xFF1A1D29),
                ),
              ),
              Text(
                'Add, edit, or remove emergency contacts',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          onPressed: () {
            Navigator.pop(context); // Close admin modal
            showHotlinesModal(context,  // Open regular hotlines modal
              isSidebarVisible: widget.isSidebarVisible,
              sidebarWidth: widget.sidebarWidth,
            );
          },
        ),
      ],
    ),
  );
}

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading hotlines...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHotlines,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Category Button
          _buildAddCategoryButton(),
          
          const SizedBox(height: 16),
          
          // Categories list
          if (hotlines.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hotlines.length,
              itemBuilder: (context, index) {
                final category = hotlines[index];
                return _buildCategoryCard(category);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first hotline category',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCategoryDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Add New Category',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getCategoryColorFromString(category['color']).withOpacity(0.1),
                        _getCategoryColorFromString(category['color']).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getCategoryColorFromString(category['color']).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getIconFromString(category['icon']),
                    color: _getCategoryColorFromString(category['color']),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category['category'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (category['description'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          category['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      onPressed: () => _showCategoryDialog(category: category),
                      tooltip: 'Edit Category',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      onPressed: () => _confirmDeleteCategory(category['id']),
                      tooltip: 'Delete Category',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Direct Numbers
          if (category.containsKey('numbers') && (category['numbers'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Direct Numbers',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showNumberDialog(categoryId: category['id']),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Number'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...((category['numbers'] as List).map((number) => 
                    _buildNumberItem(number, category['id'])
                  )),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextButton.icon(
                onPressed: () => _showNumberDialog(categoryId: category['id']),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Direct Number'),
              ),
            ),
          ],
          
          // Stations
          if (category.containsKey('stations')) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showStationDialog(categoryId: category['id']),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Station'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildStationsList(category['stations'], category['id']),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextButton.icon(
                onPressed: () => _showStationDialog(categoryId: category['id']),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Station'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildStationsList(List stations, int categoryId) {
    return stations.map<Widget>((station) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.blue.shade600, size: 18),
                      onPressed: () => _showNumberDialog(
                        categoryId: categoryId,
                        stationId: station['id'],
                      ),
                      tooltip: 'Add Number',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600, size: 18),
                      onPressed: () => _showStationDialog(
                        categoryId: categoryId,
                        station: station,
                      ),
                      tooltip: 'Edit Station',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
                      onPressed: () => _confirmDeleteStation(station['id']),
                      tooltip: 'Delete Station',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ],
            ),
            if ((station['numbers'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              ...((station['numbers'] as List).map((number) => 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        number,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              )),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildNumberItem(Map<String, dynamic> number, int categoryId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  number['number'],
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600, size: 18),
                onPressed: () => _showNumberDialog(
                  categoryId: categoryId,
                  number: number,
                ),
                tooltip: 'Edit',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
                onPressed: () => _confirmDeleteNumber(number['id']),
                tooltip: 'Delete',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

 // Replace all dialog methods in hotlines_admin_desktop.dart with these:

// 0. CATEGORY DIALOG - Add/Update (Desktop)
void _showCategoryDialog({Map<String, dynamic>? category}) {
  final nameController = TextEditingController(text: category?['category']);
  final descController = TextEditingController(text: category?['description']);
  String selectedIcon = category?['icon'] ?? 'contact_phone_rounded';
  String selectedColor = category?['color'] ?? 'blue_600';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                decoration: const InputDecoration(
                  labelText: 'Icon',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'warning_rounded',
                  'local_hospital_rounded',
                  'security_rounded',
                  'local_police_rounded',
                  'local_fire_department_rounded',
                  'shield_rounded',
                  'contact_phone_rounded',
                ].map((icon) => DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(_getIconFromString(icon), size: 20),
                      const SizedBox(width: 8),
                      Text(icon.replaceAll('_', ' ').toUpperCase()),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedIcon = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'orange_600',
                  'pink_600',
                  'indigo_600',
                  'blue_600',
                  'deepOrange_600',
                  'purple_600',
                  'grey_600',
                ].map((color) => DropdownMenuItem(
                  value: color,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getCategoryColorFromString(color),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(color.replaceAll('_', ' ').toUpperCase()),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedColor = value!);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
                return;
              }

              try {
                if (category == null) {
                  // Create new category
                  final newCategory = await _hotlineService.createCategory(
                    name: nameController.text,
                    description: descController.text.isEmpty ? null : descController.text,
                    icon: selectedIcon,
                    color: selectedColor,
                  );
                  
                  // OPTIMISTIC UPDATE: Add to TOP
                  if (mounted) {
                    setState(() {
                      hotlines.insert(0, {
                        'id': newCategory['id'],
                        'category': nameController.text,
                        'description': descController.text.isEmpty ? null : descController.text,
                        'icon': selectedIcon,
                        'color': selectedColor,
                        'numbers': [],
                        'stations': [],
                      });
                    });
                  }
                } else {
                  // Update existing category
                  await _hotlineService.updateCategory(
                    id: category['id'],
                    name: nameController.text,
                    description: descController.text.isEmpty ? null : descController.text,
                    icon: selectedIcon,
                    color: selectedColor,
                  );
                  
                  // OPTIMISTIC UPDATE: Update in place
                  if (mounted) {
                    setState(() {
                      final index = hotlines.indexWhere((c) => c['id'] == category['id']);
                      if (index != -1) {
                        hotlines[index]['category'] = nameController.text;
                        hotlines[index]['description'] = descController.text.isEmpty ? null : descController.text;
                        hotlines[index]['icon'] = selectedIcon;
                        hotlines[index]['color'] = selectedColor;
                      }
                    });
                  }
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(category == null ? 'Category added' : 'Category updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                  _loadHotlines();
                }
              }
            },
            child: Text(category == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    ),
  );
}

// 1. STATION DIALOG - Add/Update (Desktop)
void _showStationDialog({required int categoryId, Map<String, dynamic>? station}) {
  final nameController = TextEditingController(text: station?['name']);
  final descController = TextEditingController(text: station?['description']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(station == null ? 'Add Station' : 'Edit Station'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Station Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a station name')),
              );
              return;
            }

            try {
              if (station == null) {
                // Create new station
                final newStation = await _hotlineService.createStation(
                  categoryId: categoryId,
                  name: nameController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                );
                
                // OPTIMISTIC UPDATE: Add to TOP
                if (mounted) {
                  setState(() {
                    final categoryIndex = hotlines.indexWhere((cat) => cat['id'] == categoryId);
                    if (categoryIndex != -1) {
                      if (!hotlines[categoryIndex].containsKey('stations')) {
                        hotlines[categoryIndex]['stations'] = [];
                      }
                      (hotlines[categoryIndex]['stations'] as List).insert(0, {
                        'id': newStation['id'],
                        'name': nameController.text,
                        'description': descController.text.isEmpty ? null : descController.text,
                        'numbers': [],
                      });
                    }
                  });
                }
              } else {
                // Update existing station
                await _hotlineService.updateStation(
                  id: station['id'],
                  name: nameController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                );
                
                // OPTIMISTIC UPDATE: Update in place
                if (mounted) {
                  setState(() {
                    for (var category in hotlines) {
                      if (category.containsKey('stations')) {
                        final stations = category['stations'] as List;
                        final stationIndex = stations.indexWhere((s) => s['id'] == station['id']);
                        if (stationIndex != -1) {
                          stations[stationIndex]['name'] = nameController.text;
                          stations[stationIndex]['description'] = descController.text.isEmpty ? null : descController.text;
                          break;
                        }
                      }
                    }
                  });
                }
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(station == null ? 'Station added' : 'Station updated')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                _loadHotlines();
              }
            }
          },
          child: Text(station == null ? 'Add' : 'Update'),
        ),
      ],
    ),
  );
}

// 2. DELETE STATION (Desktop)
void _confirmDeleteStation(int id) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Station'),
      content: const Text('Are you sure you want to delete this station? This will also delete all associated numbers.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await _hotlineService.deleteStation(id);
              
              // OPTIMISTIC UPDATE: Remove immediately
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  for (var category in hotlines) {
                    if (category.containsKey('stations')) {
                      (category['stations'] as List).removeWhere((s) => s['id'] == id);
                    }
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Station deleted')),
                );
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                _loadHotlines();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// 3. NUMBER DIALOG - Add/Update (Desktop)
void _showNumberDialog({
  required int categoryId,
  int? stationId,
  Map<String, dynamic>? number,
}) {
  final nameController = TextEditingController(text: number?['name']);
  final phoneController = TextEditingController(text: number?['number']);
  final descController = TextEditingController(text: number?['description']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(number == null ? 'Add Number' : 'Edit Number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.isEmpty || phoneController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill in all required fields')),
              );
              return;
            }

            try {
              if (number == null) {
                // Create new number
                final newNumber = await _hotlineService.createNumber(
                  categoryId: stationId == null ? categoryId : null,
                  stationId: stationId,
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                );
                
                // OPTIMISTIC UPDATE: Add to TOP
                if (mounted) {
                  setState(() {
                    if (stationId != null) {
                      // Add to station (at top)
                      for (var category in hotlines) {
                        if (category.containsKey('stations')) {
                          final stations = category['stations'] as List;
                          final station = stations.firstWhere(
                            (s) => s['id'] == stationId,
                            orElse: () => null,
                          );
                          if (station != null) {
                            (station['numbers'] as List).insert(0, phoneController.text);
                            break;
                          }
                        }
                      }
                    } else {
                      // Add to category direct numbers (at top)
                      final categoryIndex = hotlines.indexWhere((cat) => cat['id'] == categoryId);
                      if (categoryIndex != -1) {
                        if (!hotlines[categoryIndex].containsKey('numbers')) {
                          hotlines[categoryIndex]['numbers'] = [];
                        }
                        (hotlines[categoryIndex]['numbers'] as List).insert(0, {
                          'id': newNumber['id'],
                          'name': nameController.text,
                          'number': phoneController.text,
                          'description': descController.text.isEmpty ? null : descController.text,
                        });
                      }
                    }
                  });
                }
              } else {
                // Update existing number
                await _hotlineService.updateNumber(
                  id: number['id'],
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                );
                
                // OPTIMISTIC UPDATE: Update in place
                if (mounted) {
                  setState(() {
                    for (var category in hotlines) {
                      if (category.containsKey('numbers')) {
                        final numbers = category['numbers'] as List;
                        final numberIndex = numbers.indexWhere((n) => n['id'] == number['id']);
                        if (numberIndex != -1) {
                          numbers[numberIndex]['name'] = nameController.text;
                          numbers[numberIndex]['number'] = phoneController.text;
                          numbers[numberIndex]['description'] = descController.text.isEmpty ? null : descController.text;
                          break;
                        }
                      }
                    }
                  });
                }
              }

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(number == null ? 'Number added' : 'Number updated')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                _loadHotlines();
              }
            }
          },
          child: Text(number == null ? 'Add' : 'Update'),
        ),
      ],
    ),
  );
}

// 4. DELETE NUMBER (Desktop)
void _confirmDeleteNumber(int id) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Number'),
      content: const Text('Are you sure you want to delete this number?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await _hotlineService.deleteNumber(id);
              
              // OPTIMISTIC UPDATE: Remove immediately
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  for (var category in hotlines) {
                    if (category.containsKey('numbers')) {
                      (category['numbers'] as List).removeWhere((n) => n['id'] == id);
                    }
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Number deleted')),
                );
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                _loadHotlines();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// 5. DELETE CATEGORY (Desktop)
void _confirmDeleteCategory(int id) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Category'),
      content: const Text('Are you sure you want to delete this category? This will also delete all associated stations and numbers.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await _hotlineService.deleteCategory(id);
              
              // OPTIMISTIC UPDATE: Remove immediately
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  hotlines.removeWhere((cat) => cat['id'] == id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category deleted')),
                );
              }
            } catch (e) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                _loadHotlines();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

  // Helper methods
  IconData _getIconFromString(String iconName) {
    final icons = {
      'warning_rounded': Icons.warning_rounded,
      'local_hospital_rounded': Icons.local_hospital_rounded,
      'security_rounded': Icons.security_rounded,
      'local_police_rounded': Icons.local_police_rounded,
      'local_fire_department_rounded': Icons.local_fire_department_rounded,
      'shield_rounded': Icons.shield_rounded,
      'contact_phone_rounded': Icons.contact_phone_rounded,
    };
    return icons[iconName] ?? Icons.contact_phone_rounded;
  }

  Color _getCategoryColorFromString(String colorName) {
    final colors = {
      'orange_600': Colors.orange.shade600,
      'pink_600': Colors.pink.shade600,
      'indigo_600': Colors.indigo.shade600,
      'blue_600': Colors.blue.shade600,
      'deepOrange_600': Colors.deepOrange.shade600,
      'purple_600': Colors.purple.shade600,
      'grey_600': Colors.grey.shade600,
    };
    return colors[colorName] ?? Colors.grey.shade600;
  }
}

// Function to show the admin modal
void showHotlinesAdminModal(BuildContext context, {bool isSidebarVisible = true, double sidebarWidth = 285}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (BuildContext context) {
      return HotlinesAdminDesktopModal(
        isSidebarVisible: isSidebarVisible,
        sidebarWidth: sidebarWidth,
      );
    },
  );
}