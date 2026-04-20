import '../domain/entities/location_entity.dart';

enum LocationStatus { initial, loading, loaded, error }

class LocationState {
  final List<LocationEntity> locations;
  final LocationStatus status;
  final String? errorMessage;

  const LocationState({
    this.locations = const [],
    this.status = LocationStatus.initial,
    this.errorMessage,
  });

  LocationState copyWith({
    List<LocationEntity>? locations,
    LocationStatus? status,
    String? errorMessage,
  }) {
    return LocationState(
      locations: locations ?? this.locations,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
