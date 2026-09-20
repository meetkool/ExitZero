import 'dart:math';
import 'package:flutter/material.dart';

/// One place to drop a pin on the globe.
class GlobeMarker {
  /// Degrees. Positive is north / east.
  final double lat;
  final double lon;

  const GlobeMarker(this.lat, this.lon);
}

/// A wireframe world, turning on a tilted axis.
///
/// Latitude rings and meridians projected by hand, with the far half drawn
/// faintly and the near half brightly. That split is what makes it read as a
/// sphere rather than a flat spirograph — without it the wireframe is
/// ambiguous, and no amount of spinning fixes it.
class Globe3D extends StatefulWidget {
  final Color color;
  final double height;

  /// Seconds for one full rotation.
  final double secondsPerSpin;

  final List<GlobeMarker> markers;
  final bool showAtmosphere;
  final bool showSatellite;

  const Globe3D({
    super.key,
    required this.color,
    this.height = 150,
    this.secondsPerSpin = 14,
    this.markers = const [],
    this.showAtmosphere = true,
    this.showSatellite = true,
  });

  @override
  State<Globe3D> createState() => _Globe3DState();
}

class _Globe3DState extends State<Globe3D> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Duration get _spin => Duration(
    milliseconds: (widget.secondsPerSpin * 1000).round().clamp(2000, 120000),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _spin)..repeat();
  }

  @override
  void didUpdateWidget(Globe3D old) {
    super.didUpdateWidget(old);
    if (old.secondsPerSpin != widget.secondsPerSpin) {
      _controller.duration = _spin;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _GlobePainter(
            t: _controller.value,
            color: widget.color,
            markers: widget.markers,
            showAtmosphere: widget.showAtmosphere,
            showSatellite: widget.showSatellite,
          ),
        ),
      ),
    );
  }
}

class _V3 {
  final double x, y, z;
  const _V3(this.x, this.y, this.z);
}

class _GlobePainter extends CustomPainter {
  final double t;
  final Color color;
  final List<GlobeMarker> markers;
  final bool showAtmosphere;
  final bool showSatellite;

  const _GlobePainter({
    required this.t,
    required this.color,
    required this.markers,
    required this.showAtmosphere,
    required this.showSatellite,
  });

  // Gentle perspective. Pulling the camera in makes the near face balloon and
  // the thing stops looking like a planet.
  static const double _camDist = 5.5;
  static const double _focal = 2.8;

  /// Axial tilt, so we look slightly down on it and the pole is visible.
  static const double _tilt = 0.38;

  static const int _latRings = 5;
  static const int _meridians = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(size.width, size.height) * 0.62;

    final spin = t * 2 * pi;
    final cosT = cos(_tilt);
    final sinT = sin(_tilt);

    /// Lat/lon in radians to a point on the unit sphere, spun and tilted.
    _V3 point(double lat, double lon) {
      final cl = cos(lat);
      final x = cl * sin(lon + spin);
      final y = sin(lat);
      final z = cl * cos(lon + spin);
      // Tip the north pole toward the viewer.
      return _V3(x, y * cosT + z * sinT, -y * sinT + z * cosT);
    }

    /// Positive z is away from the camera.
    Offset project(_V3 p) {
      final s = _focal / (p.z + _camDist);
      return Offset(cx + p.x * s * radius, cy - p.y * s * radius);
    }

    final near = Path();
    final far = Path();

    void stroke(List<_V3> pts, bool closed) {
      final n = pts.length;
      final last = closed ? n : n - 1;
      for (int i = 0; i < last; i++) {
        final a = pts[i];
        final b = pts[(i + 1) % n];
        // A segment counts as near only if both ends are on the near face, so
        // the crossover lands on the silhouette rather than popping.
        final path = (a.z <= 0 && b.z <= 0) ? near : far;
        final pa = project(a);
        final pb = project(b);
        path.moveTo(pa.dx, pa.dy);
        path.lineTo(pb.dx, pb.dy);
      }
    }

    // Latitude rings, skipping the poles themselves.
    for (int r = 1; r <= _latRings; r++) {
      final lat = -pi / 2 + pi * r / (_latRings + 1);
      final pts = <_V3>[];
      for (int i = 0; i < 32; i++) {
        pts.add(point(lat, i / 32 * 2 * pi));
      }
      stroke(pts, true);
    }

    // Meridians, pole to pole.
    for (int m = 0; m < _meridians; m++) {
      final lon = m / _meridians * 2 * pi;
      final pts = <_V3>[];
      for (int i = 0; i <= 24; i++) {
        pts.add(point(-pi / 2 + pi * i / 24, lon));
      }
      stroke(pts, false);
    }

    // ── atmosphere ──
    if (showAtmosphere) {
      final limb = _focal / _camDist * radius;
      canvas.drawCircle(
        Offset(cx, cy),
        limb * 1.06,
        Paint()
          ..color = color.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        limb,
        Paint()..color = color.withValues(alpha: 0.05),
      );
    }

    // Far side first, so the near side draws over it.
    canvas.drawPath(
      far,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = color.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      near,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.9),
    );

    // ── pins ──
    for (final m in markers) {
      final p = point(m.lat * pi / 180, m.lon * pi / 180);
      // Hidden while it is round the back.
      if (p.z > 0.02) continue;
      final at = project(p);
      final fade = (1 - p.z).clamp(0.0, 2.0) / 2;
      canvas.drawCircle(
        at,
        5.5,
        Paint()
          ..color = color.withValues(alpha: 0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        at,
        2.4,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * fade),
      );
    }

    // ── satellite on an inclined orbit ──
    if (showSatellite) {
      const orbitR = 1.28;
      const incline = 0.62;
      final cosI = cos(incline);
      final sinI = sin(incline);

      _V3 orbit(double a) {
        final x = orbitR * cos(a);
        final y = orbitR * sin(a) * sinI;
        final z = orbitR * sin(a) * cosI;
        return _V3(x, y * cosT + z * sinT, -y * sinT + z * cosT);
      }

      final ring = Path();
      for (int i = 0; i <= 48; i++) {
        final p = project(orbit(i / 48 * 2 * pi));
        if (i == 0) {
          ring.moveTo(p.dx, p.dy);
        } else {
          ring.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color.withValues(alpha: 0.2),
      );

      // Three laps per rotation, so it visibly overtakes the spin.
      final sat = orbit(t * 2 * pi * 3);
      final at = project(sat);
      final bright = sat.z <= 0 ? 1.0 : 0.35;
      canvas.drawCircle(
        at,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.4 * bright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        at,
        2.6,
        Paint()..color = color.withValues(alpha: 0.95 * bright),
      );
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.t != t ||
      old.color != color ||
      old.showAtmosphere != showAtmosphere ||
      old.showSatellite != showSatellite ||
      old.markers.length != markers.length;
}
