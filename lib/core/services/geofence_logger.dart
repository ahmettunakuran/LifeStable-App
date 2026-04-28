import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeofenceEventType {
  static const String enter = 'enter';
  static const String exit = 'exit';
}

class GeofenceLogEntry {
  final String locationId;
  final String eventType;
  final DateTime triggeredAt;
  final double deviceLat;
  final double deviceLng;
  final bool notificationSent;
  final String? skippedReason;

  const GeofenceLogEntry({
    required this.locationId,
    required this.eventType,
    required this.triggeredAt,
    required this.deviceLat,
    required this.deviceLng,
    required this.notificationSent,
    this.skippedReason,
  });

  Map<String, dynamic> toMap() => {
        'location_id': locationId,
        'event_type': eventType,
        'triggered_at': Timestamp.fromDate(triggeredAt),
        'device_lat': deviceLat,
        'device_lng': deviceLng,
        'notification_sent': notificationSent,
        if (skippedReason != null) 'skipped_reason': skippedReason,
      };

  static GeofenceLogEntry fromMap(Map<String, dynamic> map) => GeofenceLogEntry(
        locationId: map['location_id'] as String? ?? '',
        eventType: map['event_type'] as String? ?? '',
        triggeredAt: (map['triggered_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        deviceLat: (map['device_lat'] as num?)?.toDouble() ?? 0,
        deviceLng: (map['device_lng'] as num?)?.toDouble() ?? 0,
        notificationSent: map['notification_sent'] as bool? ?? false,
        skippedReason: map['skipped_reason'] as String?,
      );
}

class GeofenceLogger {
  GeofenceLogger._();
  static final GeofenceLogger instance = GeofenceLogger._();

  static const int _maxLogs = 50;

  CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('geofence_logs');
  }

  Future<void> log(GeofenceLogEntry entry) async {
    final col = _collection();
    if (col == null) return;
    try {
      await col.add(entry.toMap());
      await _pruneOldLogs(col);
    } catch (_) {}
  }

  Future<List<GeofenceLogEntry>> fetchLogs({int days = 7}) async {
    final col = _collection();
    if (col == null) return [];
    try {
      final since = Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: days)));
      final snap = await col
          .where('triggered_at', isGreaterThan: since)
          .orderBy('triggered_at', descending: true)
          .get();
      return snap.docs
          .map((d) => GeofenceLogEntry.fromMap(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _pruneOldLogs(
      CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col
        .orderBy('triggered_at', descending: true)
        .limit(_maxLogs + 10)
        .get();
    if (snap.docs.length > _maxLogs) {
      final toDelete = snap.docs.sublist(_maxLogs);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
