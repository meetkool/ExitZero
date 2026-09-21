import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/widget_manifest.dart';
import 'widget_repo_config.dart';

/// Reads the widget inventory published on GitHub.
///
/// Everything is cached to disk, so the store and any installed widget keep
/// working offline and a cold start does not block on the network.
class WidgetRegistryService {
  WidgetRegistryService._();

  static const String _registryKey = 'widget_registry_cache';
  static const String _registryEtagKey = 'widget_registry_etag';
  static const String _manifestPrefix = 'widget_manifest_';

  /// Rejects anything that is not plain HTTPS. A manifest should never be
  /// able to talk the app into a cleartext or non-HTTP scheme.
  static bool isAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// Index of every published widget.
  ///
  /// Returns the cached copy on any network or parse failure, so the store
  /// degrades to "what we saw last time" rather than an empty list.
  static Future<List<WidgetRegistryEntry>> fetchRegistry({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = _parseRegistry(prefs.getString(_registryKey));
      if (cached.isNotEmpty) {
        // Refresh in the background so the next open is current.
        unawaitedRefresh(prefs);
        return cached;
      }
    }

    try {
      final headers = <String, String>{};
      final etag = prefs.getString(_registryEtagKey);
      if (etag != null && !forceRefresh) headers['If-None-Match'] = etag;

      final response = await http
          .get(Uri.parse(WidgetRepoConfig.registryUrl), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 304) {
        return _parseRegistry(prefs.getString(_registryKey));
      }
      if (response.statusCode == 200) {
        await prefs.setString(_registryKey, response.body);
        final newEtag = response.headers['etag'];
        if (newEtag != null) await prefs.setString(_registryEtagKey, newEtag);
        return _parseRegistry(response.body);
      }
    } catch (_) {
      // Fall through to whatever we already have.
    }

    return _parseRegistry(prefs.getString(_registryKey));
  }

  /// Fire-and-forget revalidation used when a cached registry was served.
  static void unawaitedRefresh(SharedPreferences prefs) {
    () async {
      try {
        final headers = <String, String>{};
        final etag = prefs.getString(_registryEtagKey);
        if (etag != null) headers['If-None-Match'] = etag;

        final response = await http
            .get(Uri.parse(WidgetRepoConfig.registryUrl), headers: headers)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          await prefs.setString(_registryKey, response.body);
          final newEtag = response.headers['etag'];
          if (newEtag != null) {
            await prefs.setString(_registryEtagKey, newEtag);
          }
        }
      } catch (_) {
        // Background refresh is best effort.
      }
    }();
  }

  static List<WidgetRegistryEntry> _parseRegistry(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final list = decoded['widgets'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map(
            (e) => WidgetRegistryEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.id.isNotEmpty && e.path.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Full manifest for one widget, cached by id after the first fetch.
  static Future<WidgetManifest?> fetchManifest(
    WidgetRegistryEntry entry, {
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_manifestPrefix${entry.id}';

    if (!forceRefresh) {
      final cached = _parseManifest(prefs.getString(key));
      if (cached != null) return cached;
    }

    final url = WidgetRepoConfig.manifestUrl(entry.path);
    if (!isAllowedUrl(url)) return null;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final parsed = _parseManifest(response.body);
        if (parsed != null) {
          await prefs.setString(key, response.body);
          return parsed;
        }
      }
    } catch (_) {
      // Fall through to cache.
    }

    return _parseManifest(prefs.getString(key));
  }

  /// Manifest for an already-installed widget, cache first.
  static Future<WidgetManifest?> cachedManifest(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return _parseManifest(prefs.getString('$_manifestPrefix$id'));
  }

  static WidgetManifest? _parseManifest(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final manifest = WidgetManifest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return manifest.id.isEmpty ? null : manifest;
    } catch (_) {
      return null;
    }
  }

  /// Drop a single widget's cached manifest, so the next fetch goes out.
  static Future<void> forgetManifest(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_manifestPrefix$id');
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registryKey);
    await prefs.remove(_registryEtagKey);
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_manifestPrefix)) await prefs.remove(key);
    }
  }
}
