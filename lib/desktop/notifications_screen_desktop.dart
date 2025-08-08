import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final Function(String) onMarkAsRead;
  final Function(Map<String, dynamic>) onNotificationTap;
  final VoidCallback onViewAll;

  const NotificationDropdown({
    super.key,
    required this.notifications,
    required this.unreadCount,
    required this.onMarkAsRead,
    required this.onNotificationTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notifications list
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification['is_read'] ?? false;
                      final time = DateTime.parse(notification['created_at']).toLocal();
                      final formattedTime = DateFormat('MMM d, h:mm a').format(time);

                      return Material(
                        color: isRead ? Colors.white : Colors.blue[50],
                        child: InkWell(
                          onTap: () {
                            if (!isRead) {
                              onMarkAsRead(notification['id']);
                            }
                            onNotificationTap(notification);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _getNotificationIcon(notification['type']),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification['title'],
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification['message'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer
          const Divider(height: 1),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View all notifications'),
          ),
        ],
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'report':
        icon = Icons.report;
        color = Colors.orange;
        break;
      case 'approval':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'rejection':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.blue;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}