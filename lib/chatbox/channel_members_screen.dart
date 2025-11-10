import 'package:flutter/material.dart';
import 'package:zecure/chatbox/chat_model.dart';
import 'package:zecure/chatbox/chat_service.dart';

class ChannelMembersScreen extends StatefulWidget {
  final ChatChannel channel;
  final String currentUserId;

  const ChannelMembersScreen({
    Key? key,
    required this.channel,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ChannelMembersScreen> createState() => _ChannelMembersScreenState();
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> {
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
      return Colors.amber.shade700;  // This works because Colors.amber is MaterialColor
    case 'moderator':
      return Colors.blue.shade700;   // This works because Colors.blue is MaterialColor
    default:
      return Colors.grey.shade700;   // This works because Colors.grey is MaterialColor
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_members.length} members',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member.userId == widget.currentUserId;
                      return _buildMemberItem(member, isCurrentUser);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No members found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(ChannelMember member, bool isCurrentUser) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue[100],
        backgroundImage: member.profilePictureUrl != null
            ? NetworkImage(member.profilePictureUrl!)
            : null,
        child: member.profilePictureUrl == null
            ? Text(
                _getInitials(member.fullName ?? member.username ?? '?'),
                style: TextStyle(
                  fontSize: 16,
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
                fontSize: 15,
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
                fontSize: 13,
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
                  fontSize: 10,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: member.isMuted
          ? Icon(Icons.volume_off, color: Colors.grey[400], size: 20)
          : null,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}