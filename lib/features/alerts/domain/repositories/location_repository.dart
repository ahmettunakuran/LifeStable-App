import '../entities/location_entity.dart';

abstract class LocationRepository {
  Future<void> addLocation(LocationEntity location);
  Stream<List<LocationEntity>> getLocations();
  Future<void> deleteLocation(String locationId);
  Future<void> updateLocation(LocationEntity location);
}
