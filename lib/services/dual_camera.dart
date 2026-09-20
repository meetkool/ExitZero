import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// One live camera, rendered into a Flutter texture by the native side.
class DualCameraFeedInfo {
  final String lens;
  final int textureId;
  final int width;
  final int height;

  /// How far the sensor is rotated relative to the device's natural
  /// orientation. Portrait phones almost always report 90 or 270.
  final int sensorOrientation;

  const DualCameraFeedInfo({
    required this.lens,
    required this.textureId,
    required this.width,
    required this.height,
    required this.sensorOrientation,
  });

  bool get isFront => lens == 'front';

  /// Quarter turns needed to stand the preview upright.
  int get quarterTurns => (sensorOrientation ~/ 90) % 4;

  /// Sensors are landscape, so a 90 or 270 degree mount swaps the axes.
  double get displayAspect {
    final swapped = quarterTurns.isOdd;
    final w = swapped ? height : width;
    final h = swapped ? width : height;
    return h == 0 ? 1 : w / h;
  }
}

/// Runs the front and back cameras together, via Camera2 on the native side.
class DualCameraService {
  DualCameraService._();

  static const MethodChannel _channel = MethodChannel(
    'exitzero/camera_capability',
  );

  /// Starts both cameras and returns one entry per lens.
  ///
  /// Throws a [DualCameraException] with a readable reason when the device
  /// refuses, which is how a phone that cannot really do this fails: the
  /// second camera declines to open or the session will not configure.
  static Future<List<DualCameraFeedInfo>> start() async {
    if (!Platform.isAndroid) {
      throw const DualCameraException('Dual camera is Android only.');
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw DualCameraException(
        status.isPermanentlyDenied
            ? 'Camera permission is blocked. Turn it on in Android settings.'
            : 'Camera permission was refused.',
      );
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('dualStart');
      final feeds = raw?['feeds'];
      if (feeds is! List || feeds.isEmpty) {
        throw const DualCameraException('The device returned no feeds.');
      }

      return feeds.whereType<Map>().map((f) {
        return DualCameraFeedInfo(
          lens: (f['lens'] ?? '').toString(),
          textureId: (f['textureId'] as num?)?.toInt() ?? -1,
          width: (f['width'] as num?)?.toInt() ?? 0,
          height: (f['height'] as num?)?.toInt() ?? 0,
          sensorOrientation: (f['sensorOrientation'] as num?)?.toInt() ?? 0,
        );
      }).where((f) => f.textureId >= 0).toList(growable: false);
    } on PlatformException catch (e) {
      throw DualCameraException(e.message ?? 'The cameras would not start.');
    } on MissingPluginException {
      throw const DualCameraException(
        'This build of the app does not have dual camera support.',
      );
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('dualStop');
    } catch (_) {
      // Stopping is best effort; the native side also releases on pause.
    }
  }
}

class DualCameraException implements Exception {
  final String message;
  const DualCameraException(this.message);
  @override
  String toString() => message;
}
