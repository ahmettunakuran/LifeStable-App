import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _initialized = await _speech.initialize(
      onError: (_) => widget.onListeningChanged(false),
    );
  }

  Future<void> _handleTap() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!_initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (widget.isListening) {
      await _speech.stop();
      widget.onListeningChanged(false);
    } else {
      widget.onListeningChanged(true);
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            widget.onListeningChanged(false);
            widget.onTranscriptionReady(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isListening
              ? Colors.red.withOpacity(0.15)
              : Colors.transparent,
          border: widget.isListening
              ? Border.all(color: Colors.red.withOpacity(0.4))
              : null,
        ),
        child: Icon(
          widget.isListening ? Icons.mic : Icons.mic_none_rounded,
          color: widget.isListening
              ? Colors.red
              : Colors.white.withOpacity(0.4),
          size: 22,
        ),
      ),
    );
  }
}