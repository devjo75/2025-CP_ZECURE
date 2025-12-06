import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Service for generating crime density heatmap data
/// This is a pure data-driven service with no clustering or preprocessing
class CrimeHeatmapService {
  /// Generates heatmap points from raw crime data
  /// Each crime becomes a weighted point based on its severity
  static List<HeatmapPoint> generateHeatmapPoints(
    List<Map<String, dynamic>> crimes,
  ) {
    final List<HeatmapPoint> points = [];

    for (var crime in crimes) {
      try {
        // Extract location
        final location = crime['location'];
        if (location == null || location['coordinates'] == null) continue;

        final coords = location['coordinates'];
        if (coords.length < 2) continue;

        final lat = coords[1] as double;
        final lng = coords[0] as double;

        // Get severity level for weighting
        final crimeType = crime['crime_type'];
        final level = crimeType?['level'] ?? 'low';

        // Convert severity to weight (higher severity = higher weight)
        final weight = _severityToWeight(level);

        points.add(
          HeatmapPoint(
            location: LatLng(lat, lng),
            weight: weight,
            crimeId: crime['id']?.toString(),
            crimeType: crimeType?['name'] ?? 'Unknown',
            timestamp: crime['time'] ?? crime['created_at'],
          ),
        );
      } catch (e) {
        print('Error processing crime for heatmap: $e');
        continue;
      }
    }

    print(
      'Generated ${points.length} heatmap points from ${crimes.length} crimes',
    );
    return points;
  }

  /// Converts severity level to heatmap weight
  /// Higher severity crimes have more visual impact on the heatmap
  static double _severityToWeight(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return 1.0; // Maximum weight
      case 'high':
        return 0.75;
      case 'medium':
        return 0.5;
      case 'low':
        return 0.3;
      default:
        return 0.3;
    }
  }

  /// Filters crimes based on date range
  /// Returns all crimes within the specified date range
  static List<Map<String, dynamic>> filterCrimesByDateRange(
    List<Map<String, dynamic>> allCrimes,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    // If no date filter is set, return empty (heatmap off by default)
    if (startDate == null || endDate == null) {
      return [];
    }

    return allCrimes.where((crime) {
      final crimeTimeStr = crime['time'] ?? crime['created_at'];
      if (crimeTimeStr == null) return false;

      final crimeTime = DateTime.tryParse(crimeTimeStr);
      if (crimeTime == null) return false;

      // Compare dates only (ignore time component)
      final crimeDateOnly = DateTime(
        crimeTime.year,
        crimeTime.month,
        crimeTime.day,
      );

      final startDateOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      // Include crimes on the end date
      final endOfDay = endDateOnly.add(const Duration(days: 1));

      return !crimeDateOnly.isBefore(startDateOnly) &&
          crimeDateOnly.isBefore(endOfDay);
    }).toList();
  }

  /// Gets heatmap configuration based on zoom level
  /// Adjusts radius and blur for better visualization at different scales
  static HeatmapConfig getConfigForZoom(double zoom) {
    if (zoom >= 16) {
      // High zoom - tight, focused heat spots
      return HeatmapConfig(
        radius: 25,
        blur: 20,
        maxOpacity: 0.7,
        minOpacity: 0.1,
      );
    } else if (zoom >= 14) {
      // Medium zoom - balanced visualization
      return HeatmapConfig(
        radius: 30,
        blur: 25,
        maxOpacity: 0.6,
        minOpacity: 0.1,
      );
    } else if (zoom >= 12) {
      // Lower zoom - broader heat areas
      return HeatmapConfig(
        radius: 40,
        blur: 30,
        maxOpacity: 0.5,
        minOpacity: 0.1,
      );
    } else {
      // Very low zoom - wide area coverage
      return HeatmapConfig(
        radius: 50,
        blur: 35,
        maxOpacity: 0.4,
        minOpacity: 0.1,
      );
    }
  }

  /// Calculates statistics for the current heatmap data
  static HeatmapStats calculateStats(List<HeatmapPoint> points) {
    if (points.isEmpty) {
      return HeatmapStats(
        totalPoints: 0,
        criticalCount: 0,
        highCount: 0,
        mediumCount: 0,
        lowCount: 0,
      );
    }

    int critical = 0;
    int high = 0;
    int medium = 0;
    int low = 0;

    for (var point in points) {
      if (point.weight >= 1.0) {
        critical++;
      } else if (point.weight >= 0.75) {
        high++;
      } else if (point.weight >= 0.5) {
        medium++;
      } else {
        low++;
      }
    }

    return HeatmapStats(
      totalPoints: points.length,
      criticalCount: critical,
      highCount: high,
      mediumCount: medium,
      lowCount: low,
    );
  }
}

/// Represents a single point on the heatmap
class HeatmapPoint {
  final LatLng location;
  final double weight; // 0.0 to 1.0
  final String? crimeId;
  final String? crimeType;
  final String? timestamp;

  HeatmapPoint({
    required this.location,
    required this.weight,
    this.crimeId,
    this.crimeType,
    this.timestamp,
  });

  @override
  String toString() {
    return 'HeatmapPoint(location: $location, weight: $weight, type: $crimeType)';
  }
}

/// Configuration for heatmap visualization
class HeatmapConfig {
  final double radius; // Radius of each heat point in pixels
  final double blur; // Blur amount for smoothing
  final double maxOpacity; // Maximum opacity for hottest areas
  final double minOpacity; // Minimum opacity for coolest areas

  HeatmapConfig({
    required this.radius,
    required this.blur,
    required this.maxOpacity,
    required this.minOpacity,
  });
}

/// Statistics about the current heatmap
class HeatmapStats {
  final int totalPoints;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;

  HeatmapStats({
    required this.totalPoints,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
  });

  String get summary {
    return 'Total: $totalPoints | Critical: $criticalCount | High: $highCount | Medium: $mediumCount | Low: $lowCount';
  }

  String get dominantSeverity {
    if (criticalCount > highCount &&
        criticalCount > mediumCount &&
        criticalCount > lowCount) {
      return 'Critical';
    } else if (highCount > mediumCount && highCount > lowCount) {
      return 'High';
    } else if (mediumCount > lowCount) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  Color get dominantColor {
    if (criticalCount > highCount &&
        criticalCount > mediumCount &&
        criticalCount > lowCount) {
      return const Color(0xFFDB0000); // Critical red
    } else if (highCount > mediumCount && highCount > lowCount) {
      return const Color(0xFFDF6A0B); // High orange
    } else if (mediumCount > lowCount) {
      return const Color(0xFF745209); // Medium brown
    } else {
      return const Color(0xFFD8BB17); // Low yellow
    }
  }
}
