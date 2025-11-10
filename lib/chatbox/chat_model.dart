
// ============================================
// CHAT CHANNEL MODEL
// ============================================
class ChatChannel {
  final String id;
  final String name;
  final String? description;
  final String channelType; // 'barangay', 'city_wide', 'custom'
  final String? barangay;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int memberCount;
  final bool isPrivate;
  final int maxMembers;

  // Additional fields for UI
  bool isJoined;
  int? unreadCount;

  ChatChannel({
    required this.id,
    required this.name,
    this.description,
    required this.channelType,
    this.barangay,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.memberCount,
    required this.isPrivate,
    required this.maxMembers,
    this.isJoined = false,
    this.unreadCount,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      channelType: json['channel_type'] as String,
      barangay: json['barangay'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      memberCount: json['member_count'] as int? ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
      maxMembers: json['max_members'] as int? ?? 500,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'channel_type': channelType,
      'barangay': barangay,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
      'member_count': memberCount,
      'is_private': isPrivate,
      'max_members': maxMembers,
    };
  }

  String get displayName {
    if (channelType == 'barangay' && barangay != null) {
      return 'Barangay $barangay';
    }
    return name;
  }

  String get channelIcon {
    switch (channelType) {
      case 'barangay':
        return '🏘️';
      case 'city_wide':
        return '🏙️';
      case 'custom':
        return '💬';
      default:
        return '📢';
    }
  }
}

// ============================================
// CHANNEL MEMBER MODEL
// ============================================
class ChannelMember {
  final String id;
  final String channelId;
  final String userId;
  final DateTime joinedAt;
  final String role; // 'admin', 'moderator', 'member'
  final bool isMuted;
  final DateTime lastReadAt;

  // User details (joined from users table)
  final String? username;
  final String? fullName;
  final String? profilePictureUrl;

  ChannelMember({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.joinedAt,
    required this.role,
    required this.isMuted,
    required this.lastReadAt,
    this.username,
    this.fullName,
    this.profilePictureUrl,
  });

  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    return ChannelMember(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      role: json['role'] as String? ?? 'member',
      isMuted: json['is_muted'] as bool? ?? false,
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
}

// ============================================
// CHAT MESSAGE MODEL
// ============================================
class ChatMessage {
  final String id;
  final String channelId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isDeleted;
  final String? replyToMessageId;
  final String? attachmentUrl;
  final String? attachmentType;

  // User details (joined from users table)
  final String? username;
  final String? fullName;
  final String? profilePictureUrl;

  // For UI
  final int? reactionCount;

  ChatMessage({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.isEdited,
    required this.isDeleted,
    this.replyToMessageId,
    this.attachmentUrl,
    this.attachmentType,
    this.username,
    this.fullName,
    this.profilePictureUrl,
    this.reactionCount,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyToMessageId: json['reply_to_message_id'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      reactionCount: json['reaction_count'] as int?,
    );
  }

  String get displayName => fullName ?? username ?? 'Unknown User';
  
 String get userInitials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return fullName![0].toUpperCase();
    }
    return username?[0].toUpperCase() ?? '?';
  }

  // ✅ ADD THIS NEW GETTER HERE:
  String get displayMessage {
    if (isDeleted) {
      return 'Message deleted';
    }
    return message;
  }
}