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
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Severity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildFilterToggle(
                      context,
                      'Critical',
                      FontAwesomeIcons.exclamationTriangle,
                      const Color.fromARGB(255, 219, 0, 0),
                      filterService.showCritical,
                      (value) => filterService.toggleCritical(),
                    ),
                    buildFilterToggle(
                      context,
                      'High',
                      Icons.priority_high,
                      const Color.fromARGB(255, 223, 106, 11),
                      filterService.showHigh,
                      (value) => filterService.toggleHigh(),
                    ),
                    buildFilterToggle(
                      context,
                      'Medium',
                      Icons.remove,
                      const Color.fromARGB(167, 116, 66, 9),
                      filterService.showMedium,
                      (value) => filterService.toggleMedium(),
                    ),
                    buildFilterToggle(
                      context,
                      'Low',
                      Icons.low_priority,
                      const Color.fromARGB(255, 216, 187, 23),
                      filterService.showLow,
                      (value) => filterService.toggleLow(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category filters
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildFilterToggle(
                      context,
                      'Violent',
                      FontAwesomeIcons.triangleExclamation,
                      Colors.blueGrey,
                      filterService.showViolent,
                      (value) => filterService.toggleViolent(),
                    ),
                    buildFilterToggle(
                      context,
                      'Property',
                      FontAwesomeIcons.bagShopping,
                      Colors.blueGrey,
                      filterService.showProperty,
                      (value) => filterService.toggleProperty(),
                    ),
                    buildFilterToggle(
                      context,
                      'Drug',
                      FontAwesomeIcons.cannabis,
                      Colors.blueGrey,
                      filterService.showDrug,
                      (value) => filterService.toggleDrug(),
                    ),
                    buildFilterToggle(
                      context,
                      'Public Order',
                      Icons.balance,
                      Colors.blueGrey,
                      filterService.showPublicOrder,
                      (value) => filterService.togglePublicOrder(),
                    ),
                    buildFilterToggle(
                      context,
                      'Financial',
                      Icons.attach_money,
                      Colors.blueGrey,
                      filterService.showFinancial,
                      (value) => filterService.toggleFinancial(),
                    ),
                    buildFilterToggle(
                      context,
                      'Traffic',
                      Icons.traffic,
                      Colors.blueGrey,
                      filterService.showTraffic,
                      (value) => filterService.toggleTraffic(),
                    ),
                    buildFilterToggle(
                      context,
                      'Alerts',
                      Icons.campaign,
                      Colors.blueGrey,
                      filterService.showAlerts,
                      (value) => filterService.toggleAlerts(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Status filters (only for logged-in users)
                    if (userProfile != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildFilterToggle(
                        context,
                        'Pending',
                        Icons.hourglass_empty,
                        Colors.deepPurple,
                        filterService.showPending,
                        (value) => filterService.togglePending(),
                      ),
                      buildFilterToggle(
                        context,
                        'Rejected',
                        Icons.cancel_outlined,
                        Colors.grey,
                        filterService.showRejected,
                        (value) => filterService.toggleRejected(),
                      ),
                      
                      // Active/Inactive filters (only for admin and regular users)
                      if (userProfile?['role'] == 'admin' || userProfile?['role'] == 'user') ...[
                        buildFilterToggle(
                          context,
                          'Active',
                          Icons.check_circle_outline,
                          Colors.green,
                          filterService.showActive,
                          (value) => filterService.toggleActive(),
                        ),
                        buildFilterToggle(
                          context,
                          'Inactive',
                          Icons.pause_circle_outline,
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