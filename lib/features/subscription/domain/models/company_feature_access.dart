import '../../../auth/domain/models/company_modules.dart';

/// Class encapsulating the evaluation of effective company feature access:
/// PLAN DEFAULT → COMPANY OVERRIDE → EFFECTIVE FEATURE ACCESS
class CompanyFeatureAccess {
  final String companyId;
  final String planId;
  final List<String> planDefaultFeatures;
  final Map<String, bool> featureOverrides;

  const CompanyFeatureAccess({
    required this.companyId,
    required this.planId,
    this.planDefaultFeatures = const [],
    this.featureOverrides = const {},
  });

  /// Calculate final effective features available to the company:
  /// 1. Start with plan default features
  /// 2. Apply Super Admin feature overrides (true = force ON, false = force OFF)
  /// 3. Produce effective feature list
  List<String> get effectiveFeatures {
    // If no plan is assigned (legacy backward compatibility), default to all modules
    final baseFeatures = planDefaultFeatures.isNotEmpty
        ? Set<String>.from(planDefaultFeatures)
        : Set<String>.from(CompanyModules.all);

    featureOverrides.forEach((featureKey, isExplicitlyEnabled) {
      if (isExplicitlyEnabled) {
        baseFeatures.add(featureKey);
      } else {
        baseFeatures.remove(featureKey);
      }
    });

    return baseFeatures.toList();
  }

  /// Check if a specific module/feature is enabled for the company
  bool isFeatureEnabled(String featureKey) {
    if (featureOverrides.containsKey(featureKey)) {
      return featureOverrides[featureKey] == true;
    }
    if (planDefaultFeatures.isNotEmpty) {
      return planDefaultFeatures.contains(featureKey);
    }
    // Backward compatibility fallback
    return CompanyModules.all.contains(featureKey);
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'planId': planId,
      'planDefaultFeatures': planDefaultFeatures,
      'featureOverrides': featureOverrides,
      'effectiveFeatures': effectiveFeatures,
    };
  }

  factory CompanyFeatureAccess.fromMap(Map<String, dynamic> map) {
    final defaultsRaw = map['planDefaultFeatures'] as List?;
    final defaults = defaultsRaw != null ? List<String>.from(defaultsRaw) : <String>[];

    final overridesRaw = map['featureOverrides'] as Map?;
    final overrides = overridesRaw != null
        ? overridesRaw.map((k, v) => MapEntry(k.toString(), v == true))
        : <String, bool>{};

    return CompanyFeatureAccess(
      companyId: (map['companyId'] ?? '') as String,
      planId: (map['planId'] ?? 'basic') as String,
      planDefaultFeatures: defaults,
      featureOverrides: overrides,
    );
  }
}
