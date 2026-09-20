import 'dart:io';
import 'package:flutter/services.dart';

/// What the device says about running two cameras at once.
class CameraCapability {
  final bool supported;
  final String reason;
  final int sdkInt;
  final String release;
  final String device;

  /// Camera id -> which way it faces.
  final Map<String, String> cameras;

  /// Id combinations the hardware can stream concurrently.
  final List<List<String>> pairs;

  const CameraCapability({
    required this.supported,
    this.reason = '',
    this.sdkInt = 0,
    this.release = '',
    this.device = '',
    this.cameras = const {},
    this.pairs = const [],
  });

  /// How many distinct lenses face each way.
  int get frontCount =>
      cameras.values.where((f) => f == 'front').length;
  int get backCount => cameras.values.where((f) => f == 'back').length;
}

/// Asks Android whether it can stream a front and a back lens together.
///
/// Flutter's camera plugin has no concurrent-camera API at all, and the
/// underlying Camera2 feature arrived in Android 11 and is optional, so
/// plenty of devices cannot do it. This asks rather than assumes, so the
/// answer for a particular phone is a fact instead of a guess.
class CameraCapabilityService {
  CameraCapabilityService._();

  static const MethodChannel _channel = MethodChannel(
    'exitzero/camera_capability',
  );

  static CameraCapability? _cached;

  static Future<CameraCapability> probe({bool force = false}) async {
    if (_cached != null && !force) return _cached!;

    if (!Platform.isAndroid) {
      return _cached = const CameraCapability(
        supported: false,
        reason: 'This check is Android only.',
      );
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'concurrentSupport',
      );
      if (raw == null) {
        return _cached = const CameraCapability(
          supported: false,
          reason: 'The device returned nothing.',
        );
      }

      final cameras = <String, String>{};
      final rawCameras = raw['cameras'];
      if (rawCameras is Map) {
        rawCameras.forEach((k, v) => cameras[k.toString()] = v.toString());
      }

      final pairs = <List<String>>[];
      final rawPairs = raw['pairs'];
      if (rawPairs is List) {
        for (final p in rawPairs) {
          if (p is List) {
            pairs.add(p.map((e) => e.toString()).toList(growable: false));
          }
        }
      }

      return _cached = CameraCapability(
        supported: raw['supported'] == true,
        reason: (raw['reason'] ?? '').toString(),
        sdkInt: raw['sdkInt'] is num ? (raw['sdkInt'] as num).toInt() : 0,
        release: (raw['release'] ?? '').toString(),
        device: (raw['device'] ?? '').toString(),
        cameras: cameras,
        pairs: pairs,
      );
    } on MissingPluginException {
      // An app build that predates the probe.
      return _cached = const CameraCapability(
        supported: false,
        reason: 'This build of the app cannot run the check.',
      );
    } catch (e) {
      return _cached = CameraCapability(
        supported: false,
        reason: 'Check failed: $e',
      );
    }
  }
}
