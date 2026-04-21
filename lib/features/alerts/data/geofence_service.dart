import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_model.dart';

typedef GeofenceEventCallback = Future<void> Function(
  String locationId,
  bool isEntering,
  double deviceLat,
  double deviceLng,
);

class AppGeofenceService {
  AppGeofenceService._();
  static final AppGeofenceService instance = AppGeofenceService._();

  static const int _maxGeofences = 100;
  static const int _cooldownMinutes = 30;
  static const int _dwellSeconds = 10;

  final _service = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: _dwellSeconds * 1000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: kDebugMode,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  GeofenceEventCallback? _eventCallback;
  bool _started = false;
  bool get isStarted => _started;

  // Tracks locations registered for state queries in debug screen
  final Map<String, LocationModel> _registeredModels = {};

  Map<String, LocationModel> get registeredModels =>
      Map.unmodifiable(_registeredModels);

  void setEventCallback(GeofenceEventCallback cb) {
    _eventCallback = cb;
  }

  Future<void> start(List<LocationModel> locations) async {
    if (_started) return;

    _service.addGeofenceStatusChangeListener(_onStatusChanged);

    final geofences = _buildGeofences(locations);
    await _service.start(geofences).catchError((Object e) {
      debugPrint('[AppGeofenceService] start error: $e');
    });

    for (final loc in locations) {
      _registeredModels[loc.locationId] = loc;
    }
    _started = true;
  }

  Future<void> registerGeofence(LocationModel location) async {
    final geofence = _toGeofence(location);
    try {
      _service.addGeofence(geofence);
      _registeredModels[location.locationId] = location;
    } catch (e) {
      debugPrint('[AppGeofenceService] addGeofence error: $e');
    }
  }

  Future<void> removeGeofence(String locationId) async {
    try {
      _service.removeGeofenceById(locationId);
      _registeredModels.remove(locationId);
    } catch (e) {
      debugPrint('[AppGeofenceService] removeGeofence error: $e');
    }
  }

  Future<void> syncAllGeofences(List<LocationModel> locations) async {
    final capped = locations.length > _maxGeofences
        ? locations.sublist(0, _maxGeofences)
        : locations;
    try {
      _service.clearGeofenceList();
      _registeredModels.clear();
      _service.addGeofenceList(_buildGeofences(capped));
      for (final loc in capped) {
        _registeredModels[loc.locationId] = loc;
      }
    } catch (e) {
      debugPrint('[AppGeofenceService] syncAll error: $e');
    }
  }

  Future<void> simulateEvent(
    String locationId,
    bool isEntering,
    double lat,
    double lng,
  ) async {
    debugPrint('[AppGeofenceService] simulate: $locationId entering=$isEntering');
    await _eventCallback?.call(locationId, isEntering, lat, lng);
  }

  Future<void> _onStatusChanged(
    Geofence geofence,
    GeofenceRadius radius,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status == GeofenceStatus.DWELL) return;

    final isEntering = status == GeofenceStatus.ENTER;
    final locationId = geofence.id;

    if (isEntering && await _isCooldownActive(locationId)) {
      debugPrint('[AppGeofenceService] cooldown active for $locationId, skipping');
      return;
    }

    if (isEntering) {
      await _saveTriggerTime(locationId);
    }

    await _eventCallback?.call(
      locationId,
      isEntering,
      location.latitude,
      location.longitude,
    );
  }

  List<Geofence> _buildGeofences(List<LocationModel> locations) {
    return locations.map(_toGeofence).toList();
  }

  Geofence _toGeofence(LocationModel loc) {
    return Geofence(
      id: loc.locationId,
      latitude: loc.lat,
      longitude: loc.lng,
      radius: [
        GeofenceRadius(
          id: '${loc.locationId}_r',
          length: smartRadius(loc.label, loc.radiusM).toDouble(),
        ),
      ],
    );
  }

  static int smartRadius(String label, int userRadius) {
    final lower = label.toLowerCase();
    if (lower.contains('gym') ||
        lower.contains('market') ||
        lower.contains('pharmacy')) {
      return 100;
    }
    if (lower.contains('school') ||
        lower.contains('university') ||
        lower.contains('campus')) {
      return 200;
    }
    return userRadius;
  }

  Future<bool> _isCooldownActive(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'geofence_last_trigger_$locationId';
    final lastMs = prefs.getInt(key);
    if (lastMs == null) return false;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - lastMs;
    return elapsed < _cooldownMinutes * 60 * 1000;
  }

  Future<void> _saveTriggerTime(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'geofence_last_trigger_$locationId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
