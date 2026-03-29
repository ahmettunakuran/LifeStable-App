import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Registers FCM token on `users/{uid}.fcmTokens` for team board push (Cloud Functions).
class TeamPushNotifications {
  TeamPushNotifications._();

  static final TeamPushNotifications instance = TeamPushNotifications._();

  StreamSubscription<String>? _tokenRefreshSub;
  String? _registeredUid;

  Future<void> registerIfSignedIn(String? uid) async {
    if (kIsWeb || uid == null) {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _registeredUid = null;
      return;
    }

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _saveToken(uid, token);

    if (_registeredUid != uid) {
      await _tokenRefreshSub?.cancel();
      _registeredUid = uid;
      _tokenRefreshSub = messaging.onTokenRefresh.listen((t) {
        unawaited(_saveToken(uid, t));
      });
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
      },
      SetOptions(merge: true),
    );
  }
}

/// Subscribes to [FirebaseAuth.authStateChanges] and registers FCM for the signed-in user.
class TeamPushBootstrap extends StatefulWidget {
  const TeamPushBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<TeamPushBootstrap> createState() => _TeamPushBootstrapState();
}

class _TeamPushBootstrapState extends State<TeamPushBootstrap> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(TeamPushNotifications.instance.registerIfSignedIn(user?.uid));
    });
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
