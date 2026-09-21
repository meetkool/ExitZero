import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'music_controller.dart';

/// Puts the player in the notification shade and on the lock screen.
///
/// audio_service owns the platform's media session; playback itself stays
/// with [MusicController]. So the buttons in the shade and the buttons on the
/// card drive exactly the same player, and neither can drift from the other.
class MusicSession extends BaseAudioHandler with SeekHandler {
  static MusicSession? _live;
  static Future<MusicSession>? _pending;
  static bool _unavailable = false;

  /// Brings the session up, once per process.
  ///
  /// Returns null if the platform will not give us one. That is not fatal:
  /// the card keeps working, it just loses the notification.
  static Future<MusicSession?> start() async {
    if (_live != null) return _live;
    if (_unavailable) return null;

    _pending ??= AudioService.init<MusicSession>(
      builder: MusicSession.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.my_first_app.playback',
        androidNotificationChannelName: 'Now playing',
        // Let the notification be swiped away once paused, rather than
        // pinning it there for as long as the app is alive.
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );

    try {
      final session = await _pending!;
      _live = session;
      // Two cards mounting together await the same future, so this has to be
      // idempotent: a second listener would publish everything twice.
      session._watch();
      return session;
    } catch (_) {
      _unavailable = true;
      _pending = null;
      return null;
    }
  }

  int _publishedEpoch = -1;
  String? _artTrackId;
  Uri? _artUri;
  bool _watching = false;

  void _watch() {
    if (_watching) return;
    _watching = true;

    final music = MusicController.instance;
    music.addListener(() {
      // Position ticks do not bump the epoch, and the system extrapolates
      // position between updates, so this skips several pushes a second.
      if (music.epoch == _publishedEpoch) return;
      _publishedEpoch = music.epoch;
      unawaited(_publish());
    });
  }

  Future<void> _publish() async {
    final music = MusicController.instance;
    final track = music.current;

    if (track == null) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      return;
    }

    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist.isEmpty ? 'Unknown artist' : track.artist,
        album: track.album.isEmpty ? null : track.album,
        // The player's own reading once it has one; the media store's
        // figure until then, so the shade is not blank on the first frame.
        duration: music.length > Duration.zero ? music.length : track.duration,
        artUri: await _artwork(track.id, music.art),
      ),
    );

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (music.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: music.playing,
        updatePosition: music.position,
        speed: 1.0,
      ),
    );
  }

  /// Artwork has to reach the platform as a URI, and what we hold is bytes,
  /// so it goes through a file in the cache directory. Kept per track, so a
  /// repeating song does not rewrite it on every loop.
  Future<Uri?> _artwork(String id, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    if (_artTrackId == id && _artUri != null) return _artUri;

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nowplaying_$id.img');
      await file.writeAsBytes(bytes, flush: true);
      _artTrackId = id;
      _artUri = Uri.file(file.path);
      return _artUri;
    } catch (_) {
      // No artwork is a cosmetic loss; never a reason to fail the update.
      return null;
    }
  }

  // ── what the shade's buttons do ────────────────────────────────────────

  @override
  Future<void> play() => MusicController.instance.play();

  @override
  Future<void> pause() => MusicController.instance.pause();

  @override
  Future<void> skipToNext() => MusicController.instance.skip(1);

  @override
  Future<void> skipToPrevious() => MusicController.instance.skip(-1);

  @override
  Future<void> seek(Duration position) =>
      MusicController.instance.seek(position);

  @override
  Future<void> stop() async {
    await MusicController.instance.stop();
    await super.stop();
  }
}
