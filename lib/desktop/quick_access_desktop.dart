import 'dart:math' show sin, cos, sqrt, atan2;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:latlong2/latlong.dart';
import 'quick_hotspot_desktop.dart';

class QuickAccessDesktopScreen extends StatefulWidget {
  final List<Map<String, dynamic>> safeSpots;
  final List<Map<String, dynamic>> hotspots;
  final LatLng? currentPosition;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final Function(LatLng) onGetDirections;
  final Function(LatLng) onGetSafeRoute;
  final Function(LatLng) onShareLocation;
  final Function(Map<String, dynamic>) onShowOnMap;
  final Function(Map<String, dynamic>) onNavigateToSafeSpot;
  final Function(Map<String, dynamic>) onNavigateToHotspot;
  final VoidCallback onRefresh;
  final bool isSidebarVisible;
  final VoidCallback onClose;

  const QuickAccessDesktopScreen({
    Key? key,
    required this.safeSpots,
    required this.hotspots,
    required this.currentPosition,
    required this.userProfile,
    required this.isAdmin,
    required this.onGetDirections,
    required this.onGetSafeRoute,
    required this.onShareLocation,
    required this.onShowOnMap,
    required this.onNavigateToSafeSpot,
    required this.onNavigateToHotspot,
    required this.onRefresh,
    required this.isSidebarVisible,
    required this.onClose,
  }) : super(key: key);

  @override
  State<QuickAccessDesktopScreen> createState() => _QuickAccessDesktopScreenState();
}

