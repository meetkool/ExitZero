import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The binding context a manifest's `{{...}}` expressions resolve against.
class WidgetBindingContext {
  /// Parsed body of the widget's data source.
  final dynamic data;

  /// Values the user filled in when installing.
  final Map<String, String> config;

  /// Set while rendering a `list` item, so `{{item.x}}` works.
  final dynamic item;

  /// Index of the current `list` item.
  final int index;

  const WidgetBindingContext({
    this.data,
    this.config = const {},
    this.item,
    this.index = 0,
  });

  WidgetBindingContext withItem(dynamic value, int i) => WidgetBindingContext(
    data: data,
    config: config,
    item: value,
    index: i,
  );
}

/// Resolves the `{{ path }}` expressions used throughout a manifest.
///
/// Supported roots: `data`, `config`, `item`, `index`. A path walks maps by
/// key and lists by numeric index (`data.items.0.name`). `??` supplies a
/// fallback when the path is missing or null: `{{data.count ?? 0}}`.
class WidgetExpression {
  WidgetExpression._();

  static final RegExp _token = RegExp(r'\{\{([^}]*)\}\}');

  /// Substitutes every expression in [template] and returns the result.
  static String resolve(String template, WidgetBindingContext ctx) {
    if (!template.contains('{{')) return template;
    return template.replaceAllMapped(_token, (m) {
      final raw = (m.group(1) ?? '').trim();
      if (raw.isEmpty) return '';

      String path = raw;
      String fallback = '';
      final idx = raw.indexOf('??');
      if (idx != -1) {
        path = raw.substring(0, idx).trim();
        fallback = _unquote(raw.substring(idx + 2).trim());
      }

      final value = lookup(path, ctx);
      if (value == null) return fallback;
      if (value is String && value.isEmpty) return fallback;
      return _stringify(value);
    });
  }

  /// Resolves a single expression and keeps its native type, so numeric
  /// fields (progress values, sizes) do not have to round-trip via a string.
  static dynamic resolveValue(dynamic input, WidgetBindingContext ctx) {
    if (input is num || input is bool) return input;
    if (input is! String) return input;

    final full = _token.firstMatch(input);
    // A lone expression like "{{data.pct}}" keeps the underlying type.
    if (full != null && full.start == 0 && full.end == input.length) {
      final raw = (full.group(1) ?? '').trim();
      String path = raw;
      dynamic fallback;
      final idx = raw.indexOf('??');
      if (idx != -1) {
        path = raw.substring(0, idx).trim();
        fallback = _coerce(_unquote(raw.substring(idx + 2).trim()));
      }
      return lookup(path, ctx) ?? fallback;
    }

    return resolve(input, ctx);
  }

