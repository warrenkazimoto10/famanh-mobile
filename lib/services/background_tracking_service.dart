import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_client.dart';
import '../data/api_session.dart';

@pragma('vm:entry-point')
class BackgroundTrackingService {
  static const String notificationChannelId = 'driver_tracking_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Suivi Livreur Famanh',
      description: 'Cette notification indique que votre tracking GPS est actif.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Tournée en cours',
        initialNotificationContent: 'Tracking GPS activé',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Tracking logic
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        if (!(await service.isForegroundService())) {
          return;
        }
      }

      try {
        // Le token est désormais dans le stockage chiffré (même clé partagée).
        final token = await ApiSession.secureStorage.read(key: ApiSession.tokenKey);
        if (token == null || token.isEmpty) return;

        // On vérifie si l'utilisateur est toujours en mode "tournée"
        final prefs = await SharedPreferences.getInstance();
        final isOnline = prefs.getBool('driver_is_online') ?? false;
        if (!isOnline) {
          service.stopSelf();
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        // Appel direct à l'API (on recrée l'en-tête manuellement car ApiSession n'est pas forcément à jour en background)
        await ApiClient.driverSendLocation(
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading,
          speed: position.speed * 3.6,
          accuracy: position.accuracy,
          token: token,
        );

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Tournée Active - Famanh",
            content: "Position envoyée à ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          );
        }
      } catch (e) {
        debugPrint("Background Tracking Error: $e");
      }
    });
  }

  static Future<void> start() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_online', true);
    
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_online', false);
    
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
