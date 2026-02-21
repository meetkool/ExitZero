import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'ntfy_service.dart';
import 'notification_store.dart';
import 'local_notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'exitzero_background_channel',
    'ExitZero Background Service',
    description: 'Keeps ExitZero running in the background for real-time notifications.',
    importance: Importance.low, // Low importance so it doesn't pop up and make sound, just shows in tray
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'exitzero_background_channel',
      initialNotificationTitle: 'ExitZero',
      initialNotificationContent: 'Running in the background',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  
  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Bring service to foreground
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    service.setAsForegroundService();
  }

  // We need local notifications setup in this isolate if we want to show popups
  // So we re-initialize it here or use the plugin directly.
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  // Also initialize the generic channel if it doesn't exist.
  // We recreate it here to be safe for the isolate.
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'exitzero_channel_id',
    'ExitZero Notifications',
    description: 'Important alerts from ExitZero worker',
    importance: Importance.max,
    playSound: true,
  );
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertChannel);
  }

  // Initialize store and get last ID
  final lastId = await NotificationStore.loadLastId();
  
  // We'll run our own Ntfy Listener in this isolate
  final backgroundListener = NtfyListener.withCallback(onNotification: (n) async {
    // 1. Save to store
    final stored = await NotificationStore.load();
    if (!stored.any((existing) => existing.id == n.id)) {
      stored.insert(0, n);
      await NotificationStore.save(stored);
      await NotificationStore.saveLastId(n.id);
      
      // 2. Trigger actual visual notification if fresh
      final isOld = n.time.isBefore(DateTime.now().subtract(const Duration(minutes: 5)));
      if (!n.isRead && !isOld) {
        // Because we are in an isolate, we explicitly call the plugin to show the alert
        await flutterLocalNotificationsPlugin.show(
          n.id.hashCode,
          n.title,
          n.message,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'exitzero_channel_id',
              'ExitZero Notifications',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );
      }
      
      // We can also tell the foreground UI to update itself if it is alive
      service.invoke('update');
    }
  });

  backgroundListener.start(since: lastId);
  
  service.on('stopService').listen((event) {
    backgroundListener.stop();
    service.stopSelf();
  });
}
