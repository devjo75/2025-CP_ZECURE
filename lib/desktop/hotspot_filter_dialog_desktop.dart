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
              bool isShowingCrimes = filterService.isShowingCrimes;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with toggle
                    Row(
                      children: [
                        Text(
                          isShowingCrimes ? 'Filter Crimes' : 'Safe Spots',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Toggle button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  filterService.setFilterMode(true); // Show crimes
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isShowingCrimes ? Colors.red.shade600 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        size: 16,
                                        color: isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Crimes',
                                        style: TextStyle(
                                          color: isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                          fontWeight: isShowingCrimes ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  filterService.setFilterMode(false); // Show safe spots
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !isShowingCrimes ? Colors.green.shade600 : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        size: 16,
                                        color: !isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Safe Spots',
                                        style: TextStyle(
                                          color: !isShowingCrimes ? Colors.white : Colors.grey.shade600,
                                          fontWeight: !isShowingCrimes ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time Frame section
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Padding(
      padding: EdgeInsets.only(left: 8.0),
      child: Text(
        'Time Frame',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    ),
    const SizedBox(height: 8),
    
    // Date Range Row
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: filterService.startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  filterService.setStartDate(date);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: filterService.startDate != null 
                        ? Colors.blue.shade300 
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: filterService.startDate != null 
                      ? Colors.blue.shade50 
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: filterService.startDate != null 
                          ? Colors.blue.shade600 
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        filterService.startDate != null
                            ? '${filterService.startDate!.day}/${filterService.startDate!.month}/${filterService.startDate!.year}'
                            : 'Start Date',
                        style: TextStyle(
                          fontSize: 13,
                          color: filterService.startDate != null 
                              ? Colors.blue.shade700 
                              : Colors.grey.shade600,
                          fontWeight: filterService.startDate != null 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 20,
              height: 1,
              color: Colors.grey.shade400,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: filterService.endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  filterService.setEndDate(date);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: filterService.endDate != null 
                        ? Colors.blue.shade300 
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: filterService.endDate != null 
                      ? Colors.blue.shade50 
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: filterService.endDate != null 
                          ? Colors.blue.shade600 
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        filterService.endDate != null
                            ? '${filterService.endDate!.day}/${filterService.endDate!.month}/${filterService.endDate!.year}'
                            : 'End Date',
                        style: TextStyle(
                          fontSize: 13,
                          color: filterService.endDate != null 
                              ? Colors.blue.shade700 
                              : Colors.grey.shade600,
                          fontWeight: filterService.endDate != null 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    
    // Clear dates option - bottom right
    if (filterService.startDate != null || filterService.endDate != null) ...[
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {
                filterService.setStartDate(null);
                filterService.setEndDate(null);
              },
              child: Text(
                'Clear dates',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ],
),

const SizedBox(height: 16),

                    // Dynamic content based on toggle
                    if (isShowingCrimes) ...[
                      // CRIMES FILTERS
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
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showViolent,
                        (value) => filterService.toggleViolent(),
                      ),
                      buildFilterToggle(
                        context,
                        'Property',
                        FontAwesomeIcons.key,
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showProperty,
                        (value) => filterService.toggleProperty(),
                      ),
                      buildFilterToggle(
                        context,
                        'Drug',
                        FontAwesomeIcons.cannabis,
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showDrug,
                        (value) => filterService.toggleDrug(),
                      ),
                      buildFilterToggle(
                        context,
                        'Public Order',
                        Icons.balance,
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showPublicOrder,
                        (value) => filterService.togglePublicOrder(),
                      ),
                      buildFilterToggle(
                        context,
                        'Financial',
                        Icons.attach_money,
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showFinancial,
                        (value) => filterService.toggleFinancial(),
                      ),
                      buildFilterToggle(
                        context,
                        'Traffic',
                        Icons.traffic,
                        const Color.fromARGB(255, 139, 96, 96),
                        filterService.showTraffic,
                        (value) => filterService.toggleTraffic(),
                      ),
                      buildFilterToggle(
                        context,
                        'Alerts',
                        Icons.campaign,
                        const Color.fromARGB(255, 139, 96, 96),
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
                          Colors.red,
                          filterService.showRejected,
                          (value) => filterService.toggleRejected(),
                        ),

                        // Active/Inactive filters (only for admin and regular users)
                        if (userProfile?['role'] == 'admin' || userProfile?['role'] == 'officer' || userProfile?['role'] == 'user') ...[
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
                    ] else ...[
                      // SAFE SPOTS FILTERS
                      // Safe Spot Types
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Safe Spot Types',
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
                        'Police Station',
                        Icons.local_police,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showPoliceStations,
                        (value) => filterService.togglePoliceStations(),
                      ),
                      buildFilterToggle(
                        context,
                        'Government Building',
                        Icons.account_balance,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showGovernmentBuildings,
                        (value) => filterService.toggleGovernmentBuildings(),
                      ),
                      buildFilterToggle(
                        context,
                        'Hospital',
                        Icons.local_hospital,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showHospitals,
                        (value) => filterService.toggleHospitals(),
                      ),
                      buildFilterToggle(
                        context,
                        'School',
                        Icons.school,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showSchools,
                        (value) => filterService.toggleSchools(),
                      ),
                      buildFilterToggle(
                        context,
                        'Shopping Mall',
                        Icons.store,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showShoppingMalls,
                        (value) => filterService.toggleShoppingMalls(),
                      ),
                      buildFilterToggle(
                        context,
                        'Well-lit Area',
                        Icons.lightbulb,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showWellLitAreas,
                        (value) => filterService.toggleWellLitAreas(),
                      ),
                      buildFilterToggle(
                        context,
                        'Security Camera',
                        Icons.security,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showSecurityCameras,
                        (value) => filterService.toggleSecurityCameras(),
                      ),
                      buildFilterToggle(
                        context,
                        'Fire Station',
                        Icons.local_fire_department,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showFireStations,
                        (value) => filterService.toggleFireStations(),
                      ),
                      buildFilterToggle(
                        context,
                        'Religious Building',
                        Icons.church,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showReligiousBuildings,
                        (value) => filterService.toggleReligiousBuildings(),
                      ),
                      buildFilterToggle(
                        context,
                        'Community Center',
                        Icons.group,
                        const Color.fromARGB(255, 96, 139, 109),
                        filterService.showCommunityCenters,
                        (value) => filterService.toggleCommunityCenters(),
                      ),
                      const SizedBox(height: 16),

                      // Safe Spot Status filters (only for logged-in users)
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
                          filterService.showSafeSpotsPending,
                          (value) => filterService.toggleSafeSpotsPending(),
                        ),
                        buildFilterToggle(
                          context,
                          'Approved',
                          Icons.check_circle_outline,
                          Colors.green,
                          filterService.showSafeSpotsApproved,
                          (value) => filterService.toggleSafeSpotsApproved(),
                        ),
                        buildFilterToggle(
                          context,
                          'Rejected',
                          Icons.cancel_outlined,
                          Colors.red,
                          filterService.showSafeSpotsRejected,
                          (value) => filterService.toggleSafeSpotsRejected(),
                        ),
                        const SizedBox(height: 16),

                        // Verification filters
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Verification',
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
                          'Verified',
                          Icons.verified,
                          Colors.blue.shade600,
                          filterService.showVerifiedSafeSpots,
                          (value) => filterService.toggleVerifiedSafeSpots(),
                        ),
                        buildFilterToggle(
                          context,
                          'Unverified',
                          Icons.help_outline,
                          Colors.grey.shade600,
                          filterService.showUnverifiedSafeSpots,
                          (value) => filterService.toggleUnverifiedSafeSpots(),
                        ),
                        const SizedBox(height: 16),
                      ],
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