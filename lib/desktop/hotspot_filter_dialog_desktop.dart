import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zecure/services/hotspot_filter_service.dart';

class HotspotFilterDialogDesktop extends StatelessWidget {
  final Map<String, dynamic>? userProfile;

  const HotspotFilterDialogDesktop({super.key, required this.userProfile, required Widget Function(BuildContext context, String label, IconData icon, Color color, bool value, Function(bool p1) onChanged) buildFilterToggle});

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
                      'Filter Hotspots',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
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
                    if (userProfile != null) ...[
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
                    ],
                    const SizedBox(height: 16),
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

// You can keep this utility in the same file or move to a shared utilities file
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
  );
}
