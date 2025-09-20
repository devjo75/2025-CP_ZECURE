import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'save_point_service.dart';

class SavePointScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final LatLng? currentPosition;
  final Function(LatLng) onNavigateToPoint;
  final Function(Map<String, dynamic>)? onShowOnMap;
  final Function(LatLng)? onGetSafeRoute;
  final VoidCallback onUpdate;

  const SavePointScreen({
    super.key,
    required this.userProfile,
    required this.currentPosition,
    required this.onNavigateToPoint,
    this.onShowOnMap,
    this.onGetSafeRoute,
    required this.onUpdate,
  });

  @override
  State<SavePointScreen> createState() => _SavePointScreenState();
}

class _SavePointScreenState extends State<SavePointScreen> {
  final SavePointService _savePointService = SavePointService();
  List<Map<String, dynamic>> _savePoints = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'distance';
  bool _isSearchBarVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavePoints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavePoints() async {
    if (widget.userProfile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final points = await _savePointService.getUserSavePoints(
        widget.userProfile!['id'],
      );

      if (mounted) {
        setState(() {
          _savePoints = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading save points: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSavePoints {
    var filtered = _savePoints.where((point) {
      final name = (point['name'] ?? '').toString().toLowerCase();
      final description = (point['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'distance':
          if (widget.currentPosition == null) return 0;
          final distanceA = _calculateDistance(
            widget.currentPosition!,
            LatLng(
              a['location']['coordinates'][1],
              a['location']['coordinates'][0],
            ),
          );
          final distanceB = _calculateDistance(
            widget.currentPosition!,
            LatLng(
              b['location']['coordinates'][1],
              b['location']['coordinates'][0],
            ),
          );
          return distanceA.compareTo(distanceB);
        case 'name':
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        case 'date':
          final dateA = DateTime.parse(a['created_at']);
          final dateB = DateTime.parse(b['created_at']);
          return dateB.compareTo(dateA);
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
        cos(lat1Rad) * cos(lat2Rad) *
            sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }


  Widget _buildSavePointCard(Map<String, dynamic> savePoint) {
    final coords = savePoint['location']['coordinates'];
    final createdAt = DateTime.parse(savePoint['created_at']);
    final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final savePointLocation = LatLng(coords[1], coords[0]);
    final fullLocation = '${coords[1]}, ${coords[0]}';
    final distance = widget.currentPosition != null
        ? _calculateDistance(widget.currentPosition!, savePointLocation)
        : double.infinity;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bookmark,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        savePoint['name'] ?? 'Unnamed Save Point',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Added on $formattedDate',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (savePoint['description'] != null &&
                savePoint['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                savePoint['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.near_me, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  widget.currentPosition != null
                      ? distance < 1
                          ? '${(distance * 1000).toStringAsFixed(0)} m away'
                          : '${distance.toStringAsFixed(1)} km away'
                      : 'Distance unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
Expanded(
  child: ElevatedButton.icon(
    onPressed: widget.onGetSafeRoute != null
        ? () {
            Navigator.of(context).pop();
            widget.onGetSafeRoute!(savePointLocation);
          }
        : () => widget.onNavigateToPoint(savePointLocation),
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
    onPressed: () {
      if (widget.onShowOnMap != null) {
        Navigator.of(context).pop();
        widget.onShowOnMap!(savePoint);
      } else {
        widget.onNavigateToPoint(savePointLocation);
        Navigator.of(context).pop();
      }
    },
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
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _getSortMenuItems() {
    return [
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
        value: 'date',
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18),
            SizedBox(width: 8),
            Text('Date Created'),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Save Points',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.search, color: Colors.grey.shade800),
                if (_isSearchBarVisible || _searchQuery.isNotEmpty)
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
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
                if (!_isSearchBarVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                const Icon(Icons.sort),
                if (_sortBy != 'distance')
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
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => _getSortMenuItems(),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search save points...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ),
            crossFadeState:
                _isSearchBarVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  _filteredSavePoints.length.toString(),
                  Icons.bookmark,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Nearest',
                  _filteredSavePoints.isNotEmpty && widget.currentPosition != null
                      ? '${_calculateDistance(widget.currentPosition!, LatLng(_filteredSavePoints.first['location']['coordinates'][1], _filteredSavePoints.first['location']['coordinates'][0])).toStringAsFixed(1)}km'
                      : 'N/A',
                  Icons.near_me,
                  Colors.green,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSavePoints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.bookmark_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No save points found'
                                  : 'No save points yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Create your first save point\nby long-pressing on the map',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSavePoints,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredSavePoints.length,
                          itemBuilder: (context, index) {
                            return _buildSavePointCard(_filteredSavePoints[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
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
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}