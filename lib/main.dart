import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/dev_http_overrides.dart';

void main() {
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  runApp(const ExitZeroApp());
}
