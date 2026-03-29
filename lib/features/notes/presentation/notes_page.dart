import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _notesRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User not signed in');
    }
    return _db.collection('users').doc(uid).collection('notes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _domainsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(uid).collection('domains').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notesStream() {
    return _notesRef.orderBy('updatedAt', descending: true).snapshots();
  }

  Future<void> _upsertNote({
    String? noteId,
    required String domainId,
    required String title,
    required String content,
  }) async {
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'domainId': domainId,
      'title': title,
      'content': content,
      'updatedAt': now,
      if (noteId == null) 'createdAt': now,
    };

    if (noteId == null) {
      await _notesRef.add(payload);
    } else {
      await _notesRef.doc(noteId).update(payload);
    }
  }

  Future<void> _deleteNote(String noteId) => _notesRef.doc(noteId).delete();

  Future<void> _showNoteDialog({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> domains,
    QueryDocumentSnapshot<Map<String, dynamic>>? note,
  }) async {
    final titleController = TextEditingController(
      text: note?.data()['title'] as String? ?? '',
    );
    final contentController = TextEditingController(
      text: note?.data()['content'] as String? ?? '',
    );
    String? selectedDomainId = note?.data()['domainId'] as String?;
    selectedDomainId ??= domains.isNotEmpty ? domains.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(note == null ? 'Add Note' : 'Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDomainId,
                  isExpanded: true,
                  items: domains
                      .map(
                        (domain) => DropdownMenuItem<String>(
                          value: domain.id,
                          child: Text(
                            (domain.data()['name'] as String?) ?? 'Unnamed',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    selectedDomainId = value;
                  }),
                  decoration: const InputDecoration(labelText: 'Domain'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedDomainId == null ||
                    titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  return;
                }
                await _upsertNote(
                  noteId: note?.id,
                  domainId: selectedDomainId!,
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to use notes.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _domainsStream,
        builder: (context, domainsSnapshot) {
          final domains = domainsSnapshot.data?.docs ?? [];
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notesStream(),
            builder: (context, notesSnapshot) {
              if (notesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final notes = notesSnapshot.data?.docs ?? [];
              if (notes.isEmpty) {
                return const Center(child: Text('No notes yet.'));
              }

              return ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final data = note.data();
                  return ListTile(
                    title: Text((data['title'] as String?) ?? ''),
                    subtitle: Text(
                      (data['content'] as String?) ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _showNoteDialog(domains: domains, note: note),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteNote(note.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _domainsStream,
        builder: (context, snapshot) {
          final domains = snapshot.data?.docs ?? [];
          return FloatingActionButton(
            onPressed: domains.isEmpty
                ? null
                : () => _showNoteDialog(domains: domains),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
