import 'dart:math' show sin, cos, sqrt, atan2;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// Import your existing widgets/classes as needed
// import '../widgets/safe_spot_details.dart';

class QuickAccessScreen extends StatefulWidget {
  final List<Map<String, dynamic>> safeSpots;
  final LatLng? currentPosition;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final Function(LatLng) onGetDirections;
  final Function(LatLng) onGetSafeRoute;
  final Function(LatLng) onShareLocation;
  final Function(Map<String, dynamic>) onShowOnMap;
  final Function(Map<String, dynamic>) onNavigateToSafeSpot; // New callback for pure navigation
  final VoidCallback onRefresh;

  const QuickAccessScreen({
    Key? key,
    required this.safeSpots,
    required this.currentPosition,
    required this.userProfile,
    required this.isAdmin,
    required this.onGetDirections,
    required this.onGetSafeRoute,
    required this.onShareLocation,
    required this.onShowOnMap,
    required this.onNavigateToSafeSpot,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<QuickAccessScreen> createState() => _QuickAccessScreenState();
}

class _QuickAccessScreenState extends State<QuickAccessScreen> {
  String _quickAccessFilter = 'all';
  String _quickAccessSortBy = 'distance';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Safe Access'),
        actions: [
          // Filter button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_quickAccessFilter != 'all')
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
            onPressed: _showQuickAccessFilterDialog,
          ),
          // Sort button
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _quickAccessSortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 18),
                    SizedBox(width: 8),
                    Text('Distance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'type',
                child: Row(
                  children: [
                    Icon(Icons.category, size: 18),
                    SizedBox(width: 8),
                    Text('Type'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 18),
                    SizedBox(width: 8),
                    Text('Status'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: widget.currentPosition == null 
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
            child: _buildSafeSpotsList(),
          ),
      // Removed FloatingActionButton for "Add Safe Spot"
    );
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
              _quickAccessFilter == 'all' 
                ? 'No safe spots found nearby' 
                : 'No safe spots match your filter',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_quickAccessFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _quickAccessFilter = 'all';
                  });
                },
                child: const Text('Clear Filter'),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
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
                // Navigate button - pure navigation without details dialog
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Use the new callback for pure navigation
                      widget.onNavigateToSafeSpot(safeSpot);
                    },
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Show on map button (includes details dialog)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onShowOnMap(safeSpot),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Show on Map'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // More options button
                IconButton(
                  onPressed: () => _showSafeSpotOptions(safeSpot),
                  icon: const Icon(Icons.more_vert),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show more options for safe spot
  void _showSafeSpotOptions(Map<String, dynamic> safeSpot) {
    final coords = safeSpot['location']['coordinates'];
    final safeSpotLocation = LatLng(coords[1], coords[0]);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Removed "View Details" since it's included in "Show on Map"
          ListTile(
            leading: const Icon(Icons.safety_check, color: Colors.green),
            title: const Text('Get Safe Route'),
            subtitle: const Text('Route avoiding crime hotspots'),
            onTap: () {
              Navigator.pop(context);
              widget.onGetSafeRoute(safeSpotLocation);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Location'),
            onTap: () {
              Navigator.pop(context);
              widget.onShareLocation(safeSpotLocation);
            },
          ),
        ],
      ),
    );
  }

  // Filter dialog for quick access
  void _showQuickAccessFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Safe Spots'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('All Safe Spots'),
                value: 'all',
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
            ],
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
    );
  }

  // Get filtered and sorted safe spots
  List<Map<String, dynamic>> _getFilteredAndSortedSafeSpots() {
    List<Map<String, dynamic>> filtered = widget.safeSpots.where((safeSpot) {
      final status = safeSpot['status'] ?? 'pending';
      final verified = safeSpot['verified'] ?? false;
      final currentUserId = widget.userProfile?['id'];
      final createdBy = safeSpot['created_by'];
      final isOwnSpot = currentUserId != null && currentUserId == createdBy;
      
      // Base visibility rules (same as map)
      if (widget.isAdmin) {
        // Admin sees everything, apply filter on top
      } else {
        if (status == 'approved') {
          // Show approved to everyone
        } else if (status == 'pending' && currentUserId != null) {
          // Show pending to authenticated users for voting
        } else if (isOwnSpot && status == 'rejected') {
          // Show own rejected spots
        } else {
          return false; // Hide everything else
        }
      }
      
      // Apply additional filters
      switch (_quickAccessFilter) {
        case 'approved':
          return status == 'approved';
        case 'verified':
          return status == 'approved' && verified;
        case 'nearby':
          if (widget.currentPosition == null) return false;
          final coords = safeSpot['location']['coordinates'];
          final distance = _calculateDistance(
            widget.currentPosition!, 
            LatLng(coords[1], coords[0])
          );
          return distance <= 5.0; // Within 5km
        case 'mine':
          return isOwnSpot;
        case 'all':
        default:
          return true;
      }
    }).toList();
    
    // Sort the filtered results
    filtered.sort((a, b) {
      switch (_quickAccessSortBy) {
        case 'distance':
          if (widget.currentPosition == null) return 0;
          final distanceA = _calculateDistance(
            widget.currentPosition!, 
            LatLng(a['location']['coordinates'][1], a['location']['coordinates'][0])
          );
          final distanceB = _calculateDistance(
            widget.currentPosition!, 
            LatLng(b['location']['coordinates'][1], b['location']['coordinates'][0])
          );
          return distanceA.compareTo(distanceB);
        
        case 'name':
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        
        case 'type':
          return (a['safe_spot_types']['name'] ?? '').compareTo(b['safe_spot_types']['name'] ?? '');
        
        case 'status':
          final statusOrder = {'approved': 0, 'pending': 1, 'rejected': 2};
          final statusA = statusOrder[a['status']] ?? 3;
          final statusB = statusOrder[b['status']] ?? 3;
          final statusCompare = statusA.compareTo(statusB);
          if (statusCompare != 0) return statusCompare;
          
          // If same status, sort verified first within approved
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

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * 
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Helper method to convert string to IconData
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