import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleExternalAccountEntity {
  const GoogleExternalAccountEntity({
    required this.provider,
    required this.providerUserId,
    this.connectedAt,
    this.lastSyncAt,
  });

  final String provider;
  final String providerUserId;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;

  factory GoogleExternalAccountEntity.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return GoogleExternalAccountEntity(
      provider: data['provider'] as String? ?? id,
      providerUserId: data['providerUserId'] as String? ?? 'Google account',
      connectedAt: parseDate(data['connectedAt']),
      lastSyncAt: parseDate(data['lastSyncAt']),
    );
  }
}

class GoogleCalendarSyncResult {
  const GoogleCalendarSyncResult({
    required this.created,
    required this.updated,
    required this.deleted,
    required this.totalFetched,
  });

  final int created;
  final int updated;
  final int deleted;
  final int totalFetched;

  factory GoogleCalendarSyncResult.fromMap(Map<String, dynamic> data) {
    return GoogleCalendarSyncResult(
      created: data['created'] as int? ?? 0,
      updated: data['updated'] as int? ?? 0,
      deleted: data['deleted'] as int? ?? 0,
      totalFetched: data['totalFetched'] as int? ?? 0,
    );
  }
}