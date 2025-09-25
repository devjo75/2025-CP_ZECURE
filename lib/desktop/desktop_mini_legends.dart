import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zecure/services/hotspot_filter_service.dart';

class MiniLegend extends StatelessWidget {
  const MiniLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HotspotFilterService>(
      builder: (context, filterService, child) {
        // Only show on desktop/large screens
        if (MediaQuery.of(context).size.width < 1024) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.legend_toggle,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Crime Types ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content based on filter mode
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (filterService.isShowingCrimes) ...[
                        // Crime Severity Legend
                        _buildSectionTitle('Severity Levels'),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          FontAwesomeIcons.exclamationTriangle,
                          'Critical',
                          const Color.fromARGB(255, 219, 0, 0),
                        ),
                        _buildLegendItem(
                          Icons.priority_high,
                          'High',
                          const Color.fromARGB(255, 223, 106, 11),
                        ),
                        _buildLegendItem(
                          Icons.remove,
                          'Medium',
                          const Color.fromARGB(167, 116, 66, 9),
                        ),
                        _buildLegendItem(
                          Icons.low_priority,
                          'Low',
                          const Color.fromARGB(255, 216, 187, 23),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Crime Categories Legend
                        _buildSectionTitle('Crime Categories'),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          FontAwesomeIcons.triangleExclamation,
                          'Violent',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          FontAwesomeIcons.key,
                          'Property',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          FontAwesomeIcons.cannabis,
                          'Drug',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          Icons.balance,
                          'Public Order',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          Icons.attach_money,
                          'Financial',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          Icons.traffic,
                          'Traffic',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                        _buildLegendItem(
                          Icons.campaign,
                          'Alerts',
                          const Color.fromARGB(255, 139, 96, 96),
                        ),
                      ] else ...[
                        // Safe Spots Legend
                        _buildSectionTitle('Safe Spot Types'),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          Icons.local_police,
                          'Police Station',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.account_balance,
                          'Government',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.local_hospital,
                          'Hospital',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.school,
                          'School',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.store,
                          'Shopping Mall',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.lightbulb,
                          'Well-lit Area',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.security,
                          'Security Camera',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.local_fire_department,
                          'Fire Station',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.church,
                          'Religious Building',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                        _buildLegendItem(
                          Icons.group,
                          'Community Center',
                          const Color.fromARGB(255, 96, 139, 109),
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Toggle hint
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Use the filter button below the compass to toggle visibility',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}