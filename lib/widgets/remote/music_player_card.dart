import 'package:flutter/material.dart';
import '../../services/device_media.dart';
import '../../services/music_controller.dart';
import '../../services/music_session.dart';

/// A player for the music already on the phone.
///
/// Album art fills the card with the controls laid over it, and the title
/// opens a sheet listing every track the media store knows about.
///
/// The card is only the face of it: playback lives in [MusicController], so
/// the same session is driven from here and from the notification shade.
class MusicPlayerCard extends StatefulWidget {
  final double height;
  final Color accent;

  const MusicPlayerCard({
    super.key,
    this.height = 190,
    this.accent = const Color(0xFFF7A8A8),
  });

  @override
  State<MusicPlayerCard> createState() => _MusicPlayerCardState();
}

class _MusicPlayerCardState extends State<MusicPlayerCard>
    with WidgetsBindingObserver {
  final MusicController _music = MusicController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _music.addListener(_onChange);
    _music.load();
    // Best effort: a device that refuses a media session still gets a card.
    MusicSession.start();
  }

  @override
  void dispose() {
    // Deliberately not stopping the player: the notification outlives this
    // widget, and killing playback on a scroll rebuild would be surprising.
    WidgetsBinding.instance.removeObserver(this);
    _music.removeListener(_onChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The periodic save is five seconds coarse, which is enough to lose the
    // spot when the app is killed. Leaving the foreground is the last
    // reliable moment to write the exact one down.
    if (state != AppLifecycleState.resumed) {
      _music.save(force: true);
    }
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DeviceTrack? get _current => _music.current;

  void _openList() {
    if (_music.tracks.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF12161A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheet) {
        final tracks = _music.tracks;
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
                      'ON THIS DEVICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${tracks.length}',
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
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final selected = i == _music.index;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        selected ? Icons.equalizer : Icons.music_note,
                        size: 19,
                        color: selected
                            ? widget.accent
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? widget.accent : Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        t.artist.isEmpty ? 'Unknown artist' : t.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      trailing: Text(
                        _clock(t.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        _music.choose(i);
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

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _backdrop(),
            if (_music.loading)
              Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(widget.accent),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              )
            else if (_music.denied)
              _empty()
            else
              _controls(),
          ],
        ),
      ),
    );
  }

  Widget _backdrop() {
    final art = _music.art;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (art != null)
          Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accent.withValues(alpha: 0.30),
                  const Color(0xFF0B0E12),
                ],
              ),
            ),
          ),
        // Keeps the controls readable whatever the artwork happens to be.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.78),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music,
              size: 24,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 9),
            const Text(
              'No music found',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Allow access to audio, or add some mp3s to this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _music.load(force: true),
              child: Text(
                'Try again',
                style: TextStyle(fontSize: 12, color: widget.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final track = _current;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.album,
                size: 17,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const Spacer(),
              Icon(
                Icons.cast,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openList,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track?.artist.isNotEmpty == true
                            ? track!.artist
                            : 'Unknown artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              // A failure belongs where the track name goes:
                              // a pause button over a silent player is worse
                              // than an error that says so.
                              _music.error ??
                                  track?.title ??
                                  'Nothing selected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _music.error != null
                                    ? const Color(0xFFE05252)
                                    : Colors.white.withValues(alpha: 0.75),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // The big rounded play button from the reference.
              GestureDetector(
                onTap: _music.toggle,
                child: Container(
                  width: 62,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _music.playing ? Icons.pause : Icons.play_arrow,
                    size: 25,
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              _iconButton(
                Icons.shuffle,
                active: _music.shuffle,
                onTap: _music.toggleShuffle,
              ),
              _repeatButton(),
              _iconButton(Icons.skip_previous, onTap: () => _music.skip(-1)),
              Expanded(child: _seekBar()),
              _iconButton(Icons.skip_next, onTap: () => _music.skip(1)),
            ],
          ),
        ],
      ),
    );
  }

  /// off → repeat all → repeat one, shown the way every player shows it: the
  /// icon gains a "1" on the last step rather than changing colour twice.
  Widget _repeatButton() {
    final mode = _music.repeat;
    return _iconButton(
      mode == TrackRepeat.one ? Icons.repeat_one : Icons.repeat,
      active: mode != TrackRepeat.off,
      onTap: _music.cycleRepeat,
    );
  }

  Widget _iconButton(
    IconData icon, {
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Icon(
          icon,
          size: 17,
          color: active ? widget.accent : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _seekBar() {
    final total = _music.length.inMilliseconds;
    final at = _music.position.inMilliseconds;
    final progress = total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (total <= 0) return;
            final fraction = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
            _music.seek(Duration(milliseconds: (total * fraction).round()));
          },
          child: SizedBox(
            height: 22,
            child: CustomPaint(
              painter: _SeekPainter(
                progress: progress,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The squiggle-then-line seek bar from the reference: played time wiggles,
/// the rest is flat, with a handle between them.
class _SeekPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SeekPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final handleX = (size.width * progress).clamp(0.0, size.width);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35);

    // Remaining time: a plain line.
    canvas.drawLine(
      Offset(handleX + 7, midY),
      Offset(size.width, midY),
      line,
    );

    // Played time: a wave, so progress reads at a glance.
    final wave = Path();
    const amplitude = 3.2;
    const wavelength = 13.0;
    for (double x = 0; x <= handleX - 7; x += 1) {
      final y = midY +
          amplitude *
              (x / wavelength % 2 < 1
                  ? (x / wavelength % 1) * 2 - 1
                  : 1 - (x / wavelength % 1) * 2);
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Handle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(handleX, midY),
          width: 4.5,
          height: 15,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.progress != progress || old.color != color;
}
