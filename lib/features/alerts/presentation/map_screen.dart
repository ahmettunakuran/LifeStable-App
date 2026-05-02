import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/constants/app_colors.dart';
import '../domain/entities/location_entity.dart';
import '../logic/location_cubit.dart';
import '../logic/location_state.dart';
import '../../../core/localization/app_localizations.dart';
import 'widgets/add_location_bottom_sheet.dart';
import 'widgets/saved_locations_list.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  LatLng? _currentPosition;
  bool _isPickingLocation = false;
  bool _showSavedList = false;

  static const _defaultPosition = LatLng(41.0082, 28.9784); // Istanbul

  @override
  void initState() {
    super.initState();
    context.read<LocationCubit>().loadLocations();
    _initCurrentLocation();
  }

  Future<void> _initCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // DÜZELTME: Versiyon uyumluluğu için desiredAccuracy kullanıldı
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _currentPosition = latLng);

      final controller = await _mapControllerCompleter.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    } catch (_) {}
  }

  Set<Marker> _buildMarkers(List<LocationEntity> locations) {
    final markers = <Marker>{};

    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: S.of('you_are_here')),
      ));
    }

    for (final loc in locations) {
      markers.add(Marker(
        markerId: MarkerId(loc.locationId),
        position: LatLng(loc.lat, loc.lng),
        // DÜZELTME: hueGold yerine 45.0 (Altın rengi tonu) kullanıldı
        icon: BitmapDescriptor.defaultMarkerWithHue(45.0),
        infoWindow: InfoWindow(
          title: loc.label,
          snippet: S.of('radius_m', args: {'radius': loc.radiusM.toString()}),
        ),
        onTap: () => _showLocationDetailSheet(loc),
      ));
    }

    return markers;
  }

  Set<Circle> _buildCircles(List<LocationEntity> locations) {
    return locations.map((loc) => Circle(
      circleId: CircleId('circle_${loc.locationId}'),
      center: LatLng(loc.lat, loc.lng),
      radius: loc.radiusM.toDouble(),
      fillColor: AppColors.gold.withValues(alpha: 0.1),
      strokeColor: AppColors.gold.withValues(alpha: 0.4),
      strokeWidth: 1,
    )).toSet();
  }

  void _onMapTap(LatLng position) {
    if (!_isPickingLocation) return;
    setState(() => _isPickingLocation = false);
    AddLocationBottomSheet.show(context, initialPosition: position);
  }

  void _showLocationDetailSheet(LocationEntity location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<LocationCubit>(),
        child: _LocationDetailSheet(location: location),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(
          S.of('locations'),
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(
            icon: Icon(
              _showSavedList ? Icons.map_outlined : Icons.list,
              color: AppColors.gold,
            ),
            onPressed: () => setState(() => _showSavedList = !_showSavedList),
            tooltip: _showSavedList ? S.of('show_map') : S.of('saved_locations'),
          ),
        ],
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          if (_showSavedList) {
            return const SavedLocationsList();
          }
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? _defaultPosition,
                  zoom: 13,
                ),
                onMapCreated: (controller) {
                  if (!_mapControllerCompleter.isCompleted) {
                    _mapControllerCompleter.complete(controller);
                  }
                },
                markers: _buildMarkers(state.locations),
                circles: _buildCircles(state.locations),
                onTap: _onMapTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              if (_isPickingLocation)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        S.of('pin_on_map_hint'),
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 100,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'my_location',
                  backgroundColor: AppColors.cardBg,
                  onPressed: () async {
                    if (_currentPosition != null) {
                      final controller = await _mapControllerCompleter.future;
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                      );
                    } else {
                      await _initCurrentLocation();
                    }
                  },
                  child: const Icon(Icons.my_location, color: AppColors.gold, size: 20),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_showSavedList) ...[
            FloatingActionButton.extended(
              heroTag: 'pin_on_map',
              backgroundColor: AppColors.cardBg,
              onPressed: () => setState(() => _isPickingLocation = !_isPickingLocation),
              icon: Icon(
                _isPickingLocation ? Icons.close : Icons.pin_drop,
                color: _isPickingLocation ? Colors.redAccent : AppColors.gold,
              ),
              label: Text(
                _isPickingLocation ? S.of('cancel') : S.of('pin_on_map'),
                style: TextStyle(
                  color: _isPickingLocation ? Colors.redAccent : AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          FloatingActionButton.extended(
            heroTag: 'add_location',
            backgroundColor: AppColors.gold,
            onPressed: () => AddLocationBottomSheet.show(
              context,
              initialPosition: _currentPosition,
            ),
            icon: const Icon(Icons.add_location_alt, color: AppColors.black),
            label: Text(
              S.of('add_location'),
              style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDetailSheet extends StatelessWidget {
  final LocationEntity location;

  const _LocationDetailSheet({required this.location});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                location.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${location.lat.toStringAsFixed(5)}, ${location.lng.toStringAsFixed(5)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            S.of('radius_m', args: {'radius': location.radiusM.toString()}),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            context,
            label: S.of('on_arrival'),
            value: location.geofenceOnEnter,
            onChanged: (v) => context.read<LocationCubit>().updateLocation(
              location.copyWith(geofenceOnEnter: v),
            ),
          ),
          const SizedBox(height: 8),
          _buildToggle(
            context,
            label: S.of('on_leave'),
            value: location.geofenceOnExit,
            onChanged: (v) => context.read<LocationCubit>().updateLocation(
              location.copyWith(geofenceOnExit: v),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AddLocationBottomSheet.show(context, editingLocation: location);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(S.of('edit')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    context.read<LocationCubit>().deleteLocation(location.locationId);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(S.of('delete')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(BuildContext context, {required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        // DÜZELTME: activeColor uyarısı için activeThumbColor güncellendi
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.gold),
      ],
    );
  }
}