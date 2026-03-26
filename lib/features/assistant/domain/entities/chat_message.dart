import 'package:uuid/uuid.dart';

enum MessageSender { user, assistant }

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    String? id,
    required this.content,
    required this.sender,
    DateTime? timestamp,
    this.isLoading = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({String? content, bool? isLoading}) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      sender: sender,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}