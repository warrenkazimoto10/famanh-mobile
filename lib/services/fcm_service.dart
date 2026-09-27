import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_client.dart';
import '../data/api_session.dart';

/// Top-level background notification handler required for entry point
@pragma('vm:entry-point')
Future<void> famanhBackgroundNotificationHandler(NotificationResponse response) async {
  // Callback when notification is tapped in background/closed app
  debugPrint('Background notification tapped: ${response.payload}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'famanh_orders_channel';
  static const String channelName = 'Commandes & Livraisons Famanh';
  static const String channelDesc = 'Notifications de suivi de livraison, assignations et alertes en direct.';

  bool _initialized = false;

  /// Initialise la gestion des notifications locales et prépare les canaux Android/iOS
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _initialized = true;

    // 1. Canal de Notification Android Haute Importance
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // 2. Initialisation Plugin Local Notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload, navigatorKey);
      },
      onDidReceiveBackgroundNotificationResponse: famanhBackgroundNotificationHandler,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Affiche une notification locale en haut de l'écran avec son et animation (Heads-up)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  /// Traite le clic sur la notification et redirige l'utilisateur vers le bon écran
  void _handleNotificationTap(String? payloadRaw, GlobalKey<NavigatorState>? navKey) {
    if (payloadRaw == null || payloadRaw.trim().isEmpty) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payloadRaw);
      final type = data['type']?.toString();
      final orderId = data['order_id']?.toString() ?? data['id']?.toString();

      debugPrint('Notification tapped with type: $type, orderId: $orderId');

      if (navKey?.currentState != null && type != null && orderId != null) {
        // Redirection intelligente selon le type
        // Ex: navKey.currentState!.pushNamed(...)
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Enregistre le token de l'appareil auprès du backend Laravel
  Future<void> syncDeviceToken(String deviceToken, {String? platform}) async {
    if (ApiSession.token == null || ApiSession.token!.isEmpty) return;
    try {
      await ApiClient.registerDeviceToken(
        token: deviceToken,
        platform: platform ?? (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      );
      debugPrint('Device token synced with backend successfully.');
    } catch (e) {
      debugPrint('Device token sync error: $e');
    }
  }
}
