import 'package:flutter/material.dart';
import '../../../../../shared/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';

class SuggestionChips extends StatelessWidget {
  final void Function(String suggestion) onSuggestionTap;
  const SuggestionChips({super.key, required this.onSuggestionTap});

  static const List<String> _suggestions = [
    '📋  Summarize my day',
    '⏰  Upcoming tasks',
    '📅  Find a lighter day this week',
    '🔥  Today\'s habits',
    '➕  How do I add a task?',
    '💡  How do I use the app?',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 10),
          child: Text(
            'What can I help you with?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => onSuggestionTap(_suggestions[index]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.gold.withOpacity(0.07),
                  ),
                  child: Text(
                    _suggestions[index],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}