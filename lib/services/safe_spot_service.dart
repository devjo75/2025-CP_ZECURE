import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class SafeSpotService {
  static final _client = Supabase.instance.client;

  // Fixed getSafeSpotTypes method
  static Future<List<Map<String, dynamic>>> getSafeSpotTypes() async {
    try {
      print('Fetching safe spot types from database...');
      
      final response = await _client
          .from('safe_spot_types')
          .select('*')
          .order('name');
      
      print('Database response: $response');
      print('Response type: ${response.runtimeType}');
      
      // More defensive conversion with null safety
      final result = response
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      print('Converted to list: $result');
      return result;
      } catch (e) {
      print('SafeSpotService.getSafeSpotTypes error: $e');
      throw Exception('Failed to load safe spot types: $e');
    }
  }

  // Get safe spots with filtering
  static Future<List<Map<String, dynamic>>> getSafeSpots({
    String? userId,
    bool isAdmin = false,
  }) async {
    try {
      var query = _client
          .from('safe_spots')
          .select('''
            *,
            safe_spot_types!inner (
              id,
              name,
              icon,
              description
            ),
            users!safe_spots_created_by_fkey (
              id,
              first_name,
              last_name,
              role
            )
          ''');

      // Apply RLS filtering - let the database handle the visibility logic
      final response = await query.order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SafeSpotService.getSafeSpots error: $e');
      throw Exception('Failed to load safe spots: $e');
    }
  }

  // UPDATED: Check if user is admin and auto-approve their submissions
  static Future<String?> createSafeSpot({
  required int typeId,
  required String name,
  required String? description,
  required LatLng location,
  required String userId,
}) async {
  try {
    // First, check if the user is an admin
    final userResponse = await _client
        .from('users')
        .select('role')
        .eq('id', userId)
        .single();
    
    final isAdmin = userResponse['role'] == 'admin';
    final status = isAdmin ? 'approved' : 'pending';
    final verified = isAdmin; // Admin submissions are automatically verified
    
    final insertData = {
      'type_id': typeId,
      'name': name,
    'description': description,
      'location': {
        'type': 'Point',
        'coordinates': [location.longitude, location.latitude],
      },
      'created_by': userId,
      'status': status,
      'verified': verified,
      'verified_by_admin': isAdmin, // Set to true for admin-created safe spots
    };

    final response = await _client
        .from('safe_spots')
        .insert(insertData)
        .select('id')
        .single();

    return response['id'] as String;
  } catch (e) {
    throw Exception('Failed to create safe spot: $e');
  }
}

// Update safe spot status (admin only)
static Future<void> updateSafeSpotStatus({
  required String safeSpotId,
  required String status,
  String? rejectionReason,
}) async {
  try {
    final Map<String, dynamic> updateData = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'verified': status == 'approved' ? true : false,
      'verified_by_admin': status == 'approved' ? true : false, // Set to true for admin-approved safe spots
    };

    if (status == 'rejected' && rejectionReason != null) {
      updateData['rejection_reason'] = rejectionReason;
    } else if (status == 'approved') {
      // When approving, remove any rejection reason by setting to null
      updateData['rejection_reason'] = null;
    }

    await _client
        .from('safe_spots')
        .update(updateData)
        .eq('id', safeSpotId);
  } catch (e) {
    throw Exception('Failed to update safe spot status: $e');
  }
}

  // Delete safe spot
  static Future<void> deleteSafeSpot(String safeSpotId) async {
    try {
      await _client
          .from('safe_spots')
          .delete()
          .eq('id', safeSpotId);
    } catch (e) {
      throw Exception('Failed to delete safe spot: $e');
    }
  }

