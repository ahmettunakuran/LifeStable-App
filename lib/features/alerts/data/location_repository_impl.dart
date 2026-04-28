import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/location_entity.dart';
import '../domain/repositories/location_repository.dart';
import 'location_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const _uuid = Uuid();

  LocationRepositoryImpl(this._firestore, this._auth);

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('locations');

  @override
  Future<void> addLocation(LocationEntity location) async {
    final id = location.locationId.isEmpty ? _uuid.v4() : location.locationId;
    final model = LocationModel.fromEntity(
      location.copyWith(locationId: id),
    );
    await _collection.doc(id).set(model.toMap());
  }

  @override
  Stream<List<LocationEntity>> getLocations() {
    return _collection
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationModel.fromMap(doc.data(), doc.id).toEntity())
            .toList());
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    await _collection.doc(locationId).delete();
  }

  @override
  Future<void> updateLocation(LocationEntity location) async {
    final model = LocationModel.fromEntity(location);
    await _collection.doc(location.locationId).update(model.toMap());
  }
}
