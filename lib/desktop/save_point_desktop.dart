import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../savepoint/save_point_service.dart';

class SavePointDesktopScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final LatLng? currentPosition;
  final Function(LatLng) onNavigateToPoint;
  final Function(Map<String, dynamic>) onShowOnMap;
  final Function(LatLng) onGetSafeRoute;
  final VoidCallback onUpdate;
  final bool isSidebarVisible;
  final VoidCallback onClose;

  const SavePointDesktopScreen({
    super.key,
    required this.userProfile,
    required this.currentPosition,
    required this.onNavigateToPoint,
    required this.onShowOnMap,
    required this.onGetSafeRoute,
    required this.onUpdate,
    required this.isSidebarVisible,
    required this.onClose,
  });

  @override
  State<SavePointDesktopScreen> createState() => _SavePointDesktopScreenState();
}

class _SavePointDesktopScreenState extends State<SavePointDesktopScreen> {
  final SavePointService _savePointService = SavePointService();
  List<Map<String, dynamic>> _savePoints = [];
  bool _isLoading = true;
  String? _error;
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
      _error = null;
    });

    try {
      final savePoints = await _savePointService.getUserSavePoints(
        widget.userProfile!['id'],
      );

      if (mounted) {
        setState(() {
          _savePoints = savePoints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

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
                _buildHeader(),
                _buildSearchBar(),
                _buildStatsHeader(),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bookmark_rounded,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Save Points',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Manage your saved locations',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.search, color: Colors.grey[800]),
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 18),
                    SizedBox(width: 8),
                    Text('Distance'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'created_at',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18),
                    SizedBox(width: 8),
                    Text('Date Created'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isSearchBarVisible ? 64 : 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: TextStyle(color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final filteredAndSorted = _getFilteredAndSortedSavePoints();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total',
            filteredAndSorted.length.toString(),
            Icons.bookmark,
            Colors.blue,
          ),
          _buildStatItem(
            'Nearest',
            filteredAndSorted.isNotEmpty && widget.currentPosition != null
                ? '${_calculateDistance(widget.currentPosition!, _extractLatLng(filteredAndSorted.first)).toStringAsFixed(1)}km'
                : 'N/A',
            Icons.near_me,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading save points...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading save points',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSavePoints,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildSavePointsList(),
    );
  }

  Widget _buildSavePointsList() {
    final filteredAndSorted = _getFilteredAndSortedSavePoints();

    if (filteredAndSorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.bookmark_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No save points found'
                  : 'No save points yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Create your first save point\nby long-pressing on the map',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavePoints,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredAndSorted.length,
        itemBuilder: (context, index) {
          return _buildSavePointCard(filteredAndSorted[index]);
        },
      ),
    );
  }

  Widget _buildStatItem(
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

  Widget _buildSavePointCard(Map<String, dynamic> savePoint) {
    final location = _extractLatLng(savePoint);
    final distance = widget.currentPosition != null
        ? _calculateDistance(widget.currentPosition!, location)
        : 0.0;
    final name = savePoint['name'] ?? 'Unnamed Save Point';
    final description = savePoint['description'] ?? '';
    final createdAt = DateTime.tryParse(savePoint['created_at'] ?? '');
    final fullLocation = '${location.latitude}, ${location.longitude}';

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
          onTap: () => widget.onShowOnMap(savePoint),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (createdAt != null)
                            Text(
                              'Added ${_formatDate(createdAt)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
                // Distance
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.near_me, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      widget.currentPosition != null
                          ? distance < 1
                                ? '${(distance * 1000).toStringAsFixed(0)} m away'
                                : '${distance.toStringAsFixed(1)} km away'
                          : 'Distance unavailable',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Action buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onGetSafeRoute(location);
                        },
                        icon: const Icon(Icons.safety_check, size: 16),
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
                          widget.onShowOnMap(savePoint);
                        },
                        icon: const Icon(Icons.map, size: 16),
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

  List<Map<String, dynamic>> _getFilteredAndSortedSavePoints() {
    var filtered = _savePoints.where((savePoint) {
      if (_searchQuery.isEmpty) return true;

      final name = savePoint['name']?.toString().toLowerCase() ?? '';
      final description =
          savePoint['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'distance':
          if (widget.currentPosition == null) return 0;
          final distanceA = _calculateDistance(
            widget.currentPosition!,
            _extractLatLng(a),
          );
          final distanceB = _calculateDistance(
            widget.currentPosition!,
            _extractLatLng(b),
          );
          return distanceA.compareTo(distanceB);
        case 'name':
          return (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          );
        case 'created_at':
          final dateA =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final dateB =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA); // Most recent first
        default:
          return 0;
      }
    });

    return filtered;
  }

  LatLng _extractLatLng(Map<String, dynamic> savePoint) {
    final coordinates = savePoint['location']['coordinates'];
    return LatLng(coordinates[1], coordinates[0]);
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;

    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad =
        (point2.longitude - point1.longitude) * (math.pi / 180);

    double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }
}
