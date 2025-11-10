// ignore_for_file: unnecessary_cast

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zecure/chatbox/chat_model.dart';


class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // CHANNEL OPERATIONS
  // ============================================

  // Get all active channels
  Future<List<ChatChannel>> getAllChannels() async {
    try {
      final response = await _supabase
          .from('chat_channels')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ChatChannel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading channels: $e');
      return [];
    }
  }

  // Get channels user has joined
Future<List<ChatChannel>> getJoinedChannels(String userId) async {
  try {
    print('🔍 Fetching joined channels for user: $userId');
    
    final response = await _supabase
        .from('channel_members')
        .select('channel_id, chat_channels(*)')
        .eq('user_id', userId);

    print('📦 Raw response: $response');
    print('📊 Number of joined channels: ${(response as List).length}');

    final channels = (response as List)
        .map((json) {
          print('🏷️  Processing channel: ${json['chat_channels']['name']}');
          return ChatChannel.fromJson(json['chat_channels']);
        })
        .toList();

    print('✅ Successfully loaded ${channels.length} joined channels');
    return channels;
  } catch (e) {
    print('❌ Error loading joined channels: $e');
    print('Stack trace: ${StackTrace.current}');
    return [];
  }
}

 Future<ChatChannel?> createChannel({
  required String name,
  String? description,
  required String channelType,
  String? barangay,
  required String createdBy,
  bool isPrivate = false,
}) async {
  try {
    // Create the channel - DON'T set member_count, let trigger handle it
    final response = await _supabase
        .from('chat_channels')
        .insert({
          'name': name,
          'description': description,
          'channel_type': channelType,
          'barangay': barangay,
          'created_by': createdBy,
          'is_private': isPrivate,
          // Removed member_count: 0 - let the trigger handle it
        })
        .select()
        .single();

    final channel = ChatChannel.fromJson(response);

    // Auto-join creator to channel as admin
try {
  await _supabase.from('channel_members').insert({
    'channel_id': channel.id,
    'user_id': createdBy,
    'role': 'admin',
    'joined_at': DateTime.now().toIso8601String(),
    'last_read_at': DateTime(2020, 1, 1).toIso8601String(), // ✅ Set to past date like joinChannel
  });
  
  print('✅ Creator successfully joined channel as admin');
} catch (joinError) {
  print('❌ Error joining creator to channel: $joinError');
  // Try to delete the channel if joining failed
  await _supabase
      .from('chat_channels')
      .delete()
      .eq('id', channel.id);
  return null;
}

    return channel;
  } catch (e) {
    print('❌ Error creating channel: $e');
    return null;
  }
}

// Join a channel
Future<bool> joinChannel(String channelId, String userId, {String role = 'member'}) async {
  try {
    await _supabase.from('channel_members').insert({
      'channel_id': channelId,
      'user_id': userId,
      'role': role,
      'joined_at': DateTime.now().toIso8601String(),
      'last_read_at': DateTime(2020, 1, 1).toIso8601String(), // ✅ Set to past date so existing messages are unread
    });
    return true;
  } catch (e) {
    print('Error joining channel: $e');
    return false;
  }
}

  // Leave a channel
  Future<bool> leaveChannel(String channelId, String userId) async {
    try {
      await _supabase
          .from('channel_members')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error leaving channel: $e');
      return false;
    }
  }

  // Check if user is member of channel
  Future<bool> isMemberOfChannel(String channelId, String userId) async {
    try {
      final response = await _supabase
          .from('channel_members')
          .select()
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking membership: $e');
      return false;
    }
  }

  // Get channel members
 // Replace your getChannelMembers method with this:

