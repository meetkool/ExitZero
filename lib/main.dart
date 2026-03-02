import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'app.dart';
import 'services/dev_http_overrides.dart';
import 'services/background_service.dart';

import 'package:alarm/alarm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  
  // Request required permissions
  await Permission.notification.request();
  await Permission.scheduleExactAlarm.request();
  
  if (Platform.isAndroid) {
    try {
      final bool? autoStart = await isAutoStartAvailable;
      if (autoStart == true) {
        await getAutoStartPermission();
      }
    } catch (e) {
      debugPrint("Auto start permission check failed: \$e");
    }
  }

  await Alarm.init();
  await initializeBackgroundService();
  runApp(const ExitZeroApp());
}