  /// Walks a dotted path against the binding context.
  static dynamic lookup(String path, WidgetBindingContext ctx) {
    if (path.isEmpty) return null;
    final parts = path.split('.');

    dynamic current;
    switch (parts.first) {
      case 'data':
        current = ctx.data;
        break;
      case 'config':
        current = ctx.config;
        break;
      case 'item':
        current = ctx.item;
        break;
      case 'index':
        return ctx.index;
      default:
        return null;
    }

    for (final part in parts.skip(1)) {
      if (current == null) return null;
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

  /// Resolves a path that is expected to be a list, for `list` components.
  static List<dynamic> resolveList(dynamic source, WidgetBindingContext ctx) {
    if (source is List) return source;
    if (source is! String) return const [];
    final match = _token.firstMatch(source);
    final path = match != null
        ? (match.group(1) ?? '').trim()
        : source.trim();
    final value = lookup(path, ctx);
    return value is List ? value : const [];
  }

  static String _unquote(String s) {
    if (s.length >= 2 &&
        ((s.startsWith("'") && s.endsWith("'")) ||
            (s.startsWith('"') && s.endsWith('"')))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static dynamic _coerce(String s) {
    final n = num.tryParse(s);
    if (n != null) return n;
    if (s == 'true') return true;
    if (s == 'false') return false;
    return s;
  }

  static String _stringify(dynamic v) {
    if (v is double && v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    return v.toString();
  }
}

/// Number formatting available to `metric` and `text` components.
class WidgetFormat {
  WidgetFormat._();

  static String apply(String value, String? format) {
    if (format == null || format.isEmpty) return value;
    final n = num.tryParse(value);
    if (n == null) return value;

    switch (format) {
      case 'compact':
        return _compact(n);
      case 'percent':
        // Accepts either 0..1 or 0..100.
        final pct = n <= 1 ? n * 100 : n;
        return '${pct.round()}%';
      case 'integer':
        return n.round().toString();
      case 'oneDecimal':
        return n.toStringAsFixed(1);
      default:
        return value;
    }
  }

  static String _compact(num n) {
    final abs = n.abs();
    if (abs >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (abs >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.round().toString();
  }
}

/// Colours a manifest may name.
///
/// Accepts the brand tokens plus `#RRGGBB` / `#AARRGGBB` literals.
class WidgetColors {
  WidgetColors._();

  static const Map<String, Color> _tokens = {
    'orange': AppColors.orange,
    'burnt': AppColors.burnt,
    'teal': AppColors.teal,
    'tealLight': AppColors.tealLight,
    'cream': AppColors.cream,
    'dark': AppColors.dark,
    'deep': AppColors.deep,
    'white': Colors.white,
    'black': Colors.black,
    'green': Color(0xFF2E9E5B),
    'red': Color(0xFFD62828),
    'yellow': Color(0xFFFCBF49),
    'blue': Color(0xFF3A86FF),
    'purple': Color(0xFF8338EC),
    'grey': Color(0xFF8A8A8A),
  };

  static Color resolve(dynamic name, {Color fallback = AppColors.cream}) {
    if (name == null) return fallback;
    final s = name.toString().trim();
    if (s.isEmpty) return fallback;

    if (s.startsWith('#')) {
      final hex = s.substring(1);
      final value = int.tryParse(hex, radix: 16);
      if (value == null) return fallback;
      if (hex.length == 6) return Color(0xFF000000 | value);
      if (hex.length == 8) return Color(value);
      return fallback;
    }

    return _tokens[s] ?? fallback;
  }
}

/// Icons a manifest may name.
///
/// Deliberately a fixed map of const [IconData] rather than constructing
/// IconData from a remote code point: building icons dynamically defeats
/// Flutter's icon tree-shaking and would let a manifest point at any glyph.
class WidgetIcons {
  WidgetIcons._();

  static const Map<String, IconData> _icons = {
    'widgets': Icons.widgets,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'bolt': Icons.bolt,
    'local_fire_department': Icons.local_fire_department,
    'code': Icons.code,
    'terminal': Icons.terminal,
    'bug_report': Icons.bug_report,
    'commit': Icons.commit,
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'timeline': Icons.timeline,
    'insights': Icons.insights,
    'check_circle': Icons.check_circle,
    'cancel': Icons.cancel,
    'schedule': Icons.schedule,
    'alarm': Icons.alarm,
    'calendar_today': Icons.calendar_today,
    'event': Icons.event,
    'notifications': Icons.notifications,
    'mail': Icons.mail,
    'send': Icons.send,
    'chat': Icons.chat_bubble,
    'person': Icons.person,
    'group': Icons.group,
    'work': Icons.work,
    'school': Icons.school,
    'book': Icons.menu_book,
    'water_drop': Icons.water_drop,
    'restaurant': Icons.restaurant,
    'fitness_center': Icons.fitness_center,
    'directions_run': Icons.directions_run,
    'bedtime': Icons.bedtime,
    'wb_sunny': Icons.wb_sunny,
    'cloud': Icons.cloud,
    'thermostat': Icons.thermostat,
    'attach_money': Icons.attach_money,
    'savings': Icons.savings,
    'shopping_cart': Icons.shopping_cart,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'sports_esports': Icons.sports_esports,
    'flag': Icons.flag,
    'emoji_events': Icons.emoji_events,
    'lightbulb': Icons.lightbulb,
    'format_quote': Icons.format_quote,
    'link': Icons.link,
    'cloud_off': Icons.cloud_off,
    'error_outline': Icons.error_outline,
  };

  static IconData resolve(dynamic name, {IconData fallback = Icons.widgets}) {
    if (name == null) return fallback;
    return _icons[name.toString().trim()] ?? fallback;
  }

  static bool isKnown(String name) => _icons.containsKey(name);

  static List<String> get names => _icons.keys.toList(growable: false);
}
