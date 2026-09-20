import 'dart:math';
import 'package:flutter/material.dart';

/// A small figure jogging around a circular track, drawn in perspective.
///
/// No 3D package: the figure is a handful of points in world space, rotated
/// and projected by hand each frame. That keeps it a few dozen line segments
/// per paint, cheap enough to sit on a dashboard next to everything else,
/// and it needs no model file to download.
class Avatar3D extends StatefulWidget {
  final Color color;
  final double height;

  /// Seconds for one lap of the track.
  final double secondsPerLap;

  final bool showTrack;

  const Avatar3D({
    super.key,
    required this.color,
    this.height = 120,
    this.secondsPerLap = 6,
    this.showTrack = true,
  });

  @override
  State<Avatar3D> createState() => _Avatar3DState();
}

class _Avatar3DState extends State<Avatar3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.secondsPerLap * 1000).round().clamp(1000, 60000),
      ),
    )..repeat();
  }

  @override
  void didUpdateWidget(Avatar3D old) {
    super.didUpdateWidget(old);
    if (old.secondsPerLap != widget.secondsPerLap) {
      _controller.duration = Duration(
        milliseconds: (widget.secondsPerLap * 1000).round().clamp(1000, 60000),
      );
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
          painter: _RunnerPainter(
            t: _controller.value,
            color: widget.color,
            showTrack: widget.showTrack,
          ),
        ),
      ),
    );
  }
}

// ── 3D helpers ───────────────────────────────────────────────────────────────

class _V3 {
  final double x, y, z;
  const _V3(this.x, this.y, this.z);

  _V3 operator +(_V3 o) => _V3(x + o.x, y + o.y, z + o.z);
  _V3 operator *(double s) => _V3(x * s, y * s, z * s);
}

/// A projected point: where it landed, and how near it is (bigger = closer).
class _P {
  final Offset at;
  final double scale;
  const _P(this.at, this.scale);
}

class _RunnerPainter extends CustomPainter {
  /// Lap progress, 0..1.
  final double t;
  final Color color;
  final bool showTrack;

  const _RunnerPainter({
    required this.t,
    required this.color,
    required this.showTrack,
  });

  // Camera. Pitched down so the track reads as a ring on the ground rather
  // than a flat circle.
  static const double _camDist = 3.3;
  static const double _focal = 2.6;
  static const double _pitch = 0.52;

  /// Strides per lap. Sets how fast the legs cycle relative to travel.
  static const double _strides = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.58;

    // Height is what constrains the scene, so the vertical scale comes off
    // the short side. A wide card would then leave the track as a narrow
    // strip in the middle, so x is allowed to stretch a little — capped,
    // because the same stretch applies to the figure and too much of it
    // gives the runner an absurd stance.
    final worldScale = min(size.width, size.height) * 0.44;
    final scaleX = min(
      worldScale * (size.width / max(size.height, 1)),
      worldScale * 1.35,
    );

    final cosP = cos(_pitch);
    final sinP = sin(_pitch);

    _P project(_V3 p) {
      // Pitch the world about X, then divide by depth.
      final y1 = p.y * cosP + p.z * sinP;
      final z1 = -p.y * sinP + p.z * cosP;
      final denom = (z1 + _camDist).clamp(0.25, 100.0);
      final s = _focal / denom;
      return _P(
        Offset(cx + p.x * s * scaleX, cy - y1 * s * worldScale),
        s,
      );
    }

