import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'google_external_account_entity.dart';

class GoogleCalendarSyncService {
  GoogleCalendarSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    /*if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _functions.useFunctionsEmulator('10.0.2.2', 5001);
      } else {
        _functions.useFunctionsEmulator('localhost', 5001);
      }
    }*/
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _googleAccountDoc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('external_accounts')
      .doc('google');

  Stream<GoogleExternalAccountEntity?> watchGoogleConnection() {
    return _googleAccountDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GoogleExternalAccountEntity.fromFirestore(doc.id, doc.data()!);
    });
  }

  Future<String> getConnectUrl() async {
    final callable = _functions.httpsCallable('initiateGoogleCalendarAuth');
    final result = await callable.call();
    return result.data['authUrl'] as String;
  }

  Future<GoogleCalendarSyncResult> syncNow() async {
    final callable = _functions.httpsCallable(
      'syncGoogleCalendar',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );

    final result = await callable.call();
    return GoogleCalendarSyncResult.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<void> disconnect() async {
    final callable = _functions.httpsCallable('disconnectGoogleCalendar');
    await callable.call();
  }
}