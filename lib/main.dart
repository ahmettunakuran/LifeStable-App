import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase core package required to initialize Firebase before using any service

import 'firebase_options.dart';
// Auto-generated file by FlutterFire CLI containing platform-specific Firebase config

import 'screens/domains/domain_list_screen.dart';
// Imports the main domain list screen to use as the home page

void main() async {
  // Must be called before any async operation in main()
  // Ensures Flutter engine is fully initialized before Firebase setup
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase with platform-specific settings (iOS / Android)
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // Starts the Flutter application
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeStable',
      theme: ThemeData(
        // Sets the primary color theme of the entire app using deep purple seed
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // Sets DomainListScreen as the first screen users see when opening the app
      home: const DomainListScreen(),
    );
  }
}
