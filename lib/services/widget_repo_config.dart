/// Where the widget inventory lives.
///
/// The inventory is a plain public GitHub repo: an index at `registry.json`
/// plus one JSON manifest per widget. Publishing a widget is a git push —
/// no server, and no new app build.
///
/// Point [owner]/[repo]/[branch] somewhere else to run your own inventory.
class WidgetRepoConfig {
  WidgetRepoConfig._();

  static const String owner = 'meetkool';
  static const String repo = 'exitzero-widgets';
  static const String branch = 'main';

  static const String rawBase =
      'https://raw.githubusercontent.com/$owner/$repo/$branch';

  /// Index of every published widget.
  static const String registryUrl = '$rawBase/registry.json';

  /// Full URL for a manifest path listed in the registry.
  static String manifestUrl(String path) => '$rawBase/$path';

  /// Human-facing page, for the "browse the inventory" link.
  static const String browseUrl = 'https://github.com/$owner/$repo';
}
