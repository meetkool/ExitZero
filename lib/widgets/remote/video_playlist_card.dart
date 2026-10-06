import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// One entry in a widget's playlist.
class VideoLink {
  final String title;
  final String url;
  final String poster;
  final String note;

  const VideoLink({
    required this.title,
    required this.url,
    this.poster = '',
    this.note = '',
  });

  static List<VideoLink> parse(dynamic raw) {
    if (raw is! List) return const [];
    final out = <VideoLink>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final url = (entry['url'] ?? '').toString().trim();
      // Only plain https, the same rule the data sources follow: a manifest
      // should not be able to talk the app into a cleartext fetch.
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      out.add(
        VideoLink(
          title: (entry['title'] ?? 'Untitled').toString(),
          url: url,
          poster: (entry['poster'] ?? '').toString(),
          note: (entry['note'] ?? '').toString(),
        ),
      );
    }
    return out;
  }
}

/// A video player with a playlist, both supplied by the manifest.
///
/// Nothing loads until the play button is pressed. A dashboard that starts
/// pulling video the moment it is opened would be both rude and expensive,
/// so the card shows a poster and waits.
///
/// Every link is assumed to be able to fail: a playlist lives in JSON on
/// GitHub, and a host that was fine when it was written can be gone by the
/// time it is played. A dead entry reports itself and offers the next one
/// rather than taking the widget down with it.
class VideoPlaylistCard extends StatefulWidget {
  final double height;
  final Color accent;
  final List<VideoLink> videos;
  final bool autoplay;
  final bool muted;

  /// Wrap from the last entry back to the first.
  final bool loop;

  const VideoPlaylistCard({
    super.key,
    this.height = 200,
    this.accent = const Color(0xFFF77F00),
    required this.videos,
    this.autoplay = false,
    this.muted = false,
    this.loop = true,
  });

  @override
  State<VideoPlaylistCard> createState() => _VideoPlaylistCardState();
}

