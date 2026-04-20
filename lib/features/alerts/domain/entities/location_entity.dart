class LocationEntity {
  final String locationId;
  final String label;
  final double lat;
  final double lng;
  final int radiusM;
  final DateTime createdAt;
  final String userId;
  final bool geofenceOnEnter;
  final bool geofenceOnExit;
  final String? doNotRemindAfter;

  const LocationEntity({
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
  });

  LocationEntity copyWith({
    String? locationId,
    String? label,
    double? lat,
    double? lng,
    int? radiusM,
    DateTime? createdAt,
    String? userId,
    bool? geofenceOnEnter,
    bool? geofenceOnExit,
    String? doNotRemindAfter,
  }) {
    return LocationEntity(
      locationId: locationId ?? this.locationId,
      label: label ?? this.label,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusM: radiusM ?? this.radiusM,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      geofenceOnEnter: geofenceOnEnter ?? this.geofenceOnEnter,
      geofenceOnExit: geofenceOnExit ?? this.geofenceOnExit,
      doNotRemindAfter: doNotRemindAfter ?? this.doNotRemindAfter,
    );
  }
}
