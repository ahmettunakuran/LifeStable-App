import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/domain_entity.dart';
import '../../domain/repositories/domain_repository.dart';

class DomainRepositoryImpl implements DomainRepository {
  DomainRepositoryImpl(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _domainCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('domains');
  }

  @override
  Future<List<DomainEntity>> fetchDomains() async {
    final collection = _domainCollection;
    if (collection == null) return [];
    
    final snapshot = await collection.get();
    return snapshot.docs
        .map((doc) => DomainEntity.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> createOrUpdateDomain(DomainEntity domain) async {
    final collection = _domainCollection;
    if (collection == null) return;
    
    await collection.doc(domain.id).set(domain.toFirestore());
  }

  @override
  Future<void> deleteDomain(String domainId) async {
    final collection = _domainCollection;
    if (collection == null) return;
    
    await collection.doc(domainId).delete();
  }

  @override
  Stream<List<DomainEntity>> watchDomains() {
    final collection = _domainCollection;
    if (collection == null) return Stream.value([]);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DomainEntity.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}