Future<List<ChannelMember>> getChannelMembers(String channelId) async {
  try {
    print('');
    print('👥 FETCHING CHANNEL MEMBERS');
    print('   Channel ID: $channelId');
    
    // Call the database function instead of direct query
    final response = await _supabase
        .rpc('get_channel_members', params: {
          'p_channel_id': channelId,
        });

    print('   📦 Raw response: $response');
    print('   📊 Number of members: ${(response as List).length}');

    if ((response).isEmpty) {
      print('   ⚠️ No members found or you are not a member of this channel!');
      return [];
    }

    final members = (response as List).map((json) {
      print('   👤 Processing member:');
      print('      Member ID: ${json['id']}');
      print('      User ID: ${json['user_id']}');
      print('      Role: ${json['role']}');
      print('      Username: ${json['username']}');
      print('      Full name: ${json['full_name']}');
      
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
    }).toList();

    print('   ✅ Successfully loaded ${members.length} members');
    print('');
    
    return members;
  } catch (e, stackTrace) {
    print('');
    print('❌ ERROR LOADING MEMBERS');
    print('   Error: $e');
    print('   Stack trace: $stackTrace');
    print('');
    return [];
  }
}

  // ============================================
  // MESSAGE OPERATIONS
  // ============================================

 Future<List<ChatMessage>> getMessages(String channelId, {int limit = 50}) async {
  try {
    print('📥 Loading messages for channel: $channelId');
    
    // Get messages without user join to avoid relationship error
    final response = await _supabase
        .from('chat_messages')
        .select()
        .eq('channel_id', channelId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);

    print('   Found ${(response as List).length} messages');

    // Get unique user IDs
    final userIds = (response as List)
        .map((msg) => msg['user_id'] as String)
        .toSet()
        .toList();

    print('   Loading user data for ${userIds.length} users...');

    // Fetch user data separately
    Map<String, Map<String, dynamic>> usersData = {};
    try {
      final users = await _supabase
          .from('users')
          .select('id, username, full_name, profile_picture_url')
          .inFilter('id', userIds);

      for (var user in users as List) {
        usersData[user['id']] = user;
      }
      print('   Loaded ${usersData.length} user profiles');
    } catch (e) {
      print('   ⚠️ Could not fetch user data: $e');
      // Continue without user data
    }

    // Combine messages with user data
    final messages = (response as List).map((json) {
      final userId = json['user_id'] as String;
      final userData = usersData[userId];
      
      return ChatMessage.fromJson({
        ...json,
        'username': userData?['username'],
        'full_name': userData?['full_name'],
        'profile_picture_url': userData?['profile_picture_url'],
      });
    }).toList();

    print('✅ Successfully loaded ${messages.length} messages');
    return messages;
  } catch (e) {
    print('❌ Error loading messages: $e');
    return [];
  }
}

 Future<ChatMessage?> sendMessage({
  required String channelId,
  required String userId,
  required String message,
  String? replyToMessageId,
}) async {
  try {
    print('');
    print('╔════════════════════════════════════════');
    print('📤 SENDING MESSAGE');
    print('╚════════════════════════════════════════');
    print('📍 Channel ID: $channelId');
    print('👤 User ID: $userId');
    print('💬 Message: "$message"');
    print('↩️ Reply to: ${replyToMessageId ?? "none"}');

    // First, verify user is a member of the channel
    print('');
    print('🔍 Checking membership...');
    final isMember = await isMemberOfChannel(channelId, userId);
    print('   Result: ${isMember ? "✅ IS MEMBER" : "❌ NOT A MEMBER"}');
    
    if (!isMember) {
      print('❌ FAILED: User is not a member of this channel!');
      print('╚════════════════════════════════════════');
      return null;
    }

    print('');
    print('📡 Inserting message into database...');
    
    // Try inserting the message
    final response = await _supabase
        .from('chat_messages')
        .insert({
          'channel_id': channelId,
          'user_id': userId,
          'message': message,
          'reply_to_message_id': replyToMessageId,
        })
        .select('*, users(username, full_name, profile_picture_url)')
        .single();

    print('✅ Message inserted successfully!');
    print('   Message ID: ${response['id']}');
    
    final userData = response['users'];
    final chatMessage = ChatMessage.fromJson({
      ...response,
      'username': userData?['username'],
      'full_name': userData?['full_name'],
      'profile_picture_url': userData?['profile_picture_url'],
    });
    
    print('✅ Message object created');
    print('╚════════════════════════════════════════');
    print('');
    
    return chatMessage;
  } on PostgrestException catch (e) {
    print('');
    print('╔════════════════════════════════════════');
    print('❌ POSTGRESQL ERROR');
    print('╚════════════════════════════════════════');
    print('Code: ${e.code}');
    print('Message: ${e.message}');
    print('Details: ${e.details}');
    print('Hint: ${e.hint}');
    print('╚════════════════════════════════════════');
    print('');
    
    // Check for specific RLS policy violation
    if (e.code == 'PGRST200' || e.message.contains('relationship')) {
      print('⚠️ This appears to be an RLS policy issue');
      print('💡 Suggestion: Check your database policies and functions');
    }
    
    return null;
  } catch (e, stackTrace) {
    print('');
    print('╔════════════════════════════════════════');
    print('❌ ERROR SENDING MESSAGE');
    print('╚════════════════════════════════════════');
    print('Error: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
    print('╚════════════════════════════════════════');
    print('');
    return null;
  }
}

  // Edit a message
  Future<bool> editMessage(String messageId, String newMessage) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({
            'message': newMessage,
            'is_edited': true,
          })
          .eq('id', messageId);
      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  // Delete a message (soft delete)
Future<bool> deleteMessage(String messageId) async {
  try {
    await _supabase
        .from('chat_messages')
        .update({
          'is_deleted': true,
          'message': '', // ✅ Clear the message content for privacy
        })
        .eq('id', messageId);
    return true;
  } catch (e) {
    print('Error deleting message: $e');
    return false;
  }
}

Future<ChatMessage?> getMessageById(String messageId) async {
  try {
    print('📥 Fetching message by ID: $messageId');
    
    final response = await _supabase
        .from('chat_messages')
        .select('*, users(username, full_name, profile_picture_url)')
        .eq('id', messageId)
        .maybeSingle();

    if (response == null) {
      print('⚠️ Message not found: $messageId');
      return null;
    }

    final userData = response['users'];
    
    return ChatMessage.fromJson({
      ...response,
      'username': userData?['username'],
      'full_name': userData?['full_name'],
      'profile_picture_url': userData?['profile_picture_url'],
    });
  } catch (e) {
    print('❌ Error fetching message: $e');
    return null;
  }
}

  // ============================================
  // REALTIME SUBSCRIPTIONS
  // ============================================
// Subscribe to new messages in a channel
RealtimeChannel subscribeToMessages(
  String channelId,
  void Function(ChatMessage, PostgresChangeEvent) onMessageChange,
) {
  final channel = _supabase.channel('messages:$channelId');

  // Listen for inserts (new messages)
  channel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'chat_messages',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'channel_id',
      value: channelId,
    ),
    callback: (payload) async {
      // Fetch user details for the message
      final userId = payload.newRecord['user_id'];
      final userResponse = await _supabase
          .from('users')
          .select('username, full_name, profile_picture_url')
          .eq('id', userId)
          .single();

      final message = ChatMessage.fromJson({
        ...payload.newRecord,
        'username': userResponse['username'],
        'full_name': userResponse['full_name'],
        'profile_picture_url': userResponse['profile_picture_url'],
      });

      onMessageChange(message, PostgresChangeEvent.insert);
    },
  );

  // Listen for updates (edits and soft-deletes)
  channel.onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'chat_messages',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'channel_id',
      value: channelId,
    ),
    callback: (payload) async {
      // Fetch user details for the message (consistent with insert)
      final userId = payload.newRecord['user_id'];
      final userResponse = await _supabase
          .from('users')
          .select('username, full_name, profile_picture_url')
          .eq('id', userId)
          .single();

      final message = ChatMessage.fromJson({
        ...payload.newRecord,
        'username': userResponse['username'],
        'full_name': userResponse['full_name'],
        'profile_picture_url': userResponse['profile_picture_url'],
      });

      onMessageChange(message, PostgresChangeEvent.update);
    },
  );

  return channel.subscribe();
}

