import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/alerts/data/location_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _locationChannelId = 'location_alerts';
  static const _locationChannelName = 'Location Alerts';

  Future<void> initialize() async {
    if (Platform.isIOS) {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings,
        onDidReceiveNotificationResponse: (details) {});

    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _fcm.getToken();
        await _saveTokenToFirestore(token);
      }
    });

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    final currentToken = await _fcm.getToken();
    if (currentToken != null) await _saveTokenToFirestore(currentToken);
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'team_updates', 'Team Updates',
            channelDescription: 'Notifications for team board changes',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> showLocationNotification({
    required String locationLabel,
    required bool isEntering,
  }) async {
    final title = isEntering
        ? '📍 Arrived at $locationLabel'
        : '👋 Left $locationLabel';
    final body = isEntering
        ? "You've arrived at $locationLabel! Check your tasks here."
        : "You've left $locationLabel.";

    await _localNotifications.show(
      locationLabel.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _locationChannelId, _locationChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static bool checkTimeConstraint(LocationModel loc) {
    final cutoff = loc.doNotRemindAfter;
    if (cutoff == null || cutoff.isEmpty) return true;
    final parts = cutoff.split(':');
    if (parts.length != 2) return true;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return true;
    final now = DateTime.now();
    return (now.hour * 60 + now.minute) < (h * 60 + m);
  }
}
