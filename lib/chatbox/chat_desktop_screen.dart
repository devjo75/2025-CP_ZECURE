import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/chatbox/create_channel_desktop_dialog.dart';
import 'chat_model.dart';
import 'chat_service.dart';

class ChatDesktopScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const ChatDesktopScreen({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<ChatDesktopScreen> createState() => _ChatDesktopScreenState();
}

class _ChatDesktopScreenState extends State<ChatDesktopScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  List<ChatChannel> _joinedChannels = [];
  List<ChatChannel> _availableChannels = [];
  List<ChatMessage> _messages = [];
  
  ChatChannel? _selectedChannel;
  bool _isLoadingChannels = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  
  RealtimeChannel? _channelSubscription;
  RealtimeChannel? _messageSubscription;
  
  String? _replyToMessageId;
  ChatMessage? _replyToMessage;
  Map<String, ChatMessage> _repliedMessages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChannels();
    _setupChannelSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _channelSubscription?.unsubscribe();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupChannelSubscription() {
    _channelSubscription = _chatService.subscribeToChannels(() {
      _loadChannels();
    });
  }

void _setupMessageSubscription() {
  _messageSubscription?.unsubscribe();
  
  if (_selectedChannel != null) {
    _messageSubscription = _chatService.subscribeToMessages(
      _selectedChannel!.id,
      (message, event) {
        print('📨 Message change received: ${event.toString().split('.').last} - ${message.message}');
        if (mounted) {
          setState(() {
            if (event == PostgresChangeEvent.insert) {
              _messages.add(message);
            } else if (event == PostgresChangeEvent.update) {
              // Find and replace the existing message (for edits or deletes)
              final index = _messages.indexWhere((m) => m.id == message.id);
              if (index != -1) {
                _messages[index] = message;
              }
            }
          });
          
          // Fetch replied message if this is a reply
          if (message.replyToMessageId != null) {
            _fetchRepliedMessage(message.replyToMessageId!);
          }
          
          _scrollToBottom();
          _markAsRead();
        }
      },
    );
  }
}

  Future<void> _fetchRepliedMessage(String messageId) async {
  // Check if already cached
  if (_repliedMessages.containsKey(messageId)) {
    return;
  }

  // Try to find in current messages first
  final localMessage = _messages.firstWhere(
    (msg) => msg.id == messageId,
    orElse: () => ChatMessage(
      id: '',
      channelId: '',
      userId: '',
      message: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isEdited: false,
      isDeleted: false,
    ),
  );

  if (localMessage.id.isNotEmpty) {
    setState(() {
      _repliedMessages[messageId] = localMessage;
    });
    return;
  }

  // Fetch from database if not found locally
  final message = await _chatService.getMessageById(messageId);
  
  if (message != null && mounted) {
    setState(() {
      _repliedMessages[messageId] = message;
    });
  }
}



 Future<void> _loadChannels() async {
  setState(() => _isLoadingChannels = true);

  final userId = widget.userProfile['id'] as String;

  final joined = await _chatService.getJoinedChannels(userId);
  final all = await _chatService.getAllChannels();
  
  final available = all.where((channel) {
    return !joined.any((j) => j.id == channel.id);
  }).toList();

  for (var channel in joined) {
    channel.unreadCount = await _chatService.getUnreadCount(channel.id, userId);
  }

  if (mounted) {
    setState(() {
      _joinedChannels = joined;
      _availableChannels = available;
      _isLoadingChannels = false;
      
      // ✅ REMOVED AUTO-SELECT - Don't automatically select and mark as read!
      // User should manually select a channel to view it
    });
  }
}

  Future<void> _selectChannel(ChatChannel channel) async {
    setState(() {
      _selectedChannel = channel;
      _isLoadingMessages = true;
      _messages = [];
      _replyToMessageId = null;
      _replyToMessage = null;
    });

    _setupMessageSubscription();
    await _loadMessages();
    _markAsRead();
  }

  Future<void> _loadMessages() async {
    if (_selectedChannel == null) return;

    final messages = await _chatService.getMessages(_selectedChannel!.id, limit: 100);

    if (mounted) {
      setState(() {
        _messages = messages.reversed.toList();
        _isLoadingMessages = false;
      });

          final replyIds = messages
        .where((msg) => msg.replyToMessageId != null)
        .map((msg) => msg.replyToMessageId!)
        .toSet();
    
    for (final replyId in replyIds) {
      _fetchRepliedMessage(replyId);
    }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _markAsRead() async {
    if (_selectedChannel == null) return;
    
    final userId = widget.userProfile['id'] as String;
    await _chatService.updateLastRead(_selectedChannel!.id, userId);
    
    // Update unread count
    setState(() {
      final index = _joinedChannels.indexWhere((ch) => ch.id == _selectedChannel!.id);
      if (index != -1) {
        _joinedChannels[index].unreadCount = 0;
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty || _isSending || _selectedChannel == null) return;

    setState(() => _isSending = true);

    final userId = widget.userProfile['id'] as String;

    final message = await _chatService.sendMessage(
      channelId: _selectedChannel!.id,
      userId: userId,
      message: text,
      replyToMessageId: _replyToMessageId,
    );

    setState(() => _isSending = false);

    if (message != null) {
      _messageController.clear();
      setState(() {
        _replyToMessageId = null;
        _replyToMessage = null;
      });
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
        
        if (_selectedChannel?.id == channel.id) {
          setState(() => _selectedChannel = null);
        }
        
        _loadChannels();
      }
    }
  }

  void _createChannel() async {
    final result = await showCreateChannelDesktopDialog(
      context,
      widget.userProfile,
    );
    
    if (result == true) {
      _loadChannels();
    }
  }

  void _replyToMessageHandler(ChatMessage message) {
    setState(() {
      _replyToMessageId = message.id;
      _replyToMessage = message;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
    });
  }

  void _showMessageOptions(ChatMessage message) {
      if (message.isDeleted) {
    return; // Don't show options for deleted messages
  }
    final userId = widget.userProfile['id'] as String;
    final isOwn = message.userId == userId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessageHandler(message);
              },
            ),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage message) {
    final controller = TextEditingController(text: message.message);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != message.message) {
                await _chatService.editMessage(message.id, newText);
                if (mounted) {
                  Navigator.pop(context);
                  _loadMessages();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.deleteMessage(message.id);
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Left Sidebar - Channels List
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back to Map',
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Community Chat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _createChannel,
                        tooltip: 'Create Channel',
                      ),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'My Channels'),
                    Tab(text: 'Discover'),
                  ],
                ),

                // Channel List
                Expanded(
                  child: _isLoadingChannels
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildJoinedChannelsList(),
                            _buildAvailableChannelsList(),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Right Side - Chat Area
          Expanded(
            child: _selectedChannel == null
                ? _buildNoChannelSelected()
                : _buildChatArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedChannelsList() {
    if (_joinedChannels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No channels yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join a channel to start chatting',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _joinedChannels.length,
      itemBuilder: (context, index) {
        final channel = _joinedChannels[index];
        final isSelected = _selectedChannel?.id == channel.id;
        
        return _buildChannelListItem(channel, isSelected, isJoined: true);
      },
    );
  }

  Widget _buildAvailableChannelsList() {
    if (_availableChannels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No available channels',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new channel to get started',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _availableChannels.length,
      itemBuilder: (context, index) {
        final channel = _availableChannels[index];
        return _buildChannelListItem(channel, false, isJoined: false);
      },
    );
  }

  Widget _buildChannelListItem(ChatChannel channel, bool isSelected, {required bool isJoined}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: isJoined ? () => _selectChannel(channel) : null,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getChannelColor(channel.channelType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              channel.channelIcon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isJoined && channel.unreadCount != null && channel.unreadCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  channel.unreadCount! > 99 ? '99+' : '${channel.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${channel.memberCount} members',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        trailing: isJoined
            ? IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                onPressed: () => _leaveChannel(channel),
              )
            : TextButton(
                onPressed: () => _joinChannel(channel),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Join'),
              ),
      ),
    );
  }

  Widget _buildNoChannelSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'Select a channel to start chatting',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from your channels or discover new ones',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Text(
                _selectedChannel!.channelIcon,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChannel!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_selectedChannel!.memberCount} members',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showChannelInfo,
                tooltip: 'Channel Info',
              ),
            ],
          ),
        ),

        // Messages Area
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _buildEmptyMessages()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isOwn = message.userId == widget.userProfile['id'];
                        final showAvatar = index == 0 || 
                            _messages[index - 1].userId != message.userId;
                        
                        return _buildMessageBubble(message, isOwn, showAvatar);
                      },
                    ),
        ),

        // Reply Preview
        if (_replyToMessage != null) _buildReplyPreview(),

        // Message Input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _selectedChannel!.channelIcon,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to say something!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

