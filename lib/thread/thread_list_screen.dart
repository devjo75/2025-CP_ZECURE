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

  const ThreadListScreen({super.key, required this.userId, this.userLocation});

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

          // ✅ NEW: Sectioned Thread list (Unread/Read)
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredThreads.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadThreads,
                    child: _buildSectionedThreadList(),
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

  // lib/thread/thread_list_screen.dart
  // REPLACE _buildSectionedThreadList method:

  Widget _buildSectionedThreadList() {
    // ✅ FIXED: Three categories now
    // 1. NEW - User hasn't joined yet (!isFollowing)
    // 2. UNREAD - User joined AND has unread messages (isFollowing && unreadCount > 0)
    // 3. READ - User joined AND no unread messages (isFollowing && unreadCount == 0)

    final newThreads = _filteredThreads.where((t) => !t.isFollowing).toList();

    final unreadThreads = _filteredThreads
        .where((t) => t.isFollowing && t.unreadCount > 0)
        .toList();

    final readThreads = _filteredThreads
        .where((t) => t.isFollowing && t.unreadCount == 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      children: [
        // ✅ NEW THREADS SECTION (not joined)
        if (newThreads.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
            child: Row(
              children: [
                Text(
                  'New Threads (${newThreads.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'NOT JOINED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...newThreads.map((thread) => _buildNewThreadCard(thread)),
          if (unreadThreads.isNotEmpty || readThreads.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[300], thickness: 1),
            ),
            const SizedBox(height: 8),
          ],
        ],

        // ✅ UNREAD SECTION (joined + has unread)
        if (unreadThreads.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
            child: Row(
              children: [
                Text(
                  'Unread (${unreadThreads.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...unreadThreads.map((thread) => _buildUnreadThreadCard(thread)),
          if (readThreads.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[300], thickness: 1),
            ),
            const SizedBox(height: 8),
          ],
        ],

        // ✅ READ SECTION (joined + no unread)
        if (readThreads.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
            child: Text(
              'Earlier',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...readThreads.map((thread) => _buildReadThreadCard(thread)),
        ],
      ],
    );
  }

  // ✅ NEW: Add method for NEW threads (orange theme)
  Widget _buildNewThreadCard(ReportThread thread) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ThreadDetailScreen(thread: thread, userId: widget.userId),
              ),
            );
            _loadThreads();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Orange dot indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orange[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    // NEW badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  thread.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Crime info
                Text(
                  '${thread.crimeType} • ${thread.crimeCategory}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    Icon(
                      Icons.message,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.messageCount}',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.participantCount}',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getTimeAgo(thread.lastMessageAt ?? thread.createdAt),
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  // ✅ NEW: Unread thread card (blue background, prominent styling)
  Widget _buildUnreadThreadCard(ReportThread thread) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ThreadDetailScreen(thread: thread, userId: widget.userId),
              ),
            );
            _loadThreads();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Blue dot indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    // Unread count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${thread.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  thread.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Crime info
                Text(
                  '${thread.crimeType} • ${thread.crimeCategory}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    Icon(Icons.message, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.messageCount}',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${thread.participantCount}',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getTimeAgo(thread.lastMessageAt ?? thread.createdAt),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  // ✅ NEW: Read thread card (white background, normal styling)
  Widget _buildReadThreadCard(ReportThread thread) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ThreadDetailScreen(thread: thread, userId: widget.userId),
              ),
            );
            _loadThreads();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
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
                    if (thread.distanceFromUser != null)
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
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  thread.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Crime info
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
                        color: Colors.grey.shade500,
                        fontSize: 12,
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
