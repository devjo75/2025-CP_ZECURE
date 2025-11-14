import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/chatbox/channel_members_screen.dart';
import 'chat_model.dart';
import 'chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatChannel channel;
  final Map<String, dynamic> userProfile;

  const ChatRoomScreen({
    super.key,
    required this.channel,
    required this.userProfile,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _messageSubscription;

  String? _replyToMessageId;
  ChatMessage? _replyToMessage;
  final Map<String, ChatMessage> _repliedMessages = {};

  @override
  void initState() {
    super.initState();
    print('🚀 ChatRoomScreen initState - Loading messages...');
    _loadMessages();
    _setupRealtimeSubscription();
    // ✅ Removed the problematic scroll listener
  }

  @override
  void dispose() {
    print('👋 ChatRoomScreen dispose - Marking as read and cleaning up...');

    // ✅ IMPORTANT: Mark as read when leaving the chat room
    // This ensures the unread count is cleared only when user actually viewed the messages
    _markAsRead();

    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.unsubscribe();
    super.dispose();
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

  Future<void> _loadMessages() async {
    print('📥 Starting to load messages...');
    setState(() => _isLoading = true);

    try {
      final messages = await _chatService.getMessages(
        widget.channel.id,
        limit: 100,
      );
      print('✅ Loaded ${messages.length} messages');

      if (mounted) {
        setState(() {
          _messages = messages.reversed
              .toList(); // Reverse to show oldest first
          _isLoading = false;
        });

        final replyIds = messages
            .where((msg) => msg.replyToMessageId != null)
            .map((msg) => msg.replyToMessageId!)
            .toSet();

        for (final replyId in replyIds) {
          _fetchRepliedMessage(replyId);
        }

        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    print('🔔 Setting up realtime subscription...');
    _messageSubscription = _chatService.subscribeToMessages(widget.channel.id, (
      message,
      event,
    ) {
      print(
        '📨 Message change received: ${event.toString().split('.').last} - ${message.message}',
      );
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
      }
    });
  }

  Future<void> _markAsRead() async {
    final userId = widget.userProfile['id'] as String;
    print(
      '📖 Marking channel as read: ${widget.channel.name} for user: $userId',
    );
    await _chatService.updateLastRead(widget.channel.id, userId);
    print('✅ Marked as read');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    print('');
    print('🎯 _sendMessage called');
    print('   Text: "$text"');
    print('   Text empty? ${text.isEmpty}');
    print('   Is sending? $_isSending');

    if (text.isEmpty || _isSending) {
      print('   ⏭️ Skipping (empty or already sending)');
      return;
    }

    setState(() => _isSending = true);

    final userId = widget.userProfile['id'] as String;

    print('');
    print('📤 Calling chatService.sendMessage...');
    print('   Channel: ${widget.channel.name} (${widget.channel.id})');
    print('   User: $userId');

    final message = await _chatService.sendMessage(
      channelId: widget.channel.id,
      userId: userId,
      message: text,
      replyToMessageId: _replyToMessageId,
    );

    setState(() => _isSending = false);

    if (message != null) {
      print('✅ Message sent successfully!');
      _messageController.clear();
      setState(() {
        _replyToMessageId = null;
        _replyToMessage = null;
      });
      _scrollToBottom();
      _markAsRead(); // ✅ Mark as read when you send a message (you obviously saw them)
    } else {
      print('❌ Failed to send message (returned null)');
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

  void _replyToMessageHandler(ChatMessage message) {
    if (message.isDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reply to deleted messages'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
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
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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
                  _loadMessages(); // Reload to show edit
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
    print(
      '🎨 Building ChatRoomScreen - isLoading: $_isLoading, messages: ${_messages.length}',
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.channel.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${widget.channel.memberCount} members',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showChannelInfo();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isOwn = message.userId == widget.userProfile['id'];
                      final showAvatar =
                          index == 0 ||
                          _messages[index - 1].userId != message.userId;

                      return _buildMessageBubble(message, isOwn, showAvatar);
                    },
                  ),
          ),

          // Reply preview
          if (_replyToMessage != null) _buildReplyPreview(),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.channel.channelIcon,
            style: const TextStyle(fontSize: 60),
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
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8, top: showAvatar ? 8 : 2),
        child: Column(
          crossAxisAlignment: isOwn
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Show reply indicator ABOVE the bubble
            if (message.replyToMessageId != null)
              Padding(
                padding: EdgeInsets.only(
                  left: isOwn ? 0 : 48,
                  right: isOwn ? 48 : 0,
                  bottom: 4,
                ),
                child: _buildReplyIndicatorEnhanced(message, isOwn),
              ),

            // Original message bubble row
            Row(
              mainAxisAlignment: isOwn
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOwn && showAvatar) _buildAvatar(message),
                if (!isOwn && !showAvatar) const SizedBox(width: 40),

                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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

                        // Message content (deleted or normal)
                        message.isDeleted
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 14,
                                    color: isOwn
                                        ? Colors.white70
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Message deleted',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                      color: isOwn
                                          ? Colors.white70
                                          : Colors.grey[500],
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
                                color: isOwn
                                    ? Colors.white70
                                    : Colors.grey[600],
                              ),
                            ),
                            if (message.isEdited) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(edited)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isOwn
                                      ? Colors.white70
                                      : Colors.grey[600],
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

  Widget _buildReplyIndicatorEnhanced(ChatMessage message, bool isOwn) {
    // Get the original message from cache or local messages
    ChatMessage? originalMessage;

    if (message.replyToMessageId != null) {
      // First check cache
      originalMessage = _repliedMessages[message.replyToMessageId];

      // If not in cache, check current messages
      originalMessage ??= _messages.firstWhere(
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
              Icon(Icons.reply, size: 12, color: Colors.grey[600]),
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

  Widget _buildAvatar(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.blue[100],
        backgroundImage: message.profilePictureUrl != null
            ? NetworkImage(message.profilePictureUrl!)
            : null,
        child: message.profilePictureUrl == null
            ? Text(
                message.userInitials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  _replyToMessage!.message,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _cancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
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
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 44,
                height: 44,
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
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.channel.channelIcon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.channel.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.channel.memberCount} members',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.channel.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.channel.description!,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.people, color: Colors.blue[700]),
                title: const Text('View Members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChannelMembersScreen(
                        channel: widget.channel,
                        currentUserId: widget.userProfile['id'] as String,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
