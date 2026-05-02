import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/note_repository_impl.dart';
import '../domain/entities/note_entity.dart';
import '../logic/notes_cubit.dart';
import '../logic/notes_state.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotesCubit(
        NoteRepositoryImpl(FirebaseFirestore.instance),
      )..init(),
      child: const _NotesView(),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView();

  Stream<QuerySnapshot<Map<String, dynamic>>> _domainsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('domains')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Scaffold(
        body: Center(child: Text(S.of('please_sign_in_notes'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(S.of('notes'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _domainsStream(),
        builder: (context, domainsSnapshot) {
          final domains = domainsSnapshot.data?.docs ?? [];

          return BlocBuilder<NotesCubit, NotesState>(
            builder: (context, state) {
              if (state is NotesLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is NotesError) {
                return Center(child: Text(state.message));
              }
              final notes = (state as NotesLoaded).notes;
              if (notes.isEmpty) {
                return Center(child: Text(S.of('no_notes_yet')));
              }
              return ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return ListTile(
                    title: Text(note.title),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        _showNoteDialog(context, domains: domains, note: note),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          context.read<NotesCubit>().deleteNote(note.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _domainsStream(),
        builder: (context, snapshot) {
          final domains = snapshot.data?.docs ?? [];
          return FloatingActionButton(
            onPressed: domains.isEmpty
                ? null
                : () => _showNoteDialog(context, domains: domains),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Future<void> _showNoteDialog(
    BuildContext context, {
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> domains,
    NoteEntity? note,
  }) async {
    final cubit = context.read<NotesCubit>();
    final titleCtrl =
        TextEditingController(text: note?.title ?? '');
    final contentCtrl =
        TextEditingController(text: note?.content ?? '');
    String selectedDomainId =
        note?.domainId ?? (domains.isNotEmpty ? domains.first.id : '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(note == null ? S.of('add_note') : S.of('edit_note')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDomainId.isEmpty ? null : selectedDomainId,
                  isExpanded: true,
                  items: domains
                      .map((d) => DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(
                                (d.data()['name'] as String?) ?? S.of('unnamed')),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedDomainId = v ?? ''),
                  decoration: InputDecoration(labelText: S.of('domain')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: S.of('title')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: S.of('content')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (selectedDomainId.isEmpty ||
                    title.isEmpty ||
                    content.isEmpty) return;

                if (note == null) {
                  await cubit.createNote(
                    domainId: selectedDomainId,
                    title: title,
                    content: content,
                  );
                } else {
                  await cubit.updateNote(note.copyWith(
                    domainId: selectedDomainId,
                    title: title,
                    content: content,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(S.of('save')),
            ),
          ],
        ),
      ),
    );
  }
}
