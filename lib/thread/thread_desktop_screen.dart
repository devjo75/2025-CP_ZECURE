// lib/thread/thread_desktop_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:zecure/thread/thread_list_screen.dart';
import 'thread_models.dart';
import 'thread_service.dart';
import 'thread_detail_screen.dart';
import 'package:intl/intl.dart';

class ThreadDesktopScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final LatLng? userLocation;

  const ThreadDesktopScreen({
    Key? key,
    required this.userProfile,
    this.userLocation,
  }) : super(key: key);

  @override
  State<ThreadDesktopScreen> createState() => _ThreadDesktopScreenState();
}

class _ThreadDesktopScreenState extends State<ThreadDesktopScreen> {
  final ThreadService _threadService = ThreadService();
  final TextEditingController _searchController = TextEditingController();

  List<ReportThread> _threads = [];
  List<ReportThread> _filteredThreads = [];
  ReportThread? _selectedThread;
  bool _isLoading = true;

  ThreadSortOption _currentSort = ThreadSortOption.recent;
  String _statusFilter = 'all';
  String? _crimeTypeFilter;

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
    setState(() => _isLoading = true);

    try {
      final threads = await _threadService.fetchThreadsWithUnreadInfo(
        userId: widget.userProfile['id'] as String,
        userLocation: widget.userLocation,
        statusFilter: _statusFilter,
        crimeTypeFilter: _crimeTypeFilter,
      );

      setState(() {
        _threads = threads;
        _applyFiltersAndSort();
        _isLoading = false;

        // Auto-select first thread if available
        if (_selectedThread == null && _filteredThreads.isNotEmpty) {
          _selectedThread = _filteredThreads.first;
        }
      });
    } catch (e) {
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

    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      _filteredThreads = _filteredThreads.where((thread) {
        return thread.title.toLowerCase().contains(searchTerm) ||
            thread.crimeType.toLowerCase().contains(searchTerm);
      }).toList();
    }

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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
    String tempStatusFilter =
        _statusFilter; // Temporary variable for dialog state

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // ✅ Use StatefulBuilder
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      'Filter Threads',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Status Filter Section
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Status Options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChipOption(
                      label: 'All',
                      isSelected: tempStatusFilter == 'all',
                      onTap: () {
                        setDialogState(() {
                          // ✅ Update dialog state
                          tempStatusFilter = 'all';
                        });
                      },
                    ),
                    _buildFilterChipOption(
                      label: 'Active',
                      isSelected: tempStatusFilter == 'active',
                      onTap: () {
                        setDialogState(() {
                          // ✅ Update dialog state
                          tempStatusFilter = 'active';
                        });
                      },
                    ),
                    _buildFilterChipOption(
                      label: 'Inactive',
                      isSelected: tempStatusFilter == 'inactive',
                      onTap: () {
                        setDialogState(() {
                          // ✅ Update dialog state
                          tempStatusFilter = 'inactive';
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = 'all';
                          _crimeTypeFilter = null;
                        });
                        _loadThreads();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Reset',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // ✅ Apply to main state
                          _statusFilter = tempStatusFilter;
                        });
                        _loadThreads();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Apply'),
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

  Widget _buildFilterChipOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    // Mobile view - use the regular ThreadListScreen
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Threads'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: ThreadListScreen(
          userId: widget.userProfile['id'] as String,
          userLocation: widget.userLocation,
        ),
      );
    }

    // Desktop view - split panel layout
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Threads'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Row(
        children: [
          // Left Panel - Thread List
          SizedBox(
            width: 400,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Search and filters
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search threads...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _applyFiltersAndSort());
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          onChanged: (_) =>
                              setState(() => _applyFiltersAndSort()),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_filteredThreads.length} threads',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.filter_list, size: 20),
                              onPressed: _showFilterOptions,
                              tooltip: 'Filter',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.sort, size: 20),
                              onPressed: _showSortOptions,
                              tooltip: 'Sort',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Thread list
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredThreads.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _filteredThreads.length,
                            itemBuilder: (context, index) {
                              final thread = _filteredThreads[index];
                              final isSelected =
                                  _selectedThread?.id == thread.id;
                              return _buildThreadListItem(thread, isSelected);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Right Panel - Thread Detail
          Expanded(
            child: _selectedThread == null
                ? _buildNoSelectionState()
                : ThreadDetailScreen(
                    thread: _selectedThread!,
                    userId: widget.userProfile['id'] as String,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadListItem(ReportThread thread, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(
            color: isSelected ? Colors.blue.shade600 : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedThread = thread),
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
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: thread.activeStatus == 'active'
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      thread.activeStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: thread.activeStatus == 'active'
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (thread.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${thread.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                thread.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: thread.unreadCount > 0
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Crime info
              Text(
                '${thread.crimeType} • ${thread.crimeCategory}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 8),

              // Stats
              Row(
                children: [
                  Icon(Icons.message, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${thread.messageCount}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${thread.participantCount}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _getTimeAgo(thread.lastMessageAt ?? thread.createdAt),
                    style: TextStyle(
                      color: thread.unreadCount > 0
                          ? Colors.blue.shade600
                          : Colors.grey.shade500,
                      fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No threads found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a thread to view details',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd').format(dateTime);
  }
}
