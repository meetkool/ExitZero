import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Which remote widgets the user has installed, and the values they supplied
/// for each one's config fields.
class InstalledWidgetsStore {
  InstalledWidgetsStore._();

  static const String _installedKey = 'installed_widget_ids';
  static const String _configKey = 'installed_widget_config';

  /// Built-in cards the user has switched off. Stored as the exceptions
  /// rather than the enabled set, so a card added in a later release shows up
  /// by default instead of staying invisible.
  static const String _hiddenBuiltInsKey = 'hidden_builtin_widget_ids';

  /// Broadcasts whenever the installed set changes, so the dashboard can
  /// rebuild without being navigated back to.
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();
  static Stream<void> get onChanged => _changes.stream;

  static Future<List<String>> installedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_installedKey) ?? const [];
  }

  static Future<bool> isInstalled(String id) async {
    final ids = await installedIds();
    return ids.contains(id);
  }

  static Future<void> install(
    String id, {
    Map<String, String> config = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_installedKey) ?? <String>[];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList(_installedKey, ids);
    }
    if (config.isNotEmpty) await saveConfig(id, config);
    _changes.add(null);
  }

  static Future<void> uninstall(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_installedKey) ?? <String>[];
    ids.remove(id);
    await prefs.setStringList(_installedKey, ids);

    final all = await _allConfig();
    all.remove(id);
    await prefs.setString(_configKey, jsonEncode(all));

    _changes.add(null);
  }

  // ── Built-in cards ──

  static Future<Set<String>> hiddenBuiltIns() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenBuiltInsKey) ?? const []).toSet();
  }

  static Future<bool> isBuiltInEnabled(String id) async {
    final hidden = await hiddenBuiltIns();
    return !hidden.contains(id);
  }

  static Future<void> setBuiltInEnabled(String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = (prefs.getStringList(_hiddenBuiltInsKey) ?? <String>[])
        .toList();
    if (enabled) {
      hidden.remove(id);
    } else if (!hidden.contains(id)) {
      hidden.add(id);
    }
    await prefs.setStringList(_hiddenBuiltInsKey, hidden);
    _changes.add(null);
  }

  static Future<Map<String, String>> config(String id) async {
    final all = await _allConfig();
    final entry = all[id];
    if (entry is Map) {
      return entry.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  static Future<void> saveConfig(String id, Map<String, String> values) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _allConfig();
    all[id] = values;
    await prefs.setString(_configKey, jsonEncode(all));
    _changes.add(null);
  }

  static Future<Map<String, dynamic>> _allConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }
}