// Updated SafeSpotService methods with proper validation
static Future<void> upvoteSafeSpot({
  required String safeSpotId,
  required String userId,
}) async {
  try {
    // Application-level validation - more reliable than complex RLS
    
    // 1. Get the safe spot details
    final safeSpotResponse = await _client
        .from('safe_spots')
        .select('id, status, created_by')
        .eq('id', safeSpotId)
        .single();
    
    // 2. Validate business rules
    if (safeSpotResponse['status'] != 'pending') {
      throw Exception('Can only vote on pending safe spots');
    }
    
    if (safeSpotResponse['created_by'] == userId) {
      throw Exception('Cannot vote on your own safe spot');
    }
    
    // 3. Check if user already voted
    final existingVote = await _client
        .from('safe_spot_upvotes')
        .select('id')
        .eq('safe_spot_id', safeSpotId)
        .eq('user_id', userId);
    
    if (existingVote.isNotEmpty) {
      throw Exception('You have already voted on this safe spot');
    }
    
    // 4. Insert the vote (simple RLS policy will handle basic auth)
    await _client
        .from('safe_spot_upvotes')
        .insert({
          'safe_spot_id': safeSpotId,
          'user_id': userId,
        });
    
  } catch (e) {
    throw Exception('Failed to upvote safe spot: $e');
  }
}

static Future<void> removeUpvote({
  required String safeSpotId,
  required String userId,
}) async {
  try {
    final result = await _client
        .from('safe_spot_upvotes')
        .delete()
        .eq('safe_spot_id', safeSpotId)
        .eq('user_id', userId)
        .select();
    
    if (result.isEmpty) {
      throw Exception('No upvote found to remove');
    }
    
  } catch (e) {
    throw Exception('Failed to remove upvote: $e');
  }
}

static Future<int> getSafeSpotUpvoteCount(String safeSpotId) async {
  try {
    final response = await _client
        .from('safe_spot_upvotes')
        .select('id')
        .eq('safe_spot_id', safeSpotId);
    
    return response.length;
  } catch (e) {
    print('Error getting upvote count: $e');
    return 0;
  }
}

static Future<bool> hasUserUpvoted({
  required String safeSpotId,
  required String userId,
}) async {
  try {
    final response = await _client
        .from('safe_spot_upvotes')
        .select('id')
        .eq('safe_spot_id', safeSpotId)
        .eq('user_id', userId);

    return response.isNotEmpty;
  } catch (e) {
    print('Error checking upvote status: $e');
    return false;
  }
}


  // Get safe spot upvotes count with user info
  static Future<Map<String, dynamic>> getSafeSpotUpvotes(String safeSpotId) async {
    try {
      final response = await _client
          .from('safe_spot_upvotes')
          .select('user_id, users!inner(full_name)')
          .eq('safe_spot_id', safeSpotId);

      return {
        'count': response.length,
        'upvotes': List<Map<String, dynamic>>.from(response),
      };
    } catch (e) {
      throw Exception('Failed to get upvotes: $e');
    }
  }

  // UPDATED: Update safe spot details with type_id support
static Future<void> updateSafeSpot({
  required String safeSpotId,
  required String name,
  required String? description,
  int? typeId,
}) async {
  try {
    final Map<String, dynamic> updateData = {
      'name': name,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (typeId != null) {
      updateData['type_id'] = typeId;
    }

    await _client
        .from('safe_spots')
        .update(updateData)
        .eq('id', safeSpotId);
  } catch (e) {
    throw Exception('Failed to update safe spot: $e');
  }
}

  // NEW: Check if user can edit a safe spot
  static bool canUserEditSafeSpot(Map<String, dynamic> safeSpot, Map<String, dynamic>? userProfile) {
    if (userProfile == null) return false;
    
    final isAdmin = userProfile['role'] == 'admin';
    final isOwner = safeSpot['created_by'] == userProfile['id'];
    final status = safeSpot['status'] ?? 'pending';
    
    // Admin can edit all safe spots
    if (isAdmin) return true;
    
    // Regular users can only edit their own pending safe spots
    return isOwner && status == 'pending';
  }
}