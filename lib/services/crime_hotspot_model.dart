import 'package:latlong2/latlong.dart';

/// Model for Crime Hotspot Zones (not individual crimes)
class CrimeHotspot {
  final String id;
  final String name;
  final String? description;

  // Detection and geometry
  final DetectionType detectionType;
  final GeometryType geometryType;

  // Circular hotspot data
  final LatLng? center;
  final double? radiusMeters;

  // Polygon hotspot data
  final List<LatLng>? polygonPoints;

  // Statistics
  final int crimeCount; // Total crimes in zone (for date range calculation)
  final int visibleCrimeCount; // Crimes matching current filters (for display)
  final String? dominantSeverity;
  final int? dominantCrimeTypeId;
  final String? dominantCrimeTypeName;

  // Status
  final HotspotStatus status;
  final HotspotVisibility visibility;
  final RiskAssessment? riskAssessment;

  // Notes and metadata
  final String? policeNotes;

  // Date range based on contained crimes
  final DateTime? firstCrimeDate;
  final DateTime? lastCrimeDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  // User tracking with names
  final String createdBy;
  final String? createdByName;
  final String? updatedBy;
  final String? updatedByName;

  CrimeHotspot({
    required this.id,
    required this.name,
    this.description,
    required this.detectionType,
    required this.geometryType,
    this.center,
    this.radiusMeters,
    this.polygonPoints,
    required this.crimeCount,
    this.visibleCrimeCount = 0,
    this.dominantSeverity,
    this.dominantCrimeTypeId,
    this.dominantCrimeTypeName,
    required this.status,
    required this.visibility,
    this.riskAssessment,
    this.policeNotes,
    this.firstCrimeDate,
    this.lastCrimeDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.createdByName,
    this.updatedBy,
    this.updatedByName,
  });

  /// Check if hotspot's date range intersects with filter range
  bool intersectsWithDateRange(DateTime filterStart, DateTime filterEnd) {
    if (firstCrimeDate == null || lastCrimeDate == null) {
      return false;
    }

    if (lastCrimeDate!.isBefore(filterStart)) {
      return false;
    }

    if (firstCrimeDate!.isAfter(filterEnd)) {
      return false;
    }

    return true;
  }

  /// Check if hotspot is fully contained within filter range
  bool isFullyWithinDateRange(DateTime filterStart, DateTime filterEnd) {
    if (firstCrimeDate == null || lastCrimeDate == null) {
      return false;
    }

    return !firstCrimeDate!.isBefore(filterStart) &&
        !lastCrimeDate!.isAfter(filterEnd);
  }

