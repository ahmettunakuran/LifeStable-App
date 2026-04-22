import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  if (kDebugMode) {
    // Emulator disabled for Blaze/deployed backend testing.
  }

  runApp(const LifeStableApp());
}