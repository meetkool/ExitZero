import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/camera_capability.dart';
import '../../services/dual_camera.dart';

/// Both cameras at once, in one card.
///
/// It checks first and only offers Start when the device says it can stream a
/// front and a back lens together — there is no point opening a camera to
/// discover that, and the check is cheap. Both feeds come from the native
/// Camera2 session as Flutter textures, so this widget only ever positions
/// them. Nothing is captured, saved or sent.
class DualCameraFeed extends StatefulWidget {
  final Color color;
  final double height;

  /// Clockwise degrees needed to stand each preview upright.
  ///
  /// The sensor orientation a device reports does not, on its own, say which
  /// way its texture ends up on screen, and the two lenses here need turning
  /// opposite ways. These are measured values with manifest overrides, so a
  /// phone that needs different numbers is a push rather than a new build.
  final int backRotation;
  final int frontRotation;

  /// Clockwise degrees applied to each lens when recording.
  ///
  /// Separate from the preview's numbers on purpose. The preview turns a
  /// texture inside a tall pane and crops it; the recording turns the same
  /// texture into a wide frame. The geometry differs, so the value that
  /// looks right in one is not necessarily right in the other. These
  /// default to the sensor orientations the device reports, which is what
  /// stands a sensor buffer upright.
  final int recordBackRotation;
  final int recordFrontRotation;

  /// Mirror the front pane, the way a selfie camera usually reads.
  final bool mirrorFront;

  /// Print each lens's reported sensor orientation on its badge, for working
  /// out the right numbers on a device that disagrees.
  final bool debug;

  const DualCameraFeed({
    super.key,
    required this.color,
    this.height = 260,
    this.backRotation = 90,
    this.frontRotation = 270,
    this.recordBackRotation = 90,
    this.recordFrontRotation = 270,
    this.mirrorFront = false,
    this.debug = false,
  });

  @override
  State<DualCameraFeed> createState() => _DualCameraFeedState();
}

enum _Stage { checking, ready, starting, live, blocked, failed }

