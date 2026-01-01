import 'dart:math' show sin, cos, sqrt, atan2;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

class HotspotQuickAccessUtils {
  // Calculate distance between two points (same as safe spots)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Get filtered and sorted hotspots
  static List<Map<String, dynamic>> getFilteredAndSortedHotspots({
    required List<Map<String, dynamic>> hotspots,
    required String filter,
    required String sortBy,
    required String? selectedCrimeType,
    required LatLng? currentPosition,
    required Map<String, dynamic>? userProfile,
    required bool isAdmin,
    DateTime? crimeStartDate,
    DateTime? crimeEndDate,
  }) {
    final currentUserId = userProfile?['id'];
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final hasCustomDateRange = crimeStartDate != null && crimeEndDate != null;

    List<Map<String, dynamic>> filtered = hotspots.where((hotspot) {
      final status = hotspot['status'] ?? 'pending';
      final activeStatus = hotspot['active_status'] ?? 'active';
      final createdBy = hotspot['created_by'];
      final reportedBy = hotspot['reported_by'];
      final isOwnHotspot =
          currentUserId != null &&
          (currentUserId == createdBy || currentUserId == reportedBy);
      final crimeTypeName = hotspot['crime_type']?['name'];
      final userHasSupported = hotspot['user_has_supported'] ?? false;

      // ✅ Use incident time (not creation time) for 30-day rule
      final incidentTime = DateTime.tryParse(hotspot['time'] ?? '');
      final isRecent =
          incidentTime != null && incidentTime.isAfter(thirtyDaysAgo);

      // ✅ STEP 1: Apply custom date range filter (if active)
      if (hasCustomDateRange) {
        final hotspotDateStr = hotspot['time'] ?? hotspot['created_at'];
        if (hotspotDateStr != null) {
          final hotspotDate = DateTime.tryParse(hotspotDateStr);
          if (hotspotDate != null) {
            final hotspotDateOnly = DateTime(
              hotspotDate.year,
              hotspotDate.month,
              hotspotDate.day,
            );

            final startDateOnly = DateTime(
              crimeStartDate.year,
              crimeStartDate.month,
              crimeStartDate.day,
            );

            final endDateOnly = DateTime(
              crimeEndDate.year,
              crimeEndDate.month,
              crimeEndDate.day,
            );
            final endOfDay = endDateOnly.add(const Duration(days: 1));

            // Outside the date range - hide unless pending to authorized user
            if (hotspotDateOnly.isBefore(startDateOnly) ||
                hotspotDateOnly.isAfter(endOfDay) ||
                hotspotDateOnly.isAtSameMomentAs(endOfDay)) {
              // Exception: pending hotspots visible to owner/supporter regardless of date
              if (status == 'pending' && (isOwnHotspot || userHasSupported)) {
                // Continue to other checks
              } else {
                return false; // Outside date range
              }
            }
          }
        }
      }

      // ✅ STEP 2: Base visibility rules (same as map marker layer)
      if (isAdmin) {
        // Admin visibility rules
        if (!hasCustomDateRange) {
          // Pending: Always show to admin
          if (status == 'pending') {
            // Continue to other checks
          }
          // Rejected: Apply 30-day rule even for admin
          else if (status == 'rejected') {
            if (!isRecent) {
              return false;
            }
          }
          // Approved Active: ✅ ALWAYS visible (no 30-day rule)
          else if (status == 'approved' && activeStatus == 'active') {
            // Always show - no restriction
          }
          // Approved Inactive: Apply 30-day rule
          else if (status == 'approved' && activeStatus == 'inactive') {
            if (!isRecent) {
              return false;
            }
          }
        }
        // If custom date range is active, admin sees everything within range
      } else {
        // Regular users (non-admin)

        // Pending: Show to owner or supporter only
        if (status == 'pending') {
          if (!(isOwnHotspot || userHasSupported)) {
            return false;
          }
        }
        // Rejected: Only show to owner + apply 30-day rule (unless custom date range)
        else if (status == 'rejected') {
          if (!isOwnHotspot) {
            return false;
          }
          // ✅ Apply 30-day rule for rejected (unless custom date range)
          if (!hasCustomDateRange && !isRecent) {
            return false;
          }
        }
        // Approved Active: ✅ ALWAYS visible to all users (no 30-day rule)
        else if (status == 'approved' && activeStatus == 'active') {
          // Always show - no restriction
        }
        // Approved Inactive: Apply 30-day rule (unless custom date range)
        else if (status == 'approved' && activeStatus == 'inactive') {
          if (!hasCustomDateRange && !isRecent) {
            return false;
          }
        }
        // Other statuses: hide
        else {
          return false;
        }
      }

      // ✅ STEP 3: Apply status filters (from UI filter dropdown)
      switch (filter) {
        case 'pending':
          if (status != 'pending') return false;
          break;
        case 'approved':
          if (status != 'approved') return false;
          break;
        case 'active':
          if (status != 'approved' || activeStatus != 'active') return false;
          break;
        case 'inactive':
          if (activeStatus != 'inactive') return false;
          break;
        case 'nearby':
          if (currentPosition == null) return false;
          final coords = hotspot['location']['coordinates'];
          final distance = calculateDistance(
            currentPosition,
            LatLng(coords[1], coords[0]),
          );
          if (distance > 5.0) return false; // Within 5km
          break;
        case 'mine':
          if (!isOwnHotspot) return false;
          break;
        case 'all':
        default:
          break;
      }

      // ✅ STEP 4: Apply crime type filter
      if (selectedCrimeType != null && crimeTypeName != selectedCrimeType) {
        return false;
      }

      return true;
    }).toList();

    // ✅ STEP 5: Sort the filtered results
    filtered.sort((a, b) {
      switch (sortBy) {
        case 'distance':
          if (currentPosition == null) return 0;
          final distanceA = calculateDistance(
            currentPosition,
            LatLng(
              a['location']['coordinates'][1],
              a['location']['coordinates'][0],
            ),
          );
          final distanceB = calculateDistance(
            currentPosition,
            LatLng(
              b['location']['coordinates'][1],
              b['location']['coordinates'][0],
            ),
          );
          return distanceA.compareTo(distanceB);

        case 'crime_type':
          return (a['crime_type']['name'] ?? '').compareTo(
            b['crime_type']['name'] ?? '',
          );

        case 'severity':
          final severityOrder = {
            'critical': 0,
            'high': 1,
            'medium': 2,
            'low': 3,
          };
          final severityA = severityOrder[a['crime_type']['level']] ?? 4;
          final severityB = severityOrder[b['crime_type']['level']] ?? 4;
          return severityA.compareTo(severityB);

        case 'status':
          final statusOrder = {'approved': 0, 'pending': 1, 'rejected': 2};
          final statusA = statusOrder[a['status']] ?? 3;
          final statusB = statusOrder[b['status']] ?? 3;
          final statusCompare = statusA.compareTo(statusB);
          if (statusCompare != 0) return statusCompare;

          // If same status, sort by active status
          final activeStatusOrder = {'active': 0, 'inactive': 1};
          final activeA = activeStatusOrder[a['active_status']] ?? 2;
          final activeB = activeStatusOrder[b['active_status']] ?? 2;
          return activeA.compareTo(activeB);

        case 'date':
          final dateA =
              DateTime.tryParse(a['time'] ?? a['created_at'] ?? '') ??
              DateTime(1970);
          final dateB =
              DateTime.tryParse(b['time'] ?? b['created_at'] ?? '') ??
              DateTime(1970);
          return dateB.compareTo(dateA); // Newest first

        default:
          return 0;
      }
    });

    return filtered;
  }

