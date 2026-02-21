import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/app_notification.dart';
import 'notification_store.dart';
import 'ntfy_service.dart';
import 'local_notification_service.dart';

class NotificationManager {
  // Singleton
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final _controller = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> _notifications = [];
  bool _initialized = false;

  Stream<List<AppNotification>> get notificationsStream => _controller.stream;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  Future<void> initialize() async {
    if (_initialized) return;
    
    // Load stored notifications initially
    _notifications = await NotificationStore.load();
    _notify();

    // The background service is handling the SSE connection in another isolate.
    // Listen to updates from the background service to refresh UI.
    FlutterBackgroundService().on('update').listen((event) async {
       // Refresh from store
       _notifications = await NotificationStore.load();
       _notify();
    });
    
    _initialized = true;
  }

  void _addNotification(AppNotification n) {
    // Avoid duplicates if ID matches existing
    if (_notifications.any((existing) => existing.id == n.id)) return;
    
    NotificationStore.saveLastId(n.id);

    _notifications.insert(0, n);
    _saveAndNotify();

    // Prevent spam on startup for old messages
    final isOld = n.time.isBefore(DateTime.now().subtract(const Duration(minutes: 5)));
    if (!n.isRead && !isOld) {
      LocalNotificationService.showNotification(
        id: n.id.hashCode,
        title: n.title,
        body: n.message,
      );
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveAndNotify();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveAndNotify();
  }

  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveAndNotify();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveAndNotify();
  }

  Future<void> _saveAndNotify() async {
    _notify();
    await NotificationStore.save(_notifications);
  }

  void _notify() {
    _controller.add(List.unmodifiable(_notifications));
  }

  void dispose() {
    _controller.close();
  }
}