class _DualCameraFeedState extends State<DualCameraFeed>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.checking;
  String _detail = '';
  CameraCapability? _capability;
  List<DualCameraFeedInfo> _feeds = const [];

  /// Whether this device gave the recorder its second camera stream. Without
  /// it the preview still runs, so the button is hidden rather than failing
  /// when tapped.
  bool _canRecord = false;
  bool _recording = false;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    // Stopping the cameras natively also finishes and files any recording
    // that was still running, so nothing is lost on the way out.
    if (_stage == _Stage.live) DualCameraService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The native side releases the cameras on pause, so the textures behind
    // these widgets go dead. Follow it back to Ready rather than showing two
    // frozen panes that look live.
    if (state != AppLifecycleState.resumed && _stage == _Stage.live) {
      _ticker?.cancel();
      _ticker = null;
      setState(() {
        _stage = _Stage.ready;
        _feeds = const [];
        // The native side finishes the file on its way out, so a recording
        // interrupted this way is still in the gallery.
        _recording = false;
        _elapsed = Duration.zero;
      });
    }
  }

  Future<void> _check() async {
    final c = await CameraCapabilityService.probe();
    if (!mounted) return;
    setState(() {
      _capability = c;
      _stage = c.supported ? _Stage.ready : _Stage.blocked;
      _detail = c.reason;
    });
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.starting;
      _detail = '';
    });
    try {
      final feeds = await DualCameraService.start();
      if (!mounted) return;
      setState(() {
        _feeds = feeds;
        _stage = _Stage.live;
        _canRecord = DualCameraService.lastStartCanRecord;
        _recording = false;
        _elapsed = Duration.zero;
      });
      HapticFeedback.mediumImpact();
    } on DualCameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _detail = e.message;
      });
    }
  }

  Future<void> _stop() async {
    // Finish the file before the cameras go, or the clip is thrown away.
    if (_recording) await _toggleRecord();

    await DualCameraService.stop();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.ready;
      _feeds = const [];
      _recording = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _toggleRecord() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (_recording) {
        _ticker?.cancel();
        _ticker = null;
        final saved = await DualCameraService.stopRecording();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _elapsed = Duration.zero;
        });
        HapticFeedback.mediumImpact();
        _say(
          saved.withAudio
              ? 'Saved to Movies/ExitZero'
              : 'Saved to Movies/ExitZero, without sound',
        );
      } else {
        await DualCameraService.startRecording(
          backRotation: widget.recordBackRotation,
          frontRotation: widget.recordFrontRotation,
          mirrorFront: widget.mirrorFront,
        );
        if (!mounted) return;
        setState(() {
          _recording = true;
          _elapsed = Duration.zero;
        });
        HapticFeedback.heavyImpact();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _elapsed += const Duration(seconds: 1));
        });
      }
    } on DualCameraException catch (e) {
      if (!mounted) return;
      _ticker?.cancel();
      _ticker = null;
      setState(() => _recording = false);
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_stage) {
      case _Stage.checking:
      case _Stage.starting:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(widget.color),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _stage == _Stage.checking
                    ? 'Checking this device…'
                    : 'Opening both cameras…',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );

      case _Stage.ready:
        return _readyPanel();

      case _Stage.live:
        return _livePanel();

      case _Stage.blocked:
        return _notice(
          Icons.block,
          'Not supported here',
          _detail.isEmpty
              ? 'This device cannot stream both lenses together.'
              : _detail,
          retry: false,
        );

      case _Stage.failed:
        return _notice(Icons.error_outline, 'Could not start', _detail);
    }
  }

  Widget _readyPanel() {
    final c = _capability;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 15,
                color: Color(0xFF2E9E5B),
              ),
              const SizedBox(width: 6),
              const Text(
                'Both cameras supported',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E9E5B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: widget.color,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _start,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 19, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'START',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c == null || c.device.isEmpty
                ? 'Preview only — nothing is recorded'
                : '${c.device} · preview only',
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _livePanel() {
    // Back on the left, front on the right, whatever order they arrived in.
    final back = _feeds.where((f) => !f.isFront).toList();
    final front = _feeds.where((f) => f.isFront).toList();
    final ordered = [...back, ...front];

    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            for (int i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(child: _pane(ordered[i])),
            ],
          ],
        ),
        if (_recording)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(child: _recordingBadge()),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canRecord) ...[
                _roundButton(
                  icon: _recording
                      ? Icons.stop_circle
                      : Icons.fiber_manual_record,
                  colour: _recording
                      ? Colors.white
                      : const Color(0xFFE05252),
                  onTap: _busy ? null : _toggleRecord,
                ),
                const SizedBox(width: 8),
              ],
              _roundButton(
                icon: Icons.stop,
                colour: Colors.white,
                onTap: _stop,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color colour,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? colour.withValues(alpha: 0.4) : colour,
          ),
        ),
      ),
    );
  }

  Widget _recordingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE05252)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFE05252),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'REC ${_clock(_elapsed)}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Quarter turns for this lens, from the configured degrees.
  int _turnsFor(DualCameraFeedInfo feed) {
    final degrees = feed.isFront ? widget.frontRotation : widget.backRotation;
    // Normalise first: a negative or over-wound value should still land on
    // one of the four positions rather than throwing off the layout.
    return ((degrees % 360 + 360) % 360) ~/ 90;
  }

  Widget _pane(DualCameraFeedInfo feed) {
    Widget video = RotatedBox(
      quarterTurns: _turnsFor(feed),
      child: SizedBox(
        width: feed.width.toDouble(),
        height: feed.height.toDouble(),
        child: Texture(textureId: feed.textureId),
      ),
    );

    if (widget.mirrorFront && feed.isFront) {
      video = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: video,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The texture arrives in the sensor's own orientation, so it is turned
        // upright here, then scaled to cover the pane.
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: video,
          ),
        ),
        Positioned(
          left: 7,
          top: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD62828),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.debug
                      ? '${feed.lens.toUpperCase()}  '
                            'sensor ${feed.sensorOrientation}°  '
                            'shown ${_turnsFor(feed) * 90}°'
                      : feed.lens.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _notice(
    IconData icon,
    String title,
    String detail, {
    bool retry = true,
  }) {
    return InkWell(
      onTap: retry ? _start : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
