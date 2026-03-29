import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/localization/app_localizations.dart';
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
  String? _teamId; // Track if the selected domain belongs to a team
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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
    if (args != null) {
      _domainId = args['domainId'] as String?;
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
          colorScheme: const ColorScheme.dark(
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
        title: const Text('Create Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.check, color: AppColors.gold), onPressed: _saveTask)],
      ),
      body: Container(
        decoration: const BoxDecoration(
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
                const SizedBox(height: 36),
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
        style: const TextStyle(color: Colors.white, fontSize: 15),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
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
        initialValue: value,
        dropdownColor: AppColors.cardBg,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(border: InputBorder.none),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(labelOf(i)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final task = TaskEntity(
        id: const Uuid().v4(),
        domainId: _domainId!,
        title: _titleController.text,
        description: _descriptionController.text,
        status: _status,
        priority: _priority,
        dueDate: _dueDate,
        teamId: _teamId,
      );
      context.read<TasksBloc>().add(AddTask(task));
      Navigator.pop(context);
    }
  }
}
