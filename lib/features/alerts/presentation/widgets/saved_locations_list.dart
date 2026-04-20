import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/constants/app_colors.dart';
import '../../domain/entities/location_entity.dart';
import '../../logic/location_cubit.dart';
import '../../logic/location_state.dart';
import 'add_location_bottom_sheet.dart';

class SavedLocationsList extends StatelessWidget {
  const SavedLocationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        if (state.status == LocationStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        if (state.status == LocationStatus.error) {
          return Center(
            child: Text(
              state.errorMessage ?? 'An error occurred.',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (state.locations.isEmpty) {
          return const Center(
            child: Text(
              'No saved locations yet.\nTap the map to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.locations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final location = state.locations[index];
            return _LocationTile(location: location);
          },
        );
      },
    );
  }
}

class _LocationTile extends StatelessWidget {
  final LocationEntity location;

  const _LocationTile({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on, color: AppColors.gold, size: 20),
        ),
        title: Text(
          location.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _badge('${location.radiusM} m', Colors.blueAccent),
                const SizedBox(width: 6),
                if (location.geofenceOnEnter) _badge('On Arrival', Colors.greenAccent),
                if (location.geofenceOnEnter && location.geofenceOnExit) const SizedBox(width: 6),
                if (location.geofenceOnExit) _badge('On Leave', Colors.orangeAccent),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.gold, size: 20),
              onPressed: () => AddLocationBottomSheet.show(
                context,
                editingLocation: location,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(context, location),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LocationEntity location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Location', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${location.label}" from saved locations?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<LocationCubit>().deleteLocation(location.locationId);
    }
  }
}
