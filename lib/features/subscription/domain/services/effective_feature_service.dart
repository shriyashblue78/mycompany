import '../models/company_subscription_model.dart';
import '../models/subscription_plan.dart';
import '../models/subscription_duration_type.dart';
import 'subscription_service.dart';

class EffectiveFeatureService {
  /// Resolves the final list of enabled feature keys following the hierarchy:
  /// PLAN DEFAULT → COMPANY OVERRIDE → EFFECTIVE FEATURE ACCESS
  static List<String> calculateEffectiveFeatures({
    required List<String> planDefaultFeatures,
    Map<String, bool> featureOverrides = const {},
    List<String> addonFeatures = const [],
  }) {
    final effective = Set<String>.from(planDefaultFeatures);

    featureOverrides.forEach((featureKey, isExplicitlyEnabled) {
      if (isExplicitlyEnabled) {
        effective.add(featureKey);
      } else {
        effective.remove(featureKey);
      }
    });

    if (addonFeatures.isNotEmpty) {
      effective.addAll(addonFeatures);
    }

    return effective.toList();
  }

  /// Assigns a new plan to a company subscription and automatically populates its mapped default features.
  static CompanySubscriptionModel applyPlanToSubscription({
    required CompanySubscriptionModel currentSubscription,
    required SubscriptionPlan plan,
    SubscriptionDurationType durationType = SubscriptionDurationType.oneMonth,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now();
    final expiry = SubscriptionService.calculateExpiryDate(start, durationType);

    return currentSubscription.copyWith(
      planId: plan.planId,
      planName: plan.planName,
      subscriptionPlan: durationType.label,
      startDate: start,
      expiryDate: expiry,
      enabledFeatures: plan.enabledFeatures,
      updatedAt: DateTime.now(),
    );
  }

  /// Updates a Super Admin feature override for a specific feature key (explicit ON or explicit OFF).
  static CompanySubscriptionModel updateFeatureOverride({
    required CompanySubscriptionModel currentSubscription,
    required String featureKey,
    required bool isEnabled,
  }) {
    final updatedOverrides = Map<String, bool>.from(currentSubscription.featureOverrides);
    updatedOverrides[featureKey] = isEnabled;

    return currentSubscription.copyWith(
      featureOverrides: updatedOverrides,
      updatedAt: DateTime.now(),
    );
  }
}
