// lib/thread/thread_list_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'thread_models.dart';
import 'thread_service.dart';
import 'thread_detail_screen.dart';

class ThreadListScreen extends StatefulWidget {
  final String userId;
  final LatLng? userLocation;

  const ThreadListScreen({Key? key, required this.userId, this.userLocation})
    : super(key: key);

  @override
  State<ThreadListScreen> createState() => _ThreadListScreenState();
}

class _ThreadListScreenState extends State<ThreadListScreen> {
  final ThreadService _threadService = ThreadService();

  List<ReportThread> _threads = [];
  List<ReportThread> _filteredThreads = [];
  bool _isLoading = true;

  ThreadSortOption _currentSort = ThreadSortOption.recent;
  String _statusFilter = 'all'; // all, active, inactive
  String? _crimeTypeFilter;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _threadService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    print('📱 ThreadListScreen: Loading threads...');
    setState(() => _isLoading = true);

    try {
      // ✅ Use new method with unread info
      final threads = await _threadService.fetchThreadsWithUnreadInfo(
        userId: widget.userId,
        userLocation: widget.userLocation,
        statusFilter: _statusFilter,
        crimeTypeFilter: _crimeTypeFilter,
      );

      print('📱 ThreadListScreen: Received ${threads.length} threads');

      setState(() {
        _threads = threads;
        _applyFiltersAndSort();
        _isLoading = false;
      });

      print(
        '📱 ThreadListScreen: After filtering: ${_filteredThreads.length} threads',
      );
    } catch (e, stackTrace) {
      print('📱 ThreadListScreen: Error loading threads: $e');
      print('Stack: $stackTrace');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading threads: $e')));
      }
    }
  }

  void _setupRealtimeSubscription() {
    _threadService.subscribeToThreadUpdates((threads) {
      if (mounted) {
        setState(() {
          _threads = threads;
          _applyFiltersAndSort();
        });
      }
    });
  }

  void _applyFiltersAndSort() {
    _filteredThreads = List.from(_threads);

    // Apply search filter
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      _filteredThreads = _filteredThreads.where((thread) {
        return thread.title.toLowerCase().contains(searchTerm) ||
            thread.crimeType.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Apply sorting
    switch (_currentSort) {
      case ThreadSortOption.nearest:
        if (widget.userLocation != null) {
          _filteredThreads = _threadService.sortThreadsByDistance(
            _filteredThreads,
            widget.userLocation!,
          );
        }
        break;
      case ThreadSortOption.recent:
        _filteredThreads = _threadService.sortThreadsByRecent(_filteredThreads);
        break;
      case ThreadSortOption.mostActive:
        _filteredThreads = _threadService.sortThreadsByActivity(
          _filteredThreads,
        );
        break;
      case ThreadSortOption.crimeType:
        _filteredThreads.sort((a, b) => a.crimeType.compareTo(b.crimeType));
        break;
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSortOption(
              ThreadSortOption.recent,
              'Recent Activity',
              Icons.access_time,
            ),
            _buildSortOption(
              ThreadSortOption.nearest,
              'Nearest',
              Icons.near_me,
            ),
            _buildSortOption(
              ThreadSortOption.mostActive,
              'Most Active',
              Icons.forum,
            ),
            _buildSortOption(
              ThreadSortOption.crimeType,
              'Crime Type',
              Icons.category,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    ThreadSortOption option,
    String label,
    IconData icon,
  ) {
    final isSelected = _currentSort == option;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() {
          _currentSort = option;
          _applyFiltersAndSort();
        });
        Navigator.pop(context);
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Threads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All', _statusFilter == 'all', () {
                  setState(() => _statusFilter = 'all');
                  _loadThreads();
                  Navigator.pop(context);
                }),
                _buildFilterChip('Active', _statusFilter == 'active', () {
                  setState(() => _statusFilter = 'active');
                  _loadThreads();
                  Navigator.pop(context);
                }),
                _buildFilterChip('Inactive', _statusFilter == 'inactive', () {
                  setState(() => _statusFilter = 'inactive');
                  _loadThreads();
                  Navigator.pop(context);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Report Threads'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(icon: Icon(Icons.sort), onPressed: _showSortOptions),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search threads...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFiltersAndSort());
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() => _applyFiltersAndSort()),
            ),
          ),

          // Thread count and sort indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredThreads.length} threads',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  _getSortLabel(),
                  style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                ),
              ],
            ),
          ),

          // Thread list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredThreads.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadThreads,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredThreads.length,
                      itemBuilder: (context, index) {
                        final thread = _filteredThreads[index];
                        return _buildThreadCard(thread);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No threads found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Threads appear when crimes are reported',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadCard(ReportThread thread) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: thread.unreadCount > 0 ? 2 : 1, // ✅ Elevate unread threads
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // ✅ Navigate and refresh on return
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ThreadDetailScreen(thread: thread, userId: widget.userId),
            ),
          );

          // ✅ Refresh threads after returning
          _loadThreads();
        },
        child: Container(
          // ✅ Add indicator border for unread threads
          decoration: thread.unreadCount > 0
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Crime severity badge + status
                Row(
                  children: [
                    _buildSeverityBadge(thread.crimeLevel),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: thread.activeStatus == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        thread.activeStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: thread.activeStatus == 'active'
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // ✅ NEW: Unread badge
                    if (thread.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${thread.unreadCount} new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (thread.distanceFromUser != null) ...[
                      if (thread.unreadCount > 0) const SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${thread.distanceFromUser!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Title with bold indicator if unread
                Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: thread.unreadCount > 0
                        ? FontWeight
                              .w900 // ✅ Bolder if unread
                        : FontWeight.bold,
                    color: thread.unreadCount > 0
                        ? Colors.black
                        : Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Crime type and category
                Text(
                  '${thread.crimeType} • ${thread.crimeCategory}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    Icon(Icons.message, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.messageCount}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.participantCount}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getTimeAgo(thread.lastMessageAt ?? thread.createdAt),
                      style: TextStyle(
                        color: thread.unreadCount > 0
                            ? Colors
                                  .blue
                                  .shade600 // ✅ Blue if unread
                            : Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: thread.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
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

  Widget _buildSeverityBadge(String level) {
    Color color;
    switch (level.toLowerCase()) {
      case 'critical':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.yellow.shade700;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getSeverityTextColor(level, color),
        ),
      ),
    );
  }

  Color _getSeverityTextColor(String level, Color baseColor) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.red.shade800;
      case 'high':
        return Colors.orange.shade800;
      case 'medium':
        return Colors.yellow.shade800;
      case 'low':
        return Colors.green.shade800;
      default:
        return baseColor;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case ThreadSortOption.nearest:
        return 'Sorted by distance';
      case ThreadSortOption.recent:
        return 'Sorted by recent activity';
      case ThreadSortOption.mostActive:
        return 'Sorted by most active';
      case ThreadSortOption.crimeType:
        return 'Sorted by crime type';
    }
  }
}
