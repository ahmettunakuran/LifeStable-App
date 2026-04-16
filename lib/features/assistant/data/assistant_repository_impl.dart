import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import '../domain/entities/chat_message.dart';
import '../domain/repositories/assistant_repository.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  @override
  Future<String> sendMessage(
      String message,
      List<ChatMessage> history,
      ) async {
    try {
      final apiKey = _remoteConfig.getString('gemini_api_key');
      if (apiKey.isEmpty) return "API Key not found in Remote Config.";

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            ...history.map((m) => {
              "role": m.sender == MessageSender.user ? "user" : "model",
              "parts": [{"text": m.content}]
            }),
            {
              "role": "user",
              "parts": [{"text": message}]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.8,
            "topK": 40,
            "maxOutputTokens": 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "AI Connection Error: $e";
    }
  }

  @override
  Future<String> transcribeAudio(String audioPath) async {
    // TODO: Task 5.2 — Whisper API bağlantısı
    await Future.delayed(const Duration(milliseconds: 500));
    return '';
  }
}