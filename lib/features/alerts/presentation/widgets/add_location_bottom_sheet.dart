import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/constants/app_colors.dart';
import '../../domain/entities/location_entity.dart';
import '../../logic/location_cubit.dart';

class AddLocationBottomSheet extends StatefulWidget {
  final LatLng? initialPosition;
  final LocationEntity? editingLocation;

  const AddLocationBottomSheet({
    super.key,
    this.initialPosition,
    this.editingLocation,
  });

  static Future<void> show(
    BuildContext context, {
    LatLng? initialPosition,
    LocationEntity? editingLocation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<LocationCubit>(),
        child: AddLocationBottomSheet(
          initialPosition: initialPosition,
          editingLocation: editingLocation,
        ),
      ),
    );
  }

  @override
  State<AddLocationBottomSheet> createState() => _AddLocationBottomSheetState();
}

class _AddLocationBottomSheetState extends State<AddLocationBottomSheet> {
  final _searchController = TextEditingController();
  final _labelController = TextEditingController();
  double _radius = 150;
  bool _geofenceOnEnter = true;
  bool _geofenceOnExit = false;
  TimeOfDay? _doNotRemindAfter;
  LatLng? _selectedPosition;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingLocation;
    if (editing != null) {
      _labelController.text = editing.label;
      _radius = editing.radiusM.toDouble();
      _geofenceOnEnter = editing.geofenceOnEnter;
      _geofenceOnExit = editing.geofenceOnExit;
      _selectedPosition = LatLng(editing.lat, editing.lng);
      if (editing.doNotRemindAfter != null) {
        final parts = editing.doNotRemindAfter!.split(':');
        if (parts.length == 2) {
          _doNotRemindAfter = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    } else if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        setState(() {
          _selectedPosition = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchError = S.of('address_not_found');
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('pick_location_first'))),
      );
      return;
    }
    if (_labelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('enter_label'))),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doNotRemindStr = _doNotRemindAfter != null
        ? '${_doNotRemindAfter!.hour.toString().padLeft(2, '0')}:${_doNotRemindAfter!.minute.toString().padLeft(2, '0')}'
        : null;

    final editing = widget.editingLocation;
    final entity = LocationEntity(
      locationId: editing?.locationId ?? const Uuid().v4(),
      label: _labelController.text.trim(),
      lat: _selectedPosition!.latitude,
      lng: _selectedPosition!.longitude,
      radiusM: _radius.round(),
      createdAt: editing?.createdAt ?? DateTime.now(),
      userId: uid,
      geofenceOnEnter: _geofenceOnEnter,
      geofenceOnExit: _geofenceOnExit,
      doNotRemindAfter: doNotRemindStr,
    );

    final cubit = context.read<LocationCubit>();
    if (editing != null) {
      await cubit.updateLocation(entity);
    } else {
      await cubit.addLocation(entity);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
      child: SingleChildScrollView(
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
            Text(
              widget.editingLocation != null ? S.of('edit_location') : S.of('add_location'),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: S.of('search_address_hint'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _searchAddress,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.search, color: AppColors.black, size: 20),
                  ),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 6),
              Text(_searchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            if (_selectedPosition != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: S.of('location_label_hint'),
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.of('radius'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  '${_radius.round()} m',
                  style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.gold,
                thumbColor: AppColors.gold,
                inactiveTrackColor: Colors.white12,
                overlayColor: AppColors.gold.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _radius,
                min: 50,
                max: 500,
                divisions: 45,
                onChanged: (v) => setState(() => _radius = v),
              ),
            ),
            const SizedBox(height: 8),
            _buildToggleRow(S.of('on_arrival'), _geofenceOnEnter, (v) => setState(() => _geofenceOnEnter = v)),
            const SizedBox(height: 8),
            _buildToggleRow(S.of('on_leave'), _geofenceOnExit, (v) => setState(() => _geofenceOnExit = v)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _doNotRemindAfter ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _doNotRemindAfter = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.of('dont_remind_after'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      _doNotRemindAfter != null
                          ? _doNotRemindAfter!.format(context)
                          : S.of('not_set'),
                      style: TextStyle(
                        color: _doNotRemindAfter != null ? AppColors.gold : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.editingLocation != null ? S.of('save_changes') : S.of('save_location'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.gold,
        ),
      ],
    );
  }
}
