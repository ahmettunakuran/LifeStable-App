import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_colors.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/domain/task_sort.dart';
import '../domain/entities/calendar_event_entity.dart';
import '../logic/calender_cubit.dart';

/// Handles both **create** (no [existingEvent]) and **edit** flows.
/// When [type] is switched to [CalendarEventType.team] the form shows
/// a team picker and an assignee member selector.
class EventCreateEditPage extends StatefulWidget {
  const EventCreateEditPage({
    super.key,
    required this.initialDate,
    this.existingEvent,
    required this.cubit,
  });

  final DateTime initialDate;
  final CalendarEventEntity? existingEvent;

  /// Passed from CalendarPage so we can call findConflicts & saveEvent
  /// without re-reading from context (page is pushed via MaterialPageRoute).
  final CalendarCubit cubit;

  bool get isEditing => existingEvent != null;

  @override
  State<EventCreateEditPage> createState() => _EventCreateEditPageState();
}

class _EventCreateEditPageState extends State<EventCreateEditPage> {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late DateTime _startAt;
  late DateTime _endAt;
  late CalendarEventType _type;
  bool _saving = false;

  // ── Task link ─────────────────────────────────────────────────────────────
  List<TaskEntity> _availableTasks = [];
  TaskEntity? _linkedTask;
  bool _tasksLoading = false;

  // ── Team fields ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _userTeams = [];
  Map<String, dynamic>? _selectedTeam;
  List<Map<String, dynamic>> _teamMembers = [];
  Set<String> _assignedMemberIds = {};
  bool _teamsLoading = false;

