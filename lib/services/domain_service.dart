import 'package:cloud_firestore/cloud_firestore.dart';
// Firebase database package for all Firestore operations

import 'package:firebase_auth/firebase_auth.dart';
// Firebase authentication package to access the currently logged-in user

import '../models/domain.dart';
// Imports our Domain model class

class DomainService {
  // Gets the single shared Firestore instance (singleton pattern)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Gets the single shared Auth instance to access current user info
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns a Firestore reference to the current user's domains collection
  // Path structure: users → {userId} → domains
  CollectionReference get _domainsRef {
    // Gets the unique ID of the currently logged-in user
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('domains');
  }

  // CREATE — Adds a new domain document to Firestore
  Future<void> createDomain({
    required String name,
    required String colorHex,
  }) async {
    // Gets current user's ID to store as owner of the domain
    final uid = _auth.currentUser!.uid;
    await _domainsRef.add({
      'name': name,
      'color_hex': colorHex,
      // Uses Firebase server timestamp instead of device time for reliability
      'created_at': FieldValue.serverTimestamp(),
      'user_id': uid,
    });
  }

  // READ — Returns a real-time stream of the user's domain list
  // The UI will automatically update whenever data changes in Firestore
  Stream<List<Domain>> getDomains() {
    return _domainsRef
    // Orders domains by creation time, from oldest to newest
        .orderBy('created_at', descending: false)
    // .snapshots() opens a real-time listener on the Firestore collection
        .snapshots()
    // Converts each Firestore document in the snapshot to a Domain object
        .map((snapshot) =>
        snapshot.docs.map((doc) => Domain.fromFirestore(doc)).toList());
  }

  // UPDATE — Updates the name and color of an existing domain
  Future<void> updateDomain({
    required String domainId,
    required String newName,
    required String newColorHex,
  }) async {
    // .doc(domainId) locates the specific document by its Firestore ID
    await _domainsRef.doc(domainId).update({
      'name': newName,
      'color_hex': newColorHex,
    });
  }

  // DELETE — Permanently removes a domain document from Firestore
  Future<void> deleteDomain(String domainId) async {
    await _domainsRef.doc(domainId).delete();
  }
}