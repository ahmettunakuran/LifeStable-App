import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/entities/location_entity.dart';
import '../domain/repositories/location_repository.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationRepository _repository;
  StreamSubscription<List<LocationEntity>>? _subscription;

  LocationCubit(this._repository) : super(const LocationState());

  void loadLocations() {
    emit(state.copyWith(status: LocationStatus.loading));
    _subscription = _repository.getLocations().listen(
      (locations) => emit(state.copyWith(
        status: LocationStatus.loaded,
        locations: locations,
      )),
      onError: (Object e) => emit(state.copyWith(
        status: LocationStatus.error,
        errorMessage: e.toString(),
      )),
    );
  }

  Future<void> addLocation(LocationEntity location) async {
    try {
      await _repository.addLocation(location);
    } catch (e) {
      emit(state.copyWith(
        status: LocationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> deleteLocation(String locationId) async {
    try {
      await _repository.deleteLocation(locationId);
    } catch (e) {
      emit(state.copyWith(
        status: LocationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> updateLocation(LocationEntity location) async {
    try {
      await _repository.updateLocation(location);
    } catch (e) {
      emit(state.copyWith(
        status: LocationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
