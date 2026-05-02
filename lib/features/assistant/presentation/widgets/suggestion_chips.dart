import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/constants/app_colors.dart';

class SuggestionChips extends StatelessWidget {
  final void Function(String suggestion) onSuggestionTap;
  const SuggestionChips({super.key, required this.onSuggestionTap});

  static List<String> get _suggestions => [
    S.of('suggest_summarize'),
    S.of('suggest_tasks'),
    S.of('suggest_lighter_day'),
    S.of('suggest_habits'),
    S.of('suggest_add_task'),
    S.of('suggest_how_to_use'),
  ];

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 10),
          child: Text(
            S.of('assistant_help_prompt'),
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
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => onSuggestionTap(suggestions[index]),
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
                    suggestions[index],
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