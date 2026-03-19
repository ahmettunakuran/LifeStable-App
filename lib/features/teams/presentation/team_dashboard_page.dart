import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamDashboardPage extends StatefulWidget {
  const TeamDashboardPage({super.key});

  @override
  State<TeamDashboardPage> createState() => _TeamDashboardPageState();
}

class _TeamDashboardPageState extends State<TeamDashboardPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _teamsRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User not signed in');
    }
    return _db.collection('users').doc(uid).collection('teams');
  }

  Future<void> _addTeamDialog() async {
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Team'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Team Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await _teamsRef.add({
                'name': name,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTeam(String teamId) => _teamsRef.doc(teamId).delete();

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to access teams.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Dashboard'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTeamDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _teamsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teams = snapshot.data?.docs ?? [];
          if (teams.isEmpty) {
            return const Center(child: Text('No teams yet. Tap + to create one.'));
          }
          return ListView.separated(
            itemCount: teams.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final team = teams[index];
              final data = team.data();
              return ListTile(
                title: Text((data['name'] as String?) ?? 'Unnamed team'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteTeam(team.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

