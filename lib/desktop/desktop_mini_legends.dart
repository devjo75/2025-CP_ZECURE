import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zecure/services/hotspot_filter_service.dart';

class MiniLegend extends StatefulWidget {
  const MiniLegend({super.key});

  @override
  State<MiniLegend> createState() => _MiniLegendState();
}

class _MiniLegendState extends State<MiniLegend> with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Default to expanded
  bool _showCrimeTypes = true; // Toggle between crime types and safe spots
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Start expanded
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleView() {
    setState(() {
      _showCrimeTypes = !_showCrimeTypes;
    });
  }

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
                // Header with toggle button
                InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: _isExpanded ? Radius.zero : const Radius.circular(12),
                        bottomRight: _isExpanded ? Radius.zero : const Radius.circular(12),
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
                        Expanded(
                          child: Text(
                            _showCrimeTypes ? 'Crime Types' : 'Safe Spots',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Collapsible content
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Toggle button between Crime Types and Safe Spots
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_showCrimeTypes) _toggleView();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _showCrimeTypes
                                          ? Colors.blue.shade600
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.warning_rounded,
                                          size: 14,
                                          color: _showCrimeTypes
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Crime',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _showCrimeTypes
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_showCrimeTypes) _toggleView();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_showCrimeTypes
                                          ? Colors.green.shade600
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shield_rounded,
                                          size: 14,
                                          color: !_showCrimeTypes
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Safe',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: !_showCrimeTypes
                                                ? Colors.white
                                                : Colors.grey.shade600,
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

                        if (_showCrimeTypes) ...[
                          // Crime Severity Legend
                          _buildSectionTitle('Severity Levels'),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            FontAwesomeIcons.exclamationTriangle,
                            'Critical',
                            const Color.fromARGB(255, 219, 0, 0),
                            crimeTypes: [
                              'Homicide',
                              'Murder',
                              'Kidnapping',
                              'Armed Violence',
                              'Terrorism',
                              'Sexual Assault',
                              'Missing Person',
                              'Insurgency Activity',
                              'Bombing Threat',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.priority_high,
                            'High',
                            const Color.fromARGB(255, 223, 106, 11),
                            crimeTypes: [
                              'Robbery',
                              'Physical Injury',
                              'Drug Crime',
                              'Gang Activity',
                              'Domestic Violence',
                              'Traffic Crime',
                              'Drunk Driving',
                              'Emergency Incident',
                              'Environmental Crime',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.remove,
                            'Medium',
                            const Color.fromARGB(167, 116, 66, 9),
                            crimeTypes: [
                              'Theft',
                              'Burglary',
                              'Extortion',
                              'Illegal Gambling',
                              'Prostitution',
                              'Suspicious Activity',
                              'Police Activity',
                              'Smuggling',
                              'Carnapping MC',
                              'Carnapping MV',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.low_priority,
                            'Low',
                            const Color.fromARGB(255, 216, 187, 23),
                            crimeTypes: [
                              'Public Disturbance',
                              'General Crime',
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Crime Categories Legend
                          _buildSectionTitle('Crime Categories'),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            FontAwesomeIcons.triangleExclamation,
                            'Violent',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Homicide',
                              'Murder',
                              'Kidnapping',
                              'Armed Violence',
                              'Terrorism',
                              'Robbery',
                              'Physical Injury',
                              'Sexual Assault',
                              'Gang Activity',
                              'Domestic Violence',
                              'Insurgency Activity',
                              'Bombing Threat',
                              'Environmental Crime',
                            ],
                          ),
                          _buildLegendItem(
                            FontAwesomeIcons.key,
                            'Property',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Theft',
                              'Burglary',
                              'Carnapping MC',
                              'Carnapping MV',
                            ],
                          ),
                          _buildLegendItem(
                            FontAwesomeIcons.cannabis,
                            'Drug',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Drug Crime',
                              'Smuggling',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.balance,
                            'Public Order',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Illegal Gambling',
                              'Prostitution',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.attach_money,
                            'Financial',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Extortion',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.traffic,
                            'Traffic',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Traffic Crime',
                              'Drunk Driving',
                            ],
                          ),
                          _buildLegendItem(
                            Icons.campaign,
                            'Alerts',
                            const Color.fromARGB(255, 139, 96, 96),
                            crimeTypes: [
                              'Suspicious Activity',
                              'Police Activity',
                              'Missing Person',
                              'Public Disturbance',
                              'Emergency Incident',
                              'General Crime',
                            ],
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

  Widget _buildLegendItem(IconData icon, String label, Color color, {List<String>? crimeTypes}) {
    return Tooltip(
      message: crimeTypes != null ? crimeTypes.join('\n') : '',
      preferBelow: true,
      verticalOffset: 10,
      margin: const EdgeInsets.only(left: 220),
      textStyle: const TextStyle(
        fontSize: 11,
        color: Colors.white,
        height: 1.5,
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
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
            if (crimeTypes != null)
              Icon(
                Icons.info_outline,
                size: 12,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}