import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class PhotoUploadService {
  static const String bucketName = 'hotspot_photos';
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery or camera
  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: ${e.toString()}');
    }
  }

  /// Show image source selection dialog
  Future<XFile?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImage(source: ImageSource.camera);
                  if (context.mounted) {
                    Navigator.pop(context, image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImage(source: ImageSource.gallery);
                  if (context.mounted) {
                    Navigator.pop(context, image);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Upload image to Supabase Storage
  Future<String> uploadImage({
    required XFile imageFile,
    required String userId,
    String? hotspotId,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.name);
      final fileName = hotspotId != null 
          ? 'hotspot_${hotspotId}_$timestamp$extension'
          : 'temp_${userId}_$timestamp$extension';

      // Get file data
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = await imageFile.readAsBytes();
      } else {
        final file = File(imageFile.path);
        fileBytes = await file.readAsBytes();
      }

      // Upload to Supabase Storage
      final _ = await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Storage error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Save photo metadata to database
  Future<String> savePhotoToDatabase({
    required int hotspotId,
    required String photoUrl,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('hotspot_photos')
          .insert({
            'hotspot_id': hotspotId,
            'photo_url': photoUrl,
            'uploaded_by': userId,
          })
          .select('id')
          .single();

      return response['id'];
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to save photo metadata: ${e.toString()}');
    }
  }

  /// Complete photo upload process (upload + save metadata)
  Future<String> uploadAndSavePhoto({
    required XFile imageFile,
    required int hotspotId,
    required String userId,
  }) async {
    try {
      // Upload image first
      final photoUrl = await uploadImage(
        imageFile: imageFile,
        userId: userId,
        hotspotId: hotspotId.toString(),
      );

      // Save metadata to database
      final photoId = await savePhotoToDatabase(
        hotspotId: hotspotId,
        photoUrl: photoUrl,
        userId: userId,
      );

      return photoId;
    } catch (e) {
      rethrow;
    }
  }

  /// Get photos for a specific hotspot
  Future<List<Map<String, dynamic>>> getHotspotPhotos(int hotspotId) async {
    try {
      final response = await _supabase
          .from('hotspot_photos')
          .select('''
            id,
            photo_url,
            created_at,
            uploaded_by,
            users: uploaded_by (first_name, last_name)
          ''')
          .eq('hotspot_id', hotspotId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get hotspot photos: ${e.toString()}');
    }
  }

  /// Delete photo from storage and database
  Future<void> deletePhoto({
    required String photoId,
    required String photoUrl,
  }) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(photoUrl);
      final fileName = path.basename(uri.path);

      // Delete from storage
      await _supabase.storage
          .from(bucketName)
          .remove([fileName]);

      // Delete from database
      await _supabase
          .from('hotspot_photos')
          .delete()
          .eq('id', photoId);
    } on StorageException catch (e) {
      throw Exception('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete photo: ${e.toString()}');
    }
  }

  /// Validate image file
  bool isValidImage(XFile file) {
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    const _ = 5 * 1024 * 1024; // 5MB

    final extension = path.extension(file.name).toLowerCase();
    
    // Check extension
    if (!allowedExtensions.contains(extension)) {
      return false;
    }

    // Check file size (Note: XFile doesn't provide size directly on all platforms)
    // You might need to read the file to check size if needed
    
    return true;
  }

  /// Compress image if needed (for future implementation)
  Future<XFile?> compressImage(XFile file) async {
    // This is a placeholder for image compression
    // You can implement using packages like flutter_image_compress
    return file;
  }
}