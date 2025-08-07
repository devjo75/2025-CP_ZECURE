import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zecure/services/hotspot_filter_service.dart';

class HotspotFilterDialogDesktop extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final Widget Function(BuildContext, String, IconData, Color, bool, void Function(bool)) buildFilterToggle;

  const HotspotFilterDialogDesktop({
    super.key, 
    required this.userProfile,
    required this.buildFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<HotspotFilterService>(
            builder: (context, filterService, child) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Crimes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Severity filters
                    const Text('Severity:', style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildFilterToggle(
                      context,
                      'Critical',
                      Icons.warning,
                      Colors.red,
                      filterService.showCritical,
                      (value) => filterService.toggleCritical(),
                    ),
                    _buildFilterToggle(
                      context,
                      'High',
                      Icons.error,
                      Colors.orange,
                      filterService.showHigh,
                      (value) => filterService.toggleHigh(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Medium',
                      Icons.info,
                      Colors.yellow,
                      filterService.showMedium,
                      (value) => filterService.toggleMedium(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Low',
                      Icons.check_circle,
                      Colors.green,
                      filterService.showLow,
                      (value) => filterService.toggleLow(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category filters
                    const Text('Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildFilterToggle(
                      context,
                      'Property',
                      Icons.house,
                      Colors.blue,
                      filterService.showProperty,
                      (value) => filterService.toggleProperty(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Violent',
                      Icons.warning,
                      Colors.red,
                      filterService.showViolent,
                      (value) => filterService.toggleViolent(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Drug',
                      Icons.medical_services,
                      Colors.purple,
                      filterService.showDrug,
                      (value) => filterService.toggleDrug(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Public Order',
                      Icons.gavel,
                      Colors.orange,
                      filterService.showPublicOrder,
                      (value) => filterService.togglePublicOrder(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Financial',
                      Icons.attach_money,
                      Colors.green,
                      filterService.showFinancial,
                      (value) => filterService.toggleFinancial(),
                    ),
                    _buildFilterToggle(
                      context,
                      'Traffic',
                      Icons.directions_car,
                      Colors.blueGrey,
                      filterService.showTraffic,
                      (value) => filterService.toggleTraffic(),
                    ),
                      _buildFilterToggle(
                        context,
                        'Alerts',
                        Icons.notification_important,
                        Colors.deepPurple,
                        filterService.showAlerts,
                        (value) => filterService.toggleAlerts(),
                      ),
                    const SizedBox(height: 16),
                    
                    // Status filters (only for logged-in users)
                    if (userProfile != null) ...[
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildFilterToggle(
                        context,
                        'Pending',
                        Icons.question_mark,
                        Colors.purple,
                        filterService.showPending,
                        (value) => filterService.togglePending(),
                      ),
                      _buildFilterToggle(
                        context,
                        'Rejected',
                        Icons.block,
                        Colors.grey,
                        filterService.showRejected,
                        (value) => filterService.toggleRejected(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Utility function for building filter toggles
Widget _buildFilterToggle(
  BuildContext context,
  String label,
  IconData icon,
  Color color,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return SwitchListTile(
    title: Text(label),
    secondary: Icon(icon, color: color),
    value: value,
    onChanged: onChanged,
    dense: true,
  );
}