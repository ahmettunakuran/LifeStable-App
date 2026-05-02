import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/data/external_sync/google_calendar_sync_service.dart';
import '../../calendar/data/external_sync/google_external_account_entity.dart';
import '../../../core/localization/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GoogleCalendarSyncService _syncService = GoogleCalendarSyncService();

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
        title: Text(S.of('disconnect')),
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
            child: Text(S.of('disconnect')),
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
                  label: Text(isConnected ? S.of('connected') : S.of('not_connected')),
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
                    label: Text(S.of('connect')),
                  ),
                if (isConnected)
                  FilledButton.icon(
                    onPressed: _busy ? null : _syncGoogle,
                    icon: const Icon(Icons.sync),
                    label: Text(S.of('sync_now')),
                  ),
                if (isConnected)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _disconnectGoogle,
                    icon: const Icon(Icons.link_off),
                    label: Text(S.of('disconnect')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 10),
                Text(
                  S.of('language'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Locale>(
              valueListenable: localeNotifier,
              builder: (context, locale, _) {
                return Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(S.of('english')),
                      value: 'en',
                      groupValue: locale.languageCode,
                      activeColor: const Color(0xFFC9A84C),
                      onChanged: (val) {
                        if (val != null) S.setLocale(Locale(val));
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(S.of('turkish')),
                      value: 'tr',
                      groupValue: locale.languageCode,
                      activeColor: const Color(0xFFC9A84C),
                      onChanged: (val) {
                        if (val != null) S.setLocale(Locale(val));
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(S.of('settings')),
          ),
          body: StreamBuilder<GoogleExternalAccountEntity?>(
            stream: _syncService.watchGoogleConnection(),
            builder: (context, snapshot) {
              final account = snapshot.data;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    S.of('language'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageCard(),
                  const SizedBox(height: 24),
                  Text(
                    S.of('calendar_sync'),
                    style: const TextStyle(
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
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}