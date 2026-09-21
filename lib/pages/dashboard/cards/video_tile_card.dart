import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../widgets/bento_card.dart';

/// Video tile card with background video, gradient overlay, and live badge.
class VideoTileCard extends StatefulWidget {
  /// Asset path (e.g. 'assets/joji_visualizer.mp4') or network URL.
  final String videoSource;

  /// If true, [videoSource] is treated as a bundled asset; otherwise as a
  /// network URL.
  final bool isAsset;

  final String label;
  final String title;
  final String subtitle;
  final bool isLive;
  final bool showInfo;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final double videoOpacity;

  const VideoTileCard({
    super.key,
    required this.videoSource,
    this.isAsset = true,
    this.label = 'Now Playing',
    this.title = 'JOJI',
    this.subtitle = 'Visualizer',
    this.isLive = false,
    this.showInfo = true,
    this.autoplay = true,
    this.loop = true,
    this.muted = true,
    this.videoOpacity = 0.7,
  });

  @override
  State<VideoTileCard> createState() => _VideoTileCardState();
}

class _VideoTileCardState extends State<VideoTileCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController _controller;
  late AnimationController _pulse;

  bool _ready = false;
  bool _foreground = true;
  bool _reviving = false;

  /// Throttling for [_revive], so a player something else keeps pausing
  /// cannot turn into a play/pause fight that burns the battery.
  DateTime _lastRevive = DateTime.fromMillisecondsSinceEpoch(0);
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android pauses the player when the app leaves the foreground and never
    // starts it again. That is how a looping background video ends up frozen
    // on a dashboard you came back to.
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _burst = 0;
      _revive();
    }
  }

  /// Puts the video back to playing whenever anything stopped it.
  ///
  /// Called on every controller update rather than once at startup, because
  /// the pause can come from the lifecycle, from audio focus, or from a loop
  /// that failed to wrap, and none of those announce themselves.
  Future<void> _revive() async {
    if (!widget.autoplay || !_ready || _reviving || !_foreground) return;

    final value = _controller.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.isPlaying || value.isBuffering) return;

    final now = DateTime.now();
    if (now.difference(_lastRevive) < const Duration(milliseconds: 400)) return;
    if (now.difference(_lastRevive) > const Duration(seconds: 5)) _burst = 0;
    // Something is pausing this as fast as we can start it. Stop pushing
    // until the next time the app comes back to the foreground.
    if (_burst >= 8) return;
    _lastRevive = now;
    _burst++;

    _reviving = true;
    try {
      // A loop that did not wrap leaves the position parked at the end,
      // where play() on its own does nothing.
      final duration = value.duration;
      if (duration > Duration.zero &&
          value.position >= duration - const Duration(milliseconds: 150)) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    } catch (_) {
      // A disposed or broken controller is not worth a crash.
    } finally {
      _reviving = false;
    }
  }

  Future<void> _initVideo() async {
    // Note: VideoPlayer uses ExoPlayer on Android which has a known bug
    // on some emulators (like Waydroid) where it crashes the app with Error 0xffffff92
    // when native alarm audio is played concurrently.
    final controller = widget.isAsset
        ? VideoPlayerController.asset(widget.videoSource)
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoSource));
    _controller = controller;
    _ready = false;

    try {
      await controller.initialize();
      // The card can be disposed, or pointed at another source, while
      // initialize() is in flight; touching the old controller after that
      // throws.
      if (!mounted || !identical(_controller, controller)) return;

      await controller.setLooping(widget.loop);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);
      if (widget.autoplay) await controller.play();
    } catch (_) {
      return;
    }

    if (!mounted || !identical(_controller, controller)) return;
    _ready = true;
    controller.addListener(_revive);
    setState(() {});
  }

  @override
  void didUpdateWidget(VideoTileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSource != widget.videoSource) {
      _controller.removeListener(_revive);
      _controller.dispose();
      _initVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _controller.removeListener(_revive);
      _controller.dispose();
    } catch (_) {}
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)), // Updated border opacity
      backgroundColor: Colors.transparent, // Ensure no background color interferes
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          _buildGradientOverlay(),
          // Content layer if needed
          if (widget.isLive || _shouldShowInfo())
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   if (widget.isLive) _buildLiveBadge() else const SizedBox(),
                   if (_shouldShowInfo()) _buildTextBlock() else const SizedBox(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowInfo() {
    if (!widget.showInfo) return false;
    return widget.label.isNotEmpty ||
        widget.title.isNotEmpty ||
        widget.subtitle.isNotEmpty;
  }

  Widget _buildVideoLayer() {
    // If we bypassed initialization to prevent emulator crashes, controller may not be created.
    try {
      if (!_controller.value.isInitialized) {
        return Container(color: Colors.black);
      }
    } catch (_) {
      return Container(color: Colors.black);
    }

    return Opacity(
      opacity: widget.videoOpacity, // 0.6 in HTML
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black,
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _pulse.drive(Tween(begin: 0.3, end: 1.0)),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
