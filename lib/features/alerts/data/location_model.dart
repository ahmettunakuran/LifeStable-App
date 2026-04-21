import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/location_entity.dart';

class LocationModel {
  final String locationId;
  final String label;
  final double lat;
  final double lng;
  final int radiusM;
  final Timestamp createdAt;
  final String userId;
  final bool geofenceOnEnter;
  final bool geofenceOnExit;
  final String? doNotRemindAfter;
  final bool remind30MinAfterEntry;

  const LocationModel({
    required this.locationId,
    required this.label,
    required this.lat,
    required this.lng,
    this.radiusM = 150,
    required this.createdAt,
    required this.userId,
    this.geofenceOnEnter = true,
    this.geofenceOnExit = false,
    this.doNotRemindAfter,
    this.remind30MinAfterEntry = false,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map, String id) {
    return LocationModel(
      locationId: id,
      label: map['label'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radiusM: map['radius_m'] as int? ?? 150,
      createdAt: map['created_at'] as Timestamp? ?? Timestamp.now(),
      userId: map['user_id'] as String? ?? '',
      geofenceOnEnter: map['geofence_on_enter'] as bool? ?? true,
      geofenceOnExit: map['geofence_on_exit'] as bool? ?? false,
      doNotRemindAfter: map['dont_remind_after'] as String?,
      remind30MinAfterEntry: map['remind_30min_after_entry'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusM,
      'created_at': createdAt,
      'user_id': userId,
      'geofence_on_enter': geofenceOnEnter,
      'geofence_on_exit': geofenceOnExit,
      if (doNotRemindAfter != null) 'dont_remind_after': doNotRemindAfter,
      'remind_30min_after_entry': remind30MinAfterEntry,
    };
  }

  LocationEntity toEntity() {
    return LocationEntity(
      locationId: locationId,
      label: label,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      createdAt: createdAt.toDate(),
      userId: userId,
      geofenceOnEnter: geofenceOnEnter,
      geofenceOnExit: geofenceOnExit,
      doNotRemindAfter: doNotRemindAfter,
      remind30MinAfterEntry: remind30MinAfterEntry,
    );
  }

  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      locationId: entity.locationId,
      label: entity.label,
      lat: entity.lat,
      lng: entity.lng,
      radiusM: entity.radiusM,
      createdAt: Timestamp.fromDate(entity.createdAt),
      userId: entity.userId,
      geofenceOnEnter: entity.geofenceOnEnter,
      geofenceOnExit: entity.geofenceOnExit,
      doNotRemindAfter: entity.doNotRemindAfter,
      remind30MinAfterEntry: entity.remind30MinAfterEntry,
    );
  }
}