  // ── Conflict detection ────────────────────────────────────────────────────
  List<CalendarEventEntity> _conflicts = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _startAt = e.startAt;
      _endAt = e.endAt;
      _type = e.eventType;
      _assignedMemberIds = Set.from(e.assignedMemberIds);
    } else {
      final d = widget.initialDate;
      final now = TimeOfDay.now();
      _startAt = DateTime(d.year, d.month, d.day, now.hour, now.minute);
      _endAt = _startAt.add(const Duration(hours: 1));
      _type = CalendarEventType.personal;
    }
    _loadTasks();
    _loadTeams();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    setState(() => _tasksLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collectionGroup('tasks')
          .where('userId', isEqualTo: uid)
          .where('status', whereNotIn: ['done'])
          .limit(50)
          .get();

      final tasks =
          snap.docs.map((d) => TaskEntity.fromFirestore(d.id, d.data())).toList();
      sortTasksByPriorityHighFirst(tasks);

      TaskEntity? linked;
      if (widget.existingEvent?.linkedTaskId != null) {
        linked = tasks.cast<TaskEntity?>().firstWhere(
              (t) => t?.id == widget.existingEvent!.linkedTaskId,
          orElse: () => null,
        );
      }

      if (mounted) {
        setState(() {
          _availableTasks = tasks;
          _linkedTask = linked;
          _tasksLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tasksLoading = false);
    }
  }

  Future<void> _loadTeams() async {
    setState(() => _teamsLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final memberSnap = await FirebaseFirestore.instance
          .collection('team_members')
          .where('user_id', isEqualTo: uid)
          .get();

      if (memberSnap.docs.isEmpty) {
        if (mounted) setState(() => _teamsLoading = false);
        return;
      }

      final teamIds =
      memberSnap.docs.map((d) => d.data()['team_id'] as String).toList();

      final teamSnap = await FirebaseFirestore.instance
          .collection('teams')
          .where('team_id', whereIn: teamIds)
          .get();

      final teams = teamSnap.docs.map((d) => d.data()).toList();

      // If editing a team event, pre-select the team
      Map<String, dynamic>? preSelected;
      if (widget.existingEvent?.teamId != null) {
        preSelected = teams.cast<Map<String, dynamic>?>().firstWhere(
              (t) => t?['team_id'] == widget.existingEvent!.teamId,
          orElse: () => null,
        );
      }

      if (mounted) {
        setState(() {
          _userTeams = teams;
          _teamsLoading = false;
        });
        if (preSelected != null) await _selectTeam(preSelected);
      }
    } catch (_) {
      if (mounted) setState(() => _teamsLoading = false);
    }
  }

  Future<void> _selectTeam(Map<String, dynamic> team) async {
    setState(() {
      _selectedTeam = team;
      _teamMembers = [];
    });

    try {
      final teamId = team['team_id'] as String;
      final memberSnap = await FirebaseFirestore.instance
          .collection('team_members')
          .where('team_id', isEqualTo: teamId)
          .get();

      final uids =
      memberSnap.docs.map((d) => d.data()['user_id'] as String).toList();

      // Fetch display names from user profiles
      final members = <Map<String, dynamic>>[];
      for (final uid in uids) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          members.add({
            'uid': uid,
            'displayName': data['display_name'] ?? data['email'] ?? uid,
            'role': memberSnap.docs
                .firstWhere((d) => d.data()['user_id'] == uid)
                .data()['role'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _teamMembers = members;
          // Keep existing assignments if switching within same team
          if (_assignedMemberIds.isEmpty) {
            _assignedMemberIds = uids.toSet(); // default: all members
          }
        });
      }
    } catch (_) {}
  }

  void _checkConflicts() {
    final conflicts = widget.cubit.findConflicts(
      start: _startAt,
      end: _endAt,
      excludeId: widget.existingEvent?.id,
    );
    setState(() => _conflicts = conflicts);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      _buildTitleField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Event Type'),
                      const SizedBox(height: 10),
                      _buildTypeSelector(),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Time'),
                      const SizedBox(height: 10),
                      _buildTimeRow(),
                      if (_conflicts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildConflictWarning(),
                      ],
                      // ── Team section ─────────────────────────────────────
                      if (_type == CalendarEventType.team) ...[
                        const SizedBox(height: 20),
                        _buildSectionLabel('Team'),
                        const SizedBox(height: 10),
                        _buildTeamPicker(),
                        if (_selectedTeam != null &&
                            _teamMembers.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildSectionLabel('Assign Members'),
                          const SizedBox(height: 10),
                          _buildMemberChips(),
                        ],
                      ],
                      // ── Task link (personal/task only) ───────────────────
                      if (_type != CalendarEventType.team) ...[
                        const SizedBox(height: 20),
                        _buildSectionLabel('Link to Task (optional)'),
                        const SizedBox(height: 10),
                        _buildTaskLinker(),
                      ],
                      if (widget.isEditing) ...[
                        const SizedBox(height: 32),
                        _buildDeleteButton(context),
                      ],
                    ],
                  ),
                ),
              ),
              _buildSaveButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border:
                Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child:
              const Icon(Icons.close, color: AppColors.gold, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.goldLight, AppColors.gold],
            ).createShader(b),
            child: Text(
              widget.isEditing ? 'EDIT EVENT' : 'NEW EVENT',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );

  // ── Text fields ───────────────────────────────────────────────────────────

  Widget _buildTitleField() => TextFormField(
    controller: _titleCtrl,
    style: const TextStyle(color: Colors.white, fontSize: 16),
    cursorColor: AppColors.gold,
    validator: (v) =>
    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
    decoration: _inputDeco('Event title', Icons.title_outlined),
  );

  Widget _buildDescriptionField() => TextFormField(
    controller: _descCtrl,
    maxLines: 3,
    style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
    cursorColor: AppColors.gold,
    decoration:
    _inputDeco('Description (optional)', Icons.notes_outlined),
  );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle:
    TextStyle(color: Colors.white.withValues(alpha: 0.25)),
    prefixIcon:
    Icon(icon, color: AppColors.gold.withValues(alpha: 0.5), size: 20),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
      BorderSide(color: AppColors.gold.withValues(alpha: 0.12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
      BorderSide(color: AppColors.gold.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
      const BorderSide(color: AppColors.gold, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  // ── Type selector ─────────────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CalendarEventType.values
          .map((t) => _TypeOption(
        type: t,
        selected: _type == t,
        onTap: () => setState(() {
          _type = t;
          if (t != CalendarEventType.team) {
            _selectedTeam = null;
            _teamMembers = [];
            _assignedMemberIds = {};
          }
        }),
      ))
          .toList(),
    );
  }

  // ── Time row + conflict ───────────────────────────────────────────────────

  Widget _buildTimeRow() {
    return Row(
      children: [
        Expanded(
            child: _TimeTile(
                label: 'Start',
                dateTime: _startAt,
                onTap: () => _pickDateTime(isStart: true))),
        const SizedBox(width: 12),
        Expanded(
            child: _TimeTile(
                label: 'End',
                dateTime: _endAt,
                onTap: () => _pickDateTime(isStart: false))),
      ],
    );
  }

  Widget _buildConflictWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Conflicts with ${_conflicts.length} event${_conflicts.length > 1 ? 's' : ''}: '
                  '${_conflicts.map((e) => e.title).join(', ')}',
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startAt : _endAt;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (ctx, child) => _goldPickerTheme(ctx, child!),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => _goldPickerTheme(ctx, child!),
    );
    if (time == null || !mounted) return;

    final result =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startAt = result;
        if (_endAt.isBefore(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        if (result.isAfter(_startAt)) {
          _endAt = result;
        } else {
          _showSnack('End time must be after start time');
          return;
        }
      }
    });
    _checkConflicts();
  }

  Widget _goldPickerTheme(BuildContext ctx, Widget child) => Theme(
    data: Theme.of(ctx).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: Colors.black,
        surface: Color(0xFF1A1200),
      ),
      dialogTheme:
      const DialogThemeData(backgroundColor: Color(0xFF1A1200)),
    ),
    child: child,
  );

  // ── Team picker ───────────────────────────────────────────────────────────

  Widget _buildTeamPicker() {
    if (_teamsLoading) {
      return _loadingRow('Loading your teams…');
    }
    if (_userTeams.isEmpty) {
      return _emptyHint(
          'You are not in any team yet. Create or join one from the Teams screen.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>?>(
          value: _selectedTeam,
          isExpanded: true,
          dropdownColor: AppColors.cardBg,
          hint: Text('Select a team',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
          icon: Icon(Icons.expand_more,
              color: AppColors.gold.withValues(alpha: 0.5), size: 20),
          items: [
            DropdownMenuItem<Map<String, dynamic>?>(
              value: null,
              child: Text('— No team —',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13)),
            ),
            ..._userTeams.map(
                  (t) => DropdownMenuItem<Map<String, dynamic>?>(
                value: t,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(t['color'] as int? ?? 0xFF1A237E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t['name'] as String? ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${t['member_count'] ?? ''} members',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (team) {
            if (team == null) {
              setState(() {
                _selectedTeam = null;
                _teamMembers = [];
                _assignedMemberIds = {};
              });
            } else {
              _selectTeam(team);
            }
          },
        ),
      ),
    );
  }

  // ── Member chips ──────────────────────────────────────────────────────────

  Widget _buildMemberChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap to toggle assignment',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _teamMembers.map((m) {
            final uid = m['uid'] as String;
            final name = m['displayName'] as String;
            final role = m['role'] as String? ?? 'member';
            final assigned = _assignedMemberIds.contains(uid);

            return GestureDetector(
              onTap: () => setState(() {
                if (assigned) {
                  _assignedMemberIds.remove(uid);
                } else {
                  _assignedMemberIds.add(uid);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: assigned
                      ? const Color(0xFFBA68C8).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: assigned
                        ? const Color(0xFFBA68C8)
                        : Colors.white.withValues(alpha: 0.1),
                    width: assigned ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: assigned
                          ? const Color(0xFFBA68C8)
                          : Colors.white24,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color:
                          assigned ? Colors.black : Colors.white60,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: assigned
                                ? const Color(0xFFBA68C8)
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: assigned
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        Text(
                          role,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 9),
                        ),
                      ],
                    ),
                    if (assigned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check,
                          size: 12, color: Color(0xFFBA68C8)),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_assignedMemberIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '⚠ No members assigned — at least one is required',
              style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8),
                  fontSize: 11),
            ),
          ),
      ],
    );
  }

  // ── Task linker ───────────────────────────────────────────────────────────

  Widget _buildTaskLinker() {
    if (_tasksLoading) return _loadingRow('Loading tasks…');
    if (_availableTasks.isEmpty) {
      return _emptyHint(
          'No pending tasks found. Add tasks from the Domains screen.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskEntity?>(
          value: _linkedTask,
          isExpanded: true,
          dropdownColor: AppColors.cardBg,
          hint: Text('Select a task to link',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
          icon: Icon(Icons.expand_more,
              color: AppColors.gold.withValues(alpha: 0.5), size: 20),
          items: [
            DropdownMenuItem<TaskEntity?>(
              value: null,
              child: Text('— No linked task —',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13)),
            ),
            ..._availableTasks.map(
                  (t) => DropdownMenuItem<TaskEntity?>(
                value: t,
                child: Row(
                  children: [
                    Icon(_priorityIcon(t.priority),
                        size: 14, color: _priorityColor(t.priority)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    if (t.dueDate != null)
                      Text(DateFormat('MMM d').format(t.dueDate!),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (t) => setState(() => _linkedTask = t),
        ),
      ),
    );
  }

  IconData _priorityIcon(TaskPriority p) => switch (p) {
    TaskPriority.high => Icons.keyboard_double_arrow_up,
    TaskPriority.medium => Icons.remove,
    TaskPriority.low => Icons.keyboard_double_arrow_down,
  };

  Color _priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.high => Colors.redAccent,
    TaskPriority.medium => AppColors.gold,
    TaskPriority.low => const Color(0xFF81C784),
  };

  // ── Delete ────────────────────────────────────────────────────────────────

  Widget _buildDeleteButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmDelete(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.redAccent.withValues(alpha: 0.08),
          border:
          Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text('Delete Event',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete event?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('This action cannot be undone.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.existingEvent != null) {
                await widget.cubit.deleteEvent(widget.existingEvent!);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Widget _buildSaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border(
            top:
            BorderSide(color: AppColors.gold.withValues(alpha: 0.08))),
      ),
      child: GestureDetector(
        onTap: _saving ? null : () => _save(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _saving
                ? null
                : const LinearGradient(colors: [
              AppColors.goldLight,
              AppColors.gold,
              AppColors.goldDark,
            ]),
            color: _saving ? Colors.white12 : null,
            boxShadow: _saving
                ? null
                : [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: _saving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2))
                : Text(
                widget.isEditing ? 'Save Changes' : 'Create Event',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate team selection
    if (_type == CalendarEventType.team && _selectedTeam == null) {
      _showSnack('Please select a team for this event');
      return;
    }
    if (_type == CalendarEventType.team && _assignedMemberIds.isEmpty) {
      _showSnack('Please assign at least one member');
      return;
    }

    // Soft conflict warning — allow proceeding
    if (_conflicts.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Time Conflict',
              style: TextStyle(color: Colors.white)),
          content: Text(
            'This event overlaps with: ${_conflicts.map((e) => e.title).join(', ')}. Save anyway?',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5)))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Anyway',
                  style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final existing = widget.existingEvent;

      final event = CalendarEventEntity(
        id: existing?.id ?? '',
        userId: uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        startAt: _startAt,
        endAt: _endAt,
        eventType: _type,
        linkedTaskId:
        _type != CalendarEventType.team ? _linkedTask?.id : null,
        linkedTaskTitle:
        _type != CalendarEventType.team ? _linkedTask?.title : null,
        colorHex: existing?.colorHex,
        isRecurring: existing?.isRecurring ?? false,
        externalEventId: existing?.externalEventId,
        teamId: _type == CalendarEventType.team
            ? (_selectedTeam?['team_id'] as String?)
            : null,
        teamName: _type == CalendarEventType.team
            ? (_selectedTeam?['name'] as String?)
            : null,
        assignedMemberIds: _type == CalendarEventType.team
            ? _assignedMemberIds.toList()
            : [],
        sourceCollection: existing?.sourceCollection ??
            (_type == CalendarEventType.team
                ? EventSourceCollection.team
                : EventSourceCollection.personal),
      );

      await widget.cubit.saveEvent(event);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _loadingRow(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 1.5)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
      ],
    ),
  );

  Widget _emptyHint(String msg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white.withValues(alpha: 0.03),
      border:
      Border.all(color: AppColors.gold.withValues(alpha: 0.08)),
    ),
    child: Text(msg,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
  );

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.cardBg,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Type option chip ─────────────────────────────────────────────────────────

class _TypeOption extends StatelessWidget {
  const _TypeOption(
      {required this.type,
        required this.selected,
        required this.onTap});

  final CalendarEventType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      CalendarEventType.personal =>
      (Icons.person_outline, AppColors.gold),
      CalendarEventType.task =>
      (Icons.check_box_outlined, const Color(0xFF4FC3F7)),
      CalendarEventType.classSchedule =>
      (Icons.school_outlined, const Color(0xFF81C784)),
      CalendarEventType.team =>
      (Icons.groups_outlined, const Color(0xFFBA68C8)),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
              color: selected
                  ? color
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? color
                    : Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(type.label,
                style: TextStyle(
                    color: selected
                        ? color
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Time tile ────────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  const _TimeTile(
      {required this.label,
        required this.dateTime,
        required this.onTap});

  final String label;
  final DateTime dateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04),
          border:
          Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(DateFormat('HH:mm').format(dateTime),
                style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 20)),
            Text(DateFormat('EEE, MMM d').format(dateTime),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}