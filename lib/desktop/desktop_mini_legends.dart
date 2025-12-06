import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zecure/services/hotspot_filter_service.dart';
import 'package:zecure/services/crime_heatmap_service.dart';

class MiniLegend extends StatefulWidget {
  final HeatmapStats? heatmapStats;
  final bool isHeatmapVisible;

  const MiniLegend({
    super.key,
    this.heatmapStats,
    this.isHeatmapVisible = false,
  });

  @override
  State<MiniLegend> createState() => _MiniLegendState();
}

class _MiniLegendState extends State<MiniLegend>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Default to expanded
  String _selectedView = 'crime'; // 'crime', 'safe', 'heatmap'
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

  String get _headerTitle {
    switch (_selectedView) {
      case 'heatmap':
        return 'Heatmap Stats';
      case 'safe':
        return 'Safe Spots';
      case 'crime':
      default:
        return 'Crime Types';
    }
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
            constraints: const BoxConstraints(maxWidth: 220),
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
                        bottomLeft: _isExpanded
                            ? Radius.zero
                            : const Radius.circular(12),
                        bottomRight: _isExpanded
                            ? Radius.zero
                            : const Radius.circular(12),
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
                            _headerTitle,
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
                        // Dropdown selector
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedView,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedView = newValue;
                                  });
                                }
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'crime',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        size: 16,
                                        color: Colors.red.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Crime Types'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'safe',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shield_rounded,
                                        size: 16,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Safe Spots'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'heatmap',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.whatshot,
                                        size: 16,
                                        color: Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Heatmap Stats'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Dynamic content based on selection
                        if (_selectedView == 'heatmap') ...[
                          _buildHeatmapStatsView(),
                        ] else if (_selectedView == 'crime') ...[
                          _buildCrimeTypesView(),
                        ] else if (_selectedView == 'safe') ...[
                          _buildSafeSpotsView(),
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

  // ✅ NEW: Heatmap Statistics View
  Widget _buildHeatmapStatsView() {
    if (widget.heatmapStats == null || !widget.isHeatmapVisible) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.thermostat_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No Heatmap Active',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a date range in filters to view heatmap statistics',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final stats = widget.heatmapStats!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total crimes indicator
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                stats.dominantColor.withOpacity(0.1),
                stats.dominantColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: stats.dominantColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stats.dominantColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.whatshot,
                  size: 20,
                  color: stats.dominantColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.totalPoints}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: stats.dominantColor,
                      ),
                    ),
                    Text(
                      'Total Crimes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Dominant severity badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: stats.dominantColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: stats.dominantColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, size: 14, color: stats.dominantColor),
              const SizedBox(width: 6),
              Text(
                'Dominant: ${stats.dominantSeverity}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: stats.dominantColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Severity breakdown
        _buildSectionTitle('Severity Breakdown'),
        const SizedBox(height: 8),

        _buildStatBar(
          'Critical',
          stats.criticalCount,
          stats.totalPoints,
          const Color(0xFFDB0000),
          FontAwesomeIcons.exclamationTriangle,
        ),
        const SizedBox(height: 6),

        _buildStatBar(
          'High',
          stats.highCount,
          stats.totalPoints,
          const Color(0xFFDF6A0B),
          Icons.priority_high,
        ),
        const SizedBox(height: 6),

        _buildStatBar(
          'Medium',
          stats.mediumCount,
          stats.totalPoints,
          const Color(0xFF745209),
          Icons.remove,
        ),
        const SizedBox(height: 6),

        _buildStatBar(
          'Low',
          stats.lowCount,
          stats.totalPoints,
          const Color(0xFFD8BB17),
          Icons.low_priority,
        ),

        const SizedBox(height: 12),

        // Heatmap legend
        _buildSectionTitle('Heatmap Color Scale'),
        const SizedBox(height: 8),

        Container(
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0000FF), // Blue
                Color(0xFF00FFFF), // Cyan
                Color(0xFFFFFF00), // Yellow
                Color(0xFFFF8000), // Orange
                Color(0xFFFF0000), // Red
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),

        const SizedBox(height: 4),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low Density',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
            Text(
              'High Density',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBar(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Crime Types View (existing)
  Widget _buildCrimeTypesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          crimeTypes: ['Public Disturbance', 'General Crime'],
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
          crimeTypes: ['Theft', 'Burglary', 'Carnapping MC', 'Carnapping MV'],
        ),
        _buildLegendItem(
          FontAwesomeIcons.cannabis,
          'Drug',
          const Color.fromARGB(255, 139, 96, 96),
          crimeTypes: ['Drug Crime', 'Smuggling'],
        ),
        _buildLegendItem(
          Icons.balance,
          'Public Order',
          const Color.fromARGB(255, 139, 96, 96),
          crimeTypes: ['Illegal Gambling', 'Prostitution'],
        ),
        _buildLegendItem(
          Icons.attach_money,
          'Financial',
          const Color.fromARGB(255, 139, 96, 96),
          crimeTypes: ['Extortion'],
        ),
        _buildLegendItem(
          Icons.traffic,
          'Traffic',
          const Color.fromARGB(255, 139, 96, 96),
          crimeTypes: ['Traffic Crime', 'Drunk Driving'],
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
      ],
    );
  }

  // Safe Spots View (existing)
  Widget _buildSafeSpotsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildLegendItem(
    IconData icon,
    String label,
    Color color, {
    List<String>? crimeTypes,
  }) {
    return Tooltip(
      message: crimeTypes != null ? crimeTypes.join('\n') : '',
      preferBelow: true,
      verticalOffset: 10,
      margin: const EdgeInsets.only(left: 240),
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
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
            if (crimeTypes != null)
              Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
