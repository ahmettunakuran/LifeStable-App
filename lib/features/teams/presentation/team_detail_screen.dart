import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_lifestable/services/team_service.dart';
import '../../../core/localization/app_localizations.dart';

class TeamDetailScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final _teamService = TeamService();
  final _db = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;
  String? _inviteCode;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
    _loadCurrentUsername();
  }

  Future<void> _loadTeamData() async {
    final doc = await _db.collection('teams').doc(widget.teamId).get();
    if (mounted) {
      setState(() {
        _inviteCode = doc.data()?['invite_code'] as String?;
      });
    }
  }

  Future<void> _loadCurrentUsername() async {
    if (_currentUser == null) return;
    try {
      final doc =
      await _db.collection('users').doc(_currentUser!.uid).get();
      final data = doc.data();
      if (data != null) {
        final name = data['displayName'] as String?;
        if (name != null && name.isNotEmpty) {
          if (mounted) setState(() => _currentUsername = name);
          return;
        }
      }
    } catch (_) {}
    final displayName = _currentUser!.displayName;
    final email = _currentUser!.email ?? '';
    if (mounted) {
      setState(() {
        _currentUsername = displayName?.isNotEmpty == true
            ? displayName!
            : email.split('@').first;
      });
    }
  }

  Future<String> _getUsernameForId(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null) {
        final name = data['displayName'] as String?;
        if (name != null && name.isNotEmpty) return name;
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) return email.split('@').first;
      }
    } catch (_) {}
    return userId.length > 8 ? userId.substring(0, 8) : userId;
  }

  Stream<QuerySnapshot> get _membersStream => _db
      .collection('team_members')
      .where('team_id', isEqualTo: widget.teamId)
      .snapshots();

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Kurucu';
      case 'admin':
        return 'Yönetici';
      default:
        return 'Üye';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return AppColors.gold;
      case 'admin':
        return Colors.blueAccent;
      default:
        return Colors.white38;
    }
  }

  void _copyInviteCode() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite code copied!'),
        backgroundColor: AppColors.goldDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _regenerateCode() async {
    try {
      final newCode =
      await _teamService.regenerateInviteCode(widget.teamId);
      setState(() => _inviteCode = newCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New invite code generated!'),
          backgroundColor: AppColors.goldDark,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _leaveTeam() async {
    final confirm = await _showConfirmDialog(
      title: 'Leave Team',
      message: 'Are you sure you want to leave this team?',
      confirmLabel: 'Leave',
      confirmColor: Colors.redAccent,
    );
    if (!confirm) return;

    try {
      await _teamService.leaveTeam(widget.teamId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteTeam() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Team',
      message:
      'This will permanently delete the team and remove all members. Are you sure?',
      confirmLabel: 'Delete',
      confirmColor: Colors.redAccent,
    );
    if (!confirm) return;

    try {
      await _teamService.deleteTeam(widget.teamId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1500),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: TextStyle(color: Colors.white.withOpacity(0.65))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMemberOptions(
      BuildContext context,
      String targetUserId,
      String targetRole,
      String myRole,
      ) {
    final isMe = targetUserId == _currentUser?.uid;
    final canManage =
        (myRole == 'owner' || myRole == 'admin') && !isMe;
    final canRemove =
        canManage && !(myRole == 'admin' && targetRole == 'owner');
    final canMakeAdmin =
        myRole == 'owner' && targetRole == 'member';
    final canDemote = myRole == 'owner' && targetRole == 'admin';
    final canTransfer = myRole == 'owner' && !isMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1500),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Member Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (canMakeAdmin)
              _bottomSheetTile(
                ctx,
                icon: Icons.shield,
                color: Colors.blueAccent,
                label: 'Make Admin',
                onTap: () async {
                  await _teamService.updateMemberRole(
                      widget.teamId, targetUserId, 'admin');
                },
              ),
            if (canDemote)
              _bottomSheetTile(
                ctx,
                icon: Icons.person,
                color: Colors.white54,
                label: 'Remove Admin',
                onTap: () async {
                  await _teamService.updateMemberRole(
                      widget.teamId, targetUserId, 'member');
                },
              ),
            if (canTransfer)
              _bottomSheetTile(
                ctx,
                icon: Icons.star,
                color: AppColors.gold,
                label: 'Transfer Ownership',
                onTap: () async {
                  final confirm = await _showConfirmDialog(
                    title: 'Transfer Ownership',
                    message:
                    'You will become an admin. The selected user will become the new owner.',
                    confirmLabel: 'Transfer',
                    confirmColor: AppColors.gold,
                  );
                  if (confirm) {
                    await _teamService.updateMemberRole(
                        widget.teamId, targetUserId, 'owner');
                  }
                },
              ),
            if (canRemove)
              _bottomSheetTile(
                ctx,
                icon: Icons.person_remove,
                color: Colors.redAccent,
                label: 'Remove from Team',
                onTap: () async {
                  await _teamService.removeMember(
                      widget.teamId, targetUserId);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _bottomSheetTile(
      BuildContext ctx, {
        required IconData icon,
        required Color color,
        required String label,
        required Future<void> Function() onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () async {
        Navigator.pop(ctx);
        try {
          await onTap();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text(
          widget.teamName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A1200),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _membersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error: ${snapshot.error}',
                      style:
                      TextStyle(color: Colors.white.withOpacity(0.5))));
            }

            final docs = snapshot.data?.docs ?? [];
            final myDocs = docs.where(
                  (d) => (d.data() as Map<String, dynamic>)['user_id'] == _currentUser?.uid,
            ).toList();

            final myRole = myDocs.isNotEmpty
                ? (myDocs.first.data() as Map<String, dynamic>)['role'] as String? ?? 'member'
                : 'member';

            final canManage = myRole == 'owner' || myRole == 'admin';

            return Column(
              children: [
                // ── Invite Code Banner ──────────────────
                if (_inviteCode != null)
                  GestureDetector(
                    onTap: _copyInviteCode,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.black,
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.key_rounded,
                                color: AppColors.gold, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite Code',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                _inviteCode!,
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  letterSpacing: 5,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (canManage)
                            IconButton(
                              icon: Icon(Icons.refresh,
                                  color: AppColors.gold.withOpacity(0.6),
                                  size: 18),
                              tooltip: 'New Code',
                              onPressed: _regenerateCode,
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.gold.withOpacity(0.1),
                              border: Border.all(
                                  color: AppColors.gold.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.copy,
                                    color: AppColors.gold, size: 14),
                                SizedBox(width: 4),
                                Text('Copy',
                                    style: TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Members List ────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.07),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final member =
                      docs[index].data() as Map<String, dynamic>;
                      final role =
                          member['role'] as String? ?? 'member';
                      final userId = member['user_id'] as String;
                      final isMe = userId == _currentUser?.uid;

                      return FutureBuilder<String>(
                        future: isMe
                            ? Future.value(_currentUsername ?? '...')
                            : _getUsernameForId(userId),
                        builder: (context, nameSnapshot) {
                          final displayName =
                              nameSnapshot.data ?? '...';
                          final avatarLetter = displayName
                              .substring(0, 1)
                              .toUpperCase();

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                              _roleColor(role).withOpacity(0.15),
                              child: Text(
                                avatarLetter,
                                style: TextStyle(
                                  color: _roleColor(role),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              isMe ? '$displayName (You)' : displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _roleColor(role).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _roleColor(role).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _roleLabel(role),
                                style: TextStyle(
                                  color: _roleColor(role),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: !isMe && canManage
                                ? () => _showMemberOptions(
                                context, userId, role, myRole)
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),

                // ── Bottom Actions ───────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Leave Team
                      GestureDetector(
                        onTap: _leaveTeam,
                        child: Container(
                          width: double.infinity,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.red.withOpacity(0.08),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.exit_to_app,
                                  color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Leave Team',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 10),
                        // Delete Team
                        GestureDetector(
                          onTap: _deleteTeam,
                          child: Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.red.withOpacity(0.15),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_forever,
                                    color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Team',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}