import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_notification.dart';
const String kTopic  = "exitzero-notifications-worker"; // Must match worker.js
const String kServer = "https://ntfy.sh";

class NtfyListener {
  final void Function(AppNotification) onNotification;

  bool _running = false;
  // Singleton pattern to ensure only one listener is active if needed globally
  static final NtfyListener _instance = NtfyListener._internal();
  factory NtfyListener() => _instance;
  NtfyListener._internal() : onNotification = ((_) {}); // Default no-op
  
  // Instance for specific callbacks if we don't use singleton strictly
  NtfyListener.withCallback({required this.onNotification});

  Future<void> start({String? since}) async {
    _running = true;
    while (_running) {
      try {
        final sinceParam = since ?? "all";
        final uri = Uri.parse("$kServer/$kTopic/json?since=$sinceParam");
        final request = http.Request("GET", uri);
        final client  = http.Client();
        final response = await client.send(request);

        await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (!_running) break;
          if (chunk.trim().isEmpty) continue;
          try {
            final data = jsonDecode(chunk);
            if (data["event"] == "message") {
               final notif = AppNotification.fromNtfy(data);
               onNotification(notif);
               
               since = notif.id; // resume from last received
             }
          } catch (e) {
            debugPrint("Error processing notification: $e");
          }
        }

        client.close();
      } catch (e) {
        debugPrint("SSE error: $e — reconnecting in 5s");
      }

      if (_running) await Future.delayed(const Duration(seconds: 5));
    }
  }

  void stop() => _running = false;
}