// Replace your subscribeToAllMessages method in chat_service.dart with this:

RealtimeChannel subscribeToAllMessages(
  void Function() onNewMessage,
) {
  print('🔔 Setting up real-time subscription for ALL messages...');
  
  return _supabase
      .channel('chat-updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        callback: (payload) {
          print('');
          print('🆕 NEW MESSAGE DETECTED IN DATABASE!');
          print('   Message ID: ${payload.newRecord['id']}');
          print('   Channel ID: ${payload.newRecord['channel_id']}');
          print('   User ID: ${payload.newRecord['user_id']}');
          print('   Message: ${payload.newRecord['message']}');
          print('   🔄 Triggering unread count reload...');
          print('');
          
          onNewMessage();
        },
      )
      .subscribe((status, [error]) {  // ✅ FIXED: Proper callback signature
        print('📡 Subscription status: $status');
        if (error != null) {
          print('❌ Subscription error: $error');
        }
      });
}
  // Subscribe to channel updates
  RealtimeChannel subscribeToChannels(
    void Function() onChannelUpdate,
  ) {
    return _supabase
        .channel('channels')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_channels',
          callback: (payload) {
            onChannelUpdate();
          },
        )
        .subscribe();
  }

  // Update last read timestamp
Future<void> updateLastRead(String channelId, String userId) async {
  try {
    print('');
    print('📖 UPDATING LAST READ');
    print('   Channel: $channelId');
    print('   User: $userId');
    print('   Timestamp: ${DateTime.now().toIso8601String()}');
    
    await _supabase
        .from('channel_members')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('channel_id', channelId)
        .eq('user_id', userId);
    
    print('✅ Last read updated successfully');
    print('');
  } catch (e) {
    print('❌ Error updating last read: $e');
    print('');
  }
}



Future<int> getUnreadCount(String channelId, String userId) async {
  try {
    // Get user's last read timestamp
    final memberResponse = await _supabase
        .from('channel_members')
        .select('last_read_at')
        .eq('channel_id', channelId)
        .eq('user_id', userId)
        .maybeSingle();

    if (memberResponse == null) {
      return 0;
    }

    final lastReadAt = DateTime.parse(memberResponse['last_read_at']);

    // Count messages after that timestamp, excluding user's own messages
    final countResponse = await _supabase
        .from('chat_messages')
        .select('id, created_at, user_id')
        .eq('channel_id', channelId)
        .eq('is_deleted', false)
        .neq('user_id', userId)
        .gt('created_at', lastReadAt.toIso8601String());

    final messages = countResponse as List;
    
    // ✅ Add detailed logging
    if (messages.isNotEmpty) {
      print('   📊 Unread messages for channel $channelId:');
      print('      Last read: $lastReadAt');
      print('      Unread count: ${messages.length}');
      for (var msg in messages.take(3)) {
        print('      - Message at ${msg['created_at']} from ${msg['user_id']}');
      }
    }

    return messages.length;
  } catch (e) {
    print('❌ Error getting unread count: $e');
    return 0;
  }
}

}