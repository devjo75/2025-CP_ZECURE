// ignore_for_file: avoid_print

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class HotspotSupportService {
  static final _supabase = Supabase.instance.client;

  /// Check if there are nearby hotspots within specified distance
  static Future<List<Map<String, dynamic>>> getNearbyHotspots({
    required double latitude,
    required double longitude,
    int distanceMeters = 50,
    String? userId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_nearby_hotspots_with_support',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_distance_meters': distanceMeters,
          'p_user_id': userId,
        },
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting nearby hotspots: $e');
      rethrow;
    }
  }

  /// Get detailed information about a specific hotspot with support data
  static Future<Map<String, dynamic>?> getHotspotWithSupports(
    int hotspotId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_hotspot_with_supports',
        params: {'p_hotspot_id': hotspotId},
      );

      if (response != null && response.isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
      return null;
    } catch (e) {
      print('Error getting hotspot with supports: $e');
      rethrow;
    }
  }

  /// Add support to a hotspot
  static Future<Map<String, dynamic>> addSupport({
    required int hotspotId,
    required String supporterId,
    String? description,
    XFile? photo,
  }) async {
    try {
      String? photoUrl;
      String? photoPath;
      String? fileName;
      int? fileSize;
      String? mimeType;

      // Upload photo if provided
      if (photo != null) {
        final uploadResult = await _uploadSupportPhoto(
          photo: photo,
          hotspotId: hotspotId,
          supporterId: supporterId,
        );

        photoUrl = uploadResult['url'];
        photoPath = uploadResult['path'];
        fileName = uploadResult['fileName'];
        fileSize = uploadResult['fileSize'];
        mimeType = uploadResult['mimeType'];
      }

      // Insert support record
      final response = await _supabase
          .from('hotspot_supports')
          .insert({
            'hotspot_id': hotspotId,
            'supporter_id': supporterId,
            'description': description?.trim().isNotEmpty == true
                ? description!.trim()
                : null,
            'photo_url': photoUrl,
            'photo_path': photoPath,
            'file_name': fileName,
            'file_size': fileSize,
            'mime_type': mimeType,
          })
          .select()
          .single();

      print('✅ Support added successfully for hotspot $hotspotId');
      return response;
    } catch (e) {
      print('❌ Error adding support: $e');
      rethrow;
    }
  }

  /// Get a specific support by user for a hotspot
  static Future<Map<String, dynamic>?> getUserSupportForHotspot({
    required int hotspotId,
    required String? userId, // ✅ Make nullable
  }) async {
    try {
      if (userId == null) return null; // ✅ Add null check

      final response = await _supabase
          .from('hotspot_supports')
          .select('*')
          .eq('hotspot_id', hotspotId)
          .eq('supporter_id', userId)
          .maybeSingle(); // ✅ Already correct!

      return response;
    } catch (e) {
      print('Error getting user support: $e');
      return null;
    }
  }

  /// Update existing support
  /// Update existing support
  static Future<Map<String, dynamic>> updateSupport({
    required int hotspotId,
    required String supporterId,
    String? description,
    XFile? photo,
  }) async {
    try {
      // ✅ STEP 1: Verify support exists
      final existingSupport = await _supabase
          .from('hotspot_supports')
          .select('*')
          .eq('hotspot_id', hotspotId)
          .eq('supporter_id', supporterId)
          .maybeSingle();

      if (existingSupport == null) {
        throw Exception(
          'Support not found. You may not have supported this hotspot yet.',
        );
      }

      String? photoUrl = existingSupport['photo_url'];
      String? photoPath = existingSupport['photo_path'];
      String? fileName = existingSupport['file_name'];
      int? fileSize = existingSupport['file_size'];
      String? mimeType = existingSupport['mime_type'];

      // ✅ STEP 2: Upload new photo if provided
      if (photo != null) {
        try {
          // Delete old photo if exists
          if (photoPath != null) {
            await _deleteSupportPhoto(photoPath);
          }

          final uploadResult = await _uploadSupportPhoto(
            photo: photo,
            hotspotId: hotspotId,
            supporterId: supporterId,
          );

          photoUrl = uploadResult['url'];
          photoPath = uploadResult['path'];
          fileName = uploadResult['fileName'];
          fileSize = uploadResult['fileSize'];
          mimeType = uploadResult['mimeType'];
        } catch (e) {
          print('Error uploading new photo: $e');
          throw Exception('Failed to upload new photo: ${e.toString()}');
        }
      }

      // ✅ STEP 3: Update support record
      final updateData = {
        'description': description?.trim().isNotEmpty == true
            ? description!.trim()
            : null,
        'photo_url': photoUrl,
        'photo_path': photoPath,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase
          .from('hotspot_supports')
          .update(updateData)
          .eq('hotspot_id', hotspotId)
          .eq('supporter_id', supporterId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Update failed - support record may have been deleted');
      }

      print('✅ Support updated successfully for hotspot $hotspotId');
      return response;
    } catch (e) {
      print('❌ Error updating support: $e');
      rethrow;
    }
  }

  /// Remove support AND its notification with proper error handling
  static Future<void> removeSupport({
    required int hotspotId,
    required String supporterId,
  }) async {
    try {
      // ✅ STEP 1: Delete the support photo if it exists
      final support = await _supabase
          .from('hotspot_supports')
          .select('photo_path')
          .eq('hotspot_id', hotspotId)
          .eq('supporter_id', supporterId)
          .maybeSingle();

      if (support != null && support['photo_path'] != null) {
        try {
          await _deleteSupportPhoto(support['photo_path']);
        } catch (e) {
          print('⚠️ Failed to delete photo, continuing: $e');
          // Don't block the operation if photo deletion fails
        }
      }

      // ✅ STEP 2: Delete ALL related notifications (not just nearby_hotspot type)
      try {
        await _supabase
            .from('notifications')
            .delete()
            .eq('hotspot_id', hotspotId)
            .eq('user_id', supporterId);

        print(
          '✅ Deleted all notifications for user $supporterId on hotspot $hotspotId',
        );
      } catch (e) {
        print('⚠️ Failed to delete notifications, continuing: $e');
        // Don't block if notification deletion fails
      }

      // ✅ STEP 3: Delete the support record
      await _supabase
          .from('hotspot_supports')
          .delete()
          .eq('hotspot_id', hotspotId)
          .eq('supporter_id', supporterId);

      print('✅ Support removed successfully for hotspot $hotspotId');
    } catch (e) {
      print('❌ Error removing support: $e');
      rethrow;
    }
  }

  /// Delete all support photos for a hotspot (used when deleting hotspot)
  static Future<void> deleteAllSupportPhotos(int hotspotId) async {
    try {
      final supports = await getHotspotSupports(hotspotId);

      for (final support in supports) {
        if (support['photo_path'] != null) {
          await _deleteSupportPhoto(support['photo_path']);
        }
      }

      print('✅ All support photos deleted for hotspot $hotspotId');
    } catch (e) {
      print('❌ Error deleting support photos: $e');
      // Don't rethrow - this shouldn't block hotspot deletion
    }
  }

  /// Check if user has already supported a hotspot
  static Future<bool> hasUserSupported({
    required int hotspotId,
    required String userId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'has_user_supported_hotspot',
        params: {'p_hotspot_id': hotspotId, 'p_user_id': userId},
      );

      return response == true;
    } catch (e) {
      print('Error checking support status: $e');
      return false;
    }
  }

  /// Get all supports for a specific hotspot
  static Future<List<Map<String, dynamic>>> getHotspotSupports(
    int hotspotId,
  ) async {
    try {
      final response = await _supabase
          .from('hotspot_supports')
          .select('''
            *,
            supporter:supporter_id (
              id,
              full_name,
              username,
              email
            )
          ''')
          .eq('hotspot_id', hotspotId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting hotspot supports: $e');
      rethrow;
    }
  }

  /// Get all hotspots supported by a user
  static Future<List<Map<String, dynamic>>> getUserSupportedHotspots(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('user_supported_hotspots')
          .select('*')
          .eq('supporter_id', userId)
          .order('support_added_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user supported hotspots: $e');
      rethrow;
    }
  }

  /// Upload support photo to storage
  static Future<Map<String, dynamic>> _uploadSupportPhoto({
    required XFile photo,
    required int hotspotId,
    required String supporterId,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      final fileExtension = path.extension(photo.path);
      final fileName =
          'support_${hotspotId}_${supporterId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = 'hotspot_support_photos/$supporterId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('hotspot_support_photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: photo.mimeType ?? 'image/jpeg',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('hotspot_support_photos')
          .getPublicUrl(filePath);

      return {
        'url': publicUrl,
        'path': filePath,
        'fileName': fileName,
        'fileSize': bytes.length,
        'mimeType': photo.mimeType ?? 'image/jpeg',
      };
    } catch (e) {
      print('Error uploading support photo: $e');
      rethrow;
    }
  }

  /// Delete support photo from storage
  static Future<void> _deleteSupportPhoto(String photoPath) async {
    try {
      await _supabase.storage.from('hotspot_support_photos').remove([
        photoPath,
      ]);
      print('Support photo deleted: $photoPath');
    } catch (e) {
      print('Error deleting support photo: $e');
      // Don't rethrow - photo deletion failure shouldn't block support removal
    }
  }

  /// Get support statistics for a hotspot
  static Future<Map<String, dynamic>> getSupportStats(int hotspotId) async {
    try {
      final response = await _supabase
          .from('hotspot')
          .select('support_count')
          .eq('id', hotspotId)
          .single();

      final supports = await getHotspotSupports(hotspotId);

      final withPhotos = supports.where((s) => s['photo_url'] != null).length;
      final withDescriptions = supports
          .where(
            (s) =>
                s['description'] != null &&
                s['description'].toString().isNotEmpty,
          )
          .length;

      return {
        'total_supports': response['support_count'] ?? 0,
        'supports_with_photos': withPhotos,
        'supports_with_descriptions': withDescriptions,
        'recent_supporters': supports
            .take(5)
            .map((s) => s['supporter'])
            .toList(),
      };
    } catch (e) {
      print('Error getting support stats: $e');
      rethrow;
    }
  }

  /// Calculate confidence score (0-5 stars based on support count)
  static int calculateConfidenceStars(int supportCount) {
    if (supportCount == 0) return 0;
    if (supportCount == 1) return 1;
    if (supportCount <= 3) return 2;
    if (supportCount <= 5) return 3;
    if (supportCount <= 10) return 4;
    return 5; // 11+ supports
  }

  /// Get formatted support count text
  static String getFormattedSupportCount(int count) {
    if (count == 0) return 'No supports yet';
    if (count == 1) return '1 person supported';
    return '$count people supported';
  }
}
