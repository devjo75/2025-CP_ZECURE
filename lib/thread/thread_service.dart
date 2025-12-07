// lib/thread/thread_service.dart

// ignore_for_file: avoid_print

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'thread_models.dart';

class ThreadService {
  final _supabase = Supabase.instance.client;

  // Real-time subscriptions
  RealtimeChannel? _threadsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _participantsChannel;

  Future<List<ReportThread>> fetchThreads({
    LatLng? userLocation,
    String? crimeTypeFilter,
    String? statusFilter, // 'active', 'inactive', 'all'
  }) async {
    try {
      print('🔍 Starting fetchThreads...');
      print('   statusFilter: $statusFilter');
      print('   crimeTypeFilter: $crimeTypeFilter');

      // Calculate 30 days ago in UTC
      final thirtyDaysAgo = DateTime.now()
          .subtract(Duration(days: 30))
          .toUtc()
          .toIso8601String();

      print('   30 days ago: $thirtyDaysAgo');

      // Build query
      var query = _supabase.from('report_threads').select('''
          *,
          hotspot:hotspot_id!inner (
            id,
            type_id,
            time,
            location,
            active_status,
            status,
            crime_type:type_id (
              id,
              name,
              level,
              category,
              description
            )
          )
        ''');

      print('   Base query built');

      // Apply filters - IMPORTANT: Filter on the joined table's columns
      query = query
          .gte('hotspot.time', thirtyDaysAgo)
          .eq('hotspot.status', 'approved');

      print('   Applied time and status filters');

      // Apply status filter
      if (statusFilter != null && statusFilter != 'all') {
        query = query.eq('is_active', statusFilter == 'active');
        print('   Applied is_active filter: ${statusFilter == 'active'}');
      }

      if (crimeTypeFilter != null && crimeTypeFilter.isNotEmpty) {
        query = query.eq('hotspot.crime_type.name', crimeTypeFilter);
        print('   Applied crime type filter: $crimeTypeFilter');
      }

      // Order by last message
      print('   Executing query...');

      // Execute
      final response = await query.order('last_message_at', ascending: false);

      print('✅ Query executed successfully');
      print('   Raw response length: ${response.length}');

      if (response.isEmpty) {
        print('⚠️ No data returned from query');
        return [];
      }

      print('   First record: ${response[0]}');

      List<ReportThread> threads = [];
      for (var json in response) {
        try {
          print('   Parsing thread: ${json['id']}');
          var thread = ReportThread.fromJson(json);

          // Calculate distance if user location provided
          if (userLocation != null) {
            final distance = _calculateDistance(userLocation, thread.location);
            thread = thread.copyWith(distanceFromUser: distance);
          }

          threads.add(thread);
          print('   ✔ Thread parsed successfully: ${thread.title}');
        } catch (e, stackTrace) {
          print('   ❌ Error parsing thread: $e');
          print('   Stack: $stackTrace');
          print('   JSON data: $json');
        }
      }

      print('🎉 Successfully fetched ${threads.length} threads');
      return threads;
    } catch (e, stackTrace) {
      print('❌ Error in fetchThreads: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void subscribeToUnreadCountUpdates(
    String userId,
    Function(int unreadThreadCount) onUnreadCountChange,
  ) {
    _participantsChannel?.unsubscribe();

    _participantsChannel = _supabase
        .channel('thread_participants_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thread_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            print('🔔 Participant update received for user: $userId');
            // Refetch unread count whenever participant data changes
            final count = await getUnreadThreadCount(userId);
            onUnreadCountChange(count);
          },
        )
        .subscribe();

    print('✅ Subscribed to unread count updates for user: $userId');
  }

  Future<List<ThreadMessage>> fetchThreadMessages(
    String threadId, {
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      print('🔍 Fetching messages for thread: $threadId');

      var query = _supabase
          .from('thread_messages')
          .select('''
          *,
          user:user_id (
            id,
            full_name,
            profile_picture_url,
            role
          ),
          reply_to:reply_to_message_id (
            id,
            message,
            user:user_id (
              full_name
            )
          )
        ''')
          .eq('thread_id', threadId);

      // ✅ IMPORTANT: Don't filter by is_deleted initially - let's see all messages
      // We'll handle deleted messages in the UI
      print('   Not filtering deleted messages yet');

      // ✅ Apply the 'before' filter using .lt() properly
      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
        print('   Filtering messages before: $before');
      }

      // Apply ordering and limit after all filters
      print('   Ordering by created_at DESC, limit: $limit');
      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      print('✅ Query returned ${response.length} messages');

      if (response.isNotEmpty) {
        print('   First message ID: ${response.first['id']}');
        print('   First message text: ${response.first['message']}');
        print('   First message deleted: ${response.first['is_deleted']}');
      }

      // Parse messages and filter deleted ones
      final messages = response
          .map((json) => ThreadMessage.fromJson(json))
          .where((msg) => !msg.isDeleted) // Filter deleted messages here
          .toList()
          .reversed
          .toList();

      print('✅ After filtering deleted: ${messages.length} messages');

      return messages;
    } catch (e, stackTrace) {
      print('❌ Error fetching thread messages: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Send a message to a thread
  Future<ThreadMessage> sendMessage({
    required String threadId,
    required String userId,
    required String message,
    String messageType = 'comment',
    String? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      // ✅ Build insert data, only include non-null optional fields
      final Map<String, dynamic> insertData = {
        'thread_id': threadId,
        'user_id': userId,
        'message': message,
        'message_type': messageType,
      };

      // Only add optional fields if they're not null
      if (replyToMessageId != null) {
        insertData['reply_to_message_id'] = replyToMessageId;
      }
      if (attachmentUrl != null) {
        insertData['attachment_url'] = attachmentUrl;
      }
      if (attachmentType != null) {
        insertData['attachment_type'] = attachmentType;
      }

      print('📤 Sending message with data: $insertData');

      final response = await _supabase
          .from('thread_messages')
          .insert(insertData)
          .select('''
            *,
            user:user_id (
              id,
              full_name,
              profile_picture_url,
              role
            ),
            reply_to:reply_to_message_id (
              id,
              message,
              user:user_id (
                full_name
              )
            )
          ''')
          .single();

      print('✅ Message sent successfully');
      return ThreadMessage.fromJson(response);
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // ✅ NEW: Edit message
  Future<void> editMessage(String messageId, String newMessage) async {
    try {
      await _supabase
          .from('thread_messages')
          .update({
            'message': newMessage,
            'is_edited': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId);

      print('✅ Message edited successfully: $messageId');
    } catch (e) {
      print('Error editing message: $e');
      rethrow;
    }
  }

  // ✅ NEW: Delete message (soft delete)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase
          .from('thread_messages')
          .update({
            'is_deleted': true,
            'message': 'This message has been deleted',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId);

      print('✅ Message deleted successfully: $messageId');
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  /// Get participant info for current user in a thread
  Future<ThreadParticipant?> getThreadParticipant(
    String threadId,
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('thread_participants')
          .select()
          .eq('thread_id', threadId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return ThreadParticipant.fromJson(response);
    } catch (e) {
      print('Error getting thread participant: $e');
      return null;
    }
  }

  /// Mark thread as read and reset unread count
  Future<void> markThreadAsRead(String threadId, String userId) async {
    try {
      await _supabase.rpc(
        'mark_thread_as_read',
        params: {'p_thread_id': threadId, 'p_user_id': userId},
      );

      print('✅ Marked thread as read: $threadId');
    } catch (e) {
      // Fallback to direct update if RPC doesn't exist
      print('⚠️ RPC not available, using fallback: $e');
      await _supabase.from('thread_participants').upsert({
        'thread_id': threadId,
        'user_id': userId,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
        'unread_count': 0,
      }, onConflict: 'thread_id,user_id');
    }
  }

  Future<List<ReportThread>> fetchThreadsWithUnreadInfo({
    required String userId,
    LatLng? userLocation,
    String? crimeTypeFilter,
    String? statusFilter,
  }) async {
    try {
      print('🔍 Starting fetchThreadsWithUnreadInfo for user: $userId');

      final thirtyDaysAgo = DateTime.now()
          .subtract(Duration(days: 30))
          .toUtc()
          .toIso8601String();

      // Fetch threads with participant info - LEFT JOIN to include threads user hasn't joined
      var query = _supabase
          .from('report_threads')
          .select('''
          *,
          hotspot:hotspot_id!inner (
            id,
            type_id,
            time,
            location,
            active_status,
            status,
            crime_type:type_id (
              id,
              name,
              level,
              category,
              description
            )
          ),
          participant:thread_participants!thread_participants_thread_id_fkey (
            user_id,
            unread_count,
            last_read_at,
            is_following
          )
        ''')
          .gte('hotspot.time', thirtyDaysAgo)
          .eq('hotspot.status', 'approved');

      if (statusFilter != null && statusFilter != 'all') {
        query = query.eq('is_active', statusFilter == 'active');
      }

      if (crimeTypeFilter != null && crimeTypeFilter.isNotEmpty) {
        query = query.eq('hotspot.crime_type.name', crimeTypeFilter);
      }

      final response = await query.order('last_message_at', ascending: false);

      print('✅ Fetched ${response.length} threads with participant info');

      List<ReportThread> threads = [];
      for (var json in response) {
        try {
          var thread = ReportThread.fromJson(json);

          // ✅ FIXED: Properly check participant data
          final participantData = json['participant'];
          int unreadCount = 0;
          bool isFollowing = false;
          bool hasJoined = false;

          if (participantData is List && participantData.isNotEmpty) {
            // Find this user's participant record
            final userParticipant = participantData.firstWhere(
              (p) => p['user_id'] == userId,
              orElse: () => null,
            );

            if (userParticipant != null) {
              hasJoined = true;
              unreadCount = userParticipant['unread_count'] as int? ?? 0;
              isFollowing = userParticipant['is_following'] as bool? ?? false;
            }
          }

          // ✅ CRITICAL FIX: Only show as unread if:
          // 1. User has joined AND has unread messages (unreadCount > 0)
          // 2. OR user hasn't joined at all (hasJoined = false)
          // This prevents showing all threads as unread after sending a message
          thread = thread.copyWith(
            unreadCount: unreadCount,
            isFollowing: hasJoined
                ? isFollowing
                : false, // false if not joined (shows as NEW)
          );

          if (userLocation != null) {
            final distance = _calculateDistance(userLocation, thread.location);
            thread = thread.copyWith(distanceFromUser: distance);
          }

          threads.add(thread);

          // Debug log for the first few threads
          if (threads.length <= 3) {
            print('Thread: ${thread.title}');
            print(
              '  hasJoined: $hasJoined, unreadCount: $unreadCount, isFollowing: $isFollowing',
            );
          }
        } catch (e) {
          print('Error parsing thread: $e');
        }
      }

      return threads;
    } catch (e) {
      print('❌ Error fetching threads: $e');
      rethrow;
    }
  }

  // lib/thread/thread_service.dart - ADD THIS METHOD

  /// Join a thread explicitly
  Future<void> joinThread(String threadId, String userId) async {
    try {
      print('🔵 Joining thread: $threadId for user: $userId');

      await _supabase.from('thread_participants').upsert({
        'thread_id': threadId,
        'user_id': userId,
        'is_following': true,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
        'unread_count': 0,
      }, onConflict: 'thread_id,user_id');

      print('✅ Successfully joined thread: $threadId');
    } catch (e) {
      print('❌ Error joining thread: $e');
      rethrow;
    }
  }

  /// Leave a thread
  Future<void> leaveThread(String threadId, String userId) async {
    try {
      await _supabase
          .from('thread_participants')
          .update({'is_following': false})
          .eq('thread_id', threadId)
          .eq('user_id', userId);

      print('✅ Left thread: $threadId');
    } catch (e) {
      print('Error leaving thread: $e');
      rethrow;
    }
  }

  /// Get count of threads that have unread messages (not total unread messages)
  Future<int> getUnreadThreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('thread_participants')
          .select('thread_id')
          .eq('user_id', userId)
          .gt('unread_count', 0);

      // Count how many threads have unread messages
      return response.length;
    } catch (e) {
      print('Error getting unread thread count: $e');
      return 0;
    }
  }

  /// Get total unread message count across all threads
  Future<int> getTotalUnreadMessageCount(String userId) async {
    try {
      final response = await _supabase
          .from('thread_participants')
          .select('unread_count')
          .eq('user_id', userId)
          .gt('unread_count', 0);

      int total = 0;
      for (var item in response) {
        total += (item['unread_count'] as int? ?? 0);
      }
      return total;
    } catch (e) {
      print('Error getting total unread message count: $e');
      return 0;
    }
  }

  /// Toggle follow/unfollow thread
  Future<void> toggleFollowThread(
    String threadId,
    String userId,
    bool isFollowing,
  ) async {
    try {
      await _supabase
          .from('thread_participants')
          .update({'is_following': isFollowing})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error toggling follow: $e');
      rethrow;
    }
  }

  /// Setup real-time subscription for thread list updates
  void subscribeToThreadUpdates(Function(List<ReportThread>) onUpdate) {
    _threadsChannel?.unsubscribe();

    _threadsChannel = _supabase
        .channel('report_threads_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'report_threads',
          callback: (payload) async {
            print('Thread update received: ${payload.eventType}');
            // Refetch threads when any change occurs
            final threads = await fetchThreads();
            onUpdate(threads);
          },
        )
        .subscribe();
  }

  /// Setup real-time subscription for messages in a specific thread
  /// ✅ UPDATED: Now includes onUpdateMessage callback
  void subscribeToThreadMessages(
    String threadId,
    Function(ThreadMessage) onNewMessage,
    Function(String) onDeleteMessage,
    Function(ThreadMessage) onUpdateMessage, // ✅ NEW parameter
  ) {
    _messagesChannel?.unsubscribe();

    _messagesChannel = _supabase
        .channel('thread_messages_$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thread_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) async {
            print('New message received');
            try {
              // Fetch full message with user details
              final response = await _supabase
                  .from('thread_messages')
                  .select('''
                    *,
                    user:user_id (
                      id,
                      full_name,
                      profile_picture_url,
                      role
                    ),
                    reply_to:reply_to_message_id (
                      id,
                      message,
                      user:user_id (
                        full_name
                      )
                    )
                  ''')
                  .eq('id', payload.newRecord['id'])
                  .single();

              final message = ThreadMessage.fromJson(response);
              onNewMessage(message);
            } catch (e) {
              print('Error fetching new message details: $e');
            }
          },
        )
        // ✅ NEW: Listen for UPDATE events
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'thread_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) async {
            print('Message updated');
            try {
              // Fetch full updated message with user details
              final response = await _supabase
                  .from('thread_messages')
                  .select('''
                    *,
                    user:user_id (
                      id,
                      full_name,
                      profile_picture_url,
                      role
                    ),
                    reply_to:reply_to_message_id (
                      id,
                      message,
                      user:user_id (
                        full_name
                      )
                    )
                  ''')
                  .eq('id', payload.newRecord['id'])
                  .single();

              final message = ThreadMessage.fromJson(response);

              // If message was soft-deleted, call onDeleteMessage instead
              if (message.isDeleted) {
                onDeleteMessage(message.id);
              } else {
                onUpdateMessage(message);
              }
            } catch (e) {
              print('Error fetching updated message details: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'thread_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final messageId = payload.oldRecord['id'] as String;
            onDeleteMessage(messageId);
          },
        )
        .subscribe();
  }

  /// Cleanup subscriptions
  void dispose() {
    _threadsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _participantsChannel?.unsubscribe();
  }

  /// Helper: Calculate distance between two coordinates (in kilometers)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  /// Sort threads by distance
  List<ReportThread> sortThreadsByDistance(
    List<ReportThread> threads,
    LatLng userLocation,
  ) {
    final threadsWithDistance = threads.map((thread) {
      final distance = _calculateDistance(userLocation, thread.location);
      return thread.copyWith(distanceFromUser: distance);
    }).toList();

    threadsWithDistance.sort((a, b) {
      final distA = a.distanceFromUser ?? double.infinity;
      final distB = b.distanceFromUser ?? double.infinity;
      return distA.compareTo(distB);
    });

    return threadsWithDistance;
  }

  /// Sort threads by recent activity
  List<ReportThread> sortThreadsByRecent(List<ReportThread> threads) {
    threads.sort((a, b) {
      final dateA = a.lastMessageAt ?? a.createdAt;
      final dateB = b.lastMessageAt ?? b.createdAt;
      return dateB.compareTo(dateA);
    });
    return threads;
  }

  /// Sort threads by message count (most active)
  List<ReportThread> sortThreadsByActivity(List<ReportThread> threads) {
    threads.sort((a, b) => b.messageCount.compareTo(a.messageCount));
    return threads;
  }

  /// Group threads by crime type
  Map<String, List<ReportThread>> groupThreadsByCrimeType(
    List<ReportThread> threads,
  ) {
    final Map<String, List<ReportThread>> grouped = {};

    for (var thread in threads) {
      if (!grouped.containsKey(thread.crimeType)) {
        grouped[thread.crimeType] = [];
      }
      grouped[thread.crimeType]!.add(thread);
    }

    return grouped;
  }
}
