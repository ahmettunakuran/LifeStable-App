import 'package:flutter/material.dart';

/// Identifies a rate-limited capability the app guards behind monthly quotas.
///
/// The string value is what we persist in SharedPreferences and look up in
/// [PlanLimits], so changing it is a breaking change for existing installs.
enum BillableFeature {
  /// Schedule-image OCR via Gemini Vision.
  ocrScheduleImport('ocr_schedule_import'),

  /// Groq Llama assistant prompts (text/voice/image entry points).
  aiAssistantPrompt('ai_assistant_prompt'),

  /// Whisper voice transcription minutes (counted as calls, not minutes).
  voiceTranscription('voice_transcription'),

  /// RAG help-bot questions.
  helpBotQuestion('help_bot_question');

  const BillableFeature(this.id);
  final String id;
}

/// A monthly cap for one feature on one plan. `null` = unlimited.
typedef MonthlyLimit = int?;

/// The three tiers we ship plan UI for. Only [free] is actually active until
/// a payment flow is built — [plus] and [pro] are shown for marketing but
/// the catalog is the source of truth for limits when we flip the switch.
enum PlanTier { free, plus, pro }

class Plan {
  const Plan({
    required this.tier,
    required this.titleKey,
    required this.priceMonthly,
    required this.priceYearly,
    required this.currencySymbol,
    required this.tagKey,
    required this.accent,
    required this.featuresKeys,
    required this.limits,
  });

  final PlanTier tier;

  /// Localization key for the plan's display name.
  final String titleKey;

  /// Monthly price in [currencySymbol] units. 0 for the free tier.
  final num priceMonthly;

  /// Yearly price (already discounted). 0 for the free tier.
  final num priceYearly;

  final String currencySymbol;

  /// Short marketing line (localization key), e.g. "For everyday use".
  final String tagKey;

  /// Brand accent — used for card border / button gradient.
  final Color accent;

  /// Localization keys for the bullet-pointed perks shown on the plan card.
  final List<String> featuresKeys;

  /// Per-feature monthly cap. Missing entries fall back to "unlimited".
  final Map<BillableFeature, MonthlyLimit> limits;

  MonthlyLimit limitFor(BillableFeature feature) =>
      limits.containsKey(feature) ? limits[feature] : null;

  bool isUnlimited(BillableFeature feature) => limitFor(feature) == null;
}

/// Static plan definitions. Edit here to change pricing or limits — UI reads
/// everything from this catalog.
class PlanCatalog {
  const PlanCatalog._();

  static const String currencyTRY = '₺';

  static const Plan free = Plan(
    tier: PlanTier.free,
    titleKey: 'plan_free_title',
    priceMonthly: 0,
    priceYearly: 0,
    currencySymbol: currencyTRY,
    tagKey: 'plan_free_tag',
    accent: Color(0xFF6E6E6E),
    featuresKeys: [
      'plan_feature_free_ocr',
      'plan_feature_free_ai',
      'plan_feature_free_voice',
      'plan_feature_free_helpbot',
      'plan_feature_free_calendar',
    ],
    limits: {
      BillableFeature.ocrScheduleImport: 3,
      BillableFeature.aiAssistantPrompt: 50,
      BillableFeature.voiceTranscription: 5,
      BillableFeature.helpBotQuestion: 30,
    },
  );

  static const Plan plus = Plan(
    tier: PlanTier.plus,
    titleKey: 'plan_plus_title',
    priceMonthly: 49,
    priceYearly: 499,
    currencySymbol: currencyTRY,
    tagKey: 'plan_plus_tag',
    accent: Color(0xFFFFB300), // AppColors.gold
    featuresKeys: [
      'plan_feature_plus_ocr',
      'plan_feature_plus_ai',
      'plan_feature_plus_voice',
      'plan_feature_plus_helpbot',
      'plan_feature_plus_insights',
      'plan_feature_plus_support',
    ],
    limits: {
      BillableFeature.ocrScheduleImport: 30,
      BillableFeature.aiAssistantPrompt: 500,
      BillableFeature.voiceTranscription: 100,
      // Unlimited help bot — omitted from map.
    },
  );

  static const Plan pro = Plan(
    tier: PlanTier.pro,
    titleKey: 'plan_pro_title',
    priceMonthly: 149,
    priceYearly: 1499,
    currencySymbol: currencyTRY,
    tagKey: 'plan_pro_tag',
    accent: Color(0xFFFFD54F), // AppColors.goldLight
    featuresKeys: [
      'plan_feature_pro_unlimited',
      'plan_feature_pro_team',
      'plan_feature_pro_priority',
      'plan_feature_pro_early',
      'plan_feature_pro_support',
    ],
    // All limits unlimited — empty map.
    limits: {},
  );

  static const List<Plan> all = [free, plus, pro];

  static Plan forTier(PlanTier tier) {
    switch (tier) {
      case PlanTier.free:
        return free;
      case PlanTier.plus:
        return plus;
      case PlanTier.pro:
        return pro;
    }
  }
}
