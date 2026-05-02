import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../calendar/data/external_sync/google_calendar_sync_service.dart';
import '../../calendar/data/external_sync/google_external_account_entity.dart';

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
          SnackBar(content: Text(S.of('could_not_open_google'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of('browser_opened'),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('connect_failed', args: {'error': e.toString()}))),
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
            '${S.of('sync_complete')} • ${S.of('created')}: ${result.created}, ${S.of('updated')}: ${result.updated}, ${S.of('deleted')}: ${result.deleted}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('sync_failed', args: {'error': e.toString()}))),
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
        title: Text(S.of('disconnect_confirm_title')),
        content: Text(S.of('disconnect_confirm_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of('cancel')),
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
        SnackBar(content: Text('${S.of('google_calendar')} ${S.of('disconnected')}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of('disconnect_failed', args: {'error': e.toString()}))),
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
                Expanded(
                  child: Text(
                    S.of('google_calendar'),
                    style: const TextStyle(
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
                  ? '${S.of('connected')} ${S.of('account')}: ${account.providerUserId}'
                  : S.of('google_calendar_desc'),
            ),
            const SizedBox(height: 8),
            Text(S.of('connected_at', args: {'date': _formatDate(account?.connectedAt)})),
            Text(S.of('last_sync', args: {'date': _formatDate(account?.lastSyncAt)})),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(S.of('settings')),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(child: LanguageSwitcher()),
              ),
            ],
          ),
          body: StreamBuilder<GoogleExternalAccountEntity?>(
            stream: _syncService.watchGoogleConnection(),
            builder: (context, snapshot) {
              final account = snapshot.data;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    S.of('calendar_sync'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.of('settings_desc'),
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