import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/domain_entity.dart';
import '../logic/domain_cubit.dart';

class DomainEditPage extends StatefulWidget {
  const DomainEditPage({super.key, this.domain});
  final DomainEntity? domain;

  @override
  State<DomainEditPage> createState() => _DomainEditPageState();
}

class _DomainEditPageState extends State<DomainEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late Color _selectedColor;
  late IconData _selectedIcon;

  final List<IconData> _icons = [
    Icons.school, Icons.favorite, Icons.work, Icons.fitness_center,
    Icons.home, Icons.attach_money, Icons.people, Icons.brush,
    Icons.flight, Icons.restaurant,
  ];

  final List<Color> _colors = [
    const Color(0xFF7C4DFF), const Color(0xFFFFC107), const Color(0xFF4CAF50),
    const Color(0xFF2196F3), const Color(0xFFF44336), const Color(0xFF9C27B0),
    const Color(0xFFE91E63), const Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.domain?.name);
    _descriptionController = TextEditingController(text: widget.domain?.description);
    _selectedColor = widget.domain != null
        ? Color(int.parse(widget.domain!.colorHex.replaceFirst('#', '0xFF')))
        : _colors.first;
    _selectedIcon = widget.domain != null
        ? IconData(widget.domain!.iconCode, fontFamily: 'MaterialIcons')
        : _icons.first;
  }

  @override
  void dispose() { _nameController.dispose(); _descriptionController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.domain != null;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: isEditing
            ? const Text('Edit Domain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
            : null,
        actions: isEditing
            ? [IconButton(icon: const Icon(Icons.check, color: AppColors.gold), onPressed: _save)]
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)]),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(colors: [AppColors.goldLight, AppColors.gold]).createShader(b),
                    child: const Text('New Domain', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Text('Create a new life domain to organize your tasks.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                  const SizedBox(height: 28),
                ],
                _label('Domain Name'), const SizedBox(height: 8),
                _field(_nameController, 'e.g., School, Health, Work', validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 20),
                _label('Description (Optional)'), const SizedBox(height: 8),
                _field(_descriptionController, 'What is this domain about?', maxLines: 2),
                const SizedBox(height: 28),
                _label('Icon'), const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: _icons.map((icon) {
                  final sel = icon == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel ? _selectedColor.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: sel ? Border.all(color: _selectedColor, width: 2) : Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Icon(icon, color: sel ? _selectedColor : Colors.white.withOpacity(0.4)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 28),
                _label('Color'), const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: _colors.map((c) {
                  final sel = c == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                          border: Border.all(color: sel ? AppColors.goldLight : Colors.transparent, width: 2.5)),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList()),
                const SizedBox(height: 36),
                if (!isEditing) GestureDetector(
                  onTap: _save,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark]),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: const Center(child: Text('Create Domain', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600));

  Widget _field(TextEditingController c, String hint, {int maxLines = 1, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withOpacity(0.05),
          border: Border.all(color: AppColors.gold.withOpacity(0.2), width: 1.2)),
      child: TextFormField(controller: c, maxLines: maxLines, validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 15),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16))),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final domain = DomainEntity(
        id: widget.domain?.id ?? const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text,
        iconCode: _selectedIcon.codePoint,
        colorHex: '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
      );
      if (widget.domain != null) {
        context.read<DomainCubit>().updateDomain(domain);
      } else {
        context.read<DomainCubit>().addDomain(domain);
      }
      Navigator.pop(context);
    }
  }
}