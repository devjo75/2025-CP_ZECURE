import 'package:flutter/material.dart';

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
    final formattedTime = '${time.month}/${time.day}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    final status = hotspot['status'] ?? 'approved';
    final activeStatus = hotspot['active_status'] ?? 'active'; // Add active status
    final rejectionReason = hotspot['rejection_reason'];
    final isOwner = hotspot['created_by'] == userProfile?['id'] || hotspot['reported_by'] == userProfile?['id'];

    final int hotspotId = hotspot['id'];

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
                  children: [
                    Text(
                      'Hotspot Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    _infoRow('Type', hotspot['crime_type']['name']),
                    _infoRow('Level', hotspot['crime_type']['level']),
                    _infoRow('Description', hotspot['description'] ?? 'No description'),
                    _infoRow('Coordinates', coordinates),
                    _infoRow('Time', formattedTime),
                    // Add active status row for admins only
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
                    if (status != 'approved')
                      _infoRow(
                        'Status',
                        status.toUpperCase(),
                        color: status == 'pending' ? Colors.orange : Colors.red,
                      ),
                    if (status == 'rejected' && rejectionReason != null)
                      _infoRow('Rejection Reason', rejectionReason),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _buildActionButtons(context, hotspotId, status, isOwner),
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

  List<Widget> _buildActionButtons(BuildContext context, int hotspotId, String status, bool isOwner) {
    List<Widget> buttons = [];

    if (isAdmin && status == 'pending') {
      buttons.addAll([
        ElevatedButton(
          onPressed: () => onReview(hotspotId, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Approve'),
        ),
        ElevatedButton(
          onPressed: () => onReject(hotspotId),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Reject'),
        ),
        ElevatedButton(
          onPressed: () => onDelete(hotspotId),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          onPressed: () => onDelete(hotspotId),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ]);
    }

    if (status == 'rejected') {
      if (isOwner || isAdmin) {
        buttons.add(
          ElevatedButton(
            onPressed: () => onDelete(hotspotId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        );
      }
    }

    if (isAdmin && status == 'approved') {
      buttons.addAll([
        ElevatedButton(
          onPressed: () => onEdit(hotspot),
          child: const Text('Edit'),
        ),
        ElevatedButton(
          onPressed: () => onDelete(hotspotId),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  value,
                  style: TextStyle(color: color ?? Colors.black87),
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