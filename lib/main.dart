import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/dev_http_overrides.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  await initializeBackgroundService();
  runApp(const ExitZeroApp());
}
