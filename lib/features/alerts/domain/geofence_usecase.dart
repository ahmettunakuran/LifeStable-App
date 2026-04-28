import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/geofence_logger.dart';
import '../../../core/services/notification_service.dart';
import '../data/geofence_service.dart';
import '../data/location_model.dart';
import '../data/location_repository_impl.dart';
import 'entities/location_entity.dart';
import 'repositories/location_repository.dart';

class GeofenceUseCase {
  GeofenceUseCase._();
  static final GeofenceUseCase instance = GeofenceUseCase._();

  StreamSubscription<List<LocationEntity>>? _subscription;
  List<LocationModel> _currentModels = [];

  Future<void> initializeAll() async {
    await NotificationService.instance.initialize();
    AppGeofenceService.instance.setEventCallback(_handleGeofenceEvent);

    if (FirebaseAuth.instance.currentUser == null) return;

    final LocationRepository repo = LocationRepositoryImpl(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );

    _subscription = repo.getLocations().listen(
      (entities) async {
        _currentModels = entities.map(LocationModel.fromEntity).toList();

        if (!AppGeofenceService.instance.isStarted) {
          await AppGeofenceService.instance.start(_currentModels);
        } else {
          await AppGeofenceService.instance.syncAllGeofences(_currentModels);
        }
      },
      onError: (Object e) =>
          debugPrint('[GeofenceUseCase] stream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  LocationModel? _findModel(String locationId) {
    try {
      return _currentModels.firstWhere((m) => m.locationId == locationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleGeofenceEvent(
    String locationId,
    bool isEntering,
    double deviceLat,
    double deviceLng,
  ) async {
    final model = _findModel(locationId);
    bool shouldNotify = true;
    String? skipReason;

    if (model != null) {
      if (isEntering && !model.geofenceOnEnter) {
        shouldNotify = false;
        skipReason = 'geofence_on_enter disabled';
      } else if (!isEntering && !model.geofenceOnExit) {
        shouldNotify = false;
        skipReason = 'geofence_on_exit disabled';
      } else if (!NotificationService.checkTimeConstraint(model)) {
        shouldNotify = false;
        skipReason = 'past doNotRemindAfter cutoff';
      }
    }

    if (shouldNotify && model != null) {
      await NotificationService.instance.showLocationNotification(
        locationLabel: model.label,
        isEntering: isEntering,
      );

      if (isEntering && model.remind30MinAfterEntry) {
        _schedule30MinReminder(model.label, locationId);
      }
    }

    await GeofenceLogger.instance.log(GeofenceLogEntry(
      locationId: locationId,
      eventType:
          isEntering ? GeofenceEventType.enter : GeofenceEventType.exit,
      triggeredAt: DateTime.now(),
      deviceLat: deviceLat,
      deviceLng: deviceLng,
      notificationSent: shouldNotify,
      skippedReason: skipReason,
    ));
  }

  void _schedule30MinReminder(String label, String locationId) {
    Future.delayed(const Duration(minutes: 30), () async {
      if (_findModel(locationId) != null) {
        await NotificationService.instance.showReminder30Min(label);
      }
    });
  }
}
