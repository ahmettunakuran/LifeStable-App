import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/plan_catalog.dart';

/// Thrown when a [BillableFeature] is invoked but the user's monthly quota
/// for it is exhausted. Carries the feature + the limit so the caller can
/// build a useful "X / Y this month" message.
class QuotaExceededException implements Exception {
  QuotaExceededException(this.feature, this.limit);

  final BillableFeature feature;
  final int limit;

  @override
  String toString() =>
      'QuotaExceededException(${feature.id}: limit=$limit reached)';
}

/// Immutable snapshot of usage for a single feature in the current month.
@immutable
class UsageSnapshot {
  const UsageSnapshot({
    required this.feature,
    required this.used,
    required this.limit,
  });

  final BillableFeature feature;
  final int used;

  /// `null` means unlimited.
  final int? limit;

  bool get isUnlimited => limit == null;
  bool get isExhausted => !isUnlimited && used >= limit!;
  int get remaining => isUnlimited ? -1 : (limit! - used).clamp(0, limit!);

  /// 0..1, or null when unlimited.
  double? get progress {
    if (isUnlimited || limit == 0) return null;
    return (used / limit!).clamp(0.0, 1.0);
  }
}

/// Persists monthly per-feature counters in [SharedPreferences].
///
/// Singleton so widgets in different parts of the tree share the same
/// [ValueListenable] and refresh together. Counter keys include the
/// year-month, so usage rolls over automatically on the first call in a new
/// month — no scheduled job needed.
///
/// The current plan is also stored here. Until a payment flow exists,
/// everyone is on [PlanTier.free]; the setter is present so test/dev builds
/// or future entitlement code can flip it.
class UsageTracker {
  UsageTracker._();
  static final UsageTracker instance = UsageTracker._();

  static const String _prefsCountPrefix = 'usage_count_';
  static const String _prefsPlanKey = 'subscription_plan_tier';

  /// Bumps whenever any counter changes so listeners can refresh.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  PlanTier _currentTier = PlanTier.free;
  PlanTier get currentTier => _currentTier;
  Plan get currentPlan => PlanCatalog.forTier(_currentTier);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsPlanKey);
    if (stored != null) {
      _currentTier = PlanTier.values.firstWhere(
        (t) => t.name == stored,
        orElse: () => PlanTier.free,
      );
    }
    _loaded = true;
  }

  /// Reads usage for [feature] in the current month against the current plan.
  Future<UsageSnapshot> snapshot(BillableFeature feature) async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_counterKey(feature)) ?? 0;
    return UsageSnapshot(
      feature: feature,
      used: used,
      limit: currentPlan.limitFor(feature),
    );
  }

  /// Pre-flight check used by UI to decide whether to enable an action
  /// without actually consuming a slot.
  Future<bool> canConsume(BillableFeature feature) async {
    final s = await snapshot(feature);
    return s.isUnlimited || !s.isExhausted;
  }

  /// Atomically reserve one use of [feature]. Returns the new snapshot so
  /// callers can show "x of y left" without a second read.
  ///
  /// Throws [QuotaExceededException] when the user is out of quota.
  Future<UsageSnapshot> consume(BillableFeature feature) async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    final key = _counterKey(feature);
    final current = prefs.getInt(key) ?? 0;
    final limit = currentPlan.limitFor(feature);
    if (limit != null && current >= limit) {
      throw QuotaExceededException(feature, limit);
    }
    final next = current + 1;
    await prefs.setInt(key, next);
    revision.value++;
    return UsageSnapshot(feature: feature, used: next, limit: limit);
  }

  /// Refund a previously-consumed slot, e.g. when the API call ultimately
  /// failed. Never goes below zero.
  Future<void> refund(BillableFeature feature) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _counterKey(feature);
    final current = prefs.getInt(key) ?? 0;
    if (current <= 0) return;
    await prefs.setInt(key, current - 1);
    revision.value++;
  }

  /// Wipes all counters for the current month — handy for QA/dev menus.
  /// Not exposed in production UI.
  Future<void> debugResetCurrentMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final monthSuffix = _monthSuffix();
    final keys = prefs.getKeys()
        .where((k) => k.startsWith(_prefsCountPrefix) && k.endsWith(monthSuffix))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    revision.value++;
  }

  /// Override the active plan. Plumbed in so a future entitlement service
  /// (App Store / Google Play / server check) can call it after a successful
  /// purchase. No payment flow yet — manual use only.
  Future<void> setPlanTier(PlanTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPlanKey, tier.name);
    _currentTier = tier;
    revision.value++;
  }

  String _counterKey(BillableFeature feature) =>
      '$_prefsCountPrefix${feature.id}_${_monthSuffix()}';

  static String _monthSuffix() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }
}
