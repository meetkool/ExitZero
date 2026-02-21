import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationStore {
  static const _key = "notifications";
  static const _lastIdKey = "last_ntfy_id";

  static Future<List<AppNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => AppNotification.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> save(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_lastIdKey);
  }

  static Future<void> saveLastId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastIdKey, id);
  }

  static Future<String?> loadLastId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_lastIdKey);
  }
}
