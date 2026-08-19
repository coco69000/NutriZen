import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:flutter_timezone/flutter_timezone.dart'; // ✅ AJOUTER CET IMPORT

// Handler pour les notifications reçues en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("FCM Message en arrière-plan: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Identifiants des Canaux Android
  static const String channelHealthId = 'nutrizen_health_channel';
  static const String channelFastingId = 'nutrizen_fasting_channel';
  static const String channelSocialId = 'nutrizen_social_channel';

  Future<void> init() async {
    // 1. Initialisation des fuseaux horaires pour les alarmes programmées
    tz_data.initializeTimeZones();
    try {
      // ✅ CORRECTION : Utilisation de flutter_timezone pour obtenir un format IANA valide (ex: "Europe/Paris")
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback sécurisé en cas d'échec
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Configuration Android & iOS
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3. Demande explicite des permissions runtime (Android 13+ & iOS)
    await _requestPermissions();

    // 4. Création des Canaux Android avec priorités
    await _createNotificationChannels();

    // 5. Configuration FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupFCMListeners();
    await updateDeviceToken();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl =
          _localPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidImpl =
        _localPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelHealthId,
          'Santé & Métabolisme',
          description: 'Alertes glycémie, conseils nutritionnels et prévention',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelFastingId,
          'Suivi du Jeûne',
          description: 'Alertes de début, fin et étapes métaboliques du jeûne',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          channelSocialId,
          'Social & Duels',
          description: 'Défis reçus, encouragements et victoires entre amis',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }
  }

  /// Enregistre ou met à jour le token FCM de l'appareil dans Firestore
  Future<void> updateDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.operatingSystem,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Erreur mise à jour Token FCM: $e");
    }
  }

  void _setupFCMListeners() {
    // Réception de message quand l'application est au premier plan (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showInstantNotification(
          id: message.hashCode.abs() % 100000,
          title: notification.title ?? 'NutriZen',
          body: notification.body ?? '',
          channelId: channelSocialId,
        );
      }
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint("Notification cliquée avec payload: ${response.payload}");
  }

  /// Notification locale immédiate
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String channelId = channelHealthId,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelId == channelFastingId
              ? 'Suivi du Jeûne'
              : (channelId == channelSocialId
                  ? 'Social & Duels'
                  : 'Santé & Métabolisme'),
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
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

    await _localPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  /// Programmer une alarme précise (Ex: Fin de jeûne, rappel d'eau)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = channelFastingId,
    String? payload,
  }) async {
    // Si la date est déjà passée, on ne programme pas
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _localPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Suivi du Jeûne',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Annuler une notification spécifique
  Future<void> cancelNotification(int id) async {
    await _localPlugin.cancel(id: id);
  }
}
