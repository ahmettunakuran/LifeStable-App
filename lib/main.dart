import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'features/alerts/domain/geofence_usecase.dart';
import 'core/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';

import 'core/localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LanguageManager.init();
  await HomeWidget.setAppGroupId('group.com.ahmettunakuran.lifestable');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    // Emulator disabled for Blaze/deployed backend testing.
  }

  // Initialize Notifications
  await NotificationService().initialize();

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ));
  await remoteConfig.fetchAndActivate();

  // Initialize geofencing for already-logged-in users.
  // For new sign-ins, GeofenceUseCase is called from AuthCubit/SplashPage.
  if (FirebaseAuth.instance.currentUser != null) {
    await GeofenceUseCase.instance.initializeAll();
  }

  runApp(const LifeStableApp());
}