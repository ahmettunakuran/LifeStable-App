import 'dart:convert';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceInputButton extends StatefulWidget {
  final bool isListening;
  final void Function(bool) onListeningChanged;
  final void Function(String) onTranscriptionReady;

  const VoiceInputButton({
    super.key,
    required this.isListening,
    required this.onListeningChanged,
    required this.onTranscriptionReady,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

enum _Phase { idle, recording, transcribing }

class _VoiceInputButtonState extends State<VoiceInputButton> {
  static const _whisperUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _whisperModel = 'whisper-large-v3-turbo';

  final AudioRecorder _recorder = AudioRecorder();
  _Phase _phase = _Phase.idle;
  String? _currentPath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_phase == _Phase.transcribing) return;

    if (_phase == _Phase.recording) {
      await _stopAndTranscribe();
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _snack('Microphone permission is required.');
      return;
    }

    if (!await _recorder.hasPermission()) {
      _snack('Microphone is not available on this device.');
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 32000,
        ),
        path: path,
      );
      setState(() {
        _phase = _Phase.recording;
        _currentPath = path;
      });
      widget.onListeningChanged(true);
    } catch (e) {
      _snack('Could not start recording: $e');
      _resetState();
    }
  }

  Future<void> _stopAndTranscribe() async {
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _currentPath;
    }
    path ??= _currentPath;

    if (path == null) {
      _resetState();
      return;
    }

    setState(() => _phase = _Phase.transcribing);

    final apiKey =
        FirebaseRemoteConfig.instance.getString('groq_api_key');
    debugPrint('[Whisper] file=$path size=${await File(path).length()} '
        'keyLen=${apiKey.length}');
    if (apiKey.isEmpty) {
      _snack('Voice transcription is unavailable: API key missing.');
      await _safeDelete(path);
      _resetState();
      widget.onListeningChanged(false);
      return;
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_whisperUrl))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = _whisperModel
        ..fields['response_format'] = 'json'
        ..files.add(await http.MultipartFile.fromPath('file', path));

      debugPrint('[Whisper] sending request to $_whisperUrl');
      final streamed = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamed);
      debugPrint('[Whisper] status=${response.statusCode} '
          'body=${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (body['text'] as String?)?.trim() ?? '';
        // Whisper returns punctuation-only strings (e.g. "." or "...") for
        // silent input. Require at least one letter/digit before sending on.
        final hasContent = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);
        if (hasContent) {
          widget.onTranscriptionReady(text);
        } else {
          _snack('No speech detected — check microphone.');
        }
      } else {
        _snack('Transcription failed (${response.statusCode}).');
      }
    } catch (e) {
      debugPrint('[Whisper] error: $e');
      _snack('Transcription error: $e');
    } finally {
      await _safeDelete(path);
      _resetState();
      widget.onListeningChanged(false);
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _resetState() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _currentPath = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = _phase == _Phase.recording;
    final transcribing = _phase == _Phase.transcribing;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording
              ? Colors.red.withOpacity(0.15)
              : Colors.transparent,
          border: recording
              ? Border.all(color: Colors.red.withOpacity(0.4))
              : null,
        ),
        child: transcribing
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : Icon(
                recording ? Icons.mic : Icons.mic_none_rounded,
                color: recording
                    ? Colors.red
                    : Colors.white.withOpacity(0.4),
                size: 22,
              ),
      ),
    );
  }
}