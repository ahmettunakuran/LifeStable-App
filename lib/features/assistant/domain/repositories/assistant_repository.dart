import '../entities/chat_message.dart';

abstract class AssistantRepository {
  Future<String> sendMessage(String message, List<ChatMessage> history);
  Future<String> transcribeAudio(String audioPath);
}