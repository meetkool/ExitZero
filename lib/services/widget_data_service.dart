import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/widget_manifest.dart';
import '../widgets/remote/widget_dsl.dart';
import 'widget_registry_service.dart';

/// Outcome of loading a widget's data source.
class WidgetDataResult {
  final dynamic data;
  final bool fromCache;
  final String? error;

  const WidgetDataResult({this.data, this.fromCache = false, this.error});

  bool get hasError => error != null;
}

/// Fetches and caches the JSON behind a remote widget.
class WidgetDataService {
  WidgetDataService._();

  static const String _prefix = 'widget_data_';
  static const String _stampPrefix = 'widget_data_at_';

  /// Loads a widget's data, honouring its `refreshSeconds` TTL.
  ///
  /// A stale cache is always preferred over an error: a widget that showed a
  /// number yesterday should keep showing it on a flaky connection rather
  /// than flipping to a red box.
  static Future<WidgetDataResult> load(
    WidgetManifest manifest,
    Map<String, String> config, {
    bool forceRefresh = false,
  }) async {
    final source = manifest.data;
    if (source == null) {
      return const WidgetDataResult(data: null);
    }

    // Config values are substituted into the URL, headers and root path, so
    // one manifest can serve every user without a variant per person.
    final ctx = WidgetBindingContext(config: config);

    // `root` is templated too (e.g. "{{config.coin}}"), so it must be
    // resolved before it is walked — including on the cache path.
    final root = source.root == null
        ? null
        : WidgetExpression.resolve(source.root!, ctx);

    final prefs = await SharedPreferences.getInstance();
    final dataKey = '$_prefix${manifest.id}';
    final stampKey = '$_stampPrefix${manifest.id}';

    final cachedRaw = prefs.getString(dataKey);
    final cachedAt = prefs.getInt(stampKey) ?? 0;
    final ageSeconds =
        (DateTime.now().millisecondsSinceEpoch - cachedAt) ~/ 1000;

    if (!forceRefresh &&
        cachedRaw != null &&
        ageSeconds < source.refreshSeconds) {
      return WidgetDataResult(
        data: _unwrap(_decode(cachedRaw), root),
        fromCache: true,
      );
    }

    final url = WidgetExpression.resolve(source.url, ctx);

    if (!WidgetRegistryService.isAllowedUrl(url)) {
      return WidgetDataResult(
        data: cachedRaw == null
            ? null
            : _unwrap(_decode(cachedRaw), root),
        fromCache: cachedRaw != null,
        error: 'Blocked: a widget may only call https URLs.',
      );
    }

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      source.headers.forEach((k, v) {
        headers[k] = WidgetExpression.resolve(v, ctx);
      });

      final uri = Uri.parse(url);
      final response = await (source.method == 'POST'
              ? http.post(uri, headers: headers)
              : http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await prefs.setString(dataKey, response.body);
        await prefs.setInt(
          stampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        return WidgetDataResult(
          data: _unwrap(_decode(response.body), root),
        );
      }

      return WidgetDataResult(
        data: cachedRaw == null
            ? null
            : _unwrap(_decode(cachedRaw), root),
        fromCache: cachedRaw != null,
        error: 'Request failed (${response.statusCode})',
      );
    } catch (e) {
      return WidgetDataResult(
        data: cachedRaw == null
            ? null
            : _unwrap(_decode(cachedRaw), root),
        fromCache: cachedRaw != null,
        error: 'Could not reach the data source.',
      );
    }
  }

  static dynamic _decode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Applies the manifest's `root` path so bindings stay short.
  static dynamic _unwrap(dynamic decoded, String? root) {
    if (decoded == null || root == null || root.isEmpty) return decoded;
    dynamic current = decoded;
    for (final part in root.split('.')) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final i = int.tryParse(part);
        if (i == null || i < 0 || i >= current.length) return null;
        current = current[i];
      } else {
        return null;
      }
    }
    return current;
  }

  static Future<void> clear(String widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$widgetId');
    await prefs.remove('$_stampPrefix$widgetId');
  }
}
