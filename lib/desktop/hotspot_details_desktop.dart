import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HotspotDetailsDesktop extends StatelessWidget {
  final Map<String, dynamic> hotspot;
  final Map<String, dynamic>? userProfile;
  final bool isAdmin;
  final Future<void> Function(int id, bool approved) onReview;
  final void Function(int id) onReject;
  final Future<void> Function(int id) onDelete;
  final Function(Map<String, dynamic> hotspot) onEdit;

  const HotspotDetailsDesktop({
    super.key,
    required this.hotspot,
    required this.userProfile,
    required this.isAdmin,
    required this.onReview,
    required this.onReject,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final lat = hotspot['location']['coordinates'][1];
    final lng = hotspot['location']['coordinates'][0];
    final coordinates = "(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";

    final DateTime time = DateTime.parse(hotspot['time']).toLocal();
    final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(time);

    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active';
    final rejectionReason = hotspot['rejection_reason'];
    final isOwner = hotspot['created_by'] == userProfile?['id'] || 
                    hotspot['reported_by'] == userProfile?['id'];

    final crimeType = hotspot['crime_type'];
    final category = crimeType['category'] ?? 'Unknown Category';
    final level = crimeType['level'] ?? 'Unknown Level';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crime Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Crime Type with Category and Level
                    _infoRow('Type', crimeType['name']),
                    _infoRow('Category', category),
                    _infoRow('Level', level),
                    const Divider(height: 24),
                    // Description
                    _infoRow(
                      'Description', 
                      (hotspot['description'] == null || hotspot['description'].toString().trim().isEmpty)
                          ? 'No description'
                          : hotspot['description'],
                    ),
                    const Divider(height: 24),
                    // Location with copy button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hotspot['address'] ?? 'Loading address...'),
                              const SizedBox(height: 4),
                              Text(
                                coordinates,
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            final fullLocation = '${hotspot['address'] ?? 'Unknown location'}\n$coordinates';
                            Clipboard.setData(ClipboardData(text: fullLocation));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Time
                    _infoRow('Time', formattedTime),
                    const Divider(height: 24),
                    // Active Status (admin only)
                    if (isAdmin)
                      _infoRow(
                        'Active Status',
                        activeStatus.toUpperCase(),
                        color: activeStatus == 'active' ? Colors.green : Colors.grey,
                        icon: activeStatus == 'active' 
                            ? Icons.check_circle 
                            : Icons.cancel,
                        iconColor: activeStatus == 'active' ? Colors.green : Colors.grey,
                      ),
                    // Status (if not approved)
                    if (status != 'approved')
                      _infoRow(
                        'Status',
                        status.toUpperCase(),
                        color: status == 'pending' ? Colors.orange : Colors.red,
                        icon: status == 'pending' 
                            ? Icons.access_time 
                            : Icons.block,
                        iconColor: status == 'pending' ? Colors.orange : Colors.red,
                      ),
                    // Rejection reason (if rejected)
                    if (status == 'rejected' && rejectionReason != null)
                      _infoRow('Rejection Reason', rejectionReason),
                    const SizedBox(height: 32),
                    // Action buttons
                    Center(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: _buildActionButtons(context, status, isOwner),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, String status, bool isOwner) {
    final buttons = <Widget>[];

    if (isAdmin && status == 'pending') {
      buttons.addAll([
        ElevatedButton(
          onPressed: () => onReview(hotspot['id'], true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
        ElevatedButton(
          onPressed: () => onReject(hotspot['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject'),
        ),
        ElevatedButton(
          onPressed: () => onDelete(hotspot['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ]);
    }

    if (!isAdmin && status == 'pending' && isOwner) {
      buttons.addAll([
        ElevatedButton(
          onPressed: () => onEdit(hotspot),
          child: const Text('Edit'),
        ),
        ElevatedButton(
          onPressed: () => onDelete(hotspot['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ]);
    }

    if (status == 'rejected' && (isOwner || isAdmin)) {
      buttons.add(
        ElevatedButton(
          onPressed: () => onDelete(hotspot['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      );
    }

    if (isAdmin && status == 'approved') {
      buttons.addAll([
        ElevatedButton(
          onPressed: () => onEdit(hotspot),
          child: const Text('Edit'),
        ),
        ElevatedButton(
          onPressed: () => onDelete(hotspot['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ]);
    }

    return buttons;
  }

  Widget _infoRow(String label, String value, {Color? color, IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(color: color ?? Colors.black87),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: iconColor, size: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}