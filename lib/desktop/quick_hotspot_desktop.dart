import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for Clipboard
import 'package:latlong2/latlong.dart';
import 'package:zecure/quick_access/quick_hotspot_services.dart';

class HotspotQuickAccessDesktopWidgets {
  static String? get tempFilter => null;

  static String? get tempCrimeType => null;

  // Build hotspots list for desktop
  static Widget buildHotspotsList({
    required BuildContext context,
    required List<Map<String, dynamic>> hotspots,
    required String filter,
    required String sortBy,
    required String? selectedCrimeType,
    required LatLng? currentPosition,
    required Map<String, dynamic>? userProfile,
    required bool isAdmin,
    required Function(Map<String, dynamic>) onNavigateToHotspot,
    required Function(Map<String, dynamic>) onShowOnMap,
    required VoidCallback onClearFilters,
    required bool isSidebarVisible,
  }) {
    final filteredAndSortedHotspots =
        HotspotQuickAccessUtils.getFilteredAndSortedHotspots(
          hotspots: hotspots,
          filter: filter,
          sortBy: sortBy,
          selectedCrimeType: selectedCrimeType,
          currentPosition: currentPosition,
          userProfile: userProfile,
          isAdmin: isAdmin,
        );

    if (filteredAndSortedHotspots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              (filter != 'all' || selectedCrimeType != null)
                  ? 'No hotspots match your filters'
                  : 'No hotspots found nearby',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (filter != 'all' || selectedCrimeType != null)
              TextButton(
                onPressed: onClearFilters,
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
          color: Colors.red[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                filteredAndSortedHotspots.length.toString(),
                Icons.warning,
                Colors.red,
              ),
              _buildStatItem(
                'Nearest',
                filteredAndSortedHotspots.isNotEmpty && currentPosition != null
                    ? '${HotspotQuickAccessUtils.calculateDistance(currentPosition, LatLng(filteredAndSortedHotspots.first['location']['coordinates'][1], filteredAndSortedHotspots.first['location']['coordinates'][0])).toStringAsFixed(1)}km'
                    : 'N/A',
                Icons.near_me,
                Colors.orange,
              ),
              _buildStatItem(
                'Active',
                filteredAndSortedHotspots
                    .where(
                      (h) =>
                          h['status'] == 'approved' &&
                          (h['active_status'] ?? 'active') == 'active',
                    )
                    .length
                    .toString(),
                Icons.visibility,
                Colors.green,
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredAndSortedHotspots.length,
            itemBuilder: (context, index) {
              final hotspot = filteredAndSortedHotspots[index];
              return _buildHotspotCard(
                context: context,
                hotspot: hotspot,
                currentPosition: currentPosition,
                userProfile: userProfile,
                onNavigateToHotspot: onNavigateToHotspot,
                onShowOnMap: onShowOnMap,
                isSidebarVisible: isSidebarVisible,
              );
            },
          ),
        ),
      ],
    );
  }

  // Build stat item
  static Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // Build hotspot card
  static Widget _buildHotspotCard({
    required BuildContext context,
    required Map<String, dynamic> hotspot,
    required LatLng? currentPosition,
    required Map<String, dynamic>? userProfile,
    required Function(Map<String, dynamic>) onNavigateToHotspot,
    required Function(Map<String, dynamic>) onShowOnMap,
    required bool isSidebarVisible,
  }) {
    final coords = hotspot['location']['coordinates'];
    final hotspotLocation = LatLng(coords[1], coords[0]);
    final distance = currentPosition != null
        ? HotspotQuickAccessUtils.calculateDistance(
            currentPosition,
            hotspotLocation,
          )
        : 0.0;

    final statusInfo = HotspotQuickAccessUtils.getHotspotStatusInfo(hotspot);
    final crimeType = hotspot['crime_type'];
    final crimeTypeName = crimeType['name'] ?? 'Unknown Crime';
    final crimeCategory = crimeType['category'] ?? '';
    final description = hotspot['description'] ?? '';
    final currentUserId = userProfile?['id'];
    final createdBy = hotspot['created_by'];
    final reportedBy = hotspot['reported_by'];
    final isOwnHotspot =
        currentUserId != null &&
        (currentUserId == createdBy || currentUserId == reportedBy);

    final statusColor = statusInfo['color'] as Color;
    final statusIcon = statusInfo['icon'] as IconData;
    final statusText = statusInfo['text'] as String;

    // Format location for copying
    final fullLocation =
        '${hotspotLocation.latitude}, ${hotspotLocation.longitude}';

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
          onTap: () => onShowOnMap(hotspot),
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
                        HotspotQuickAccessUtils.getCrimeTypeIcon(crimeCategory),
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Crime type and category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crimeTypeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${crimeCategory.isNotEmpty ? crimeCategory : 'General'} ',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Distance and own hotspot indicator
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      currentPosition != null
                          ? '${distance.toStringAsFixed(1)} km away'
                          : 'Distance unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isOwnHotspot) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Your report',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
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
                    // Navigate button with warning
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Show warning dialog before navigation
                          _showDirectionsConfirmation(
                            context,
                            hotspotLocation,
                            () {
                              onNavigateToHotspot(hotspot);
                            },
                            isSidebarVisible: isSidebarVisible,
                          ); // Remove hardcoded true
                        },
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Navigate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Show on map button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onShowOnMap(hotspot),
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy location button
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullLocation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location copied to clipboard'),
                          ),
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

  // Warning dialog for navigation
  static void _showDirectionsConfirmation(
    BuildContext context,
    LatLng coordinates,
    VoidCallback onConfirm, {
    required bool isSidebarVisible,
  }) {
    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: isSidebarVisible ? 285 : 85,
            top: 100,
            child: Container(
              width: 450,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                contentPadding: EdgeInsets.zero, // Add this line
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade600,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Warning: Navigate to Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content Section
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are about to navigate to a reported crime location. This area may be unsafe. Please ensure you are taking necessary precautions before proceeding.',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.security,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Consider traveling in groups, informing others of your destination, and avoiding the area during nighttime.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Do you want to proceed with navigation?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Actions Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Proceed Anyway',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
          ),
        ],
      ),
    );
  }

  // Filter dialog method for desktop
  static void showHotspotFilterDialog({
    required BuildContext context,
    required String currentFilter,
    required String? selectedCrimeType,
    required List<Map<String, dynamic>> hotspots,
    required Map<String, dynamic>? userProfile,
    required Function(String filter, String? crimeType) onFilterChanged,
    required bool isSidebarVisible,
  }) {
    String tempFilter = currentFilter;
    String? tempCrimeType = selectedCrimeType;
    final availableTypes = HotspotQuickAccessUtils.getAvailableCrimeTypes(
      hotspots,
    );

    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          Positioned(
            left: isSidebarVisible ? 285 : 85,
            top: 100,
            child: Container(
              width: 450,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: AlertDialog(
                title: const Text('Filter Hotspots'),
                content: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status filters
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<String>(
                            title: const Text('All Hotspots'),
                            value: 'all',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Pending'),
                            value: 'pending',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Approved Only'),
                            value: 'approved',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Active Only'),
                            value: 'active',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Inactive'),
                            value: 'inactive',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Within 5km'),
                            value: 'nearby',
                            groupValue: tempFilter,
                            onChanged: (value) {
                              setDialogState(() {
                                tempFilter = value!;
                              });
                            },
                          ),
                          if (userProfile != null)
                            RadioListTile<String>(
                              title: const Text('My Reports'),
                              value: 'mine',
                              groupValue: tempFilter,
                              onChanged: (value) {
                                setDialogState(() {
                                  tempFilter = value!;
                                });
                              },
                            ),

                          // Crime Type filters
                          if (availableTypes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Crime Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioListTile<String?>(
                              title: const Text('All Types'),
                              value: null,
                              groupValue: tempCrimeType,
                              onChanged: (value) {
                                setDialogState(() {
                                  tempCrimeType = value;
                                });
                              },
                            ),
                            ...availableTypes.map(
                              (type) => RadioListTile<String>(
                                title: Text(type),
                                value: type,
                                groupValue: tempCrimeType,
                                onChanged: (value) {
                                  setDialogState(() {
                                    tempCrimeType = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      onFilterChanged(tempFilter, tempCrimeType);
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
}
