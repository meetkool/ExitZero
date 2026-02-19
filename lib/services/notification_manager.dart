import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import 'notification_store.dart';
import 'ntfy_service.dart';

class NotificationManager {
  // Singleton
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final _controller = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> _notifications = [];
  bool _initialized = false;
  late NtfyListener _ntfyListener;

  Stream<List<AppNotification>> get notificationsStream => _controller.stream;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  Future<void> initialize() async {
    if (_initialized) return;
    
    // Load stored notifications
    _notifications = await NotificationStore.load();
    _notify();

    // Start listening to Ntfy
    _ntfyListener = NtfyListener.withCallback(onNotification: (n) {
      _addNotification(n);
    });
    
    // Start listener asynchronously
    _ntfyListener.start();
    
    _initialized = true;
  }

  void _addNotification(AppNotification n) {
    // Avoid duplicates if ID matches existing
    if (_notifications.any((existing) => existing.id == n.id)) return;
    
    _notifications.insert(0, n);
    _saveAndNotify();
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
    _ntfyListener.stop();
    _controller.close();
  }
}
