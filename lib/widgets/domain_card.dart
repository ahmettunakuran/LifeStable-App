import 'package:flutter/material.dart';
import '../models/domain.dart';
// Imports the Domain model to access domain properties

// A reusable card widget that displays a single domain item
// This widget is stateless because it only displays data passed from parent
class DomainCard extends StatelessWidget {
  final Domain domain;         // The domain data to display in this card
  final VoidCallback onDelete; // Callback function triggered when delete button is pressed
  final VoidCallback onEdit;   // Callback function triggered when edit button is pressed

  const DomainCard({
    Key? key,
    required this.domain,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  // Getter that converts the hex color string to a Flutter Color object
  Color get _color {
    try {
      // Replaces '#' with '0xFF' prefix which Flutter requires for Color parsing
      // Example: '#6200EE' becomes '0xFF6200EE'
      return Color(
        int.parse('0xFF${domain.colorHex.replaceAll('#', '')}'),
      );
    } catch (_) {
      // If color string is invalid or parsing fails, default to purple
      return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // Adds spacing around each card in the list
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Gives the card rounded corners with a 12px radius
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // Colored circle on the left side showing the domain's assigned color
        leading: CircleAvatar(backgroundColor: _color),
        // Displays the domain name in bold text
        title: Text(
          domain.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        // Edit and delete action buttons on the right side of the card
        trailing: Row(
          // MainAxisSize.min prevents the Row from taking full width
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              // Calls the onEdit function passed from the parent widget
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              // Calls the onDelete function passed from the parent widget
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}