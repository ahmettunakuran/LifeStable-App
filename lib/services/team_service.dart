import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class TeamService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Domain Mirroring Helpers ───────────────────────────────

  /// Creates a mirrored domain in the user's personal domain list for a team.
  Future<void> _createMirrorDomain({
    required String userId,
    required String teamId,
    required String teamName,
    int? teamColor,
  }) async {
    final domainRef = _db
        .collection('users')
        .doc(userId)
        .collection('domains')
        .doc('team_$teamId'); // deterministic ID based on teamId

    final colorHex = '#${(teamColor ?? 0xFF1A237E).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    await domainRef.set({
      'name': teamName,
      'description': 'Team domain – $teamName',
      'iconCode': 0xe7ef, // Icons.group (Material Icons codepoint)
      'colorHex': colorHex,
      'teamId': teamId,
    });
  }

  /// Deletes the mirrored domain for a team from a user's personal domain list.
  Future<void> _deleteMirrorDomain({
    required String userId,
    required String teamId,
  }) async {
    final domainRef = _db
        .collection('users')
        .doc(userId)
        .collection('domains')
        .doc('team_$teamId');

    await domainRef.delete();
  }


  Future<String> createTeam(String name, String objective, {int? color}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final inviteCode = _generateInviteCode();
    final teamRef = _db.collection('teams').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(teamRef, {
        'team_id': teamRef.id,
        'name': name,
        'objective': objective,
        'created_by': user.uid,
        'created_at': FieldValue.serverTimestamp(),
        'invite_code': inviteCode,
        'color': color ?? 0xFF1A237E,
        'member_count': 1,
      });

      final memberRef = _db.collection('team_members').doc();
      transaction.set(memberRef, {
        'team_id': teamRef.id,
        'user_id': user.uid,
        'role': 'owner',
        'joined_at': FieldValue.serverTimestamp(),
      });
    });

    // Domain Mirroring: auto-create a domain for the creator
    await _createMirrorDomain(
      userId: user.uid,
      teamId: teamRef.id,
      teamName: name,
      teamColor: color,
    );

    return inviteCode;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> joinTeamWithCode(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final query = await _db
        .collection('teams')
        .where('invite_code', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Invalid invite code.');

    final teamDoc = query.docs.first;
    final teamId = teamDoc.id;

    final existing = await _db
        .collection('team_members')
        .where('team_id', isEqualTo: teamId)
        .where('user_id', isEqualTo: user.uid)
        .get();

    if (existing.docs.isNotEmpty) throw Exception('You are already a member.');

    final batch = _db.batch();

    final memberRef = _db.collection('team_members').doc();
    batch.set(memberRef, {
      'team_id': teamId,
      'user_id': user.uid,
      'role': 'member',
      'joined_at': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('teams').doc(teamId), {
      'member_count': FieldValue.increment(1),
    });

    await batch.commit();

    // Domain Mirroring: auto-create a domain for the joining user
    final teamData = teamDoc.data() as Map<String, dynamic>?;
    await _createMirrorDomain(
      userId: user.uid,
      teamId: teamId,
      teamName: teamData?['name'] as String? ?? 'Team',
      teamColor: teamData?['color'] as int?,
    );
  }

  Future<List<Map<String, dynamic>>> getUserTeams() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final memberDocs = await _db
        .collection('team_members')
        .where('user_id', isEqualTo: user.uid)
        .get();

    if (memberDocs.docs.isEmpty) return [];

    final teamIds = memberDocs.docs
        .map((doc) => doc['team_id'] as String)
        .toList();

    final teamDocs = await _db
        .collection('teams')
        .where('team_id', whereIn: teamIds)
        .get();

    return teamDocs.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateMemberRole(
      String teamId,
      String targetUserId,
      String newRole,
      ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final callerDoc = await _getMyMembership(teamId);
    final callerRole = callerDoc?.data()?['role'] as String?;

    if (callerRole != 'owner' && callerRole != 'admin') {
      throw Exception('Permission denied.');
    }

    if (newRole == 'owner' && callerRole != 'owner') {
      throw Exception('Only owner can transfer ownership.');
    }

    final targetDoc = await _getMembership(teamId, targetUserId);
    if (targetDoc == null) throw Exception('Member not found.');

    final batch = _db.batch();

    if (newRole == 'owner') {
      final myMembership = await _getMyMembership(teamId);
      if (myMembership != null) {
        batch.update(myMembership.reference, {'role': 'admin'});
      }
      batch.update(_db.collection('teams').doc(teamId), {
        'created_by': targetUserId,
      });
    }

    batch.update(targetDoc.reference, {'role': newRole});
    await batch.commit();
  }

  Future<void> removeMember(String teamId, String targetUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final callerDoc = await _getMyMembership(teamId);
    final callerRole = callerDoc?.data()?['role'] as String?;

    if (callerRole != 'owner' && callerRole != 'admin') {
      throw Exception('Permission denied.');
    }

    final targetDoc = await _getMembership(teamId, targetUserId);
    if (targetDoc == null) throw Exception('Member not found.');

    final targetRole = targetDoc.data()?['role'] as String?;

    if (callerRole == 'admin' && targetRole == 'owner') {
      throw Exception('Admins cannot remove the owner.');
    }

    final batch = _db.batch();
    batch.delete(targetDoc.reference);
    batch.update(_db.collection('teams').doc(teamId), {
      'member_count': FieldValue.increment(-1),
    });
    await batch.commit();

    // Domain Mirroring: remove the mirrored domain for the removed user
    await _deleteMirrorDomain(userId: targetUserId, teamId: teamId);
  }

  Future<void> leaveTeam(String teamId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final myDoc = await _getMyMembership(teamId);
    if (myDoc == null) throw Exception('You are not a member.');

    final myRole = myDoc.data()?['role'] as String?;

    final allMembers = await _db
        .collection('team_members')
        .where('team_id', isEqualTo: teamId)
        .get();

    final otherMembers = allMembers.docs
        .where((d) => (d.data())['user_id'] != user.uid)
        .toList();

    if (otherMembers.isEmpty) {
      await deleteTeam(teamId);
      return;
    }

    final batch = _db.batch();

    if (myRole == 'owner') {
      final admins = otherMembers.where((d) {
        final role = (d.data())['role'] as String?;
        return role == 'admin';
      }).toList();

      final DocumentSnapshot newOwnerDoc =
      admins.isNotEmpty ? admins.first : otherMembers.first;

      batch.update(newOwnerDoc.reference, {'role': 'owner'});
      batch.update(_db.collection('teams').doc(teamId), {
        'created_by': (newOwnerDoc.data() as Map<String, dynamic>)['user_id'],
      });
    }

    if (myRole == 'admin') {
      final remainingAdmins = otherMembers.where((d) {
        final role = (d.data())['role'] as String?;
        return role == 'admin' || role == 'owner';
      }).toList();

      if (remainingAdmins.isEmpty) {
        batch.update(otherMembers.first.reference, {'role': 'admin'});
      }
    }

    batch.delete(myDoc.reference);
    batch.update(_db.collection('teams').doc(teamId), {
      'member_count': FieldValue.increment(-1),
    });

    await batch.commit();

    // Domain Mirroring: remove the mirrored domain for the leaving user
    await _deleteMirrorDomain(userId: user.uid, teamId: teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final myDoc = await _getMyMembership(teamId);
    final myRole = myDoc?.data()?['role'] as String?;

    if (myRole != 'owner' && myRole != 'admin') {
      throw Exception('Only owner or admin can delete the team.');
    }

    final members = await _db
        .collection('team_members')
        .where('team_id', isEqualTo: teamId)
        .get();

    // Domain Mirroring: remove mirrored domains for ALL team members
    final mirrorBatch = _db.batch();
    for (final doc in members.docs) {
      final memberId = doc.data()['user_id'] as String;
      final domainRef = _db
          .collection('users')
          .doc(memberId)
          .collection('domains')
          .doc('team_$teamId');
      mirrorBatch.delete(domainRef);
    }
    await mirrorBatch.commit();

    final batch = _db.batch();
    for (final doc in members.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('teams').doc(teamId));
    await batch.commit();
  }

  Future<String> regenerateInviteCode(String teamId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final myDoc = await _getMyMembership(teamId);
    final myRole = myDoc?.data()?['role'] as String?;

    if (myRole != 'owner' && myRole != 'admin') {
      throw Exception('Permission denied.');
    }

    final newCode = _generateInviteCode();
    await _db.collection('teams').doc(teamId).update({
      'invite_code': newCode,
    });
    return newCode;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getMyMembership(
      String teamId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getMembership(teamId, user.uid);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getMembership(
      String teamId, String userId) async {
    final query = await _db
        .collection('team_members')
        .where('team_id', isEqualTo: teamId)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }
}