Widget _buildMessageBubble(ChatMessage message, bool isOwn, bool showAvatar) {
  return GestureDetector(
    onLongPress: () => _showMessageOptions(message),  // onTap for desktop
    child: Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        top: showAvatar ? 8 : 2,
      ),
      child: Column(  // ✅ Changed from Row to Column
        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ✅ NEW: Show reply indicator ABOVE the bubble
          if (message.replyToMessageId != null)
            Padding(
              padding: EdgeInsets.only(
                left: isOwn ? 0 : 56,  // Account for avatar space
                right: isOwn ? 56 : 0,
                bottom: 4,
              ),
              child: _buildReplyIndicator(message, isOwn),
            ),
          
          // ✅ Original message bubble row
          Row(
            mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn && showAvatar) _buildAvatar(message),
              if (!isOwn && !showAvatar) const SizedBox(width: 40),
              
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75, // 0.5 for desktop
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOwn ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOwn ? 16 : 4),
                      bottomRight: Radius.circular(isOwn ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isOwn && showAvatar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      
                      // ✅ REMOVED: Reply indicator is now outside
                      // Message content (deleted or normal)
                      message.isDeleted
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 14,
                                  color: isOwn ? Colors.white70 : Colors.grey[500],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Message deleted',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: isOwn ? Colors.white70 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              message.message,
                              style: TextStyle(
                                fontSize: 15,
                                color: isOwn ? Colors.white : Colors.black87,
                              ),
                            ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isOwn ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          if (message.isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(edited)',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isOwn ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isOwn && showAvatar) _buildAvatar(message),
              if (isOwn && !showAvatar) const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAvatar(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue[100],
        backgroundImage: message.profilePictureUrl != null
            ? NetworkImage(message.profilePictureUrl!)
            : null,
        child: message.profilePictureUrl == null
            ? Text(
                message.userInitials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              )
            : null,
      ),
    );
  }

Widget _buildReplyIndicator(ChatMessage message, bool isOwn) {
  // Get the original message from cache or local messages
  ChatMessage? originalMessage;
  
  if (message.replyToMessageId != null) {
    // First check cache
    originalMessage = _repliedMessages[message.replyToMessageId];
    
    // If not in cache, check current messages
    if (originalMessage == null) {
      originalMessage = _messages.firstWhere(
        (msg) => msg.id == message.replyToMessageId,
        orElse: () => ChatMessage(
          id: '',
          channelId: '',
          userId: '',
          message: 'Loading...',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isEdited: false,
          isDeleted: false,
        ),
      );
    }
  }

  // Fallback if message not found
  if (originalMessage == null || originalMessage.id.isEmpty) {
    // Trigger fetch if not loading already
    if (message.replyToMessageId != null && 
        !_repliedMessages.containsKey(message.replyToMessageId)) {
      _fetchRepliedMessage(message.replyToMessageId!);
    }
    
    originalMessage = ChatMessage(
      id: '',
      channelId: '',
      userId: '',
      message: 'Loading message...',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isEdited: false,
      isDeleted: false,
    );
  }

  return Container(
    constraints: const BoxConstraints(maxWidth: 250),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(
          color: isOwn ? Colors.blue : Colors.grey[400]!,
          width: 3,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reply,
              size: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                originalMessage.id.isEmpty 
                    ? 'Unknown User' 
                    : originalMessage.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          originalMessage.isDeleted 
              ? 'Message deleted' 
              : originalMessage.message,
          style: TextStyle(
            fontSize: 11,
            color: originalMessage.id.isEmpty 
                ? Colors.grey[500] 
                : Colors.grey[700],
            fontStyle: originalMessage.isDeleted || originalMessage.id.isEmpty 
                ? FontStyle.italic 
                : FontStyle.normal,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.displayName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  _replyToMessage!.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

 void _showChannelInfo() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Text(
            _selectedChannel!.channelIcon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedChannel!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_selectedChannel!.memberCount} members',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedChannel!.description != null && _selectedChannel!.description!.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedChannel!.description!,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people, color: Colors.blue[700]),
            title: const Text('View Members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context); // Close the channel info dialog
              _showMembersModal(); // Open the members modal
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

// Add this new method after _showChannelInfo:

void _showMembersModal() {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: ChannelMembersModalContent(
          channel: _selectedChannel!,
          currentUserId: widget.userProfile['id'] as String,
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }
}

class ChannelMembersModalContent extends StatefulWidget {
  final ChatChannel channel;
  final String currentUserId;

  const ChannelMembersModalContent({
    Key? key,
    required this.channel,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChannelMembersModalContent> createState() => _ChannelMembersModalContentState();
}

class _ChannelMembersModalContentState extends State<ChannelMembersModalContent> {
  final ChatService _chatService = ChatService();
  List<ChannelMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    final members = await _chatService.getChannelMembers(widget.channel.id);

    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  String _getRoleBadge(String role) {
    switch (role) {
      case 'admin':
        return '👑';
      case 'moderator':
        return '⭐';
      default:
        return '';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.amber.shade700;
      case 'moderator':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.people, size: 28, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_members.length} members',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Close',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        
        // Members List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No members found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMembers,
                      child: ListView.builder(
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isCurrentUser = member.userId == widget.currentUserId;
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue[100],
                              backgroundImage: member.profilePictureUrl != null
                                  ? NetworkImage(member.profilePictureUrl!)
                                  : null,
                              child: member.profilePictureUrl == null
                                  ? Text(
                                      _getInitials(member.fullName ?? member.username ?? '?'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    member.fullName ?? member.username ?? 'Unknown User',
                                    style: TextStyle(
                                      fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (member.role != 'member') ...[
                                  Text(
                                    _getRoleBadge(member.role),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                if (member.username != null)
                                  Text(
                                    '@${member.username}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                if (member.role != 'member') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(member.role).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      member.role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: _getRoleColor(member.role),
                                      ),
                                    ),
                                  ),
                                ],
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: member.isMuted
                                ? Icon(Icons.volume_off, color: Colors.grey[400], size: 18)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

