import 'package:supabase_flutter/supabase_flutter.dart';

class HotlineService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Cache variables
  static List<Map<String, dynamic>>? _cachedHotlines;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Clear cache method
  void clearCache() {
    _cachedHotlines = null;
    _lastFetchTime = null;
  }

  // Check if cache is still valid
  bool _isCacheValid() {
    if (_cachedHotlines == null || _lastFetchTime == null) {
      return false;
    }
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  Future<List<Map<String, dynamic>>> fetchHotlineData({bool forceRefresh = false}) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid()) {
      print('Returning cached hotline data');
      return List<Map<String, dynamic>>.from(_cachedHotlines!);
    }

    try {
      print('Fetching fresh hotline data from database');
      
      final categoriesResponse = await _supabase
          .from('hotline_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      List<Map<String, dynamic>> hotlines = [];

      for (var category in categoriesResponse) {
        Map<String, dynamic> categoryData = {
          'id': category['id'],
          'category': category['name'],
          'description': category['description'],
          'icon': category['icon'],
          'color': category['color'],
        };

        final numbersResponse = await _supabase
            .from('hotline_numbers')
            .select()
            .eq('category_id', category['id'])
            .isFilter('station_id', null)
            .eq('is_active', true)
            .order('display_order', ascending: true);

        if (numbersResponse.isNotEmpty) {
          categoryData['numbers'] = numbersResponse.map((number) => {
            'id': number['id'],
            'name': number['name'],
            'number': number['phone_number'],
            'description': number['description'],
          }).toList();
        }

        final stationsResponse = await _supabase
            .from('hotline_stations')
            .select()
            .eq('category_id', category['id'])
            .eq('is_active', true)
            .order('display_order', ascending: true);

        if (stationsResponse.isNotEmpty) {
          List<Map<String, dynamic>> stations = [];
          
          for (var station in stationsResponse) {
            final stationNumbersResponse = await _supabase
                .from('hotline_numbers')
                .select()
                .eq('station_id', station['id'])
                .eq('is_active', true)
                .order('display_order', ascending: true);

            stations.add({
              'id': station['id'],
              'name': station['name'],
              'description': station['description'],
              'numbers': stationNumbersResponse
                  .map((number) => number['phone_number'])
                  .toList(),
            });
          }
          
          categoryData['stations'] = stations;
        }

        hotlines.add(categoryData);
      }

      // Update cache
      _cachedHotlines = hotlines;
      _lastFetchTime = DateTime.now();

      return hotlines;
    } catch (e) {
      print('Error fetching hotline data: $e');
      if (_cachedHotlines != null) {
        print('Error occurred, returning cached data');
        return List<Map<String, dynamic>>.from(_cachedHotlines!);
      }
      rethrow;
    }
  }

  // Helper methods remain the same
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _supabase
        .from('hotline_categories')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchStationsByCategory(int categoryId) async {
    final response = await _supabase
        .from('hotline_stations')
        .select()
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchNumberById(int id) async {
    final response = await _supabase
        .from('hotline_numbers')
        .select()
        .eq('id', id)
        .single();
    return response;
  }

  Future<Map<String, dynamic>?> fetchStationById(int id) async {
    final response = await _supabase
        .from('hotline_stations')
        .select()
        .eq('id', id)
        .single();
    return response;
  }

  // CRUD operations - NO CACHE UPDATES (let UI handle optimistic updates)
  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? description,
    required String icon,
    required String color,
    int displayOrder = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    final response = await _supabase.from('hotline_categories').insert({
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'display_order': displayOrder,
      'created_by': userId,
    }).select().single();
    
    // Invalidate cache so next fetch gets fresh data
    clearCache();
    
    return response;
  }

  Future<void> updateCategory({
    required int id,
    String? name,
    String? description,
    String? icon,
    String? color,
    int? displayOrder,
    bool? isActive,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    Map<String, dynamic> updates = {
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (icon != null) updates['icon'] = icon;
    if (color != null) updates['color'] = color;
    if (displayOrder != null) updates['display_order'] = displayOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _supabase
        .from('hotline_categories')
        .update(updates)
        .eq('id', id);
    
    clearCache();
  }

  Future<void> deleteCategory(int id) async {
    await _supabase
        .from('hotline_categories')
        .delete()
        .eq('id', id);
    
    clearCache();
  }

  Future<Map<String, dynamic>> createStation({
    required int categoryId,
    required String name,
    String? description,
    int displayOrder = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    final response = await _supabase.from('hotline_stations').insert({
      'category_id': categoryId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'created_by': userId,
    }).select().single();
    
    clearCache();
    
    return response;
  }

  Future<void> updateStation({
    required int id,
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    Map<String, dynamic> updates = {
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (displayOrder != null) updates['display_order'] = displayOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _supabase
        .from('hotline_stations')
        .update(updates)
        .eq('id', id);
    
    clearCache();
  }

  Future<void> deleteStation(int id) async {
    await _supabase
        .from('hotline_stations')
        .delete()
        .eq('id', id);
    
    clearCache();
  }

  Future<Map<String, dynamic>> createNumber({
    int? categoryId,
    int? stationId,
    required String name,
    required String phoneNumber,
    String? description,
    int displayOrder = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    final response = await _supabase.from('hotline_numbers').insert({
      'category_id': categoryId,
      'station_id': stationId,
      'name': name,
      'phone_number': phoneNumber,
      'description': description,
      'display_order': displayOrder,
      'created_by': userId,
    }).select().single();
    
    clearCache();
    
    return response;
  }

  Future<void> updateNumber({
    required int id,
    String? name,
    String? phoneNumber,
    String? description,
    int? displayOrder,
    bool? isActive,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    
    Map<String, dynamic> updates = {
      'updated_by': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (name != null) updates['name'] = name;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (description != null) updates['description'] = description;
    if (displayOrder != null) updates['display_order'] = displayOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _supabase
        .from('hotline_numbers')
        .update(updates)
        .eq('id', id);
    
    clearCache();
  }

  Future<void> deleteNumber(int id) async {
    await _supabase
        .from('hotline_numbers')
        .delete()
        .eq('id', id);
    
    clearCache();
  }
}