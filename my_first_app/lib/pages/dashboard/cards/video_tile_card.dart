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
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = widget.isAsset
        ? VideoPlayerController.asset(widget.videoSource)
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoSource));
    await _controller.initialize();
    await _controller.setLooping(widget.loop);
    await _controller.setVolume(widget.muted ? 0.0 : 1.0);
    if (widget.autoplay) {
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoTileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSource != widget.videoSource) {
      _controller.dispose();
      _initVideo();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 40,
          spreadRadius: -10,
          offset: const Offset(0, 10),
        ),
      ],
      backgroundDecoration: Positioned.fill(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoLayer(),
            _buildGradientOverlay(),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.isLive) _buildLiveBadge(),
          if (_shouldShowInfo()) _buildTextBlock(),
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
    if (!_controller.value.isInitialized) {
      return Container(
        color: Colors.black.withValues(alpha: 0.6),
      );
    }

    return Opacity(
      opacity: widget.videoOpacity,
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.9),
          ],
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
