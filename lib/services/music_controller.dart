import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
    _changed();

    if (tracks.isNotEmpty) await _loadArt();
  }

  void _wire() {
    if (_wired) return;
    _wired = true;

    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (playing == _playing) return;
      _playing = playing;
      _changed();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      _changed(structural: false);
    });
    _player.onDurationChanged.listen((d) {
      _length = d;
      _changed();
    });
    _player.onPlayerComplete.listen((_) => _complete());
  }

  Future<void> _loadArt() async {
    final track = current;
    if (track == null) return;
    _art = await DeviceMediaService.art(track);
    _changed();
  }

  Future<void> _start() async {
    final track = current;
    if (track == null) return;
    // A real file where scoped storage still exposes one, the content uri
    // otherwise; DeviceFileSource cannot open a content:// path.
    await _player.play(
      track.isFile
          ? DeviceFileSource(track.playable)
          : UrlSource(track.playable),
    );
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
    if (_playing) {
      await _player.pause();
    } else if (_position > Duration.zero) {
      await _player.resume();
    } else {
      await _start();
    }
  }

  /// For the notification's play button, which is never a toggle.
  Future<void> play() async {
    if (!_playing) await toggle();
  }

  Future<void> pause() async {
    if (_playing) await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _position = Duration.zero;
    _changed();
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
    _changed();

    await _loadArt();
    await _start();
  }

  Future<void> choose(int i) async {
    if (i < 0 || i >= _tracks.length) return;
    _index = i;
    _position = Duration.zero;
    _length = Duration.zero;
    _art = null;
    _changed();

    await _loadArt();
    await _start();
  }

  Future<void> seek(Duration to) async {
    _position = to;
    _changed();
    await _player.seek(to);
  }

  /// off → all → one → off, the order every player uses.
  void cycleRepeat() {
    _repeat = switch (_repeat) {
      TrackRepeat.off => TrackRepeat.all,
      TrackRepeat.all => TrackRepeat.one,
      TrackRepeat.one => TrackRepeat.off,
    };
    _changed();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _changed();
  }
}
