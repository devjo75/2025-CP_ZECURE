// UPDATED SavePointService to properly handle PostGIS geography data
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class SavePointService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Gets save points with proper PostGIS coordinate extraction
  Future<List<Map<String, dynamic>>> getUserSavePoints(String userId) async {
    try {
      print('Fetching save points for user: $userId');
      
      // Use ST_AsGeoJSON to properly extract coordinates from PostGIS geography
      final response = await _supabase
          .rpc('get_user_save_points_with_coords', params: {
            'user_id_param': userId,
          });

      print('Raw database response: $response');
      
      if (response is! List) {
        throw Exception('Unexpected response format: expected List, got ${response.runtimeType}');
      }
      
      final savePoints = <Map<String, dynamic>>[];
      
      for (final item in response) {
        if (item is Map<String, dynamic>) {
          try {
            // The RPC function should return proper GeoJSON
            final processedItem = Map<String, dynamic>.from(item);
            
            // Parse the location_geojson if it exists
            if (processedItem['location_geojson'] != null) {
              processedItem['location'] = processedItem['location_geojson'];
              processedItem.remove('location_geojson');
            }
            
            savePoints.add(processedItem);
          } catch (e) {
            print('⚠️ Error processing save point item: $e');
            continue;
          }
        } else {
          print('⚠️ Skipping invalid save point item: $item');
        }
      }
      
      print('Successfully processed ${savePoints.length} save points');
      return savePoints;
      
    } on PostgrestException catch (e) {
      print('PostgrestException in getUserSavePoints: ${e.message}');
      print('Details: ${e.details}');
      print('Hint: ${e.hint}');
      
      // Fallback to direct query with coordinate extraction
      try {
        return await _getUserSavePointsFallback(userId);
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      print('General error in getUserSavePoints: $e');
      throw Exception('Failed to fetch save points: $e');
    }
  }

  /// Fallback method that extracts coordinates directly
  Future<List<Map<String, dynamic>>> _getUserSavePointsFallback(String userId) async {
    print('Using fallback method for save points');
    
    final response = await _supabase
        .from('save_points')
        .select('''
          id,
          user_id,
          name,
          description,
          ST_X(location::geometry) as longitude,
          ST_Y(location::geometry) as latitude,
          created_at,
          updated_at
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final savePoints = <Map<String, dynamic>>[];
    
    for (final item in response) {
      try {
        final longitude = item['longitude'];
        final latitude = item['latitude'];
        
        if (longitude != null && latitude != null) {
          final processedItem = Map<String, dynamic>.from(item);
          
          // Create proper GeoJSON location
          processedItem['location'] = {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          };
          
          // Remove raw coordinate fields
          processedItem.remove('longitude');
          processedItem.remove('latitude');
          
          savePoints.add(processedItem);
        } else {
          print('⚠️ Skipping save point with null coordinates: ${item['id']}');
        }
      } catch (e) {
        print('⚠️ Error processing fallback save point: $e');
        continue;
      }
        }
    
    return savePoints;
  }

  /// Creates a new save point using the database function
  Future<Map<String, dynamic>> createSavePoint(Map<String, dynamic> savePointData) async {
    try {
      final coordinates = savePointData['location']['coordinates'];
      final longitude = coordinates[0];
      final latitude = coordinates[1];
      
      // Validate coordinates
      if (longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
        throw Exception('Invalid coordinates: longitude must be between -180 and 180, latitude between -90 and 90');
      }
      
      final response = await _supabase
          .rpc('create_save_point', params: {
            'user_id_param': savePointData['user_id'],
            'name_param': savePointData['name'],
            'description_param': savePointData['description'],
            'longitude_param': longitude,
            'latitude_param': latitude,
          });

      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      } else if (response is Map<String, dynamic>) {
        return response;
      } else {
        throw Exception('Unexpected response format from database function');
      }
      
    } on PostgrestException catch (e) {
      print('PostgrestException: ${e.message}');
      print('Details: ${e.details}');
      print('Hint: ${e.hint}');
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      print('General error: $e');
      throw Exception('Failed to create save point: $e');
    }
  }

  /// Updates an existing save point
  Future<Map<String, dynamic>> updateSavePoint(
    String savePointId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final dataToUpdate = Map<String, dynamic>.from(updateData);
      
      // Handle location update using RPC function
      if (updateData.containsKey('location')) {
        final coordinates = updateData['location']['coordinates'];
        final longitude = coordinates[0];
        final latitude = coordinates[1];
        
        // Update location using RPC function
        await _supabase.rpc('update_save_point_location', params: {
          'save_point_id': savePointId,
          'longitude_param': longitude,
          'latitude_param': latitude,
        });
        
        // Remove location from update data since it's handled separately
        dataToUpdate.remove('location');
      }
      
      // Update other fields if any
      if (dataToUpdate.isNotEmpty) {
        dataToUpdate['updated_at'] = DateTime.now().toIso8601String();
        
        await _supabase
            .from('save_points')
            .update(dataToUpdate)
            .eq('id', savePointId);
      }

      // Fetch and return the updated record
      return await getSavePointById(savePointId) ?? {};
      
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update save point: $e');
    }
  }

  /// Gets a specific save point by ID
  Future<Map<String, dynamic>?> getSavePointById(String savePointId) async {
    try {
      // First try with RPC function
      try {
        final response = await _supabase
            .rpc('get_save_point_by_id_with_coords', params: {
              'save_point_id_param': savePointId,
            });
            
        if (response is List && response.isNotEmpty) {
          final item = response.first;
          if (item['location_geojson'] != null) {
            item['location'] = item['location_geojson'];
            item.remove('location_geojson');
          }
          return Map<String, dynamic>.from(item);
        }
      } catch (rpcError) {
        print('RPC method failed, using fallback: $rpcError');
      }
      
      // Fallback method
      final response = await _supabase
          .from('save_points')
          .select('''
            id,
            user_id,
            name,
            description,
            ST_X(location::geometry) as longitude,
            ST_Y(location::geometry) as latitude,
            created_at,
            updated_at
          ''')
          .eq('id', savePointId)
          .maybeSingle();

      if (response != null) {
        final processedItem = Map<String, dynamic>.from(response);
        
        if (response['longitude'] != null && response['latitude'] != null) {
          processedItem['location'] = {
            'type': 'Point',
            'coordinates': [response['longitude'], response['latitude']],
          };
          
          processedItem.remove('longitude');
          processedItem.remove('latitude');
        }
        
        return processedItem;
      }
      
      return null;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch save point: $e');
    }
  }

  /// Deletes a save point
  Future<void> deleteSavePoint(String savePointId) async {
    try {
      await _supabase
          .from('save_points')
          .delete()
          .eq('id', savePointId);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete save point: $e');
    }
  }

  /// Searches save points by name or description
  Future<List<Map<String, dynamic>>> searchSavePoints(
    String userId,
    String searchQuery,
  ) async {
    try {
      // Try RPC function first
      try {
        final response = await _supabase
            .rpc('search_user_save_points', params: {
              'user_id_param': userId,
              'search_query': searchQuery,
            });
            
        if (response is List) {
          return response.map((item) {
            if (item['location_geojson'] != null) {
              item['location'] = item['location_geojson'];
              item.remove('location_geojson');
            }
            return Map<String, dynamic>.from(item);
          }).toList();
        }
      } catch (rpcError) {
        print('RPC search failed, using fallback: $rpcError');
      }
      
      // Fallback method
      final response = await _supabase
          .from('save_points')
          .select('''
            id,
            user_id,
            name,
            description,
            ST_X(location::geometry) as longitude,
            ST_Y(location::geometry) as latitude,
            created_at,
            updated_at
          ''')
          .eq('user_id', userId)
          .or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%')
          .order('created_at', ascending: false);

      return response.map<Map<String, dynamic>>((item) {
        final processedItem = Map<String, dynamic>.from(item);
        
        if (item['longitude'] != null && item['latitude'] != null) {
          processedItem['location'] = {
            'type': 'Point',
            'coordinates': [item['longitude'], item['latitude']],
          };
          
          processedItem.remove('longitude');
          processedItem.remove('latitude');
        }
        
        return processedItem;
      }).toList();
      
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to search save points: $e');
    }
  }

  /// Gets the count of save points for a user
  Future<int> getSavePointCount(String userId) async {
    try {
      final response = await _supabase
          .from('save_points')
          .select('id')
          .eq('user_id', userId);

      return response.length;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get save point count: $e');
    }
  }

  /// Validates save point data before saving
  bool validateSavePointData(Map<String, dynamic> data) {
    if (data['user_id'] == null || data['user_id'].toString().isEmpty) {
      return false;
    }

    if (data['name'] == null || data['name'].toString().trim().isEmpty) {
      return false;
    }

    if (data['location'] == null || data['location']['coordinates'] == null) {
      return false;
    }

    final coordinates = data['location']['coordinates'];
    if (coordinates.length != 2) {
      return false;
    }

    final longitude = coordinates[0];
    final latitude = coordinates[1];

    if (longitude < -180 || longitude > 180) {
      return false;
    }

    if (latitude < -90 || latitude > 90) {
      return false;
    }

    if (data['name'].toString().length > 100) {
      return false;
    }

    if (data['description'] != null && 
        data['description'].toString().length > 500) {
      return false;
    }

    return true;
  }

  /// Creates a formatted display name for a save point
  String formatSavePointDisplayName(Map<String, dynamic> savePoint) {
    final name = savePoint['name']?.toString() ?? 'Unnamed Save Point';
    final description = savePoint['description']?.toString();
    
    if (description != null && description.isNotEmpty) {
      return '$name - ${description.length > 50 ? '${description.substring(0, 50)}...' : description}';
    }
    
    return name;
  }

  /// Gets the distance between two coordinates in meters
  double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.pow(math.sin(dLon / 2), 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}