class _VideoPlaylistCardState extends State<VideoPlaylistCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  int _index = 0;
  bool _loading = false;
  bool _muted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = widget.muted;
    if (widget.autoplay && widget.videos.isNotEmpty) {
      _open(0, play: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app pauses playback and leaves it paused. Unlike a looping
    // background tile, this is something the person chose to start, so
    // restarting it behind their back would be wrong.
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    }
  }

  void _disposeController() {
    final old = _controller;
    _controller = null;
    if (old == null) return;
    old.removeListener(_onValue);
    try {
      old.dispose();
    } catch (_) {
      // Already gone.
    }
  }

  void _onValue() {
    final c = _controller;
    if (c == null || !mounted) return;

    if (c.value.hasError && _error == null) {
      setState(() => _error = 'This one would not play.');
      return;
    }

    // Auto-advance. isCompleted is only meaningful once initialised.
    if (c.value.isInitialized &&
        !c.value.isPlaying &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      _skip(1);
      return;
    }

    setState(() {});
  }

  VideoLink? get _current =>
      (_index >= 0 && _index < widget.videos.length)
          ? widget.videos[_index]
          : null;

  Future<void> _open(int index, {bool play = true}) async {
    if (widget.videos.isEmpty) return;
    final target = widget.videos[index.clamp(0, widget.videos.length - 1)];

    _disposeController();
    setState(() {
      _index = index.clamp(0, widget.videos.length - 1);
      _loading = true;
      _error = null;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(target.url));
    _controller = controller;

    try {
      await controller.initialize();
      // The card can be disposed, or moved to another entry, while
      // initialize() is in flight. Touching the old controller after that
      // throws, and setState after dispose throws too.
      if (!mounted || !identical(_controller, controller)) return;

      await controller.setVolume(_muted ? 0.0 : 1.0);
      controller.addListener(_onValue);
      if (play) await controller.play();

      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this video.';
      });
    }
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      await _open(_index);
      return;
    }
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _skip(int delta) async {
    if (widget.videos.isEmpty) return;
    var next = _index + delta;
    if (next >= widget.videos.length) {
      if (!widget.loop) return;
      next = 0;
    }
    if (next < 0) {
      if (!widget.loop) return;
      next = widget.videos.length - 1;
    }
    await _open(next);
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _controller?.setVolume(_muted ? 0.0 : 1.0);
  }

  void _seekTo(double fraction) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration.inMilliseconds;
    if (total <= 0) return;
    c.seekTo(Duration(milliseconds: (total * fraction).round()));
  }

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return SizedBox(height: widget.height, child: _empty());
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _stage(),
            _scrim(),
            _chrome(),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Text(
        'No videos linked.',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// The video itself, or the poster standing in for it.
  Widget _stage() {
    final c = _controller;
    if (c != null && c.value.isInitialized && _error == null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }
    return _poster();
  }

  Widget _poster() {
    final poster = _current?.poster ?? '';
    if (poster.isEmpty) return _posterFallback();
    return Image.network(
      poster,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _posterFallback(),
    );
  }

  Widget _posterFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accent.withValues(alpha: 0.35),
            const Color(0xFF0B0E12),
          ],
        ),
      ),
    );
  }

  Widget _scrim() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.80),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }

  Widget _chrome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(),
          Expanded(child: Center(child: _centrepiece())),
          _progress(),
          const SizedBox(height: 6),
          _buttons(),
        ],
      ),
    );
  }

  Widget _titleRow() {
    final video = _current;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openList,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    video?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.expand_more,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_index + 1}/${widget.videos.length}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  /// Whatever the middle of the card should be saying right now.
  Widget _centrepiece() {
    if (_loading) {
      return SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(widget.accent),
          backgroundColor: Colors.white.withValues(alpha: 0.12),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 20, color: Color(0xFFE05252)),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFE05252),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pill('Retry', () => _open(_index)),
                const SizedBox(width: 8),
                _pill('Skip', () => _skip(1)),
              ],
            ),
          ],
        ),
      );
    }

    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    if (playing) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: widget.accent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.play_arrow,
          size: 26,
          color: Colors.black.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: widget.accent,
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    final c = _controller;
    final value = c?.value;
    final total = value?.duration.inMilliseconds ?? 0;
    final at = value?.position.inMilliseconds ?? 0;
    final played = total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0);

    // How much has arrived, so a stall reads as buffering rather than as a
    // frozen picture.
    var buffered = played;
    if (value != null && total > 0 && value.buffered.isNotEmpty) {
      final end = value.buffered.last.end.inMilliseconds;
      buffered = (end / total).clamp(0.0, 1.0);
    }

    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              _seekTo((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
          onHorizontalDragUpdate: (d) =>
              _seekTo((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
          child: SizedBox(
            height: 16,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: buffered,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: played,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buttons() {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    final position = c?.value.position ?? Duration.zero;
    final total = c?.value.duration ?? Duration.zero;

    return Row(
      children: [
        _icon(Icons.skip_previous, () => _skip(-1)),
        _icon(playing ? Icons.pause : Icons.play_arrow, _toggle),
        _icon(Icons.skip_next, () => _skip(1)),
        const SizedBox(width: 6),
        Text(
          '${_clock(position)} / ${_clock(total)}',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const Spacer(),
        _icon(_muted ? Icons.volume_off : Icons.volume_up, _toggleMute),
        _icon(Icons.fullscreen, _openFullscreen),
        _icon(Icons.playlist_play, _openList),
      ],
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  void _openFullscreen() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    // The same controller, shown in another route. It must not be disposed
    // when that route pops, or coming back leaves a dead card.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideo(controller: c, accent: widget.accent),
      ),
    );
  }

  void _openList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF12161A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheet) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'PLAYLIST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.videos.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.videos.length,
                  itemBuilder: (context, i) {
                    final v = widget.videos[i];
                    final selected = i == _index;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        selected
                            ? Icons.play_circle_fill
                            : Icons.play_circle_outline,
                        size: 20,
                        color: selected
                            ? widget.accent
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                      title: Text(
                        v.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? widget.accent : Colors.white,
                        ),
                      ),
                      subtitle: v.note.isEmpty
                          ? null
                          : Text(
                              v.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _open(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The same video, filling the screen.
class _FullscreenVideo extends StatefulWidget {
  final VideoPlayerController controller;
  final Color accent;

  const _FullscreenVideo({required this.controller, required this.accent});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
  }

  @override
  void dispose() {
    // Only the listener. The card still owns this controller.
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => c.value.isPlaying ? c.pause() : c.play(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio:
                    c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            ),
            if (!c.value.isPlaying)
              Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
