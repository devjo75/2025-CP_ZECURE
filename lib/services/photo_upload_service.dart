import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class PhotoService {
  static const String bucketName = 'hotspot-photos';
  
  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
  
  static Future<XFile?> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      return image;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> uploadPhoto({
    required XFile imageFile,
    required int hotspotId,
    required String userId,
  }) async {
    String? uploadedFilePath;
    
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExtension = path.extension(imageFile.name).toLowerCase();
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      
      // Generate unique filename
      final fileName = 'hotspot_${hotspotId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = '$userId/$fileName';
      uploadedFilePath = filePath;
      
      // Upload to Supabase Storage first
      final uploadResponse = await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(filePath, bytes);
      
      if (uploadResponse.isEmpty) {
        throw Exception('Failed to upload image to storage');
      }
      
      print('File uploaded successfully to storage: $filePath');
      
      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(filePath);
      
      print('Generated public URL: $publicUrl');
      
      // Save photo record to database
      final photoRecord = await Supabase.instance.client
          .from('hotspot_photos')
          .insert({
            'hotspot_id': hotspotId,
            'photo_url': publicUrl,
            'photo_path': filePath,
            'file_name': fileName,
            'file_size': bytes.length,
            'mime_type': mimeType,
            'created_by': userId,
          })
          .select()
          .single();
      
      print('Photo record saved to database: ${photoRecord['id']}');
      
      return photoRecord;
    } catch (e) {
      print('Error uploading photo: $e');
      
      // If database insert failed but file was uploaded, clean up the file
      if (uploadedFilePath != null && e.toString().contains('hotspot_photos')) {
        try {
          await Supabase.instance.client.storage
              .from(bucketName)
              .remove([uploadedFilePath]);
          print('Cleaned up uploaded file after database error');
        } catch (cleanupError) {
          print('Failed to clean up file: $cleanupError');
        }
      }
      
      throw Exception('Failed to upload photo: $e');
    }
  }
  
  static Future<void> deletePhoto(Map<String, dynamic> photoRecord) async {
    try {
      final photoPath = photoRecord['photo_path'];
      
      // Delete from storage
      await Supabase.instance.client.storage
          .from(bucketName)
          .remove([photoPath]);
      
      // Delete from database
      await Supabase.instance.client
          .from('hotspot_photos')
          .delete()
          .eq('id', photoRecord['id']);
      
    } catch (e) {
      print('Error deleting photo: $e');
      throw Exception('Failed to delete photo: $e');
    }
  }
  
  static Future<Map<String, dynamic>?> getHotspotPhoto(int hotspotId) async {
    try {
      final response = await Supabase.instance.client
          .from('hotspot_photos')
          .select()
          .eq('hotspot_id', hotspotId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error getting hotspot photo: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>?> updatePhoto({
    required XFile newImageFile,
    required Map<String, dynamic> existingPhotoRecord,
    required String userId,
  }) async {
    try {
      // Delete old photo first
      await deletePhoto(existingPhotoRecord);
      
      // Upload new photo
      final newPhotoRecord = await uploadPhoto(
        imageFile: newImageFile,
        hotspotId: existingPhotoRecord['hotspot_id'],
        userId: userId,
      );
      
      return newPhotoRecord;
    } catch (e) {
      print('Error updating photo: $e');
      throw Exception('Failed to update photo: $e');
    }
  }
  
  // Helper method to check if user is authenticated (for upload permissions)
  static bool isUserAuthenticated() {
    return Supabase.instance.client.auth.currentUser != null;
  }
}