    // ── the track ──
    if (showTrack) {
      final path = Path();
      for (int i = 0; i <= 72; i++) {
        final a = i / 72 * 2 * pi;
        final p = project(_V3(cos(a), 0, sin(a)));
        if (i == 0) {
          path.moveTo(p.at.dx, p.at.dy);
        } else {
          path.lineTo(p.at.dx, p.at.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.28),
      );
    }

    // ── where the runner is, and which way it faces ──
    final theta = t * 2 * pi;
    final phase = t * 2 * pi * _strides;

    final base = _V3(cos(theta), 0, sin(theta));
    // Along the track, and outward from its centre.
    final fwd = _V3(-sin(theta), 0, cos(theta));
    final side = _V3(cos(theta), 0, sin(theta));

    // Two foot-strikes per stride, so the bounce peaks twice.
    final bob = sin(phase) * sin(phase) * 0.022;

    /// Local coordinates: l = left/right, u = up, f = forward.
    _V3 local(double l, double u, double f) =>
        base + side * l + _V3(0, u + bob, 0) + fwd * f;

    // ── limbs ──
    const hipY = 0.20;
    const shoulderY = 0.335;
    const thigh = 0.105;
    const shin = 0.105;
    const upperArm = 0.085;
    const foreArm = 0.085;

    // Legs swing opposite each other; the trailing one bends at the knee.
    final swingL = sin(phase) * 0.62;
    final swingR = sin(phase + pi) * 0.62;
    final bendL = max(0.0, -sin(phase)) * 1.05 + 0.12;
    final bendR = max(0.0, -sin(phase + pi)) * 1.05 + 0.12;

    // Arms counter-swing against the legs.
    final armL = sin(phase + pi) * 0.55;
    final armR = sin(phase) * 0.55;

    List<_V3> leg(double sideOffset, double swing, double bend) {
      final hip = local(sideOffset, hipY, 0);
      final knee =
          hip + _V3(0, -cos(swing) * thigh, 0) + fwd * (sin(swing) * thigh);
      final ankle = swing - bend;
      final foot =
          knee + _V3(0, -cos(ankle) * shin, 0) + fwd * (sin(ankle) * shin);
      return [hip, knee, foot];
    }

    List<_V3> arm(double sideOffset, double swing) {
      final shoulder = local(sideOffset, shoulderY, 0);
      final elbow = shoulder +
          _V3(0, -cos(swing) * upperArm, 0) +
          fwd * (sin(swing) * upperArm);
      // Elbows stay bent, the way they do when you run.
      final wrist = swing + 1.15;
      final hand = elbow +
          _V3(0, -cos(wrist) * foreArm, 0) +
          fwd * (sin(wrist) * foreArm);
      return [shoulder, elbow, hand];
    }

    final legLeft = leg(-0.035, swingL, bendL);
    final legRight = leg(0.035, swingR, bendR);
    final armLeft = arm(-0.055, armL);
    final armRight = arm(0.055, armR);

    final hipMid = local(0, hipY, 0);
    final chest = local(0, shoulderY, 0);
    final headC = local(0, 0.415, 0.005);

    final depth = project(base).scale;
    final stroke = (depth * worldScale * 0.042).clamp(1.6, 5.0);

    // ── shadow, so the figure sits on the ground instead of floating ──
    final groundAt = project(base);
    canvas.drawOval(
      Rect.fromCenter(
        center: groundAt.at,
        width: depth * worldScale * 0.16,
        height: depth * worldScale * 0.055,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38 - bob * 6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    void bone(List<_V3> chain, {double widthFactor = 1}) {
      final path = Path();
      for (int i = 0; i < chain.length; i++) {
        final p = project(chain[i]);
        if (i == 0) {
          path.moveTo(p.at.dx, p.at.dy);
        } else {
          path.lineTo(p.at.dx, p.at.dy);
        }
      }
      // A soft pass underneath makes it glow against the dark card.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke * widthFactor * 2.4
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke * widthFactor
          ..color = color,
      );
    }

    bone([hipMid, chest], widthFactor: 1.15);
    bone(legLeft);
    bone(legRight);
    bone(armLeft, widthFactor: 0.85);
    bone(armRight, widthFactor: 0.85);

    // ── head ──
    final head = project(headC);
    final headR = (depth * worldScale * 0.062).clamp(3.0, 12.0);

    canvas.drawCircle(
      head.at,
      headR * 1.9,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(head.at, headR, Paint()..color = color);

    // A face, but only once the head is big enough to read as one.
    if (headR >= 6) {
      final eyeR = (headR * 0.17).clamp(0.9, 2.2);
      final eyeDx = headR * 0.34;
      final eyeDy = headR * 0.12;
      final eyePaint = Paint()..color = Colors.black.withValues(alpha: 0.75);

      // Facing along the track: eyes lead, so they shift with the tangent as
      // seen on screen.
      final ahead = project(headC + fwd * 0.05).at;
      final dir = ahead - head.at;
      final len = dir.distance;
      final unit = len < 0.001 ? const Offset(0, 0) : dir / len;
      final perp = Offset(-unit.dy, unit.dx);

      canvas.drawCircle(
        head.at + perp * eyeDx + Offset(0, -eyeDy) + unit * (headR * 0.25),
        eyeR,
        eyePaint,
      );
      canvas.drawCircle(
        head.at - perp * eyeDx + Offset(0, -eyeDy) + unit * (headR * 0.25),
        eyeR,
        eyePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RunnerPainter old) =>
      old.t != t || old.color != color || old.showTrack != showTrack;
}
