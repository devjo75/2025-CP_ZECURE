import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
                    buildFilterToggle(
                      context,
                      'Critical',
                      FontAwesomeIcons.exclamationTriangle,  // Updated to match mobile
                      const Color.fromARGB(255, 219, 0, 0),
                      filterService.showCritical,
                      (value) => filterService.toggleCritical(),
                    ),
                    buildFilterToggle(
                      context,
                      'High',
                      Icons.priority_high,  // Updated to match mobile
                      const Color.fromARGB(255, 223, 106, 11),
                      filterService.showHigh,
                      (value) => filterService.toggleHigh(),
                    ),
                    buildFilterToggle(
                      context,
                      'Medium',
                      Icons.remove,  // Updated to match mobile
                      const Color.fromARGB(167, 116, 66, 9),
                      filterService.showMedium,
                      (value) => filterService.toggleMedium(),
                    ),
                    buildFilterToggle(
                      context,
                      'Low',
                      Icons.low_priority,  // Updated to match mobile
                      const Color.fromARGB(255, 216, 187, 23),
                      filterService.showLow,
                      (value) => filterService.toggleLow(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category filters
                    const Text('Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
                    buildFilterToggle(
                      context,
                      'Property',
                      Icons.home_outlined,  // Updated to match mobile
                      Colors.blue,
                      filterService.showProperty,
                      (value) => filterService.toggleProperty(),
                    ),
                    buildFilterToggle(
                      context,
                      'Violent',
                      Icons.priority_high,  // Updated to match mobile
                      Colors.red,
                      filterService.showViolent,
                      (value) => filterService.toggleViolent(),
                    ),
                    buildFilterToggle(
                      context,
                      'Drug',
                      FontAwesomeIcons.syringe,
                      Colors.purple,
                      filterService.showDrug,
                      (value) => filterService.toggleDrug(),
                    ),
                    buildFilterToggle(
                      context,
                      'Public Order',
                      Icons.balance,  // Updated to match mobile
                      Colors.orange,
                      filterService.showPublicOrder,
                      (value) => filterService.togglePublicOrder(),
                    ),
                    buildFilterToggle(
                      context,
                      'Financial',
                      Icons.attach_money,
                      Colors.green,
                      filterService.showFinancial,
                      (value) => filterService.toggleFinancial(),
                    ),
                    buildFilterToggle(
                      context,
                      'Traffic',
                      Icons.traffic,  // Updated to match mobile
                      Colors.blueGrey,
                      filterService.showTraffic,
                      (value) => filterService.toggleTraffic(),
                    ),
                    buildFilterToggle(
                      context,
                      'Alerts',
                      Icons.campaign,  // Updated to match mobile
                      Colors.deepPurple,
                      filterService.showAlerts,
                      (value) => filterService.toggleAlerts(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Status filters (only for logged-in users)
                    if (userProfile != null) ...[
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      buildFilterToggle(
                        context,
                        'Pending',
                        Icons.hourglass_empty,  // Updated to match mobile
                        Colors.amber,  // Updated color to match mobile
                        filterService.showPending,
                        (value) => filterService.togglePending(),
                      ),
                      buildFilterToggle(
                        context,
                        'Rejected',
                        Icons.cancel_outlined,  // Updated to match mobile
                        Colors.grey,
                        filterService.showRejected,
                        (value) => filterService.toggleRejected(),
                      ),
                      
                      // Active/Inactive filters (only for admin and regular users) - ADDED
                      if (userProfile?['role'] == 'admin' || userProfile?['role'] == 'user') ...[
                        buildFilterToggle(
                          context,
                          'Active',
                          Icons.check_circle_outline,  // Active icon
                          Colors.green,
                          filterService.showActive,
                          (value) => filterService.toggleActive(),
                        ),
                        buildFilterToggle(
                          context,
                          'Inactive',
                          Icons.pause_circle_outline,  // Inactive icon
                          Colors.grey,
                          filterService.showInactive,
                          (value) => filterService.toggleInactive(),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                    ],
                    
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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