import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
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
    Icons.school,
    Icons.favorite,
    Icons.work,
    Icons.fitness_center,
    Icons.home,
    Icons.attach_money,
    Icons.people,
    Icons.brush,
    Icons.flight,
    Icons.restaurant,
  ];

  final List<Color> _colors = [
    const Color(0xFF7C4DFF),
    const Color(0xFFFFC107),
    const Color(0xFF4CAF50),
    const Color(0xFF2196F3),
    const Color(0xFFF44336),
    const Color(0xFF9C27B0),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
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
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.domain != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Domain' : 'New Domain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Domain Name',
                  hintText: 'e.g., School, Health, Work',
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              Text('Icon', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _icons.map<Widget>((icon) {
                  final isSelected = icon == _selectedIcon;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedColor.withValues(alpha: 0.1) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: _selectedColor, width: 2) : null,
                      ),
                      child: Icon(icon, color: isSelected ? _selectedColor : theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text('Color', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map<Widget>((color) {
                  final isSelected = color == _selectedColor;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
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
