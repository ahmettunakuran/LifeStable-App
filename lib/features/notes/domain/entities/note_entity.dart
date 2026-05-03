import 'package:cloud_firestore/cloud_firestore.dart';

class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.userId,
    required this.domainId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String domainId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteEntity copyWith({
    String? domainId,
    String? title,
    String? content,
    DateTime? updatedAt,
  }) =>
      NoteEntity(
        id: id,
        userId: userId,
        domainId: domainId ?? this.domainId,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'domainId': domainId,
        'title': title,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory NoteEntity.fromFirestore(String id, Map<String, dynamic> data) =>
      NoteEntity(
        id: id,
        userId: data['userId'] as String? ?? '',
        domainId: data['domainId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