  // Get all unique crime types for filter options
  static List<String> getAvailableCrimeTypes(
    List<Map<String, dynamic>> hotspots,
  ) {
    final Set<String> types = {};
    for (final hotspot in hotspots) {
      final typeName = hotspot['crime_type']?['name'];
      if (typeName != null) {
        types.add(typeName);
      }
    }
    return types.toList()..sort();
  }

  // Get hotspot status color and icon
  static Map<String, dynamic> getHotspotStatusInfo(
    Map<String, dynamic> hotspot,
  ) {
    final status = hotspot['status'] ?? 'pending';
    final activeStatus = hotspot['active_status'] ?? 'active';
    final crimeLevel = hotspot['crime_type']['level'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (status == 'pending') {
      statusColor = Colors.deepPurple;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Pending';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Rejected';
    } else if (status == 'approved') {
      if (activeStatus == 'inactive') {
        statusColor = Colors.grey;
        statusIcon = Icons.visibility_off;
        statusText = 'Inactive';
      } else {
        // Active approved hotspot - color by severity
        switch (crimeLevel) {
          case 'critical':
            statusColor = const Color.fromARGB(255, 219, 0, 0);
            statusIcon = Icons.warning;
            statusText = 'Critical';
            break;
          case 'high':
            statusColor = const Color.fromARGB(255, 223, 106, 11);
            statusIcon = Icons.priority_high;
            statusText = 'High Risk';
            break;
          case 'medium':
            statusColor = const Color.fromARGB(167, 116, 66, 9);
            statusIcon = Icons.warning_amber;
            statusText = 'Medium Risk';
            break;
          case 'low':
            statusColor = const Color.fromARGB(255, 216, 187, 23);
            statusIcon = Icons.info;
            statusText = 'Low Risk';
            break;
          default:
            statusColor = Colors.blue;
            statusIcon = Icons.location_pin;
            statusText = 'Active';
        }
      }
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help;
      statusText = 'Unknown';
    }

    return {'color': statusColor, 'icon': statusIcon, 'text': statusText};
  }

  // Get crime type icon
  static IconData getCrimeTypeIcon(String? crimeCategory) {
    switch (crimeCategory?.toLowerCase()) {
      case 'property':
        return Icons.home_outlined;
      case 'violent':
        return Icons.warning;
      case 'drug':
        return FontAwesomeIcons.cannabis;
      case 'public order':
        return Icons.balance;
      case 'financial':
        return Icons.attach_money;
      case 'traffic':
        return Icons.traffic;
      case 'alert':
        return Icons.campaign;
      default:
        return Icons.location_pin;
    }
  }
}
