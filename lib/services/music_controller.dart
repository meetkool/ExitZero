import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_media.dart';

/// What happens when a track ends.
enum TrackRepeat { off, all, one }

/// Playback for the music on the device.
///
/// A singleton rather than widget state, because the media notification
/// outlives the card: leaving the dashboard, or backgrounding the app,
/// should not stop the music or empty the shade. A player owned by a widget
/// dies with the widget, which would make those controls lie.
class MusicController extends ChangeNotifier {
  MusicController._();

  static final MusicController instance = MusicController._();

  static const String _kTrack = 'music_last_track';
  static const String _kPosition = 'music_last_position';
  static const String _kShuffle = 'music_shuffle';
  static const String _kRepeat = 'music_repeat';

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  List<DeviceTrack> _tracks = const [];
  int _index = -1;
  Uint8List? _art;
  bool _loading = true;
  bool _denied = false;
  bool _playing = false;
  bool _shuffle = false;
  TrackRepeat _repeat = TrackRepeat.off;
  Duration _position = Duration.zero;
  Duration _length = Duration.zero;
  bool _wired = false;

  /// Which track the player actually has open, as opposed to which one is
  /// selected. They differ after a restart: the position is restored from
  /// disk before anything has been handed to the player.
  int _loadedIndex = -1;

  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// An offset waiting for the source to be ready to take it.
  Duration? _pendingSeek;

  /// Why playback is not happening, when it should be.
  String? _error;

  /// Bumped whenever anything but the playing position changes.
  ///
  /// The media session republishes on this rather than on every listener
  /// call: position ticks arrive several times a second, and the system
  /// extrapolates position on its own between updates.
  int _epoch = 0;

  int get epoch => _epoch;
  List<DeviceTrack> get tracks => _tracks;
  int get index => _index;
  Uint8List? get art => _art;
  bool get loading => _loading;
  bool get denied => _denied;
  bool get playing => _playing;
  bool get shuffle => _shuffle;
  TrackRepeat get repeat => _repeat;
  Duration get position => _position;
  Duration get length => _length;
  String? get error => _error;

  DeviceTrack? get current =>
      (_index >= 0 && _index < _tracks.length) ? _tracks[_index] : null;

  /// `structural: false` for a position tick, which the session ignores.
  void _changed({bool structural = true}) {
    if (structural) _epoch++;
    notifyListeners();
  }

  /// Reads the device's library. Cheap to call again; only re-reads on
  /// `force`, so every card that mounts does not re-query MediaStore.
  Future<void> load({bool force = false}) async {
    if (_tracks.isNotEmpty && !force) return;
    _wire();

    _loading = true;
    _changed();

    final tracks = await DeviceMediaService.tracks();
    _tracks = tracks;
    _loading = false;
    _denied = tracks.isEmpty;
    if (tracks.isNotEmpty && _index < 0) _index = 0;
    if (tracks.isNotEmpty) await _restore();
    _changed();

    if (tracks.isNotEmpty) await _loadArt();
  }

