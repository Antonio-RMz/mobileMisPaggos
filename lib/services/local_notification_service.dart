import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    // Usar el icono por defecto de Android de launcher_icon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _notificationsPlugin.initialize(settings);
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  static Future<void> showAlarmNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      debugPrint("ALERTA WEB: $title - $body");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel_id',
      'Alertas de Pedidos',
      channelDescription: 'Canal para pedidos que vencen en menos de 30 minutos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(id, title, body, platformDetails);
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }
}
