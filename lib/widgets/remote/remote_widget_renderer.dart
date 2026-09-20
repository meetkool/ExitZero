import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'avatar_3d.dart';
import 'globe_3d.dart';
import 'widget_dsl.dart';

/// Turns a manifest's `body` into widgets.
///
/// The vocabulary is deliberately closed: a manifest picks from these
/// component types and nothing else. That is what makes a remote widget safe
/// to render — it describes a layout, it cannot express behaviour.
class RemoteWidgetRenderer {
  RemoteWidgetRenderer._();

  /// Renders a list of components as a column.
  static Widget buildBody(
    List<Map<String, dynamic>> body,
    WidgetBindingContext ctx, {
    Color accent = AppColors.orange,
  }) {
    if (body.isEmpty) {
      return const SizedBox.shrink();
    }
    if (body.length == 1) {
      return build(body.first, ctx, accent) ?? const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: _children(body, ctx, accent),
    );
  }

  static List<Widget> _children(
    List<Map<String, dynamic>> nodes,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final out = <Widget>[];
    for (final node in nodes) {
      final w = build(node, ctx, accent);
      if (w != null) out.add(w);
    }
    return out;
  }

  static List<Map<String, dynamic>> _childNodes(dynamic v) => v is List
      ? v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];

  /// Builds one component. Returns null for an unknown type, so a manifest
  /// written against a newer schema degrades instead of crashing.
  static Widget? build(
    Map<String, dynamic> node,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final type = (node['type'] ?? '').toString();

    // A component can hide itself when a binding is empty.
    final showIf = node['showIf'];
    if (showIf != null) {
      final v = WidgetExpression.resolveValue(showIf, ctx);
      if (v == null ||
          v == false ||
          (v is String && (v.isEmpty || v == 'false')) ||
          (v is num && v == 0)) {
        return null;
      }
    }

    switch (type) {
      case 'text':
        return _text(node, ctx);
      case 'label':
        return _label(node, ctx);
      case 'metric':
        return _metric(node, ctx, accent);
      case 'iconBadge':
        return _iconBadge(node, ctx, accent);
      case 'badge':
        return _badge(node, ctx, accent);
      case 'progressBar':
        return _progressBar(node, ctx, accent);
      case 'progressRing':
        return _progressRing(node, ctx, accent);
      case 'row':
        return _row(node, ctx, accent);
      case 'column':
        return _column(node, ctx, accent);
      case 'list':
        return _list(node, ctx, accent);
      case 'avatar3d':
        return _avatar3d(node, ctx, accent);
      case 'globe3d':
        return _globe3d(node, ctx, accent);
      case 'divider':
        return Divider(
          height: _dbl(node['height'], 17),
          color: Colors.white.withValues(alpha: 0.1),
        );
      case 'spacer':
        return node['size'] == null
            ? const Spacer()
            : SizedBox(height: _dbl(node['size'], 8));
      default:
        return null;
    }
  }

  /// A small figure jogging a circular track, drawn in perspective.
  ///
  /// Projection maths in a painter rather than a 3D package: no dependency,
  /// no model file to fetch, and cheap enough to sit in the grid.
  static Widget _avatar3d(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    // These go through the binding engine so a manifest can drive them from
    // config. Config values arrive as strings, which _dbl alone would reject
    // and silently replace with its fallback.
    return Avatar3D(
      color: WidgetColors.resolve(n['color'], fallback: accent),
      height: _numeric(WidgetExpression.resolveValue(n['size'], ctx), 120),
      secondsPerLap: _numeric(
        WidgetExpression.resolveValue(n['secondsPerLap'], ctx),
        6,
      ),
      showTrack: n['showTrack'] != false,
    );
  }

  /// A turning wireframe world, optionally with pins on it.
  static Widget _globe3d(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    return Globe3D(
      color: WidgetColors.resolve(n['color'], fallback: accent),
      height: _numeric(WidgetExpression.resolveValue(n['size'], ctx), 150),
      secondsPerSpin: _numeric(
        WidgetExpression.resolveValue(n['secondsPerSpin'], ctx),
        14,
      ),
      markers: _markers(n['markers'], ctx),
      showAtmosphere: n['showAtmosphere'] != false,
      showSatellite: n['showSatellite'] != false,
    );
  }

  /// Pins come either as a literal list in the manifest or bound from data,
  /// so each coordinate is resolved rather than read straight off the map.
  static List<GlobeMarker> _markers(dynamic raw, WidgetBindingContext ctx) {
    final list = raw is List
        ? raw
        : WidgetExpression.resolveList(raw, ctx);
    final out = <GlobeMarker>[];
    for (final e in list) {
      if (e is! Map) continue;
      final lat = _numeric(
        WidgetExpression.resolveValue(e['lat'], ctx),
        double.nan,
      );
      final lon = _numeric(
        WidgetExpression.resolveValue(e['lon'], ctx),
        double.nan,
      );
      // Skip anything that did not resolve to a usable coordinate rather
      // than dropping a pin at (0, 0) in the Atlantic.
      if (lat.isNaN || lon.isNaN) continue;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
      out.add(GlobeMarker(lat, lon));
    }
    return out;
  }

  /// Accepts a number or a numeric string, since a bound value may be either.
  static double _numeric(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  // ── leaves ─────────────────────────────────────────────────────────────────

  static Widget _text(Map<String, dynamic> n, WidgetBindingContext ctx) {
    final raw = WidgetExpression.resolve(_s(n['text']), ctx);
    return Text(
      WidgetFormat.apply(raw, n['format']?.toString()),
      maxLines: _int(n['maxLines'], 2),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: _dbl(n['size'], 13),
        fontWeight: _weight(n['weight']),
        height: 1.25,
        color: WidgetColors.resolve(
          n['color'],
          fallback: AppColors.cream.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  /// The small spaced-out caption used across the dashboard.
  static Widget _label(Map<String, dynamic> n, WidgetBindingContext ctx) {
    final raw = WidgetExpression.resolve(_s(n['text']), ctx);
    return Text(
      raw.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: _dbl(n['size'], 9),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: WidgetColors.resolve(
          n['color'],
          fallback: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Big value with an optional caption underneath.
  static Widget _metric(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final value = WidgetFormat.apply(
      WidgetExpression.resolve(_s(n['value']), ctx),
      n['format']?.toString(),
    );
    final unit = WidgetExpression.resolve(_s(n['unit']), ctx);
    final caption = WidgetExpression.resolve(_s(n['caption']), ctx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value.isEmpty ? '--' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _dbl(n['size'], 26),
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                  letterSpacing: -0.5,
                  color: WidgetColors.resolve(
                    n['color'],
                    fallback: Colors.white,
                  ),
                ),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: _dbl(n['unitSize'], 12),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _iconBadge(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final color = WidgetColors.resolve(n['color'], fallback: accent);
    final size = _dbl(n['size'], 36);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _dbl(n['bgOpacity'], 0.2)),
        shape: BoxShape.circle,
      ),
      child: Icon(
        WidgetIcons.resolve(n['icon']),
        color: color,
        size: size * 0.5,
      ),
    );
  }

  static Widget _badge(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    // Either a plain templated `text`, or a `value` that can be formatted and
    // wrapped in a prefix/suffix. Formatting needs the number on its own,
    // which a template with surrounding words cannot provide.
    String text;
    if (n['value'] != null) {
      final formatted = WidgetFormat.apply(
        WidgetExpression.resolve(_s(n['value']), ctx),
        n['format']?.toString(),
      );
      text =
          WidgetExpression.resolve(_s(n['prefix']), ctx) +
          formatted +
          WidgetExpression.resolve(_s(n['suffix']), ctx);
    } else {
      text = WidgetExpression.resolve(_s(n['text']), ctx);
    }
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final color = WidgetColors.resolve(n['color'], fallback: accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: _dbl(n['size'], 10),
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static Widget _progressBar(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final v = _progressValue(n, ctx);
    final color = WidgetColors.resolve(n['color'], fallback: accent);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: v,
        minHeight: _dbl(n['thickness'], 6),
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }

  static Widget _progressRing(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final v = _progressValue(n, ctx);
    final color = WidgetColors.resolve(n['color'], fallback: accent);
    final size = _dbl(n['size'], 56);
    final label = WidgetExpression.resolve(_s(n['centerText']), ctx);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: _dbl(n['thickness'], 5),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: size * 0.24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          else if (n['centerIcon'] != null)
            Icon(
              WidgetIcons.resolve(n['centerIcon']),
              color: color,
              size: size * 0.32,
            ),
        ],
      ),
    );
  }

  /// Clamped 0..1. Accepts a 0..1 fraction, or a `value`/`max` pair.
  static double _progressValue(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
  ) {
    final rawValue = WidgetExpression.resolveValue(n['value'], ctx);
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue?.toString() ?? '') ?? 0;

    final rawMax = WidgetExpression.resolveValue(n['max'], ctx);
    final max = rawMax is num
        ? rawMax.toDouble()
        : double.tryParse(rawMax?.toString() ?? '') ?? 0;

    if (max > 0) return (value / max).clamp(0.0, 1.0);
    if (value > 1) return (value / 100).clamp(0.0, 1.0);
    return value.clamp(0.0, 1.0);
  }

  // ── containers ─────────────────────────────────────────────────────────────

  static Widget _row(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final kids = _children(_childNodes(n['children']), ctx, accent);
    final gap = _dbl(n['gap'], 0);
    return Row(
      mainAxisAlignment: _mainAxis(n['justify']),
      crossAxisAlignment: _crossAxis(n['align'], defaultCentre: true),
      mainAxisSize: MainAxisSize.max,
      children: gap > 0 ? _withGaps(kids, gap, horizontal: true) : kids,
    );
  }

  static Widget _column(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final kids = _children(_childNodes(n['children']), ctx, accent);
    final gap = _dbl(n['gap'], 0);
    final column = Column(
      mainAxisAlignment: _mainAxis(n['justify']),
      crossAxisAlignment: _crossAxis(n['align'], defaultCentre: false),
      mainAxisSize: n['expand'] == true
          ? MainAxisSize.max
          : MainAxisSize.min,
      children: gap > 0 ? _withGaps(kids, gap, horizontal: false) : kids,
    );
    return n['flex'] == true ? Expanded(child: column) : column;
  }

  /// Repeats [item] once per entry of [source].
  static Widget _list(
    Map<String, dynamic> n,
    WidgetBindingContext ctx,
    Color accent,
  ) {
    final source = WidgetExpression.resolveList(n['source'], ctx);
    if (source.isEmpty) {
      final empty = _s(n['emptyText']);
      if (empty.isEmpty) return const SizedBox.shrink();
      return Text(
        WidgetExpression.resolve(empty, ctx),
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      );
    }

    final template = n['item'];
    if (template is! Map) return const SizedBox.shrink();
    final node = Map<String, dynamic>.from(template);

    final limit = _int(n['limit'], 3);
    final count = source.length < limit ? source.length : limit;
    final gap = _dbl(n['gap'], 6);

    final rows = <Widget>[];
    for (int i = 0; i < count; i++) {
      final w = build(node, ctx.withItem(source[i], i), accent);
      if (w == null) continue;
      if (rows.isNotEmpty && gap > 0) rows.add(SizedBox(height: gap));
      rows.add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static List<Widget> _withGaps(
    List<Widget> kids,
    double gap, {
    required bool horizontal,
  }) {
    if (kids.length < 2) return kids;
    final out = <Widget>[];
    for (int i = 0; i < kids.length; i++) {
      if (i > 0) {
        out.add(
          horizontal ? SizedBox(width: gap) : SizedBox(height: gap),
        );
      }
      out.add(kids[i]);
    }
    return out;
  }

  static MainAxisAlignment _mainAxis(dynamic v) {
    switch (v?.toString()) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'between':
        return MainAxisAlignment.spaceBetween;
      case 'around':
        return MainAxisAlignment.spaceAround;
      default:
        return MainAxisAlignment.start;
    }
  }

  static CrossAxisAlignment _crossAxis(
    dynamic v, {
    required bool defaultCentre,
  }) {
    switch (v?.toString()) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'start':
        return CrossAxisAlignment.start;
      default:
        return defaultCentre
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;
    }
  }

  static FontWeight _weight(dynamic v) {
    switch (v?.toString()) {
      case 'bold':
        return FontWeight.bold;
      case 'semibold':
        return FontWeight.w600;
      case 'medium':
        return FontWeight.w500;
      default:
        return FontWeight.normal;
    }
  }

  static String _s(dynamic v) => v == null ? '' : v.toString();

  static double _dbl(dynamic v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : fallback;
}
