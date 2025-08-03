import 'package:flutter/material.dart';

class LocationOptionsDialogDesktop extends StatelessWidget {
  final String locationName;
  final bool isAdmin;
  final Map<String, dynamic>? userProfile;
  final double distance;
  final String duration;
  final VoidCallback onGetDirections;
  final VoidCallback onGetSafeRoute;
  final VoidCallback onShareLocation;
  final VoidCallback onReportHotspot;
  final VoidCallback onAddHotspot;

  const LocationOptionsDialogDesktop({
    super.key,
    required this.locationName,
    required this.isAdmin,
    required this.userProfile,
    required this.distance,
    required this.duration,
    required this.onGetDirections,
    required this.onGetSafeRoute,
    required this.onShareLocation,
    required this.onReportHotspot,
    required this.onAddHotspot,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    locationName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions),
                  title: const Text('Get Regular Route'),
                  onTap: () {
                    Navigator.pop(context);
                    onGetDirections();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.safety_check, color: Colors.green),
                  title: const Text('Get Safe Route'),
                  subtitle: const Text('Avoids reported hotspots'),
                  onTap: () {
                    Navigator.pop(context);
                    onGetSafeRoute();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share Location'),
                  onTap: () {
                    Navigator.pop(context);
                    onShareLocation();
                  },
                ),
                if (!isAdmin && userProfile != null)
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.orange),
                    title: const Text('Report Hotspot'),
                    subtitle: const Text('Submit for admin approval'),
                    onTap: () {
                      Navigator.pop(context);
                      onReportHotspot();
                    },
                  ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.add_location_alt),
                    title: const Text('Add Hotspot'),
                    subtitle: const Text('Immediately published'),
                    onTap: () {
                      Navigator.pop(context);
                      onAddHotspot();
                    },
                  ),
                if (distance > 0)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Distance: ${distance.toStringAsFixed(2)} km | Duration: $duration',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
