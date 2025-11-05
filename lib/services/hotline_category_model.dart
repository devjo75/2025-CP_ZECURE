
class HotlineCategory {
  final int id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  HotlineCategory({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory HotlineCategory.fromJson(Map<String, dynamic> json) {
    return HotlineCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}

// hotline_station_model.dart
class HotlineStation {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  HotlineStation({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory HotlineStation.fromJson(Map<String, dynamic> json) {
    return HotlineStation(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}

// hotline_number_model.dart
class HotlineNumber {
  final int id;
  final int? categoryId;
  final int? stationId;
  final String name;
  final String phoneNumber;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  HotlineNumber({
    required this.id,
    this.categoryId,
    this.stationId,
    required this.name,
    required this.phoneNumber,
    this.description,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory HotlineNumber.fromJson(Map<String, dynamic> json) {
    return HotlineNumber(
      id: json['id'],
      categoryId: json['category_id'],
      stationId: json['station_id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      description: json['description'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'station_id': stationId,
      'name': name,
      'phone_number': phoneNumber,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}