import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/geofence_logger.dart';
import '../../../shared/constants/app_colors.dart';
import '../data/geofence_service.dart';

class BatteryReportScreen extends StatelessWidget {
  const BatteryReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Battery & Efficiency Report',
          style: TextStyle(color: AppColors.gold),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: FutureBuilder<List<GeofenceLogEntry>>(
        future: GeofenceLogger.instance.fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.gold));
          }
          final logs = snapshot.data ?? [];
          return _ReportBody(logs: logs);
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final List<GeofenceLogEntry> logs;
  const _ReportBody({required this.logs});

  int get _sentCount => logs.where((l) => l.notificationSent).length;
  int get _skippedCount => logs.length - _sentCount;

  double get _avgPerDay {
    if (logs.isEmpty) return 0;
    return logs.length / 7.0;
  }

  Map<String, int> get _skipReasons {
    final map = <String, int>{};
    for (final l in logs.where((l) => !l.notificationSent)) {
      final reason = l.skippedReason ?? 'unknown';
      map[reason] = (map[reason] ?? 0) + 1;
    }
    return map;
  }

  int get _registeredCount =>
      AppGeofenceService.instance.registeredModels.length;

  void _export(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('LifeStable — Geofence Battery Report');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');
    buffer.writeln('Registered geofences: $_registeredCount');
    buffer.writeln('Total triggers (7 days): ${logs.length}');
    buffer.writeln('Notifications sent: $_sentCount');
    buffer.writeln('Notifications skipped: $_skippedCount');
    buffer.writeln(
        'Average triggers/day: ${_avgPerDay.toStringAsFixed(1)}');
    if (_skipReasons.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Skip reasons:');
      for (final e in _skipReasons.entries) {
        buffer.writeln('  ${e.key}: ${e.value}');
      }
    }
    buffer.writeln('');
    buffer.writeln(
        'Battery note: OS-native geofencing only. No continuous GPS polling.');

    SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsGrid(
            registered: _registeredCount,
            total: logs.length,
            sent: _sentCount,
            skipped: _skippedCount,
            avgPerDay: _avgPerDay,
          ),
          const SizedBox(height: 16),
          _BatteryNoteCard(),
          const SizedBox(height: 16),
          if (_skipReasons.isNotEmpty) ...[
            _SkipReasonsCard(reasons: _skipReasons),
            const SizedBox(height: 16),
          ],
          const _SectionLabel('RECENT ACTIVITY'),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text(
              'No triggers in the last 7 days.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, i) => _LogTile(entry: logs[i]),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _export(context),
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: AppColors.gold, width: 1.5),
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Export Summary'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int registered;
  final int total;
  final int sent;
  final int skipped;
  final double avgPerDay;

  const _StatsGrid({
    required this.registered,
    required this.total,
    required this.sent,
    required this.skipped,
    required this.avgPerDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Geofences', registered.toString()),
              _Stat('7-Day Triggers', total.toString()),
              _Stat('Avg/Day', avgPerDay.toStringAsFixed(1)),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Sent', sent.toString(),
                  color: Colors.greenAccent),
              _Stat('Skipped', skipped.toString(),
                  color: Colors.orangeAccent),
              const _Stat('Battery', 'Low',
                  color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _BatteryNoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.battery_saver_outlined,
              color: Colors.greenAccent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using OS-native geofencing. No continuous GPS polling.',
              style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipReasonsCard extends StatelessWidget {
  final Map<String, int> reasons;
  const _SkipReasonsCard({required this.reasons});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SKIP REASONS',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...reasons.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                  Text(e.value.toString(),
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final GeofenceLogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isEnter = entry.eventType == GeofenceEventType.enter;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isEnter ? Icons.location_on : Icons.location_off,
        color: isEnter ? Colors.greenAccent : Colors.orangeAccent,
        size: 20,
      ),
      title: Text(
        isEnter ? 'Entered Zone' : 'Exited Zone',
        style:
            const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        entry.triggeredAt.toString().substring(0, 16),
        style:
            const TextStyle(color: Colors.white24, fontSize: 11),
      ),
      trailing: Icon(
        entry.notificationSent
            ? Icons.check_circle_outline
            : Icons.notifications_off_outlined,
        color: entry.notificationSent
            ? AppColors.gold
            : Colors.white10,
        size: 18,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          letterSpacing: 1.2),
    );
  }
}
