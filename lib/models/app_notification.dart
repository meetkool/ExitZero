import 'dart:convert';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final String priority;
  final List<String> tags;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.priority = "default",
    this.tags = const [],
    this.isRead = false,
  });

  factory AppNotification.fromNtfy(Map<String, dynamic> json) {
    return AppNotification(
      id:       json["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title:    json["title"] ?? "Notification",
      message:  json["message"] ?? "",
      time:     json["time"] != null
                  ? DateTime.fromMillisecondsSinceEpoch((json["time"] as int) * 1000)
                  : DateTime.now(),
      priority: json["priority"]?.toString() ?? "default",
      tags:     json["tags"] != null ? List<String>.from(json["tags"]) : [],
    );
  }

  Map<String, dynamic> toJson() => {
    "id":       id,
    "title":    title,
    "message":  message,
    "time":     time.millisecondsSinceEpoch,
    "priority": priority,
    "tags":     tags,
    "isRead":   isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:       json["id"],
      title:    json["title"],
      message:  json["message"],
      time:     DateTime.fromMillisecondsSinceEpoch(json["time"]),
      priority: json["priority"] ?? "default",
      tags:     List<String>.from(json["tags"] ?? []),
      isRead:   json["isRead"] ?? false,
    );
  }
}
