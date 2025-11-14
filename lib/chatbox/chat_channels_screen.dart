import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_model.dart';
import 'chat_service.dart';
import 'chat_room_screen.dart';
import 'create_channel_screen.dart';

class ChatChannelsScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const ChatChannelsScreen({super.key, required this.userProfile});

  @override
  State<ChatChannelsScreen> createState() => _ChatChannelsScreenState();
}

class _ChatChannelsScreenState extends State<ChatChannelsScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late TabController _tabController;

  List<ChatChannel> _joinedChannels = [];
  List<ChatChannel> _availableChannels = [];
  bool _isLoading = true;

  RealtimeChannel? _channelSubscription;
  RealtimeChannel? _messageSubscription; // ✅ ADD THIS

  @override
  void initState() {
    super.initState();
    print('📱 MOBILE ChatChannelsScreen initState');
    _tabController = TabController(length: 2, vsync: this);
    _loadChannels();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channelSubscription?.unsubscribe();
    _messageSubscription?.unsubscribe(); // ✅ ADD THIS
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    print('🔔 Setting up realtime subscriptions...');

    // Subscribe to channel changes (new channels, etc.)
    _channelSubscription = _chatService.subscribeToChannels(() {
      print('📢 Channel update detected, reloading channels...');
      _loadChannels();
    });

    // ✅ NEW: Subscribe to ALL new messages to update unread counts
    _messageSubscription = _chatService.subscribeToAllMessages(() {
      print('📩 New message detected, refreshing unread counts...');
      _refreshUnreadCounts();
    });
  }

  // ✅ NEW METHOD: Only refresh unread counts, don't reload everything
  Future<void> _refreshUnreadCounts() async {
    final userId = widget.userProfile['id'] as String;

    // Update unread counts for joined channels only
    for (var channel in _joinedChannels) {
      final unreadCount = await _chatService.getUnreadCount(channel.id, userId);
      if (mounted) {
        setState(() {
          channel.unreadCount = unreadCount;
        });
      }
    }
    print('✅ Unread counts refreshed');
  }

  Future<void> _loadChannels() async {
    print('📥 Loading channels...');
    setState(() => _isLoading = true);

    final userId = widget.userProfile['id'] as String;

    // Load joined channels
    final joined = await _chatService.getJoinedChannels(userId);

    // Load all channels
    final all = await _chatService.getAllChannels();

    // Filter out joined channels from available
    final available = all.where((channel) {
      return !joined.any((j) => j.id == channel.id);
    }).toList();

    // Load unread counts for joined channels
    for (var channel in joined) {
      channel.unreadCount = await _chatService.getUnreadCount(
        channel.id,
        userId,
      );
    }

    if (mounted) {
      setState(() {
        _joinedChannels = joined;
        _availableChannels = available;
        _isLoading = false;
      });
      print(
        '✅ Loaded ${joined.length} joined channels, ${available.length} available',
      );
    }
  }

  Future<void> _joinChannel(ChatChannel channel) async {
    final userId = widget.userProfile['id'] as String;

    final success = await _chatService.joinChannel(channel.id, userId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${channel.name}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadChannels();
    }
  }

  Future<void> _leaveChannel(ChatChannel channel) async {
    final userId = widget.userProfile['id'] as String;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Channel?'),
        content: Text('Are you sure you want to leave ${channel.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _chatService.leaveChannel(channel.id, userId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left ${channel.name}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadChannels();
      }
    }
  }

  void _openChannel(ChatChannel channel) {
    print('🚪 Opening channel: ${channel.name}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomScreen(channel: channel, userProfile: widget.userProfile),
      ),
    ).then((_) {
      print('🔙 Returned from chat room, refreshing unread counts...');
      _refreshUnreadCounts(); // ✅ Only refresh counts, not full reload
    });
  }

  void _createChannel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateChannelScreen(userProfile: widget.userProfile),
      ),
    ).then((_) => _loadChannels()); // Full reload for new channel
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Community Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'My Channels'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildJoinedChannels(), _buildAvailableChannels()],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChannel,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildJoinedChannels() {
    if (_joinedChannels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No channels yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a channel or create your own',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _joinedChannels.length,
        itemBuilder: (context, index) {
          final channel = _joinedChannels[index];
          return _buildChannelCard(channel, isJoined: true);
        },
      ),
    );
  }

  Widget _buildAvailableChannels() {
    if (_availableChannels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No available channels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to create one!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableChannels.length,
        itemBuilder: (context, index) {
          final channel = _availableChannels[index];
          return _buildChannelCard(channel, isJoined: false);
        },
      ),
    );
  }

  Widget _buildChannelCard(ChatChannel channel, {required bool isJoined}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isJoined ? () => _openChannel(channel) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Channel icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getChannelColor(
                        channel.channelType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        channel.channelIcon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Channel info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                channel.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isJoined &&
                                channel.unreadCount != null &&
                                channel.unreadCount! > 0)
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
                                  channel.unreadCount! > 99
                                      ? '99+'
                                      : '${channel.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${channel.memberCount} members',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (channel.channelType == 'barangay' &&
                                channel.barangay != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  channel.barangay!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  const SizedBox(width: 8),
                  if (isJoined)
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(
                                Icons.exit_to_app,
                                size: 20,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Leave Channel',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ],
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _leaveChannel(channel),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _joinChannel(channel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Join',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),

              // Description
              if (channel.description != null &&
                  channel.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  channel.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getChannelColor(String type) {
    switch (type) {
      case 'barangay':
        return Colors.green;
      case 'city_wide':
        return Colors.blue;
      case 'custom':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
