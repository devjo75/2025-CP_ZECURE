import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zecure/services/crime_hotspot_model.dart';

// ============================================
// Desktop Dialog - Hotspot Zone Details
// ============================================

class HotspotZoneDetailsDialog extends StatelessWidget {
  final CrimeHotspot hotspot;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewCrimes;
  final VoidCallback onClose;

  const HotspotZoneDetailsDialog({
    super.key,
    required this.hotspot,
    required this.userProfile,
    required this.isAdmin,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onViewCrimes,
    required this.onClose,
  });

  bool get _canSeeAuditInfo {
    final role = userProfile?['role'] as String?;
    return role == 'admin' || role == 'officer' || role == 'tanod';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getHeaderColor(),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hotspot.geometryType == GeometryType.circle
                          ? Icons.circle_outlined
                          : Icons.pentagon_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotspot.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _getZoneTypeLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      onClose();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Risk Level Badge
                    _buildRiskBadge(),
                    const SizedBox(height: 16),

                    // Description
                    if (hotspot.description != null) ...[
                      _buildInfoSection(
                        'Description',
                        hotspot.description!,
                        Icons.description_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Statistics
                    _buildStatsCard(),
                    const SizedBox(height: 16),

                    // Geometry Info
                    _buildGeometryInfo(),
                    const SizedBox(height: 16),

                    // Police Notes (admin only)
                    if (isAdmin && hotspot.policeNotes != null) ...[
                      _buildInfoSection(
                        'Police Notes',
                        hotspot.policeNotes!,
                        Icons.shield_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Dates
                    _buildDatesInfo(),

                    // ✅ NEW: Creator/Updater Audit Info (admin/officer/tanod only)
                    if (_canSeeAuditInfo) ...[
                      const SizedBox(height: 16),
                      _buildAuditInfo(),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            if (isAdmin) _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Color _getHeaderColor() {
    if (hotspot.riskAssessment == null) return Colors.grey.shade700;

    switch (hotspot.riskAssessment!) {
      case RiskAssessment.extreme:
        return Colors.red.shade700;
      case RiskAssessment.high:
        return Colors.orange.shade600;
      case RiskAssessment.moderate:
        return Colors.yellow.shade700;
      case RiskAssessment.low:
        return Colors.green.shade600;
    }
  }

  String _getZoneTypeLabel() {
    final type = hotspot.geometryType == GeometryType.circle
        ? 'Circular Zone'
        : 'Polygon Zone';
    final detection = hotspot.detectionType == DetectionType.auto
        ? 'Auto-detected'
        : 'Manually Created';
    return '$type • $detection';
  }

  Widget _buildRiskBadge() {
    if (hotspot.riskAssessment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getHeaderColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getHeaderColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _getHeaderColor(), size: 20),
          const SizedBox(width: 8),
          Text(
            hotspot.riskAssessment!.displayName,
            style: TextStyle(
              color: _getHeaderColor(),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Crimes',
                '${hotspot.visibleCrimeCount}',
                Icons.report_outlined,
                Colors.red,
              ),
              _buildStatItem(
                'Status',
                hotspot.status.value.toUpperCase(),
                Icons.info_outline,
                Colors.blue,
              ),
              _buildStatItem(
                'Visibility',
                _getVisibilityShort(),
                Icons.visibility_outlined,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  String _getVisibilityShort() {
    switch (hotspot.visibility) {
      case HotspotVisibility.public:
        return 'PUBLIC';
      case HotspotVisibility.policeOnly:
        return 'POLICE';
      case HotspotVisibility.adminOnly:
        return 'ADMIN';
    }
  }

  Widget _buildGeometryInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten, color: Colors.grey.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hotspot.geometryType == GeometryType.circle
                  ? 'Radius: ${hotspot.radiusMeters!.toInt()} meters'
                  : 'Polygon: ${hotspot.polygonPoints!.length} boundary points',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesInfo() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hotspot.firstCrimeDate != null) ...[
          _buildDateRow(
            'First Crime',
            dateFormat.format(hotspot.firstCrimeDate!),
          ),
          const SizedBox(height: 8),
        ],
        if (hotspot.lastCrimeDate != null) ...[
          _buildDateRow(
            'Last Crime',
            dateFormat.format(hotspot.lastCrimeDate!),
          ),
          const SizedBox(height: 8),
        ],
        _buildDateRow('Created', dateFormat.format(hotspot.createdAt)),
      ],
    );
  }

  Widget _buildDateRow(String label, String date) {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          date,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// ✅ NEW: Show creator and last updater info (admin/officer/tanod only)
  Widget _buildAuditInfo() {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 16,
                color: Colors.amber.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                'Admin Info',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Created by
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_add, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created by',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      hotspot.createdByName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      dateFormat.format(hotspot.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Last updated by (if exists and different from creator)
          if (hotspot.updatedBy != null &&
              hotspot.updatedBy != hotspot.createdBy) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last updated by',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        hotspot.updatedByName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        dateFormat.format(hotspot.updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onViewCrimes,
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('View Crimes'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: canDelete
                  ? onDelete
                  : null, // ✅ Disable if can't delete
              icon: const Icon(Icons.delete_outline),
              color: canDelete ? Colors.red.shade600 : Colors.grey.shade400,
              tooltip: canDelete
                  ? 'Delete'
                  : 'Only creator or admin can delete',
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// Mobile Bottom Sheet - Hotspot Zone Details
// ============================================

class HotspotZoneDetailsSheet extends StatelessWidget {
  final CrimeHotspot hotspot;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewCrimes;
  final VoidCallback onClose;

  const HotspotZoneDetailsSheet({
    super.key,
    required this.hotspot,
    required this.userProfile,
    required this.isAdmin,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onViewCrimes,
    required this.onClose,
  });

  bool get _canSeeAuditInfo {
    final role = userProfile?['role'] as String?;
    return role == 'admin' || role == 'officer' || role == 'tanod';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: DraggableScrollableSheet(
        initialChildSize: _calculateInitialSize(context),
        minChildSize: 0.3,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: _getSnapSizes(
          context,
        ), // ✅ Use a method that ensures unique values
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildMobileHeader(context),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Risk Badge
                              if (hotspot.riskAssessment != null)
                                _buildRiskBadge(),

                              const SizedBox(height: 16),

                              // Description
                              if (hotspot.description != null) ...[
                                _buildSectionLabel('Description'),
                                Text(
                                  hotspot.description!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Stats Card
                              _buildStatsCard(),

                              const SizedBox(height: 16),

                              // Geometry Info
                              _buildGeometryInfo(),

                              const SizedBox(height: 16),

                              // Police Notes (admin only)
                              if (isAdmin && hotspot.policeNotes != null) ...[
                                _buildSectionLabel('Police Notes'),
                                Text(
                                  hotspot.policeNotes!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Dates
                              _buildDatesInfo(),

                              // Audit Info (admin/officer/tanod only)
                              if (_canSeeAuditInfo) ...[
                                const SizedBox(height: 16),
                                _buildAuditInfo(),
                              ],

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                _buildMobileActions(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _getHeaderColor(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hotspot.geometryType == GeometryType.circle
                  ? Icons.circle_outlined
                  : Icons.pentagon_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotspot.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getZoneTypeLabel(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              onClose();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getHeaderColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getHeaderColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _getHeaderColor(), size: 18),
          const SizedBox(width: 6),
          Text(
            hotspot.riskAssessment!.displayName,
            style: TextStyle(
              color: _getHeaderColor(),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.report_outlined,
            '${hotspot.visibleCrimeCount}',
            'Crimes',
            Colors.red,
          ),
          _buildStatItem(
            Icons.info_outline,
            hotspot.status.value.toUpperCase(),
            'Status',
            Colors.blue,
          ),
          _buildStatItem(
            Icons.visibility_outlined,
            _getVisibilityShort(),
            'Visibility',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildGeometryInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten, color: Colors.grey.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hotspot.geometryType == GeometryType.circle
                  ? 'Radius: ${hotspot.radiusMeters!.toInt()} meters'
                  : 'Polygon: ${hotspot.polygonPoints!.length} boundary points',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesInfo() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hotspot.firstCrimeDate != null)
          _buildDateRow(
            'First Crime',
            dateFormat.format(hotspot.firstCrimeDate!),
          ),
        if (hotspot.lastCrimeDate != null) ...[
          const SizedBox(height: 8),
          _buildDateRow(
            'Last Crime',
            dateFormat.format(hotspot.lastCrimeDate!),
          ),
        ],
        const SizedBox(height: 8),
        _buildDateRow('Created', dateFormat.format(hotspot.createdAt)),
      ],
    );
  }

  Widget _buildDateRow(String label, String date) {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          date,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAuditInfo() {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Review Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Created by
          Row(
            children: [
              Icon(Icons.create, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Created by: ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                hotspot.createdByName ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Created date
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text(
              dateFormat.format(hotspot.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),

          // Last updated by
          if (hotspot.updatedBy != null &&
              hotspot.updatedBy != hotspot.createdBy) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Updated by: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  hotspot.updatedByName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                dateFormat.format(hotspot.updatedAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onViewCrimes();
                },
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('View Crimes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed:
                    canDelete // ✅ Check permission before allowing delete
                    ? () {
                        Navigator.pop(context);
                        onDelete();
                      }
                    : null, // ✅ Disable if can't delete
                icon: const Icon(Icons.delete_outline),
                color: canDelete
                    ? Colors.red.shade600
                    : Colors.grey.shade400, // ✅ Grey out if disabled
                tooltip: canDelete
                    ? 'Delete'
                    : 'Only creator or admin can delete', // ✅ Helpful tooltip
                style: IconButton.styleFrom(
                  backgroundColor: canDelete
                      ? Colors.red.shade50
                      : Colors
                            .grey
                            .shade100, // ✅ Change background when disabled
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getHeaderColor() {
    if (hotspot.riskAssessment == null) return Colors.grey.shade700;

    switch (hotspot.riskAssessment!) {
      case RiskAssessment.extreme:
        return Colors.red.shade700;
      case RiskAssessment.high:
        return Colors.orange.shade600;
      case RiskAssessment.moderate:
        return Colors.yellow.shade700;
      case RiskAssessment.low:
        return Colors.green.shade600;
    }
  }

  String _getZoneTypeLabel() {
    final type = hotspot.geometryType == GeometryType.circle
        ? 'Circular Zone'
        : 'Polygon Zone';
    final detection = hotspot.detectionType == DetectionType.auto
        ? 'Auto-detected'
        : 'Manually Created';
    return '$type • $detection';
  }

  String _getVisibilityShort() {
    switch (hotspot.visibility) {
      case HotspotVisibility.public:
        return 'PUBLIC';
      case HotspotVisibility.policeOnly:
        return 'POLICE';
      case HotspotVisibility.adminOnly:
        return 'ADMIN';
    }
  }

  /// Calculate initial size based on content
  double _calculateInitialSize(BuildContext context) {
    // Base height for header, stats, geometry, dates, and actions
    double estimatedHeight = 500.0; // Base content height

    // Add height for description if present
    if (hotspot.description != null && hotspot.description!.isNotEmpty) {
      final descriptionLines = (hotspot.description!.length / 40).ceil();
      estimatedHeight += descriptionLines * 20.0 + 40; // Line height + spacing
    }

    // Add height for police notes if admin and notes exist
    if (isAdmin &&
        hotspot.policeNotes != null &&
        hotspot.policeNotes!.isNotEmpty) {
      final notesLines = (hotspot.policeNotes!.length / 40).ceil();
      estimatedHeight += notesLines * 20.0 + 40;
    }

    // Add height for audit info if visible
    if (_canSeeAuditInfo) {
      estimatedHeight +=
          hotspot.updatedBy != null && hotspot.updatedBy != hotspot.createdBy
          ? 120.0 // With updater info
          : 80.0; // Without updater info
    }

    // Calculate percentage of screen height
    final screenHeight = MediaQuery.of(context).size.height;
    double initialSize = estimatedHeight / screenHeight;

    // Clamp between 0.5 and 0.95
    return initialSize.clamp(0.5, 0.95);
  }

  /// Get snap sizes, ensuring no duplicates
  List<double> _getSnapSizes(BuildContext context) {
    final initialSize = _calculateInitialSize(context);

    // If initial size is already at max (0.95), only use one snap size
    if (initialSize >= 0.95) {
      return [0.95];
    }

    // Otherwise, use both initial and max sizes
    return [initialSize, 0.95];
  }
}

// ============================================
// Edit Hotspot Zone Dialog
// ============================================

class EditHotspotZoneDialog extends StatefulWidget {
  final CrimeHotspot hotspot;
  final bool canDelete; // ✅ Add this
  final Function(Map<String, dynamic> updates) onSave;

  const EditHotspotZoneDialog({
    super.key,
    required this.hotspot,
    required this.canDelete, // ✅ Add this
    required this.onSave,
  });

  @override
  State<EditHotspotZoneDialog> createState() => _EditHotspotZoneDialogState();
}

class _EditHotspotZoneDialogState extends State<EditHotspotZoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late RiskAssessment _riskAssessment;
  late HotspotVisibility _visibility;
  late HotspotStatus _status;
  bool _isSaving = false;
  bool get _canModifyStatus => widget.canDelete;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hotspot.name);
    _descriptionController = TextEditingController(
      text: widget.hotspot.description ?? '',
    );
    _notesController = TextEditingController(
      text: widget.hotspot.policeNotes ?? '',
    );
    _riskAssessment = widget.hotspot.riskAssessment ?? RiskAssessment.high;
    _visibility = widget.hotspot.visibility;
    _status = widget.hotspot.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updates = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'risk_assessment': _riskAssessment.value,
      'visibility': _visibility.value,
      'status': _status.value,
      'police_notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    await widget.onSave(updates);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Hotspot Zone',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!widget.canDelete)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Only an admin or the creator of this hotspot zone can delete or deactivate it.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RiskAssessment>(
                        value: _riskAssessment,
                        decoration: const InputDecoration(
                          labelText: 'Risk Level',
                          border: OutlineInputBorder(),
                        ),
                        items: RiskAssessment.values.map((risk) {
                          return DropdownMenuItem(
                            value: risk,
                            child: Text(risk.displayName),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _riskAssessment = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<HotspotVisibility>(
                        value: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                          border: OutlineInputBorder(),
                        ),
                        items: HotspotVisibility.values.map((vis) {
                          return DropdownMenuItem(
                            value: vis,
                            child: Text(vis.displayName),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _visibility = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<HotspotStatus>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        // ✅ Disable if user can't modify status
                        items: HotspotStatus.values.map((status) {
                          final isInactive = status == HotspotStatus.inactive;
                          final canSelect = _canModifyStatus || !isInactive;

                          return DropdownMenuItem(
                            value: status,
                            enabled:
                                canSelect, // ✅ Disable inactive option if not allowed
                            child: Text(
                              status.value.toUpperCase(),
                              style: TextStyle(
                                color: canSelect ? null : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _canModifyStatus
                            ? (v) => setState(() => _status = v!)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Police Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MOBILE BOTTOM SHEET - Edit Hotspot Zone
// ============================================

class EditHotspotZoneSheet extends StatefulWidget {
  final CrimeHotspot hotspot;
  final bool canDelete;
  final Function(Map<String, dynamic> updates) onSave;

  const EditHotspotZoneSheet({
    super.key,
    required this.hotspot,
    required this.canDelete,
    required this.onSave,
  });

  @override
  State<EditHotspotZoneSheet> createState() => _EditHotspotZoneSheetState();
}

class _EditHotspotZoneSheetState extends State<EditHotspotZoneSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late RiskAssessment _riskAssessment;
  late HotspotVisibility _visibility;
  late HotspotStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hotspot.name);
    _descriptionController = TextEditingController(
      text: widget.hotspot.description ?? '',
    );
    _notesController = TextEditingController(
      text: widget.hotspot.policeNotes ?? '',
    );
    _riskAssessment = widget.hotspot.riskAssessment ?? RiskAssessment.high;
    _visibility = widget.hotspot.visibility;
    _status = widget.hotspot.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updates = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      'risk_assessment': _riskAssessment.value,
      'visibility': _visibility.value,
      'status': _status.value,
      'police_notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    await widget.onSave(updates);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.8, 0.95],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                _buildMobileHeader(),

                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!widget.canDelete)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.amber.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Only an admin or the creator of this hotspot zone can delete or deactivate it.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<RiskAssessment>(
                            value: _riskAssessment,
                            decoration: const InputDecoration(
                              labelText: 'Risk Level',
                              border: OutlineInputBorder(),
                            ),
                            items: RiskAssessment.values.map((risk) {
                              return DropdownMenuItem(
                                value: risk,
                                child: Text(risk.displayName),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _riskAssessment = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<HotspotVisibility>(
                            value: _visibility,
                            decoration: const InputDecoration(
                              labelText: 'Visibility',
                              border: OutlineInputBorder(),
                            ),
                            items: HotspotVisibility.values.map((vis) {
                              return DropdownMenuItem(
                                value: vis,
                                child: Text(vis.displayName),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _visibility = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<HotspotStatus>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: HotspotStatus.values.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status.value.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Police Notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 80), // Space for fixed button
                        ],
                      ),
                    ),
                  ),
                ),

                // Fixed action buttons
                _buildMobileActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      // ✅ Should be Padding, NOT Container with color
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Edit Hotspot Zone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Crimes in Zone Dialog
// ============================================

class CrimesInZoneDialog extends StatelessWidget {
  final CrimeHotspot hotspot;
  final List<Map<String, dynamic>> crimes;
  final Function(Map<String, dynamic> crime) onCrimeSelected;

  const CrimesInZoneDialog({
    super.key,
    required this.hotspot,
    required this.crimes,
    required this.onCrimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crimes in ${hotspot.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${crimes.length} incident${crimes.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: crimes.length,
                itemBuilder: (context, index) {
                  final crime = crimes[index];
                  final crimeType = crime['crime_type'];
                  final dateStr = crime['time'] ?? crime['created_at'];
                  final date = DateTime.tryParse(dateStr ?? '');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCrimeLevelColor(
                          crimeType?['level'] ?? 'low',
                        ),
                        child: const Icon(
                          Icons.report_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        crimeType?['name'] ?? 'Unknown Crime',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: date != null
                          ? Text(DateFormat('MMM dd, yyyy').format(date))
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => onCrimeSelected(crime),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCrimeLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.yellow.shade700;
      case 'low':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }
}

// ============================================
// Crimes in Zone Bottom Sheet (Mobile)
// ============================================

class CrimesInZoneSheet extends StatelessWidget {
  final CrimeHotspot hotspot;
  final List<Map<String, dynamic>> crimes;
  final Function(Map<String, dynamic> crime) onCrimeSelected;

  const CrimesInZoneSheet({
    super.key,
    required this.hotspot,
    required this.crimes,
    required this.onCrimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevents dismissal when tapping content
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.7, 0.95],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.list_alt,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crimes in ${hotspot.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${crimes.length} incident${crimes.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Crimes List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: crimes.length,
                    itemBuilder: (context, index) {
                      final crime = crimes[index];
                      final crimeType = crime['crime_type'];
                      final dateStr = crime['time'] ?? crime['created_at'];
                      final date = DateTime.tryParse(dateStr ?? '');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => onCrimeSelected(crime),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Crime Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getCrimeLevelColor(
                                      crimeType?['level'] ?? 'low',
                                    ).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.report_outlined,
                                    color: _getCrimeLevelColor(
                                      crimeType?['level'] ?? 'low',
                                    ),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Crime Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        crimeType?['name'] ?? 'Unknown Crime',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (date != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat(
                                                'MMM dd, yyyy',
                                              ).format(date),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),

                                // Arrow
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getCrimeLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.yellow.shade700;
      case 'low':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }
}
