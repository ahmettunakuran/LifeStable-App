import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/constants/app_colors.dart';
import '../../data/usage_tracker.dart';
import '../../domain/plan_catalog.dart';

/// Renders the live "Usage this month" panel — current plan name, then a
/// progress bar per [BillableFeature] showing used / limit (or "Unlimited").
///
/// Listens to [UsageTracker.instance.revision] so any consume/refund in the
/// app updates the bars immediately, no manual refresh wiring required.
class UsageSummaryCard extends StatelessWidget {
  const UsageSummaryCard({
    super.key,
    this.showHeader = true,
    this.showSeePlansButton = true,
  });

  final bool showHeader;
  final bool showSeePlansButton;

  static const _features = [
    (BillableFeature.ocrScheduleImport, 'feature_ocr', Icons.document_scanner_outlined),
    (BillableFeature.aiAssistantPrompt, 'feature_ai_assistant', Icons.auto_awesome_outlined),
    (BillableFeature.voiceTranscription, 'feature_voice', Icons.mic_none_outlined),
    (BillableFeature.helpBotQuestion, 'feature_help_bot', Icons.help_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<int>(
          valueListenable: UsageTracker.instance.revision,
          builder: (context, _, __) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.18),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            color: AppColors.gold, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            S.of('usage_this_month'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _PlanBadge(plan: UsageTracker.instance.currentPlan),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final entry in _features) ...[
                    _UsageRow(
                      feature: entry.$1,
                      labelKey: entry.$2,
                      icon: entry.$3,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showSeePlansButton) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.premiumPlans),
                        icon: const Icon(Icons.workspace_premium, size: 16),
                        label: Text(S.of('view_plans')),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: plan.accent.withOpacity(0.15),
        border: Border.all(color: plan.accent.withOpacity(0.5)),
      ),
      child: Text(
        S.of(plan.titleKey),
        style: TextStyle(
          color: plan.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _UsageRow extends StatefulWidget {
  const _UsageRow({
    required this.feature,
    required this.labelKey,
    required this.icon,
  });

  final BillableFeature feature;
  final String labelKey;
  final IconData icon;

  @override
  State<_UsageRow> createState() => _UsageRowState();
}

class _UsageRowState extends State<_UsageRow> {
  UsageSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _UsageRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final s = await UsageTracker.instance.snapshot(widget.feature);
    if (!mounted) return;
    setState(() => _snapshot = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    final usedText = s == null
        ? '—'
        : s.isUnlimited
            ? S.of('usage_unlimited')
            : s.isExhausted
                ? S.of('usage_exhausted')
                : S
                    .of('usage_remaining')
                    .replaceAll('{used}', s.used.toString())
                    .replaceAll('{limit}', s.limit.toString());

    final progress = s?.progress;
    final color = s != null && s.isExhausted
        ? const Color(0xFFE57373)
        : AppColors.gold;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: AppColors.gold, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.of(widget.labelKey),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    usedText,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress ?? (s?.isUnlimited == true ? 0.0 : null),
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}