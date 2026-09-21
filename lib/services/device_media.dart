import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// One track from the device's media store.
class DeviceTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  /// A file path where scoped storage still exposes one.
  final String path;

  /// A `content://` uri, which always works.
  final String uri;

  const DeviceTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.path,
    required this.uri,
  });

  /// What to hand the player: a real file when there is one, else the uri.
  String get playable => path.isNotEmpty ? path : uri;
  bool get isFile => path.isNotEmpty;
}

/// Reads the device's next alarm and its music library.
class DeviceMediaService {
  DeviceMediaService._();

  static const MethodChannel _channel = MethodChannel(
    'exitzero/camera_capability',
  );

  /// When the system's next alarm fires, or null if none is set.
  static Future<DateTime?> nextAlarm() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('nextAlarm');
      final at = raw?['triggerTime'];
      if (at is! num || at <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(at.toInt());
    } catch (_) {
      return null;
    }
  }

  /// Whether we may read the user's audio, asking if we have not yet.
  static Future<bool> ensureAudioPermission() async {
    if (!Platform.isAndroid) return false;
    // Android 13 replaced storage reads with a media-specific permission;
    // permission_handler maps `audio` to whichever this device uses.
    final status = await Permission.audio.request();
    if (status.isGranted) return true;
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  static Future<List<DeviceTrack>> tracks({int limit = 300}) async {
    if (!Platform.isAndroid) return const [];
    if (!await ensureAudioPermission()) return const [];

    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'audioTracks',
        {'limit': limit},
      );
      if (raw == null) return const [];

      return raw.whereType<Map>().map((t) {
        return DeviceTrack(
          id: (t['id'] ?? '').toString(),
          title: (t['title'] ?? 'Unknown').toString(),
          artist: (t['artist'] ?? '').toString(),
          album: (t['album'] ?? '').toString(),
          duration: Duration(
            milliseconds: (t['durationMs'] as num?)?.toInt() ?? 0,
          ),
          path: (t['path'] ?? '').toString(),
          uri: (t['uri'] ?? '').toString(),
        );
      }).where((t) => t.playable.isNotEmpty).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Artwork embedded in a track, or null when it carries none.
  static Future<Uint8List?> art(DeviceTrack track) async {
    if (!Platform.isAndroid) return null;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('audioArt', {
        'path': track.path,
        'uri': track.uri,
      });
      return (bytes == null || bytes.isEmpty) ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}
