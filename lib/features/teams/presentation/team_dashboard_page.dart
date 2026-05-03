import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_lifestable/services/team_service.dart';
import '../../../app/router/app_routes.dart';

import '../../../shared/constants/app_colors.dart';
import 'join_team_screen.dart';
import 'team_detail_screen.dart';

class TeamDashboardPage extends StatefulWidget {
  const TeamDashboardPage({super.key});

  @override
  State<TeamDashboardPage> createState() => _TeamDashboardPageState();
}

class _TeamDashboardPageState extends State<TeamDashboardPage> {
  final _teamService = TeamService();
  late Future<List<Map<String, dynamic>>> _teamsFuture;

  final List<Color> _teamColors = [
    const Color(0xFF1A237E),
    const Color(0xFF0D47A1),
    const Color(0xFFF9A825),
    const Color(0xFFB71C1C),
    const Color(0xFF1B5E20),
    const Color(0xFF4A148C),
    const Color(0xFF37474F),
    const Color(0xFFE65100),
  ];

  @override
  void initState() {
    super.initState();
    _teamsFuture = _teamService.getUserTeams();
  }

  void _refresh() {
    setState(() {
      _teamsFuture = _teamService.getUserTeams();
    });
  }

  Color _getTeamColor(Map<String, dynamic> team) {
    final colorValue = team['color'] as int?;
    if (colorValue != null) return Color(colorValue);
    return _teamColors[0];
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final objectiveController = TextEditingController();
    Color pickedColor = _teamColors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Create Team',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(nameController, 'Team Name', Icons.group),
                const SizedBox(height: 12),
                _dialogField(objectiveController, 'Objective (optional)', Icons.flag_outlined),
                const SizedBox(height: 16),
                Text(
                  'Team Color',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _teamColors.map((color) {
                    final isSelected = pickedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => pickedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.gold : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final code = await _teamService.createTeam(
                    nameController.text.trim(),
                    objectiveController.text.trim(),
                    color: pickedColor.value,
                  );
                  if (mounted) {
                    _refresh();
                    _showInviteCodeDialog(code);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.goldDark],
                  ),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.gold.withOpacity(0.5), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }

  void _showInviteCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Team Created!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this invite code with your teammates:',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Invite code copied!'),
                    backgroundColor: AppColors.goldDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldLight,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy, color: AppColors.gold, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to copy',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        iconTheme: const IconThemeData(color: AppColors.gold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gold),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.homeDashboard),
        ),
        title: const Text(
          'Team Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, color: AppColors.gold),
            tooltip: 'Join with Code',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinTeamScreen()),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _teamsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              );
            }
            final teams = snapshot.data ?? [];
            if (teams.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off,
                        size: 64, color: AppColors.gold.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No teams yet.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create one or join with a code.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35), fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final team = teams[index];
                final teamColor = _getTeamColor(team);
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(
                          teamId: team['team_id'],
                          teamName: team['name'],
                        ),
                      ),
                    );
                    _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: teamColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: teamColor.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (team['name'] as String? ?? 'T')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (team['objective'] != null &&
                                  (team['objective'] as String).isNotEmpty)
                                Text(
                                  team['objective'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.gold.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: _showCreateTeamDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text(
                'Create Team',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(Icons.group_outlined, 'Team', AppRoutes.teamDashboard, active: true),
            _navBtn(Icons.calendar_month_outlined, 'Calendar', AppRoutes.calendar),
            _navBtn(Icons.dashboard_outlined, 'Dashboard', AppRoutes.homeDashboard),
            _navBtn(Icons.local_fire_department_outlined, 'Habit', AppRoutes.habitTracker),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, String route, {bool active = false}) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? AppColors.gold : AppColors.gold.withValues(alpha: 0.45),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

