import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:zecure/services/crime_hotspot_model.dart';

/// Service for managing crime hotspot zones
class CrimeHotspotService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all hotspots visible to current user
  Future<List<CrimeHotspot>> fetchHotspots({
    bool includeInactive = false,
  }) async {
    try {
      var query = _supabase.from('crime_hotspots').select('''
            *,
            crime_type:dominant_crime_type (
              id,
              name,
              level,
              category
            ),
            creator:created_by (
              id,
              full_name
            ),
            updater:updated_by (
              id,
              full_name
            )
          ''');

      if (!includeInactive) {
        query = query.eq('status', 'active');
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) {
        // Add crime type name if available
        if (json['crime_type'] != null) {
          json['dominant_crime_type_name'] = json['crime_type']['name'];
        }
        return CrimeHotspot.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error fetching hotspots: $e');
      return [];
    }
  }

  /// Create a new hotspot
  Future<CrimeHotspot?> createHotspot(CrimeHotspot hotspot) async {
    try {
      final response = await _supabase
          .from('crime_hotspots')
          .insert(hotspot.toJson())
          .select()
          .single();

      // Create audit log
      await _createAuditLog(
        hotspotId: response['id'],
        action: 'created',
        changedBy: hotspot.createdBy,
        changes: {'initial_creation': hotspot.toJson()},
      );

      return CrimeHotspot.fromJson(response);
    } catch (e) {
      print('Error creating hotspot: $e');
      return null;
    }
  }

  /// Update existing hotspot
  Future<bool> updateHotspot(
    String hotspotId,
    Map<String, dynamic> updates,
    String userId,
  ) async {
    try {
      // ✅ Always set updated_by when updating
      await _supabase
          .from('crime_hotspots')
          .update({
            ...updates,
            'updated_by': userId, // Track who updated it
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hotspotId);

      // Create audit log
      await _createAuditLog(
        hotspotId: hotspotId,
        action: 'updated',
        changedBy: userId,
        changes: updates,
      );

      return true;
    } catch (e) {
      print('Error updating hotspot: $e');
      return false;
    }
  }

  /// Deactivate hotspot
  Future<bool> deactivateHotspot(String hotspotId, String userId) async {
    try {
      await _supabase
          .from('crime_hotspots')
          .update({
            'status': 'inactive',
            'deactivated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hotspotId);

      await _createAuditLog(
        hotspotId: hotspotId,
        action: 'deactivated',
        changedBy: userId,
        changes: {'status': 'inactive'},
      );

      return true;
    } catch (e) {
      print('Error deactivating hotspot: $e');
      return false;
    }
  }

  /// Reactivate hotspot
  Future<bool> reactivateHotspot(String hotspotId, String userId) async {
    try {
      await _supabase
          .from('crime_hotspots')
          .update({
            'status': 'active',
            'deactivated_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hotspotId);

      await _createAuditLog(
        hotspotId: hotspotId,
        action: 'reactivated',
        changedBy: userId,
        changes: {'status': 'active'},
      );

      return true;
    } catch (e) {
      print('Error reactivating hotspot: $e');
      return false;
    }
  }

  /// Delete hotspot
  Future<bool> deleteHotspot(String hotspotId, String userId) async {
    try {
      await _createAuditLog(
        hotspotId: hotspotId,
        action: 'deleted',
        changedBy: userId,
        changes: {'deleted': true},
      );

      await _supabase.from('crime_hotspots').delete().eq('id', hotspotId);

      return true;
    } catch (e) {
      print('Error deleting hotspot: $e');
      return false;
    }
  }

  /// Link a crime to a hotspot
  Future<bool> linkCrimeToHotspot({
    required String hotspotId,
    required int crimeId,
    required String linkType, // 'auto_detected' or 'manually_added'
    String? userId,
  }) async {
    try {
      await _supabase.from('hotspot_crimes').insert({
        'hotspot_id': hotspotId,
        'crime_id': crimeId,
        'link_type': linkType,
        'added_by': userId,
        'is_contributing': true,
      });

      // Update hotspot crime count
      await _recalculateHotspotStats(hotspotId);

      return true;
    } catch (e) {
      print('Error linking crime to hotspot: $e');
      return false;
    }
  }

  /// Get crimes within a hotspot
  Future<List<Map<String, dynamic>>> getCrimesInHotspot(
    String hotspotId,
  ) async {
    try {
      final response = await _supabase
          .from('hotspot_crimes')
          .select('''
            *,
            crime:crime_id (
              *,
              crime_type:type_id (
                id,
                name,
                level,
                category
              )
            )
          ''')
          .eq('hotspot_id', hotspotId)
          .eq('is_contributing', true);

      return (response as List).map((item) {
        return item['crime'] as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print('Error fetching crimes in hotspot: $e');
      return [];
    }
  }

  /// Recalculate hotspot statistics
  Future<void> _recalculateHotspotStats(String hotspotId) async {
    try {
      // Get all contributing crimes
      final crimes = await getCrimesInHotspot(hotspotId);

      if (crimes.isEmpty) {
        await _supabase
            .from('crime_hotspots')
            .update({
              'crime_count': 0,
              'dominant_severity': null,
              'dominant_crime_type': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', hotspotId);
        return;
      }

      // Calculate dominant severity
      Map<String, int> severityCounts = {};
      Map<int, int> crimeTypeCounts = {};
      DateTime? firstCrime;
      DateTime? lastCrime;

      for (var crime in crimes) {
        // Count severities
        final severity = crime['crime_type']?['level'] as String?;
        if (severity != null) {
          severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
        }

        // Count crime types
        final typeId = crime['type_id'] as int?;
        if (typeId != null) {
          crimeTypeCounts[typeId] = (crimeTypeCounts[typeId] ?? 0) + 1;
        }

        // Track dates
        final crimeDate = DateTime.tryParse(crime['time'] ?? '');
        if (crimeDate != null) {
          if (firstCrime == null || crimeDate.isBefore(firstCrime)) {
            firstCrime = crimeDate;
          }
          if (lastCrime == null || crimeDate.isAfter(lastCrime)) {
            lastCrime = crimeDate;
          }
        }
      }

      // Find dominant severity
      String? dominantSeverity;
      int maxSeverityCount = 0;
      severityCounts.forEach((severity, count) {
        if (count > maxSeverityCount) {
          maxSeverityCount = count;
          dominantSeverity = severity;
        }
      });

      // Find dominant crime type
      int? dominantCrimeType;
      int maxTypeCount = 0;
      crimeTypeCounts.forEach((typeId, count) {
        if (count > maxTypeCount) {
          maxTypeCount = count;
          dominantCrimeType = typeId;
        }
      });

      // Update hotspot
      await _supabase
          .from('crime_hotspots')
          .update({
            'crime_count': crimes.length,
            'dominant_severity': dominantSeverity,
            'dominant_crime_type': dominantCrimeType,
            'first_crime_date': firstCrime?.toIso8601String(),
            'last_crime_date': lastCrime?.toIso8601String(),
            'last_recalculated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hotspotId);
    } catch (e) {
      print('Error recalculating hotspot stats: $e');
    }
  }

  /// Create audit log entry
  Future<void> _createAuditLog({
    required String hotspotId,
    required String action,
    required String changedBy,
    required Map<String, dynamic> changes,
  }) async {
    try {
      await _supabase.from('crime_hotspots_audit').insert({
        'hotspot_id': hotspotId,
        'action': action,
        'changed_by': changedBy,
        'changes': changes,
      });
    } catch (e) {
      print('Error creating audit log: $e');
    }
  }

  /// Check if a crime is inside a circular hotspot
  bool isCrimeInCircularHotspot({
    required LatLng crimeLocation,
    required LatLng hotspotCenter,
    required double radiusMeters,
  }) {
    final distance = const Distance().as(
      LengthUnit.Meter,
      crimeLocation,
      hotspotCenter,
    );
    return distance <= radiusMeters;
  }

  /// Check if a crime is inside a polygon hotspot
  bool isCrimeInPolygonHotspot({
    required LatLng crimeLocation,
    required List<LatLng> polygonPoints,
  }) {
    // Ray-casting algorithm for point-in-polygon test
    int intersections = 0;
    final x = crimeLocation.longitude;
    final y = crimeLocation.latitude;

    for (int i = 0; i < polygonPoints.length; i++) {
      final j = (i + 1) % polygonPoints.length;
      final xi = polygonPoints[i].longitude;
      final yi = polygonPoints[i].latitude;
      final xj = polygonPoints[j].longitude;
      final yj = polygonPoints[j].latitude;

      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }
}
