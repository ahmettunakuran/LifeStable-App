import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/alerts/data/location_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'location_alerts';
  static const _channelName = 'Location Alerts';
  static const _channelDesc =
      'Notifications triggered by saved geofence locations';

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showLocationNotification({
    required String locationLabel,
    required bool isEntering,
  }) async {
    final title =
        isEntering ? '📍 Arrived at $locationLabel' : '👋 Left $locationLabel';
    final body = isEntering
        ? "You've arrived at $locationLabel! Check your tasks here."
        : "You've left $locationLabel.";

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      id: locationLabel.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showReminder30Min(String locationLabel) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: '${locationLabel}_30m'.hashCode,
      title: '⏰ 30 min at $locationLabel',
      body: "You've been at $locationLabel for 30 minutes.",
      notificationDetails: details,
    );
  }

  static bool checkTimeConstraint(LocationModel loc) {
    final cutoff = loc.doNotRemindAfter;
    if (cutoff == null || cutoff.isEmpty) return true;
    final parts = cutoff.split(':');
    if (parts.length != 2) return true;
    final cutoffH = int.tryParse(parts[0]);
    final cutoffM = int.tryParse(parts[1]);
    if (cutoffH == null || cutoffM == null) return true;
    final now = DateTime.now();
    final cutoffMinutes = cutoffH * 60 + cutoffM;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes < cutoffMinutes;
  }
}
