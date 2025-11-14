import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:zecure/savepoint/save_point_service.dart';
import 'add_save_point.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SavePointDetails {
  static void showSavePointDetails({
    required BuildContext context,
    required Map<String, dynamic> savePoint,
    required Map<String, dynamic>? userProfile,
    required VoidCallback onUpdate,
    required Future<void> Function(LatLng destination) onGetSafeRoute,
  }) async {
    final lat = savePoint['location']['coordinates'][1];
    final lng = savePoint['location']['coordinates'][0];
    final coordinates =
        "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

    String address = "Loading address...";
    String fullLocation = coordinates;

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        address = data['display_name'] ?? "Unknown location";
        fullLocation = "$address\n$coordinates";
      }
    } catch (e) {
      address = "Could not load address";
      fullLocation = "$address\n$coordinates";
    }

    final DateTime createdTime = DateTime.parse(
      savePoint['created_at'],
    ).toLocal();
    final formattedTime = DateFormat(
      'MMM dd, yyyy - hh:mm a',
    ).format(createdTime);

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SavePointDetailsContent(
              savePoint: savePoint,
              userProfile: userProfile,
              onUpdate: onUpdate,
              address: address,
              fullLocation: fullLocation,
              formattedTime: formattedTime,
              isDesktop: true,
              onGetSafeRoute: onGetSafeRoute,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        isDismissible: true,
        builder: (context) => SavePointDetailsContent(
          savePoint: savePoint,
          userProfile: userProfile,
          onUpdate: onUpdate,
          address: address,
          fullLocation: fullLocation,
          formattedTime: formattedTime,
          isDesktop: false,
          onGetSafeRoute: onGetSafeRoute,
        ),
      );
    }
  }

  // Show delete confirmation dialog
  static void _showDeleteDialog(
    BuildContext context,
    String savePointId,
    VoidCallback onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Save Point'),
        content: const Text(
          'Are you sure you want to delete this save point? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SavePointService().deleteSavePoint(savePointId);
                onUpdate();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close details sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Save point deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class SavePointDetailsContent extends StatelessWidget {
  final Map<String, dynamic> savePoint;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onUpdate;
  final String address;
  final String fullLocation;
  final String formattedTime;
  final bool isDesktop;
  final Function(LatLng) onGetSafeRoute;

  const SavePointDetailsContent({
    super.key,
    required this.savePoint,
    required this.userProfile,
    required this.onUpdate,
    required this.address,
    required this.fullLocation,
    required this.formattedTime,
    required this.isDesktop,
    required this.onGetSafeRoute,
  });

  get coordinates => null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: Container(
        constraints: isDesktop
            ? null
            : BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.95,
                minHeight: MediaQuery.of(context).size.height * 0.2,
              ),
        decoration: isDesktop
            ? null
            : const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle at the top (only for mobile)
            if (!isDesktop)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // Content wrapper
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon and name
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bookmark,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                savePoint['name'] ?? 'Unnamed Save Point',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Personal Save Point',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Description
                    if (savePoint['description'] != null &&
                        savePoint['description'].toString().trim().isNotEmpty)
                      _buildInfoTile(
                        'Description',
                        savePoint['description'],
                        Icons.description,
                      ),

                    // Location
                    _buildInfoTile(
                      'Location',
                      address,
                      Icons.location_on,
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: fullLocation));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location copied to clipboard'),
                            ),
                          );
                        },
                      ),
                      subtitle: coordinates,
                    ),

                    // Get Safe Route button below lat/long
                    Padding(
                      padding: const EdgeInsets.only(left: 34, top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final coords = savePoint['location']['coordinates'];
                            final savePointLocation = LatLng(
                              coords[1],
                              coords[0],
                            );
                            Navigator.pop(context);
                            onGetSafeRoute(savePointLocation);
                          },
                          icon: const Icon(Icons.safety_check, size: 15),
                          label: const Text('Get Safe Route'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    ),

                    // Created time
                    _buildInfoTile('Created', formattedTime, Icons.access_time),

                    // Actions
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close details
                              AddSavePointScreen.showAddSavePointForm(
                                context: context,
                                userProfile: userProfile,
                                editSavePoint: savePoint,
                                onUpdate: () {
                                  onUpdate(); // Call the provided onUpdate callback
                                },
                              );
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => SavePointDetails._showDeleteDialog(
                              context,
                              savePoint['id'],
                              onUpdate,
                            ),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build info tiles
  Widget _buildInfoTile(
    String title,
    String content,
    IconData icon, {
    Widget? trailing,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
