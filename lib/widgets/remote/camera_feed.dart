import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A live camera preview, switchable between front and back.
///
/// Deliberately preview only: it never captures a frame, writes a file, or
/// sends anything anywhere. A remote manifest can ask for this component, so
/// the app decides what it is allowed to do — and "show me a picture of now"
/// is the whole of it.
///
/// It also never starts by itself. The camera stays closed until tapped,
/// because a dashboard that silently opens the lens when you scroll past is
/// both a battery problem and a nasty surprise. It closes again whenever the
/// app leaves the foreground.
class CameraFeed extends StatefulWidget {
  final Color color;
  final double height;

  /// Which camera to try first.
  final bool startWithFront;

  const CameraFeed({
    super.key,
    required this.color,
    this.height = 220,
    this.startWithFront = false,
  });

  @override
  State<CameraFeed> createState() => _CameraFeedState();
}

enum _Status { idle, starting, live, denied, unavailable, failed }

class _CameraFeedState extends State<CameraFeed> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  _Status _status = _Status.idle;
  String _detail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hand the camera back the moment the app is not in front. Android will
    // take it from us anyway when another app asks, and holding it open is
    // both rude and expensive.
    if (state != AppLifecycleState.resumed && _status == _Status.live) {
      _stop();
    }
  }

  Future<void> _start() async {
    if (_status == _Status.starting || _status == _Status.live) return;
    setState(() {
      _status = _Status.starting;
      _detail = '';
    });

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _status = _Status.unavailable;
          _detail = 'No camera on this device.';
        });
        return;
      }

      final wanted = widget.startWithFront
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final preferred = _cameras.indexWhere((c) => c.lensDirection == wanted);
      _index = preferred >= 0 ? preferred : 0;

      await _open(_cameras[_index]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _denialCode(e.code) ? _Status.denied : _Status.failed;
        _detail = _denialCode(e.code)
            ? 'Camera permission is off for ExitZero.'
            : (e.description ?? e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.failed;
        _detail = e.toString();
      });
    }
  }

  static bool _denialCode(String code) =>
      code == 'CameraAccessDenied' ||
      code == 'CameraAccessDeniedWithoutPrompt' ||
      code == 'CameraAccessRestricted' ||
      code == 'AudioAccessDenied';

  Future<void> _open(CameraDescription description) async {
    // Tear the previous one down first: a device will only hand out the
    // camera once, so flipping without disposing fails on the second open.
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      // No microphone. This is a preview, not a recorder, and asking for
      // audio would drag in a permission it has no use for.
      enableAudio: false,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _status = _Status.live;
    });
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _status != _Status.live) return;
    HapticFeedback.selectionClick();
    final next = (_index + 1) % _cameras.length;
    setState(() => _status = _Status.starting);
    try {
      _index = next;
      await _open(_cameras[next]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.failed;
        _detail = e.description ?? e.code;
      });
    }
  }

  Future<void> _stop() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() => _status = _Status.idle);
  }

  bool get _isFront =>
      _cameras.isNotEmpty &&
      _index < _cameras.length &&
      _cameras[_index].lensDirection == CameraLensDirection.front;

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
    switch (_status) {
      case _Status.live:
        return _preview();
      case _Status.starting:
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(widget.color),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        );
      case _Status.idle:
        return _tapToStart();
      case _Status.denied:
        return _message(
          Icons.no_photography,
          'Camera permission needed',
          '$_detail Turn it on in Android settings, then tap to retry.',
        );
      case _Status.unavailable:
        return _message(Icons.videocam_off, 'No camera', _detail);
      case _Status.failed:
        return _message(Icons.error_outline, 'Camera failed', _detail);
    }
  }

  Widget _tapToStart() {
    return InkWell(
      onTap: _start,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.videocam, color: widget.color, size: 22),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to start camera',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Preview only — nothing is saved',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String detail) {
    return InkWell(
      onTap: _start,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
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
                const SizedBox(height: 3),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The sensor's aspect ratio rarely matches the card, so cover the
        // card and crop rather than letterboxing it.
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 720,
            height: controller.value.previewSize?.width ?? 1280,
            child: CameraPreview(controller),
          ),
        ),

        // A live dot, so it is never ambiguous that the lens is open.
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD62828),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isFront ? 'FRONT' : 'BACK',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 10,
          bottom: 10,
          child: Row(
            children: [
              if (_cameras.length > 1)
                _button(Icons.flip_camera_android, 'Switch camera', _flip),
              if (_cameras.length > 1) const SizedBox(width: 8),
              _button(Icons.stop, 'Stop camera', _stop),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