  void _wire() {
    if (_wired) return;
    _wired = true;

    // Cheap insurance: a player left at zero volume looks exactly like a
    // player that is stuck.
    try {
      _player.setVolume(1.0);
    } catch (_) {
      // Not fatal; the default is full volume anyway.
    }

    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (playing == _playing) return;
      _playing = playing;
      if (playing) _error = null;
      _changed();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      _changed(structural: false);
      // Throttled inside: the tick fires several times a second, and the
      // point is only to survive a kill, not to record every frame.
      save();
    });
    _player.onDurationChanged.listen((d) {
      _length = d;
      _changed();
      // The duration arriving means the source is prepared, which is the
      // first moment a seek on it will actually land.
      _applyPendingSeek();
    });
    _player.onPlayerComplete.listen((_) => _complete());
  }

  Future<void> _loadArt() async {
    final track = current;
    if (track == null) return;
    _art = await DeviceMediaService.art(track);
    _changed();
  }

  Future<void> _start({Duration from = Duration.zero}) async {
    final track = current;
    if (track == null) return;

    // A real file where scoped storage still exposes one, the content uri
    // otherwise; DeviceFileSource cannot open a content:// path.
    final source = track.isFile
        ? DeviceFileSource(track.playable)
        : UrlSource(track.playable);

    // Always the plain play() path. setSource() returns once the source is
    // set, not once it is prepared, so seeking and resuming straight after
    // it left the player reporting that it was playing while producing no
    // sound at all -- the state was true and the audio was not.
    //
    // The offset is applied once the duration arrives instead, which is the
    // player's own signal that the source is ready to be moved around.
    _pendingSeek = from > Duration.zero ? from : null;
    await _player.play(source);
    _loadedIndex = _index;
  }

  /// Applies an offset that was waiting for the source to be ready.
  Future<void> _applyPendingSeek() async {
    final to = _pendingSeek;
    if (to == null) return;
    _pendingSeek = null;

    // A saved spot past the end of what actually loaded is not worth
    // chasing; letting it play from the top beats seeking into nothing.
    if (_length > Duration.zero && to >= _length) return;

    try {
      await _player.seek(to);
    } catch (_) {
      // The track plays from the beginning. Sound beats precision.
    }
  }

  /// What to do when a track runs out.
  Future<void> _complete() async {
    if (_repeat == TrackRepeat.one) {
      _position = Duration.zero;
      _changed();
      await _start();
      return;
    }

    // With repeat off, the end of the list is the end: rolling back round to
    // track one would make "off" indistinguishable from "repeat all".
    final atEnd = !_shuffle && _index >= _tracks.length - 1;
    if (_repeat == TrackRepeat.off && atEnd) {
      await stop();
      return;
    }

    await skip(1);
  }

  Future<void> toggle() async {
    if (current == null) return;

    try {
      if (_playing) {
        await _player.pause();
        await save(force: true);
        return;
      }

      _error = null;

      // After a restart the position is restored but the player holds
      // nothing, so resume() would do exactly nothing. Only resume a track
      // the player actually has open; otherwise load it from the top and
      // let the saved offset be applied once it is ready.
      if (_loadedIndex == _index && _position > Duration.zero) {
        await _player.resume();
        await _ensureActuallyPlaying();
      } else {
        await _start(from: _position);
      }
    } catch (e) {
      _error = 'Could not play this track.';
      _playing = false;
      _changed();
    }
  }

  /// Reloads the track when a resume did not take.
  ///
  /// A player can be left holding a source it will no longer play -- the
  /// file moved, the session was torn down underneath it -- and resume()
  /// then returns without complaint and without sound. Rather than leave a
  /// pause button that does nothing, load the track again from scratch.
  Future<void> _ensureActuallyPlaying() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_playing) return;
    _loadedIndex = -1;
    await _start(from: _position);
  }

  /// For the notification's play button, which is never a toggle.
  Future<void> play() async {
    if (!_playing) await toggle();
  }

  Future<void> pause() async {
    if (!_playing) return;
    await _player.pause();
    await save(force: true);
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _position = Duration.zero;
    _loadedIndex = -1;
    _changed();
    await save(force: true);
  }

  Future<void> skip(int delta) async {
    if (_tracks.isEmpty) return;

    int next;
    if (_shuffle && _tracks.length > 1) {
      // Never hand back the track already playing: on shuffle that reads as
      // a broken skip button rather than as chance.
      do {
        next = _random.nextInt(_tracks.length);
      } while (next == _index);
    } else {
      next = (_index + delta) % _tracks.length;
      if (next < 0) next += _tracks.length;
    }

    _index = next;
    _position = Duration.zero;
    _length = Duration.zero;
    _art = null;
    _error = null;
    _changed();

    await _loadArt();
    await save(force: true);
    await _start();
  }

  Future<void> choose(int i) async {
    if (i < 0 || i >= _tracks.length) return;
    _index = i;
    _position = Duration.zero;
    _length = Duration.zero;
    _art = null;
    _error = null;
    _changed();

    await _loadArt();
    await save(force: true);
    await _start();
  }

  Future<void> seek(Duration to) async {
    _position = to;
    _changed();
    // Seeking a track the player has not opened yet would be dropped; the
    // offset is remembered instead and applied when play is pressed.
    if (_loadedIndex == _index) await _player.seek(to);
    await save(force: true);
  }

  /// off → all → one → off, the order every player uses.
  void cycleRepeat() {
    _repeat = switch (_repeat) {
      TrackRepeat.off => TrackRepeat.all,
      TrackRepeat.all => TrackRepeat.one,
      TrackRepeat.one => TrackRepeat.off,
    };
    _changed();
    save(force: true);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _changed();
    save(force: true);
  }

  // ── remembering where you were ─────────────────────────────────────────

  /// Writes the current track, offset and modes to disk.
  ///
  /// Throttled unless forced, because the position tick calls it several
  /// times a second and the goal is only to survive the app being killed.
  Future<void> save({bool force = false}) async {
    final track = current;
    if (track == null) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) {
      return;
    }
    _lastSave = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTrack, track.id);
      await prefs.setInt(_kPosition, _position.inMilliseconds);
      await prefs.setBool(_kShuffle, _shuffle);
      await prefs.setInt(_kRepeat, _repeat.index);
    } catch (_) {
      // Losing the bookmark is not worth interrupting playback over.
    }
  }

  /// Puts back what [save] wrote, as far as it still makes sense.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _shuffle = prefs.getBool(_kShuffle) ?? false;
      final repeat = prefs.getInt(_kRepeat) ?? 0;
      _repeat =
          TrackRepeat.values[repeat.clamp(0, TrackRepeat.values.length - 1)];

      final id = prefs.getString(_kTrack);
      if (id == null || id.isEmpty) return;

      // The file may have been deleted since. Falling back to the first
      // track beats restoring a selection that cannot play.
      final i = _tracks.indexWhere((t) => t.id == id);
      if (i < 0) return;
      _index = i;

      // Seed the length from the media store so the seek bar is right
      // before the player has opened anything and reported its own.
      final total = _tracks[i].duration;
      _length = total;

      final saved = Duration(milliseconds: prefs.getInt(_kPosition) ?? 0);
      // Resuming into the last second would end the track instantly and
      // skip to the next one, which is not what "carry on" means.
      final nearEnd = total > Duration.zero &&
          saved >= total - const Duration(seconds: 1);
      _position = (saved < Duration.zero || nearEnd) ? Duration.zero : saved;
    } catch (_) {
      // No bookmark is the same as a fresh install.
    }
  }
}