  /// Create from Supabase JSON response
  factory CrimeHotspot.fromJson(Map<String, dynamic> json) {
    // Parse center coordinates
    LatLng? center;
    if (json['center_lat'] != null && json['center_lng'] != null) {
      center = LatLng(
        json['center_lat'] as double,
        json['center_lng'] as double,
      );
    }

    // Parse polygon coordinates
    List<LatLng>? polygonPoints;
    if (json['polygon_coordinates'] != null) {
      final coords = json['polygon_coordinates'] as List;
      polygonPoints = coords.map((coord) {
        return LatLng(coord['lat'] as double, coord['lng'] as double);
      }).toList();
    }

    // Parse creator and updater names
    String? createdByName;
    if (json['creator'] != null && json['creator'] is Map) {
      final creator = json['creator'] as Map<String, dynamic>;
      createdByName = creator['full_name'] as String?;
    }

    String? updatedByName;
    if (json['updater'] != null && json['updater'] is Map) {
      final updater = json['updater'] as Map<String, dynamic>;
      updatedByName = updater['full_name'] as String?;
    }

    return CrimeHotspot(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      detectionType: DetectionType.fromString(json['detection_type'] as String),
      geometryType: GeometryType.fromString(json['geometry_type'] as String),
      center: center,
      radiusMeters: json['radius_meters'] as double?,
      polygonPoints: polygonPoints,
      crimeCount: json['crime_count'] as int? ?? 0,
      visibleCrimeCount: 0, // Will be calculated dynamically
      dominantSeverity: json['dominant_severity'] as String?,
      dominantCrimeTypeId: json['dominant_crime_type'] as int?,
      dominantCrimeTypeName: json['dominant_crime_type_name'] as String?,
      status: HotspotStatus.fromString(json['status'] as String),
      visibility: HotspotVisibility.fromString(json['visibility'] as String),
      riskAssessment: json['risk_assessment'] != null
          ? RiskAssessment.fromString(json['risk_assessment'] as String)
          : null,
      policeNotes: json['police_notes'] as String?,
      firstCrimeDate: json['first_crime_date'] != null
          ? DateTime.parse(json['first_crime_date'] as String)
          : null,
      lastCrimeDate: json['last_crime_date'] != null
          ? DateTime.parse(json['last_crime_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String,
      createdByName: createdByName,
      updatedBy: json['updated_by'] as String?,
      updatedByName: updatedByName,
    );
  }

  /// Convert to JSON for database insertion
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'detection_type': detectionType.value,
      'geometry_type': geometryType.value,
      'center_lat': center?.latitude,
      'center_lng': center?.longitude,
      'radius_meters': radiusMeters,
      'polygon_coordinates': polygonPoints?.map((point) {
        return {'lat': point.latitude, 'lng': point.longitude};
      }).toList(),
      'crime_count': crimeCount,
      'dominant_severity': dominantSeverity,
      'dominant_crime_type': dominantCrimeTypeId,
      'status': status.value,
      'visibility': visibility.value,
      'risk_assessment': riskAssessment?.value,
      'police_notes': policeNotes,
      'first_crime_date': firstCrimeDate?.toIso8601String(),
      'last_crime_date': lastCrimeDate?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  /// Copy with method for updates
  CrimeHotspot copyWith({
    String? name,
    String? description,
    int? crimeCount,
    int? visibleCrimeCount,
    String? dominantSeverity,
    HotspotStatus? status,
    String? policeNotes,
    RiskAssessment? riskAssessment,
    DateTime? firstCrimeDate,
    DateTime? lastCrimeDate,
    String? updatedBy,
    String? updatedByName,
  }) {
    return CrimeHotspot(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      detectionType: detectionType,
      geometryType: geometryType,
      center: center,
      radiusMeters: radiusMeters,
      polygonPoints: polygonPoints,
      crimeCount: crimeCount ?? this.crimeCount,
      visibleCrimeCount: visibleCrimeCount ?? this.visibleCrimeCount,
      dominantSeverity: dominantSeverity ?? this.dominantSeverity,
      dominantCrimeTypeId: dominantCrimeTypeId,
      dominantCrimeTypeName: dominantCrimeTypeName,
      status: status ?? this.status,
      visibility: visibility,
      riskAssessment: riskAssessment ?? this.riskAssessment,
      policeNotes: policeNotes ?? this.policeNotes,
      firstCrimeDate: firstCrimeDate ?? this.firstCrimeDate,
      lastCrimeDate: lastCrimeDate ?? this.lastCrimeDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      createdByName: createdByName,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}

/// Detection type enum
enum DetectionType {
  auto('auto'),
  manual('manual');

  final String value;
  const DetectionType(this.value);

  static DetectionType fromString(String value) {
    return DetectionType.values.firstWhere((e) => e.value == value);
  }
}

/// Geometry type enum
enum GeometryType {
  circle('circle'),
  polygon('polygon');

  final String value;
  const GeometryType(this.value);

  static GeometryType fromString(String value) {
    return GeometryType.values.firstWhere((e) => e.value == value);
  }
}

/// Hotspot status enum
enum HotspotStatus {
  active('active'),
  inactive('inactive'),
  monitoring('monitoring');

  final String value;
  const HotspotStatus(this.value);

  static HotspotStatus fromString(String value) {
    return HotspotStatus.values.firstWhere((e) => e.value == value);
  }
}

/// Visibility level enum
enum HotspotVisibility {
  public('public'),
  policeOnly('police_only'),
  adminOnly('admin_only');

  final String value;
  const HotspotVisibility(this.value);

  static HotspotVisibility fromString(String value) {
    return HotspotVisibility.values.firstWhere((e) => e.value == value);
  }

  String get displayName {
    switch (this) {
      case HotspotVisibility.public:
        return 'Public';
      case HotspotVisibility.policeOnly:
        return 'Police Only';
      case HotspotVisibility.adminOnly:
        return 'Admin Only';
    }
  }
}

/// Risk assessment level enum
enum RiskAssessment {
  extreme('extreme'),
  high('high'),
  moderate('moderate'),
  low('low');

  final String value;
  const RiskAssessment(this.value);

  static RiskAssessment fromString(String value) {
    return RiskAssessment.values.firstWhere((e) => e.value == value);
  }

  String get displayName {
    switch (this) {
      case RiskAssessment.extreme:
        return 'Extreme Risk';
      case RiskAssessment.high:
        return 'High Risk';
      case RiskAssessment.moderate:
        return 'Moderate Risk';
      case RiskAssessment.low:
        return 'Low Risk';
    }
  }
}
