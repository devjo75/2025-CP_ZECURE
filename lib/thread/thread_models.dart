// lib/thread/thread_models.dart

import 'package:latlong2/latlong.dart';

class ReportThread {
  final String id;
  final int hotspotId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final int participantCount;
  final bool isActive;

  // Hotspot details
  final String crimeType;
  final String crimeLevel;
  final String crimeCategory;
  final LatLng location;
  final DateTime incidentTime;
  final String activeStatus;
  final double? distanceFromUser;

  // Participant info
  final int unreadCount;
  final bool isFollowing;

  ReportThread({
    required this.id,
    required this.hotspotId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    required this.messageCount,
    required this.participantCount,
    required this.isActive,
    required this.crimeType,
    required this.crimeLevel,
    required this.crimeCategory,
    required this.location,
    required this.incidentTime,
    required this.activeStatus,
    this.distanceFromUser,
    this.unreadCount = 0,
    this.isFollowing = false,
  });

  factory ReportThread.fromJson(Map<String, dynamic> json) {
    final hotspot = json['hotspot'] ?? {};
    final crimeTypeData = hotspot['crime_type'] ?? {};

    // Parse location - it can be either a string or an object
    LatLng location;
    final locationData = hotspot['location'];

    if (locationData is String) {
      // PostGIS format: "POINT(lng lat)"
      final locationStr = locationData;
      final coords = locationStr
          .replaceAll('POINT(', '')
          .replaceAll(')', '')
          .split(' ');

      final lng = double.tryParse(coords[0]) ?? 0.0;
      final lat = double.tryParse(coords[1]) ?? 0.0;
      location = LatLng(lat, lng);
    } else if (locationData is Map) {
      // GeoJSON format: {type: "Point", coordinates: [lng, lat]}
      final coordinates = locationData['coordinates'] as List?;
      if (coordinates != null && coordinates.length >= 2) {
        final lng = (coordinates[0] as num).toDouble();
        final lat = (coordinates[1] as num).toDouble();
        location = LatLng(lat, lng);
      } else {
        location = LatLng(0, 0);
      }
    } else {
      location = LatLng(0, 0);
    }

    return ReportThread(
      id: json['id'] as String,
      hotspotId: json['hotspot_id'] as int,
      title: json['title'] as String? ?? 'Unknown Report',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      messageCount: json['message_count'] as int? ?? 0,
      participantCount: json['participant_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      crimeType: crimeTypeData['name'] as String? ?? 'Unknown',
      crimeLevel: crimeTypeData['level'] as String? ?? 'unknown',
      crimeCategory: crimeTypeData['category'] as String? ?? 'General',
      location: location,
      incidentTime: DateTime.parse(hotspot['time'] as String),
      activeStatus: hotspot['active_status'] as String? ?? 'active',
    );
  }

  ReportThread copyWith({
    double? distanceFromUser,
    int? unreadCount,
    bool? isFollowing,
  }) {
    return ReportThread(
      id: id,
      hotspotId: hotspotId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
      messageCount: messageCount,
      participantCount: participantCount,
      isActive: isActive,
      crimeType: crimeType,
      crimeLevel: crimeLevel,
      crimeCategory: crimeCategory,
      location: location,
      incidentTime: incidentTime,
      activeStatus: activeStatus,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      unreadCount: unreadCount ?? this.unreadCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

/// Represents a message in a thread
class ThreadMessage {
  final String id;
  final String threadId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isDeleted;
  final String? replyToMessageId;
  final String? attachmentUrl;
  final String? attachmentType;
  final String messageType; // comment, update, inquiry

  // User details
  final String userFullName;
  final String? userProfilePicture;
  final String userRole; // user, admin, officer, tanod

  // Reply details (if replying to another message)
  final ThreadMessage? replyToMessage;

  ThreadMessage({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.isEdited,
    required this.isDeleted,
    this.replyToMessageId,
    this.attachmentUrl,
    this.attachmentType,
    required this.messageType,
    required this.userFullName,
    this.userProfilePicture,
    required this.userRole,
    this.replyToMessage,
  });

  factory ThreadMessage.fromJson(Map<String, dynamic> json) {
    // ✅ FIXED: Handle null user data gracefully
    final userData = json['user'];

    // Extract user info with proper null handling
    String fullName = 'Unknown User';
    String? profilePicture;
    String role = 'user';

    if (userData != null && userData is Map<String, dynamic>) {
      fullName = userData['full_name'] as String? ?? 'Unknown User';
      profilePicture = userData['profile_picture_url'] as String?;
      role = userData['role'] as String? ?? 'user';
    }

    // ✅ FIXED: Handle reply_to data with null safety
    ThreadMessage? replyToMessage;
    final replyToData = json['reply_to'];

    if (replyToData != null && replyToData is Map<String, dynamic>) {
      try {
        // Parse nested user data for reply
        final replyUserData = replyToData['user'];
        String replyUserName = 'Unknown User';

        if (replyUserData != null && replyUserData is Map<String, dynamic>) {
          replyUserName =
              replyUserData['full_name'] as String? ?? 'Unknown User';
        }

        replyToMessage = ThreadMessage(
          id: replyToData['id'] as String? ?? '',
          threadId: json['thread_id'] as String? ?? '',
          userId: '',
          message: replyToData['message'] as String? ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isEdited: false,
          isDeleted: false,
          messageType: 'comment',
          userFullName: replyUserName,
          userRole: 'user',
        );
      } catch (e) {
        print('Error parsing reply_to message: $e');
        replyToMessage = null;
      }
    }

    return ThreadMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyToMessageId: json['reply_to_message_id'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      messageType: json['message_type'] as String? ?? 'comment',
      userFullName: fullName,
      userProfilePicture: profilePicture,
      userRole: role,
      replyToMessage: replyToMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thread_id': threadId,
      'user_id': userId,
      'message': message,
      'message_type': messageType,
      'reply_to_message_id': replyToMessageId,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
    };
  }
}

/// Represents a user's participation in a thread
class ThreadParticipant {
  final String id;
  final String threadId;
  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final bool isFollowing;
  final int unreadCount;

  ThreadParticipant({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
    required this.isFollowing,
    required this.unreadCount,
  });

  factory ThreadParticipant.fromJson(Map<String, dynamic> json) {
    return ThreadParticipant(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      isFollowing: json['is_following'] as bool? ?? true,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

/// Enum for thread sorting options
enum ThreadSortOption { nearest, recent, mostActive, crimeType }

/// Enum for message type filtering
enum MessageTypeFilter { all, comments, updates, inquiries }
