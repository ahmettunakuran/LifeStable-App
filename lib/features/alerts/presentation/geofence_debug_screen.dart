import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/services/geofence_logger.dart';
import '../../../shared/constants/app_colors.dart';
import '../data/geofence_service.dart';
import '../logic/location_cubit.dart';
import '../logic/location_state.dart';

class GeofenceDebugScreen extends StatefulWidget {
  const GeofenceDebugScreen({super.key});

  @override
  State<GeofenceDebugScreen> createState() => _GeofenceDebugScreenState();
}

class _GeofenceDebugScreenState extends State<GeofenceDebugScreen> {
  Position? _devicePosition;
  List<GeofenceLogEntry> _recentLogs = [];
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    context.read<LocationCubit>().loadLocations();
    _startLocationRefresh();
    _loadLogs();
  }

  void _startLocationRefresh() {
    _fetchPosition();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchPosition();
      _loadLogs();
    });
  }

  Future<void> _fetchPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _devicePosition = pos);
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    final logs = await GeofenceLogger.instance.fetchLogs(days: 1);
    if (mounted) setState(() => _recentLogs = logs.take(10).toList());
  }

  double _distanceTo(double lat, double lng) {
    if (_devicePosition == null) return 0;
    const R = 6371000.0;
    final dLat = _toRad(lat - _devicePosition!.latitude);
    final dLng = _toRad(lng - _devicePosition!.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(_devicePosition!.latitude)) *
            cos(_toRad(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug/profile builds
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(child: Text('Debug tools disabled in release builds.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Geofence Debug Tool',
          style: TextStyle(
              color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeviceLocationCard(position: _devicePosition),
                const SizedBox(height: 16),
                const _SectionHeader('GEOFENCES'),
                const SizedBox(height: 8),
                if (state.locations.isEmpty)
                  const Center(
                    child: Text('No locations saved.',
                        style: TextStyle(color: Colors.white54)),
                  )
                else
                  ...state.locations.map((loc) {
                    final distM = _distanceTo(loc.lat, loc.lng);
                    final radius = AppGeofenceService.smartRadius(
                        loc.label, loc.radiusM);
                    final isInside = _devicePosition != null &&
                        distM <= radius;
                    return _GeofenceCard(
                      label: loc.label,
                      lat: loc.lat,
                      lng: loc.lng,
                      radius: radius,
                      distanceM: distM,
                      isInside: isInside,
                      onEnter: () => AppGeofenceService.instance
                          .simulateEvent(
                              loc.locationId, true, loc.lat, loc.lng),
                      onExit: () => AppGeofenceService.instance
                          .simulateEvent(
                              loc.locationId, false, loc.lat, loc.lng),
                    );
                  }),
                const SizedBox(height: 20),
                const _SectionHeader('LAST 10 TRIGGER LOGS (today)'),
                const SizedBox(height: 8),
                if (_recentLogs.isEmpty)
                  const Text('No triggers today.',
                      style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ..._recentLogs.map((e) => _LogRow(entry: e)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceLocationCard extends StatelessWidget {
  final Position? position;
  const _DeviceLocationCard({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          if (position == null)
            const Text('Fetching device location...',
                style: TextStyle(color: Colors.white54, fontSize: 13))
          else
            Expanded(
              child: Text(
                'Device: ${position!.latitude.toStringAsFixed(5)}, '
                '${position!.longitude.toStringAsFixed(5)}  '
                'Acc: ±${position!.accuracy.toStringAsFixed(0)}m',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  final String label;
  final double lat;
  final double lng;
  final int radius;
  final double distanceM;
  final bool isInside;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const _GeofenceCard({
    required this.label,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.distanceM,
    required this.isInside,
    required this.onEnter,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInside
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : AppColors.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isInside
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isInside ? 'INSIDE' : 'OUTSIDE',
                  style: TextStyle(
                    color: isInside ? Colors.greenAccent : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}  |  '
            'R: ${radius}m  |  '
            'Dist: ${distanceM.toStringAsFixed(0)}m',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const Divider(color: Colors.white10, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(
                  label: 'Simulate Enter',
                  icon: Icons.login,
                  color: Colors.greenAccent,
                  onTap: onEnter),
              _ActionBtn(
                  label: 'Simulate Exit',
                  icon: Icons.logout,
                  color: Colors.redAccent,
                  onTap: onExit),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final GeofenceLogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isEnter = entry.eventType == GeofenceEventType.enter;
    final fmt = DateFormat('HH:mm:ss');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isEnter ? Icons.login : Icons.logout,
            color: isEnter ? Colors.greenAccent : Colors.orangeAccent,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            fmt.format(entry.triggeredAt),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.locationId.substring(0, entry.locationId.length.clamp(0, 8))}..  '
              '${isEnter ? 'ENTER' : 'EXIT'}  '
              '${entry.notificationSent ? '✓ sent' : '✗ ${entry.skippedReason ?? 'skipped'}'}',
              style:
                  const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600),
    );
  }
}
