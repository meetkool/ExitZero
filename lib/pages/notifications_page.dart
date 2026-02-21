import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';

import '../services/notification_manager.dart';

class NotificationsPage extends StatelessWidget {
  final String? filterTag;

  const NotificationsPage({super.key, this.filterTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Notifications", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Mark all read",
            onPressed: () => NotificationManager().markAllAsRead(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Clear all",
            onPressed: () => NotificationManager().clearAll(),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationManager().notificationsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          var notifications = snapshot.data!;
          if (filterTag != null) {
            notifications = notifications.where((n) => n.tags.contains(filterTag)).toList();
            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  'No matching notifications found.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Dismissible(
                key: Key(notif.id),
                // Swipe Right (Start to End): Mark as Read
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                // Swipe Left (End to Start): Delete
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await NotificationManager().markAsRead(notif.id);
                    return false; // Don't remove from list visually instantly via dismiss
                  } else {
                    return true; // Delete
                  }
                },
                onDismissed: (direction) {
                  if (direction == DismissDirection.endToStart) {
                    NotificationManager().delete(notif.id);
                  }
                },
                child: GestureDetector(
                  onTap: () => NotificationManager().markAsRead(notif.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFF1E293B), // Highlight unread
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: notif.isRead
                            ? Colors.transparent
                            : Colors.blueAccent.withOpacity(0.3),
                      ),
                      boxShadow: notif.isRead ? [] : [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (!notif.isRead)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, h:mm a').format(notif.time),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notif.message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        if (notif.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: notif.tags.map((tag) => Chip(
                              label: Text(
                                tag, 
                                style: const TextStyle(fontSize: 10, color: Colors.white),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              side: BorderSide.none,
                            )).toList(),
                          ),
                        ],
                        if (!notif.isRead)
                           Align(
                             alignment: Alignment.centerRight,
                             child: TextButton.icon(
                               onPressed: () => NotificationManager().markAsRead(notif.id),
                               icon: const Icon(Icons.check, size: 16, color: Colors.blueAccent),
                               label: const Text("Mark Read", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                               style: TextButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                 minimumSize: const Size(0, 32),
                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                               ),
                             ),
                           ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
