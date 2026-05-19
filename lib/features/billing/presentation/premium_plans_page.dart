import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/constants/app_colors.dart';
import '../data/usage_tracker.dart';
import '../domain/plan_catalog.dart';
import 'widgets/usage_summary_card.dart';

/// Pricing & plan-management page. Reads the active plan from
/// [UsageTracker] and renders Free / Plus / Pro cards from [PlanCatalog].
///
/// No payment integration yet — upgrade CTAs are intentionally inert
/// (labeled "Coming soon") so the layout is real but won't charge anyone.
class PremiumPlansPage extends StatelessWidget {
  const PremiumPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.gold, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            S.of('premium_plans_title'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: UsageTracker.instance.revision,
          builder: (context, _, __) {
            final activeTier = UsageTracker.instance.currentTier;
            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const SizedBox(height: 4),
                _Header(),
                const SizedBox(height: 20),
                const UsageSummaryCard(showSeePlansButton: false),
                const SizedBox(height: 28),
                for (final plan in PlanCatalog.all) ...[
                  _PlanCard(
                    plan: plan,
                    isActive: plan.tier == activeTier,
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 8),
                _Disclaimer(),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
          ).createShader(bounds),
          child: Text(
            S.of('premium_plans_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of('premium_plans_subtitle'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isActive});

  final Plan plan;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isFree = plan.tier == PlanTier.free;
    final highlightedBorder = isActive
        ? plan.accent
        : plan.accent.withOpacity(plan.tier == PlanTier.pro ? 0.45 : 0.25);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlightedBorder, width: isActive ? 1.6 : 1),
        boxShadow: plan.tier == PlanTier.pro
            ? [
                BoxShadow(
                  color: plan.accent.withOpacity(0.18),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: plan.accent.withOpacity(0.15),
                  border: Border.all(color: plan.accent.withOpacity(0.55)),
                ),
                child: Text(
                  S.of(plan.titleKey),
                  style: TextStyle(
                    color: plan.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    S.of('current_plan_badge'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PriceLine(plan: plan),
          const SizedBox(height: 6),
          Text(
            S.of(plan.tagKey),
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ...plan.featuresKeys.map(
            (k) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, color: plan.accent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.of(k),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _PlanCta(plan: plan, isActive: isActive, isFree: isFree),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.tier == PlanTier.free) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            '0',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              plan.currencySymbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${plan.currencySymbol}${plan.priceMonthly}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                S.of('per_month'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (plan.priceYearly > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: plan.accent.withOpacity(0.12),
              border: Border.all(color: plan.accent.withOpacity(0.4)),
            ),
            child: Text(
              '${plan.currencySymbol}${plan.priceYearly}${S.of('per_year')} · ${S.of('save_yearly')}',
              style: TextStyle(
                color: plan.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanCta extends StatelessWidget {
  const _PlanCta({
    required this.plan,
    required this.isActive,
    required this.isFree,
  });

  final Plan plan;
  final bool isActive;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: plan.accent.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor: Colors.white70,
        ),
        child: Text(
          S.of('plan_cta_active'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (isFree) {
      // Downgrade to free isn't wired yet — keep it disabled.
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor: Colors.white54,
        ),
        child: Text(
          S.of('plan_cta_unavailable'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    // Upgrade CTA — inert until billing is wired. We still show a clear
    // "Coming soon" toast so the affordance feels alive.
    return FilledButton(
      onPressed: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            backgroundColor: AppColors.cardBg,
            content: Text(
              S.of('coming_soon'),
              style: const TextStyle(color: Colors.white),
            ),
          ));
      },
      style: FilledButton.styleFrom(
        backgroundColor: plan.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      child: Text(
          '${S.of('plan_cta_upgrade')} · ${S.of('coming_soon')}'),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of('billing_disclaimer'),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}