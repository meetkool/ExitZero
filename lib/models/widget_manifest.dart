/// Models for the remote widget format.
///
/// A widget is data, not code: the app ships the renderer and the inventory
/// ships JSON describing what to draw and where to get the numbers.

// ── parse helpers ────────────────────────────────────────────────────────────

String _str(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

int _int(dynamic v, int fallback) => v is num ? v.toInt() : fallback;

double _dbl(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;

List<String> _strList(dynamic v) => v is List
    ? v.map((e) => e.toString()).toList(growable: false)
    : const <String>[];

List<Map<String, dynamic>> _mapList(dynamic v) => v is List
    ? v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

// ── registry ─────────────────────────────────────────────────────────────────

/// One row of `registry.json` — enough to render the store list without
/// fetching every manifest.
class WidgetRegistryEntry {
  final String id;
  final String name;
  final String description;
  final String version;
  final String icon;
  final String? accent;
  final List<String> tags;
  final String path;

  const WidgetRegistryEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.icon,
    required this.path,
    this.accent,
    this.tags = const [],
  });

  factory WidgetRegistryEntry.fromJson(Map<String, dynamic> j) {
    return WidgetRegistryEntry(
      id: _str(j['id']),
      name: _str(j['name'], _str(j['id'])),
      description: _str(j['description']),
      version: _str(j['version'], '1.0.0'),
      icon: _str(j['icon'], 'widgets'),
      accent: j['accent'] == null ? null : _str(j['accent']),
      tags: _strList(j['tags']),
      path: _str(j['path']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'icon': icon,
    if (accent != null) 'accent': accent,
    'tags': tags,
    'path': path,
  };
}

// ── manifest pieces ──────────────────────────────────────────────────────────

/// A value the user fills in when installing (an API key, a username…).
class WidgetConfigField {
  final String key;
  final String label;
  final String type; // string | number
  final String defaultValue;
  final String hint;
  final bool required;

  const WidgetConfigField({
    required this.key,
    required this.label,
    this.type = 'string',
    this.defaultValue = '',
    this.hint = '',
    this.required = false,
  });

  factory WidgetConfigField.fromJson(Map<String, dynamic> j) {
    return WidgetConfigField(
      key: _str(j['key']),
      label: _str(j['label'], _str(j['key'])),
      type: _str(j['type'], 'string'),
      defaultValue: _str(j['default']),
      hint: _str(j['hint']),
      required: j['required'] == true,
    );
  }
}

/// Where a widget's numbers come from.
class WidgetDataSource {
  final String url;
  final String method;
  final Map<String, String> headers;
  final int refreshSeconds;

  /// Optional dotted path to unwrap before binding, so manifests can write
  /// `{{data.name}}` instead of `{{data.result.user.name}}`.
  final String? root;

  const WidgetDataSource({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.refreshSeconds = 900,
    this.root,
  });

  static WidgetDataSource? fromJson(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    final url = _str(j['url']);
    if (url.isEmpty) return null;
    final rawHeaders = j['headers'];
    return WidgetDataSource(
      url: url,
      method: _str(j['method'], 'GET').toUpperCase(),
      headers: rawHeaders is Map
          ? rawHeaders.map((k, val) => MapEntry(k.toString(), val.toString()))
          : const {},
      refreshSeconds: _int(j['refreshSeconds'], 900),
      root: j['root'] == null ? null : _str(j['root']),
    );
  }
}

/// Default size of the card in the bento grid.
class WidgetLayoutSpec {
  final int span;
  final int minSpan;
  final int maxSpan;
  final double height;
  final double minHeight;
  final double maxHeight;

  const WidgetLayoutSpec({
    this.span = 1,
    this.minSpan = 1,
    this.maxSpan = 2,
    this.height = 140,
    this.minHeight = 100,
    this.maxHeight = 260,
  });

  factory WidgetLayoutSpec.fromJson(dynamic v) {
    if (v is! Map) return const WidgetLayoutSpec();
    final j = Map<String, dynamic>.from(v);
    final minSpan = _int(j['minSpan'], 1).clamp(1, 2);
    final maxSpan = _int(j['maxSpan'], 2).clamp(minSpan, 2);
    final minHeight = _dbl(j['minHeight'], 100);
    final maxHeight = _dbl(j['maxHeight'], 260);
    return WidgetLayoutSpec(
      span: _int(j['span'], 1).clamp(minSpan, maxSpan),
      minSpan: minSpan,
      maxSpan: maxSpan,
      height: _dbl(j['height'], 140).clamp(minHeight, maxHeight),
      minHeight: minHeight,
      maxHeight: maxHeight < minHeight ? minHeight : maxHeight,
    );
  }
}

// ── manifest ─────────────────────────────────────────────────────────────────

class WidgetManifest {
  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String icon;
  final String? accent;
  final List<String> tags;
  final WidgetLayoutSpec layout;
  final List<WidgetConfigField> config;
  final WidgetDataSource? data;
  final List<Map<String, dynamic>> body;

  const WidgetManifest({
    required this.id,
    required this.name,
    this.schemaVersion = 1,
    this.description = '',
    this.author = '',
    this.version = '1.0.0',
    this.icon = 'widgets',
    this.accent,
    this.tags = const [],
    this.layout = const WidgetLayoutSpec(),
    this.config = const [],
    this.data,
    this.body = const [],
  });

  /// Highest schema this build of the app knows how to render.
  static const int supportedSchemaVersion = 1;

  bool get isSupported => schemaVersion <= supportedSchemaVersion;

  factory WidgetManifest.fromJson(Map<String, dynamic> j) {
    return WidgetManifest(
      schemaVersion: _int(j['schemaVersion'], 1),
      id: _str(j['id']),
      name: _str(j['name'], _str(j['id'])),
      description: _str(j['description']),
      author: _str(j['author']),
      version: _str(j['version'], '1.0.0'),
      icon: _str(j['icon'], 'widgets'),
      accent: j['accent'] == null ? null : _str(j['accent']),
      tags: _strList(j['tags']),
      layout: WidgetLayoutSpec.fromJson(j['layout']),
      config: (j['config'] is List)
          ? (j['config'] as List)
                .whereType<Map>()
                .map(
                  (e) => WidgetConfigField.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
      data: WidgetDataSource.fromJson(j['data']),
      body: _mapList(j['body']),
    );
  }
}
