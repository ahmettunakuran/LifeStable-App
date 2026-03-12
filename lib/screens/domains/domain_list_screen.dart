import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../services/domain_service.dart';
import '../../widgets/domain_card.dart';

// Main screen that displays the list of user domains
// StatefulWidget is used because the screen manages dialog state
class DomainListScreen extends StatefulWidget {
  const DomainListScreen({Key? key}) : super(key: key);

  @override
  State<DomainListScreen> createState() => _DomainListScreenState();
}

class _DomainListScreenState extends State<DomainListScreen> {
  // Creates an instance of DomainService to handle all Firestore operations
  final DomainService _service = DomainService();

  // List of available color options for domain creation and editing
  final List<Map<String, dynamic>> _colorOptions = [
    {'label': 'Purple', 'hex': '#6200EE'},
    {'label': 'Blue',   'hex': '#1976D2'},
    {'label': 'Green',  'hex': '#388E3C'},
    {'label': 'Orange', 'hex': '#F57C00'},
    {'label': 'Red',    'hex': '#D32F2F'},
  ];

  // Tracks which color is currently selected in the dialog
  String _selectedColor = '#6200EE';

  // Shows a dialog for creating a new domain
  void _showAddDialog() {
    final nameController = TextEditingController();
    // Reset selected color to default purple each time dialog opens
    _selectedColor = '#6200EE';

    showDialog(
      context: context,
      // StatefulBuilder allows the dialog to call its own setState
      // This is needed to update the color selection UI inside the dialog
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('New Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text field for entering the domain name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. School, Health, Work',
                  labelText: 'Domain Name',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pick a color:'),
              const SizedBox(height: 8),
              // Wrap places color circles side by side
              // and wraps to the next line if there is not enough space
              Wrap(
                spacing: 8,
                children: _colorOptions.map((c) {
                  final isSelected = _selectedColor == c['hex'];
                  return GestureDetector(
                    // Updates the selected color when user taps a circle
                    onTap: () => setStateDialog(
                            () => _selectedColor = c['hex']),
                    child: CircleAvatar(
                      // Selected circle is slightly larger to indicate selection
                      radius: isSelected ? 18 : 14,
                      backgroundColor: Color(
                        int.parse(
                            '0xFF${(c['hex'] as String).replaceAll('#', '')}'),
                      ),
                      // Shows a checkmark icon on the selected color
                      child: isSelected
                          ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            // Cancel button closes the dialog without saving
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Only creates domain if name field is not empty
                if (nameController.text.trim().isNotEmpty) {
                  _service.createDomain(
                    name: nameController.text.trim(),
                    colorHex: _selectedColor,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Shows a dialog for editing an existing domain
  // Pre-fills the form with the domain's current name and color
  void _showEditDialog(Domain domain) {
    final nameController = TextEditingController(text: domain.name);
    // Pre-select the domain's current color
    _selectedColor = domain.colorHex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                const InputDecoration(labelText: 'Domain Name'),
              ),
              const SizedBox(height: 16),
              const Text('Pick a color:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((c) {
                  final isSelected = _selectedColor == c['hex'];
                  return GestureDetector(
                    onTap: () => setStateDialog(
                            () => _selectedColor = c['hex']),
                    child: CircleAvatar(
                      radius: isSelected ? 18 : 14,
                      backgroundColor: Color(
                        int.parse(
                            '0xFF${(c['hex'] as String).replaceAll('#', '')}'),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Only saves if the name field is not empty
                if (nameController.text.trim().isNotEmpty) {
                  _service.updateDomain(
                    domainId: domain.id,
                    newName: nameController.text.trim(),
                    newColorHex: _selectedColor,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Shows a confirmation dialog before permanently deleting a domain
  void _confirmDelete(Domain domain) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Domain'),
        content: Text('"${domain.name}" will be deleted. Are you sure?'),
        actions: [
          // Cancel button dismisses the dialog without deleting
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Calls the delete function in DomainService
              _service.deleteDomain(domain.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Domains')),
      // Floating button in the bottom right corner to open the add domain dialog
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      // StreamBuilder listens to real-time Firestore data
      // and automatically rebuilds the UI whenever data changes
      body: StreamBuilder<List<Domain>>(
        stream: _service.getDomains(),
        builder: (context, snapshot) {
          // Shows a loading spinner while waiting for first data from Firestore
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Shows an empty state message if the user has no domains yet
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No domains yet. Tap + to add one!'),
            );
          }
          final domains = snapshot.data!;
          // Builds a scrollable list of DomainCard widgets
          return ListView.builder(
            itemCount: domains.length,
            itemBuilder: (_, i) => DomainCard(
              domain: domains[i],
              // Passes delete and edit callbacks to each DomainCard
              onDelete: () => _confirmDelete(domains[i]),
              onEdit: () => _showEditDialog(domains[i]),
            ),
          );
        },
      ),
    );
  }
}