import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/data/external_sync/google_calendar_sync_service.dart';
import '../../calendar/data/external_sync/google_external_account_entity.dart';
import '../data/user_preferences_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GoogleCalendarSyncService _syncService = GoogleCalendarSyncService();
  final UserPreferencesService _prefsService = UserPreferencesService();

  bool _busy = false;

  Future<void> _connectGoogle() async {
    try {
      setState(() => _busy = true);

      final authUrl = await _syncService.getConnectUrl();
      final uri = Uri.parse(authUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Google sign-in page.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Browser opened. After approving access, return to the app.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _syncGoogle() async {
    try {
      setState(() => _busy = true);

      final result = await _syncService.syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync complete • Created: ${result.created}, Updated: ${result.updated}, Deleted: ${result.deleted}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar'),
        content: const Text(
          'This removes the Google connection and sync mappings. Imported events already in LifeStable will stay unless you delete them manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _busy = true);
      await _syncService.disconnect();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Calendar disconnected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd MMM yyyy • HH:mm').format(value);
  }

  Widget _buildGoogleCard(GoogleExternalAccountEntity? account) {
    final isConnected = account != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Google Calendar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(isConnected ? 'Connected' : 'Not connected'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isConnected
                  ? 'Connected account: ${account.providerUserId}'
                  : 'Connect your Google Calendar to import events into LifeStable.',
            ),
            const SizedBox(height: 8),
            Text('Connected at: ${_formatDate(account?.connectedAt)}'),
            Text('Last sync: ${_formatDate(account?.lastSyncAt)}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!isConnected)
                  FilledButton.icon(
                    onPressed: _busy ? null : _connectGoogle,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                if (isConnected)
                  FilledButton.icon(
                    onPressed: _busy ? null : _syncGoogle,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                if (isConnected)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _disconnectGoogle,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return StreamBuilder<UserPreferences>(
      stream: _prefsService.watch(),
      builder: (context, snapshot) {
        final prefs = snapshot.data ?? const UserPreferences();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tune),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Scheduling Preferences',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These guide the assistant when proposing free slots and detecting overload.',
                ),
                const SizedBox(height: 12),
                _hourRangeTile(
                  label: 'Working hours',
                  fromValue: prefs.workStartHour,
                  toValue: prefs.workEndHour,
                  onChanged: (start, end) => _prefsService.save(
                    prefs.copyWith(workStartHour: start, workEndHour: end),
                  ),
                ),
                _hourRangeTile(
                  label: 'Sleep window',
                  fromValue: prefs.sleepStartHour,
                  toValue: prefs.sleepEndHour,
                  onChanged: (start, end) => _prefsService.save(
                    prefs.copyWith(sleepStartHour: start, sleepEndHour: end),
                  ),
                ),
                _minutesTile(
                  label: 'Focus block (minutes)',
                  value: prefs.focusBlockMinutes,
                  options: const [25, 45, 60, 90, 120],
                  onChanged: (v) => _prefsService.save(prefs.copyWith(focusBlockMinutes: v)),
                ),
                _minutesTile(
                  label: 'Break (minutes)',
                  value: prefs.breakMinutes,
                  options: const [5, 10, 15, 20, 30],
                  onChanged: (v) => _prefsService.save(prefs.copyWith(breakMinutes: v)),
                ),
                _minutesTile(
                  label: 'Daily max scheduled (minutes)',
                  value: prefs.dailyMaxScheduledMinutes,
                  options: const [240, 360, 480, 600, 720],
                  onChanged: (v) => _prefsService.save(prefs.copyWith(dailyMaxScheduledMinutes: v)),
                ),
                if (prefs.acceptedSlotHours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Learned: prefers slots near ${prefs.topPreferredHours().map((h) => "${h.toString().padLeft(2, '0')}:00").join(", ")}',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hourRangeTile({
    required String label,
    required int fromValue,
    required int toValue,
    required void Function(int start, int end) onChanged,
  }) {
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int>(
            value: fromValue,
            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(fmt(i)))),
            onChanged: (v) => v == null ? null : onChanged(v, toValue),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('—')),
          DropdownButton<int>(
            value: toValue,
            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(fmt(i)))),
            onChanged: (v) => v == null ? null : onChanged(fromValue, v),
          ),
        ],
      ),
    );
  }

  Widget _minutesTile({
    required String label,
    required int value,
    required List<int> options,
    required void Function(int) onChanged,
  }) {
    final safeValue = options.contains(value) ? value : options.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int>(
            value: safeValue,
            items: options
                .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                .toList(),
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: StreamBuilder<GoogleExternalAccountEntity?>(
        stream: _syncService.watchGoogleConnection(),
        builder: (context, snapshot) {
          final account = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Calendar Sync',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This MVP imports events from Google Calendar into your LifeStable calendar.',
              ),
              const SizedBox(height: 16),
              _buildGoogleCard(account),
              const SizedBox(height: 24),
              const Text(
                'Personalization',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _buildPreferencesCard(),
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }
}