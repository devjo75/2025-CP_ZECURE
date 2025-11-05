import 'package:flutter/material.dart';
import 'package:zecure/services/hotline_service.dart';

class HotlinesAdminScreen extends StatefulWidget {
  const HotlinesAdminScreen({super.key});

  @override
  State<HotlinesAdminScreen> createState() => _HotlinesAdminScreenState();
}

class _HotlinesAdminScreenState extends State<HotlinesAdminScreen> {
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

    // Pass forceRefresh = true for admin screen to always get fresh data
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LIGHT.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC).withOpacity(0.2),
          ),
          child: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  pinned: false,
                  floating: false,
                  expandedHeight: 0,
                  flexibleSpace: Container(),
                  title: const Text(
                    'Manage Hotlines',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.8,
                      color: Color(0xFF1A1D29),
                    ),
                  ),
                  foregroundColor: const Color(0xFF1A1D29),
                  centerTitle: false,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Color(0xFF6B7280),
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadHotlines,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ];
            },
            body: isLoading
                ? _buildLoadingState()
                : errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ),
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 20),
                _buildAddCategoryButton(),
              ],
            ),
          ),
        ),
        if (hotlines.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = hotlines[index];
                return _buildCategoryCard(category);
              },
              childCount: hotlines.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 92, 118, 165),
            Color.fromARGB(255, 61, 91, 131),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Admin Panel',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage Contacts',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBadge(Icons.edit_rounded, 'Edit Mode'),
              const SizedBox(width: 12),
              _buildBadge(Icons.admin_panel_settings, 'Admin'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          iconColor: Colors.grey[400],
          collapsedIconColor: Colors.grey[400],
          title: Row(
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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showCategoryDialog(category: category);
                  } else if (value == 'delete') {
                    _confirmDeleteCategory(category['id']);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Category'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete Category', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            // Direct Numbers Section
            if (category.containsKey('numbers') && (category['numbers'] as List).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
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
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
              ...((category['numbers'] as List).map((number) => 
                _buildNumberItem(number, category['id'])
              )),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _showNumberDialog(categoryId: category['id']),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Direct Number'),
                ),
              ),
            ],
            
            // Stations Section
            if (category.containsKey('stations') && (category['stations'] as List).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Divider(color: Colors.grey.shade200),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
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
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
              ..._buildStationsList(category['stations'], category['id']),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Divider(color: Colors.grey.shade200),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _showStationDialog(categoryId: category['id']),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Station'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStationsList(List stations, int categoryId) {
    return stations.map<Widget>((station) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
                  onSelected: (value) {
                    if (value == 'add_number') {
                      _showNumberDialog(
                        categoryId: categoryId,
                        stationId: station['id'],
                      );
                    } else if (value == 'edit') {
                      _showStationDialog(
                        categoryId: categoryId,
                        station: station,
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteStation(station['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_number',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 12),
                          Text('Add Number'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Edit Station'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete Station', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if ((station['numbers'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              ...((station['numbers'] as List).map((number) => 
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          number,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _showNumberDialog(
                  categoryId: categoryId,
                  number: number,
                );
              } else if (value == 'delete') {
                _confirmDeleteNumber(number['id']);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dialog methods
 // Replace all your dialog methods with these optimized versions:
// NEW ITEMS NOW APPEAR AT THE TOP!

// 0. CATEGORY DIALOG - Add/Update
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
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
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
                  isExpanded: true,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getIconFromString(icon), size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            icon.replaceAll('_', ' ').toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
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
                  isExpanded: true,
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
                      mainAxisSize: MainAxisSize.min,
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
                        Flexible(
                          child: Text(
                            color.replaceAll('_', ' ').toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
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
                  
                  // OPTIMISTIC UPDATE: Add to TOP of list
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
                  // On error, reload to ensure consistency
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

// 1. STATION DIALOG - Add/Update
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
                
                // OPTIMISTIC UPDATE: Add to TOP of stations list
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

// 2. DELETE STATION
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

// 3. NUMBER DIALOG - Add/Update
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
      content: SingleChildScrollView(
        child: Column(
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

// 4. DELETE NUMBER
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

// 5. DELETE CATEGORY
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