class _QuickAccessDesktopScreenState extends State<QuickAccessDesktopScreen> {
  bool _showingSafeSpots = true;
  String _quickAccessFilter = 'all';
  String _quickAccessSortBy = 'distance';
  String? _selectedSafeSpotType;
  String _hotspotFilter = 'all';
  String _hotspotSortBy = 'distance';
  String? _selectedCrimeType;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.isSidebarVisible ? 285 : 85,
      top: 100,
      child: GestureDetector(
        onTap: () {},
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withOpacity(0.2),
          child: Container(
            width: 450,
            height: 800,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Toggle between Safe Spots and Hotspots
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Safe Spot Toggle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showingSafeSpots = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _showingSafeSpots ? Colors.blue : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.security,
                                      size: 18,
                                      color: _showingSafeSpots ? Colors.white : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Safe Spot',
                                      style: TextStyle(
                                        color: _showingSafeSpots ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Hotspot Toggle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showingSafeSpots = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_showingSafeSpots ? Colors.red : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      size: 18,
                                      color: !_showingSafeSpots ? Colors.white : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Hotspot',
                                      style: TextStyle(
                                        color: !_showingSafeSpots ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Filter button with indicator
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(Icons.filter_list),
                                  if (_hasActiveFilters())
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: _showFilterDialog,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Sort button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _showingSafeSpots ? _quickAccessSortBy : _hotspotSortBy,
                            items: _showingSafeSpots
                                ? _getSafeSpotsMenuItems()
                                : _getHotspotsMenuItems(),
                            onChanged: (value) {
                              setState(() {
                                if (_showingSafeSpots) {
                                  _quickAccessSortBy = value ?? 'distance';
                                } else {
                                  _hotspotSortBy = value ?? 'distance';
                                }
                              });
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: widget.currentPosition == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Getting your location...'),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            widget.onRefresh();
                          },
child: _showingSafeSpots
    ? _buildSafeSpotsList()
    : HotspotQuickAccessDesktopWidgets.buildHotspotsList(
        context: context,
        hotspots: widget.hotspots,
        filter: _hotspotFilter,
        sortBy: _hotspotSortBy,
        selectedCrimeType: _selectedCrimeType,
        currentPosition: widget.currentPosition,
        userProfile: widget.userProfile,
        isAdmin: widget.isAdmin,
        onNavigateToHotspot: widget.onNavigateToHotspot,
        onShowOnMap: widget.onShowOnMap,
        onClearFilters: () {
          setState(() {
            _hotspotFilter = 'all';
            _selectedCrimeType = null;
          });
        },
        isSidebarVisible: widget.isSidebarVisible,
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

  bool _hasActiveFilters() {
    if (_showingSafeSpots) {
      return _quickAccessFilter != 'all' || _selectedSafeSpotType != null;
    } else {
      return _hotspotFilter != 'all' || _selectedCrimeType != null;
    }
  }

  void _showFilterDialog() {
    if (_showingSafeSpots) {
      _showSafeSpotsFilterDialog();
    } else {
      HotspotQuickAccessDesktopWidgets.showHotspotFilterDialog(
        context: context,
        currentFilter: _hotspotFilter,
        selectedCrimeType: _selectedCrimeType,
        hotspots: widget.hotspots,
        userProfile: widget.userProfile,
        onFilterChanged: (filter, crimeType) {
          setState(() {
            _hotspotFilter = filter;
            _selectedCrimeType = crimeType;
          });
        },
        isSidebarVisible: widget.isSidebarVisible,
      );
    }
  }

  List<DropdownMenuItem<String>> _getSafeSpotsMenuItems() {
    return const [
      DropdownMenuItem(
        value: 'distance',
        child: Row(
          children: [
            Icon(Icons.near_me, size: 14),
            SizedBox(width: 4),
            Text('Distance'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'name',
        child: Row(
          children: [
            Icon(Icons.sort_by_alpha, size: 14),
            SizedBox(width: 4),
            Text('Name'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'type',
        child: Row(
          children: [
            Icon(Icons.category, size: 14),
            SizedBox(width: 4),
            Text('Type'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'status',
        child: Row(
          children: [
            Icon(Icons.verified, size: 14),
            SizedBox(width: 4),
            Text('Status'),
          ],
        ),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _getHotspotsMenuItems() {
    return const [
      DropdownMenuItem(
        value: 'distance',
        child: Row(
          children: [
            Icon(Icons.near_me, size: 14),
            SizedBox(width: 4),
            Text('Distance'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'crime_type',
        child: Row(
          children: [
            Icon(Icons.category, size: 14),
            SizedBox(width: 4),
            Text('Type'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'severity',
        child: Row(
          children: [
            Icon(Icons.priority_high, size: 14),
            SizedBox(width: 4),
            Text('Severity'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'status',
        child: Row(
          children: [
            Icon(Icons.verified, size: 14),
            SizedBox(width: 4),
            Text('Status'),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'date',
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14),
            SizedBox(width: 4),
            Text('Date'),
          ],
        ),
      ),
    ];
  }

  Widget _buildSafeSpotsList() {
    final filteredAndSortedSafeSpots = _getFilteredAndSortedSafeSpots();

    if (filteredAndSortedSafeSpots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              (_quickAccessFilter != 'all' || _selectedSafeSpotType != null)
                  ? 'No safe spots match your filters'
                  : 'No safe spots found nearby',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_quickAccessFilter != 'all' || _selectedSafeSpotType != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _quickAccessFilter = 'all';
                    _selectedSafeSpotType = null;
                  });
                },
                child: const Text('Clear Filters'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                filteredAndSortedSafeSpots.length.toString(),
                Icons.location_pin,
                Colors.blue,
              ),
              _buildStatItem(
                'Nearest',
                filteredAndSortedSafeSpots.isNotEmpty
                    ? '${_calculateDistance(widget.currentPosition!, LatLng(filteredAndSortedSafeSpots.first['location']['coordinates'][1], filteredAndSortedSafeSpots.first['location']['coordinates'][0])).toStringAsFixed(1)}km'
                    : 'N/A',
                Icons.near_me,
                Colors.green,
              ),
              _buildStatItem(
                'Verified',
                filteredAndSortedSafeSpots.where((s) => s['verified'] == true).length.toString(),
                Icons.verified,
                Colors.orange,
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredAndSortedSafeSpots.length,
            itemBuilder: (context, index) {
              final safeSpot = filteredAndSortedSafeSpots[index];
              return _buildSafeSpotCard(safeSpot);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSafeSpotCard(Map<String, dynamic> safeSpot) {
    final coords = safeSpot['location']['coordinates'];
    final safeSpotLocation = LatLng(coords[1], coords[0]);
    final distance = _calculateDistance(widget.currentPosition!, safeSpotLocation);
    final status = safeSpot['status'] ?? 'pending';
    final verified = safeSpot['verified'] ?? false;
    final safeSpotType = safeSpot['safe_spot_types'];
    final safeSpotName = safeSpot['name'] ?? 'Safe Spot';
    final description = safeSpot['description'] ?? '';
    final currentUserId = widget.userProfile?['id'];
    final createdBy = safeSpot['created_by'];
    final isOwnSpot = currentUserId != null && currentUserId == createdBy;

    // Format location for copying
    final fullLocation = '${safeSpotLocation.latitude}, ${safeSpotLocation.longitude}';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
      case 'approved':
        statusColor = verified ? Colors.green : Colors.blue;
        statusIcon = verified ? Icons.verified : Icons.check_circle;
        statusText = verified ? 'Verified' : 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onShowOnMap(safeSpot),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconFromString(safeSpotType['icon']),
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            safeSpotName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            safeSpotType['name'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Description
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Distance and own spot indicator
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isOwnSpot) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Your spot',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Action buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onGetSafeRoute(safeSpotLocation);
                        },
                        icon: const Icon(Icons.safety_check, size: 18),
                        label: const Text('Safe Route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onShowOnMap(safeSpot),
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullLocation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSafeSpotsFilterDialog() {
    final availableTypes = _getAvailableSafeSpotTypes();

    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: widget.isSidebarVisible ? 285 : 85,
            top: 100,
            child: Container(
              width: 450,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: AlertDialog(
                title: const Text('Filter Safe Spots'),
                content: StatefulBuilder(
                  builder: (context, setDialogState) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          title: const Text('All Safe Spots'),
                          value: 'all',
                          groupValue: _quickAccessFilter,
                          onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Pending'),
                          value: 'pending',
                          groupValue: _quickAccessFilter,
                          onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Approved Only'),
                          value: 'approved',
                          groupValue: _quickAccessFilter,
                          onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Verified Only'),
                          value: 'verified',
                          groupValue: _quickAccessFilter,
                          onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Within 5km'),
                          value: 'nearby',
                          groupValue: _quickAccessFilter,
                          onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                        ),
                        if (widget.userProfile != null)
                          RadioListTile<String>(
                            title: const Text('My Safe Spots'),
                            value: 'mine',
                            groupValue: _quickAccessFilter,
                            onChanged: (value) => setDialogState(() => _quickAccessFilter = value!),
                          ),
                        if (availableTypes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Safe Spot Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<String?>(
                            title: const Text('All Types'),
                            value: null,
                            groupValue: _selectedSafeSpotType,
                            onChanged: (value) => setDialogState(() => _selectedSafeSpotType = value),
                          ),
                          ...availableTypes.map((type) => RadioListTile<String>(
                                title: Text(type),
                                value: type,
                                groupValue: _selectedSafeSpotType,
                                onChanged: (value) => setDialogState(() => _selectedSafeSpotType = value),
                              )).toList(),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {}); // Trigger rebuild with new filter
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableSafeSpotTypes() {
    final Set<String> types = {};
    for (final safeSpot in widget.safeSpots) {
      final typeName = safeSpot['safe_spot_types']?['name'];
      if (typeName != null) {
        types.add(typeName);
      }
    }
    return types.toList()..sort();
  }

  List<Map<String, dynamic>> _getFilteredAndSortedSafeSpots() {
    List<Map<String, dynamic>> filtered = widget.safeSpots.where((safeSpot) {
      final status = safeSpot['status'] ?? 'pending';
      final verified = safeSpot['verified'] ?? false;
      final currentUserId = widget.userProfile?['id'];
      final createdBy = safeSpot['created_by'];
      final isOwnSpot = currentUserId != null && currentUserId == createdBy;
      final safeSpotTypeName = safeSpot['safe_spot_types']?['name'];

      if (widget.isAdmin) {
        // Admin sees everything
      } else {
        if (status == 'approved') {
          // Show approved to everyone
        } else if (status == 'pending' && currentUserId != null) {
          // Show pending to authenticated users
        } else if (isOwnSpot && status == 'rejected') {
          // Show own rejected spots
        } else {
          return false;
        }
      }

      switch (_quickAccessFilter) {
        case 'pending':
          if (status != 'pending') return false;
          break;
        case 'approved':
          if (status != 'approved') return false;
          break;
        case 'verified':
          if (status != 'approved' || !verified) return false;
          break;
        case 'nearby':
          if (widget.currentPosition == null) return false;
          final coords = safeSpot['location']['coordinates'];
          final distance = _calculateDistance(
            widget.currentPosition!,
            LatLng(coords[1], coords[0]),
          );
          if (distance > 5.0) return false;
          break;
        case 'mine':
          if (!isOwnSpot) return false;
          break;
        case 'all':
        default:
          break;
      }

      if (_selectedSafeSpotType != null && safeSpotTypeName != _selectedSafeSpotType) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_quickAccessSortBy) {
        case 'distance':
          if (widget.currentPosition == null) return 0;
          final distanceA = _calculateDistance(
            widget.currentPosition!,
            LatLng(a['location']['coordinates'][1], a['location']['coordinates'][0]),
          );
          final distanceB = _calculateDistance(
            widget.currentPosition!,
            LatLng(b['location']['coordinates'][1], b['location']['coordinates'][0]),
          );
          return distanceA.compareTo(distanceB);
        case 'name':
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        case 'type':
          return (a['safe_spot_types']['name'] ?? '')
              .compareTo(b['safe_spot_types']['name'] ?? '');
        case 'status':
          final statusOrder = {'approved': 0, 'pending': 1, 'rejected': 2};
          final statusA = statusOrder[a['status']] ?? 3;
          final statusB = statusOrder[b['status']] ?? 3;
          final statusCompare = statusA.compareTo(statusB);
          if (statusCompare != 0) return statusCompare;
          if (a['status'] == 'approved' && b['status'] == 'approved') {
            final verifiedA = a['verified'] ?? false;
            final verifiedB = b['verified'] ?? false;
            return verifiedB ? 1 : (verifiedA ? -1 : 0);
          }
          return 0;
        default:
          return 0;
      }
    });

    return filtered;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  IconData _getIconFromString(String iconName) {
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
        return Icons.group;
      default:
        return Icons.place;
    }
  }
}