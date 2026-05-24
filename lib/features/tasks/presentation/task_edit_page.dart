import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/router/app_routes.dart';
import '../../../features/alerts/domain/entities/location_entity.dart';
import '../../../features/alerts/logic/location_cubit.dart';
import '../../../features/alerts/logic/location_state.dart';
import '../domain/entities/task_entity.dart';
import 'bloc/tasks_bloc.dart';
import 'bloc/tasks_event.dart';

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key});
  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  String? _domainId;
  String? _teamId;
  String? _locationId;
  String? _locationLabel;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  TaskEntity? _editingTask;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _editingTask == null && _domainId == null) {
      if (args['task'] is TaskEntity) {
        _editingTask = args['task'] as TaskEntity;
        _titleController.text = _editingTask!.title;
        _descriptionController.text = _editingTask!.description ?? '';
        _status = _editingTask!.status;
        _priority = _editingTask!.priority;
        _dueDate = _editingTask!.dueDate;
        _domainId = _editingTask!.domainId;
        _teamId = _editingTask!.teamId;
        _locationId = _editingTask!.locationId;
        _locationLabel = _editingTask!.locationLabel;
      } else {
        _domainId = args['domainId'] as String?;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text('Create Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: Icon(Icons.check, color: AppColors.gold), onPressed: _saveTask)],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lbl('Title'),
                const SizedBox(height: 8),
                _fld(_titleController, 'Task title', validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 20),
                _lbl('Description'),
                const SizedBox(height: 8),
                _fld(_descriptionController, 'Optional description', maxLines: 3),
                const SizedBox(height: 20),
                _lbl('Domain'),
                const SizedBox(height: 8),
                _domainDropdown(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl('Status'),
                          const SizedBox(height: 8),
                          _dropdown<TaskStatus>(
                            value: _status,
                            items: TaskStatus.values,
                            labelOf: (s) => s.name.toUpperCase(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lbl('Priority'),
                          const SizedBox(height: 8),
                          _dropdown<TaskPriority>(
                            value: _priority,
                            items: TaskPriority.values,
                            labelOf: (p) => p.name.toUpperCase(),
                            onChanged: (v) => setState(() => _priority = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _lbl('Due Date'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dueDate == null ? 'Select date' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                          style: TextStyle(color: _dueDate == null ? Colors.white.withValues(alpha: 0.25) : Colors.white, fontSize: 15),
                        ),
                        Icon(Icons.calendar_today, size: 18, color: AppColors.gold.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLocationSection(),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _saveTask,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark]),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: const Center(
                      child: Text('Save Task', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600));

  Widget _fld(TextEditingController c, String hint, {int maxLines = 1, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 1.2),
      ),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _domainDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(_auth.currentUser?.uid).collection('domains').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 1.2),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: docs.any((doc) => doc.id == _domainId) ? _domainId : null,
            dropdownColor: AppColors.cardBg,
            style: TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(border: InputBorder.none),
            hint: Text('Select domain', style: TextStyle(color: Colors.white.withValues(alpha: 0.25))),
            items: docs.map((doc) {
              final data = doc.data();
              final isTeam = data['teamId'] != null;
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Row(
                  children: [
                    Text(data['name'] as String? ?? 'Unnamed'),
                    if (isTeam) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('TEAM', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            validator: (v) => v == null ? 'Please select a domain' : null,
            onChanged: (v) {
              setState(() {
                _domainId = v;
                if (v != null) {
                  final selectedDoc = docs.firstWhere((doc) => doc.id == v);
                  _teamId = selectedDoc.data()['teamId'] as String?;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 1.2),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: AppColors.cardBg,
        style: TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(border: InputBorder.none),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(labelOf(i)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLocationSection() {
    if (_locationId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.gold.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location Reminder', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    _locationLabel ?? 'Saved location',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _locationId = null;
                _locationLabel = null;
              }),
              child: const Icon(Icons.close, color: Colors.white38, size: 20),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showLocationPickerSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.25),
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt_outlined, color: AppColors.gold.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 10),
            Text(
              'Add location for reminders',
              style: TextStyle(
                color: AppColors.gold.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        onAddNew: _navigateToMapPicker,
        onSelectSaved: _showSavedLocationsSheet,
      ),
    );
  }

  Future<void> _navigateToMapPicker() async {
    Navigator.pop(context); // close picker sheet
    final locationId = await Navigator.pushNamed<String?>(
      context,
      AppRoutes.map,
      arguments: true,
    );
    if (locationId != null && mounted) {
      String label = 'Location';
      try {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          final doc = await _db
              .collection('users')
              .doc(uid)
              .collection('locations')
              .doc(locationId)
              .get();
          label = doc.data()?['label'] as String? ?? 'Location';
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _locationId = locationId;
          _locationLabel = label;
        });
      }
    }
  }

  void _showSavedLocationsSheet() {
    Navigator.pop(context); // close picker sheet
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<LocationCubit>(),
        child: _SavedLocationsPickerSheet(
          onSelect: (location) {
            Navigator.pop(context);
            setState(() {
              _locationId = location.locationId;
              _locationLabel = location.label;
            });
          },
        ),
      ),
    );
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final task = TaskEntity(
        id: _editingTask?.id ?? const Uuid().v4(),
        domainId: _domainId!,
        title: _titleController.text,
        description: _descriptionController.text,
        status: _status,
        priority: _priority,
        dueDate: _dueDate,
        teamId: _teamId,
        assignedTo: _editingTask?.assignedTo,
        locationId: _locationId,
        locationLabel: _locationLabel,
      );

      context.read<TasksBloc>().add(AddTask(task));
      Navigator.pop(context);
    }
  }
}

class _LocationPickerSheet extends StatelessWidget {
  final VoidCallback onAddNew;
  final VoidCallback onSelectSaved;

  const _LocationPickerSheet({required this.onAddNew, required this.onSelectSaved});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.location_on, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                'Add Location for Reminders',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You will be notified when you arrive at this location.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _OptionTile(
            icon: Icons.add_location_alt,
            title: 'Add new location',
            subtitle: 'Open the map and pin a new location',
            onTap: onAddNew,
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.bookmark_outline,
            title: 'Add from saved locations',
            subtitle: 'Pick from your previously saved locations',
            onTap: onSelectSaved,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SavedLocationsPickerSheet extends StatelessWidget {
  final void Function(LocationEntity) onSelect;

  const _SavedLocationsPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.bookmark, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                'Saved Locations',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: BlocBuilder<LocationCubit, LocationState>(
              builder: (context, state) {
                if (state.status == LocationStatus.loading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                }
                if (state.locations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No saved locations yet.\nGo to the map to add one first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.locations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final loc = state.locations[index];
                    return GestureDetector(
                      onTap: () => onSelect(loc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, color: AppColors.gold, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.label,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    '${loc.radiusM} m radius',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.check_circle_outline, color: AppColors.gold.withValues(alpha: 0.5), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
