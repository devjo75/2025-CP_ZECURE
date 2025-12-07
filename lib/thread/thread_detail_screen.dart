// lib/thread/thread_detail_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'thread_models.dart';
import 'thread_service.dart';
import 'package:intl/intl.dart';

class ThreadDetailScreen extends StatefulWidget {
  final ReportThread thread;
  final String userId;

  const ThreadDetailScreen({
    super.key,
    required this.thread,
    required this.userId,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final ThreadService _threadService = ThreadService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ThreadMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isJoined = false;
  bool _isJoining = false;
  String _messageType = 'comment';
  ThreadMessage? _replyingTo;

  // ✅ NEW: Track current thread ID to detect changes
  String? _currentThreadId;

  @override
  void initState() {
    super.initState();
    _currentThreadId = widget.thread.id;
    _isJoined = widget.thread.isFollowing;
    _loadMessages();
    _setupRealtimeSubscription();

    // ✅ ONLY mark as read if already joined
    if (_isJoined) {
      _markAsRead();
    }
  }

  // ✅ NEW: Detect when thread changes and reload
  @override
  void didUpdateWidget(ThreadDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.thread.id != widget.thread.id) {
      print(
        '🔄 Thread changed from ${oldWidget.thread.id} to ${widget.thread.id}',
      );

      _threadService.dispose();
      _currentThreadId = widget.thread.id;
      _isJoined = widget.thread.isFollowing; // Update join status

      setState(() {
        _messages = [];
        _isLoading = true;
        _replyingTo = null;
      });

      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted && _currentThreadId == widget.thread.id) {
          _setupRealtimeSubscription();
          _loadMessages();
          if (_isJoined) {
            _markAsRead();
          }
        }
      });
    }
  }

  Future<void> _joinThread() async {
    setState(() => _isJoining = true);

    try {
      await _threadService.joinThread(widget.thread.id, widget.userId);

      if (mounted) {
        setState(() {
          _isJoined = true;
          _isJoining = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You joined this thread'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Mark as read after joining
        _markAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join thread: $e')));
      }
    }
  }

  @override
  void dispose() {
    _threadService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('📥 Loading messages for thread: ${widget.thread.id}');
      print('   Current thread ID: $_currentThreadId');

      final messages = await _threadService.fetchThreadMessages(
        widget.thread.id,
      );

      print('✅ Loaded ${messages.length} messages');
      if (messages.isNotEmpty) {
        print('   First message: ${messages.first.message}');
        print('   Last message: ${messages.last.message}');
      }

      // ✅ IMPORTANT: Only update if we're still viewing the same thread
      if (_currentThreadId == widget.thread.id && mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        print('✅ Messages updated in state: ${_messages.length}');
        _scrollToBottom();
      } else {
        print('⚠️ Thread changed during load, ignoring messages');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading messages: $e');
      print('Stack trace: $stackTrace');

      if (mounted && _currentThreadId == widget.thread.id) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupRealtimeSubscription() {
    _threadService.subscribeToThreadMessages(
      widget.thread.id,
      (newMessage) {
        // ✅ Only add message if we're still viewing this thread
        if (mounted && _currentThreadId == widget.thread.id) {
          print('📨 New message received for current thread');
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
          _markAsRead();
        } else {
          print('⚠️ Ignoring message for different thread');
        }
      },
      (deletedMessageId) {
        if (mounted && _currentThreadId == widget.thread.id) {
          setState(() {
            _messages.removeWhere((m) => m.id == deletedMessageId);
          });
        }
      },
      // ✅ NEW: Handle message updates (edits)
      (updatedMessage) {
        if (mounted && _currentThreadId == widget.thread.id) {
          print('✏️ Message updated');
          setState(() {
            final index = _messages.indexWhere(
              (m) => m.id == updatedMessage.id,
            );
            if (index != -1) {
              _messages[index] = updatedMessage;
            }
          });
        }
      },
    );
  }

  Future<void> _markAsRead() async {
    await _threadService.markThreadAsRead(widget.thread.id, widget.userId);
    print('✅ Thread marked as read: ${widget.thread.id}');
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Auto-join if not joined yet
    if (!_isJoined) {
      await _joinThread();
      if (!_isJoined) return; // Failed to join
    }

    setState(() => _isSending = true);

    try {
      await _threadService.sendMessage(
        threadId: widget.thread.id,
        userId: widget.userId,
        message: text,
        messageType: _messageType,
        replyToMessageId: _replyingTo?.id,
      );

      _messageController.clear();
      _replyingTo = null;
      _messageType = 'comment';

      if (mounted) {
        setState(() => _isSending = false);
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() => _isSending = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _showMessageTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Message Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMessageTypeOption(
              'comment',
              'Comment',
              Icons.comment,
              'General discussion',
            ),
            _buildMessageTypeOption(
              'update',
              'Update',
              Icons.update,
              'Status or situation update',
            ),
            _buildMessageTypeOption(
              'inquiry',
              'Inquiry',
              Icons.help_outline,
              'Ask a question',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypeOption(
    String type,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = _messageType == type;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.black,
        ),
      ),
      subtitle: Text(description),
      trailing: isSelected ? Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() => _messageType = type);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.thread.crimeType, style: const TextStyle(fontSize: 16)),
            Text(
              DateFormat('MMM dd, yyyy').format(widget.thread.incidentTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showThreadInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thread header info
          _buildThreadHeader(),

          // Messages list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : !_isJoined // ✅ Check join status FIRST
                ? _buildJoinPrompt() // Show join prompt instead
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isOwnMessage = message.userId == widget.userId;
                      final showDateHeader = _shouldShowDateHeader(index);

                      return Column(
                        children: [
                          if (showDateHeader)
                            _buildDateHeader(_messages[index].createdAt),
                          _buildMessageBubble(message, isOwnMessage),
                        ],
                      );
                    },
                  ),
          ),

          // Reply indicator
          if (_replyingTo != null) _buildReplyIndicator(),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.orange.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Join to View Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Join this thread to read and participate in the discussion',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isJoining ? null : _joinThread,
            icon: _isJoining
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.person_add),
            label: Text(_isJoining ? 'Joining...' : 'Join Thread'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildSeverityBadge(widget.thread.crimeLevel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.thread.crimeCategory,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.thread.participantCount} participants',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.message, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.thread.messageCount} messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.thread.activeStatus == 'active'
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.thread.activeStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: widget.thread.activeStatus == 'active'
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;

    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );

    final previousDate = DateTime(
      previousMessage.createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );

    return currentDate != previousDate;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ThreadMessage message, bool isOwnMessage) {
    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOwnMessage
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender name (for others' messages)
            if (!isOwnMessage)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.userFullName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (message.userRole != 'user') ...[
                      const SizedBox(width: 6),
                      _buildRoleBadge(message.userRole),
                    ],
                  ],
                ),
              ),

            // ✅ Message bubble with long-press menu
            GestureDetector(
              onLongPress: () => _showMessageOptions(message, isOwnMessage),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOwnMessage ? Colors.blue.shade600 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator
                    if (message.replyToMessage != null)
                      _buildReplyPreview(message.replyToMessage!, isOwnMessage),

                    // Message type badge
                    if (message.messageType != 'comment')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildMessageTypeBadge(
                          message.messageType,
                          isOwnMessage,
                        ),
                      ),

                    // Message text
                    Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 15,
                        color: isOwnMessage ? Colors.white : Colors.black87,
                      ),
                    ),

                    // Timestamp and edited indicator
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat(
                            'h:mm a',
                          ).format(message.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: isOwnMessage
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isOwnMessage
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;

    switch (role) {
      case 'admin':
        color = Colors.red;
        label = 'ADMIN';
        break;
      case 'officer':
        color = Colors.blue;
        label = 'OFFICER';
        break;
      case 'tanod':
        color = Colors.green;
        label = 'TANOD';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageTypeBadge(String type, bool isOwnMessage) {
    IconData icon;
    String label;

    switch (type) {
      case 'update':
        icon = Icons.update;
        label = 'Update';
        break;
      case 'inquiry':
        icon = Icons.help_outline;
        label = 'Inquiry';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isOwnMessage
              ? Colors.white.withOpacity(0.9)
              : Colors.blue.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isOwnMessage
                ? Colors.white.withOpacity(0.9)
                : Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(ThreadMessage replyTo, bool isOwnMessage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOwnMessage
            ? Colors.white.withOpacity(0.2)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isOwnMessage ? Colors.white : Colors.blue.shade600,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo.userFullName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isOwnMessage ? Colors.white : Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isOwnMessage
                  ? Colors.white.withOpacity(0.9)
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(top: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.userFullName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade600,
                  ),
                ),
                Text(
                  _replyingTo!.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    if (!_isJoined) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_getMessageTypeIcon(), color: Colors.blue.shade600),
            onPressed: _showMessageTypeSelector,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.send, color: Colors.blue.shade600),
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }

  IconData _getMessageTypeIcon() {
    switch (_messageType) {
      case 'update':
        return Icons.update;
      case 'inquiry':
        return Icons.help_outline;
      default:
        return Icons.comment;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showThreadInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thread Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Crime Type', widget.thread.crimeType),
            _buildInfoRow('Category', widget.thread.crimeCategory),
            _buildInfoRow('Severity', widget.thread.crimeLevel.toUpperCase()),
            _buildInfoRow('Status', widget.thread.activeStatus.toUpperCase()),
            _buildInfoRow(
              'Incident Date',
              DateFormat(
                'MMM dd, yyyy h:mm a',
              ).format(widget.thread.incidentTime),
            ),
            if (widget.thread.distanceFromUser != null)
              _buildInfoRow(
                'Distance',
                '${widget.thread.distanceFromUser!.toStringAsFixed(2)} km away',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show message options (Reply, Edit, Delete)
  void _showMessageOptions(ThreadMessage message, bool isOwnMessage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply option (available for all messages)
            ListTile(
              leading: Icon(Icons.reply, color: Colors.blue.shade600),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingTo = message;
                });
              },
            ),

            // Edit option (only for own messages)
            if (isOwnMessage)
              ListTile(
                leading: Icon(Icons.edit, color: Colors.orange.shade600),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMessageDialog(message);
                },
              ),

            // Delete option (only for own messages)
            if (isOwnMessage)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade600),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Show edit message dialog
  void _showEditMessageDialog(ThreadMessage message) {
    final editController = TextEditingController(text: message.message);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message cannot be empty')),
                );
                return;
              }

              if (newText == message.message) {
                Navigator.pop(context);
                return;
              }

              try {
                await _threadService.editMessage(message.id, newText);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message updated')),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show delete confirmation dialog
  void _showDeleteConfirmation(ThreadMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _threadService.deleteMessage(message.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
