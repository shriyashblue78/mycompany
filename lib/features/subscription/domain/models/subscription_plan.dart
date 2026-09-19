import 'subscription_duration_type.dart';
import '../../../auth/domain/models/company_modules.dart';

/// Mapping entity connecting a Subscription Plan to its default enabled features.
class PlanFeature {
  final String planId;
  final String featureKey;
  final bool isIncludedByDefault;

  const PlanFeature({
    required this.planId,
    required this.featureKey,
    this.isIncludedByDefault = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'featureKey': featureKey,
      'isIncludedByDefault': isIncludedByDefault,
    };
  }

  factory PlanFeature.fromMap(Map<String, dynamic> map) {
    return PlanFeature(
      planId: (map['planId'] ?? '') as String,
      featureKey: (map['featureKey'] ?? '') as String,
      isIncludedByDefault: (map['isIncludedByDefault'] ?? true) as bool,
    );
  }
}

/// Architectural enumeration for future pricing models.
enum PricingModelType {
  fixedPackage,   // OPTION A: Basic / Professional / Enterprise fixed packages
  perModule,      // OPTION B: Individual feature selection with per-module pricing
  basePlusAddon;  // OPTION C: Base tier + optional add-on modules

  static PricingModelType fromString(String val) {
    return PricingModelType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => PricingModelType.fixedPackage,
    );
  }
}

/// Flexible Subscription Plan model holding plan definition, duration options, enabled features, and extensibility slots.
class SubscriptionPlan {
  final String planId;
  final String planName;
  final String description;
  final double? price;
  final bool isActive;
  final List<SubscriptionDurationType> durationOptions;
  final List<String> enabledFeatures;

  /// Configurable tier/order for plan hierarchy.
  /// Lower number = lower tier (e.g., Basic=1, Professional=2, Enterprise=3).
  /// Plans with tier 0 (default) are treated as unordered / shown to all.
  final int tier;

  // Extensibility fields for future pricing & module structures (Options A, B, C)
  final PricingModelType pricingModel;
  final List<String> addonFeatures;
  final Map<String, double>? modulePrices;

  const SubscriptionPlan({
    required this.planId,
    required this.planName,
    required this.description,
    this.price,
    this.isActive = true,
    this.tier = 0,
    this.durationOptions = const [
      SubscriptionDurationType.oneMonth,
      SubscriptionDurationType.threeMonths,
      SubscriptionDurationType.sixMonths,
      SubscriptionDurationType.oneYear,
    ],
    this.enabledFeatures = const [],
    this.pricingModel = PricingModelType.fixedPackage,
    this.addonFeatures = const [],
    this.modulePrices,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, String id) {
    final durationsRaw = map['durationOptions'] as List?;
    final durations = durationsRaw != null
        ? durationsRaw
            .map((d) => SubscriptionDurationType.fromLabel(d.toString()))
            .toList()
        : const [
            SubscriptionDurationType.oneMonth,
            SubscriptionDurationType.threeMonths,
            SubscriptionDurationType.sixMonths,
            SubscriptionDurationType.oneYear,
          ];

    final featuresRaw = map['enabledFeatures'] as List?;
    final enabledFeatures = featuresRaw != null
        ? List<String>.from(featuresRaw)
        : <String>[];

    final addonsRaw = map['addonFeatures'] as List?;
    final addonFeatures = addonsRaw != null ? List<String>.from(addonsRaw) : <String>[];

    return SubscriptionPlan(
      planId: id,
      planName: (map['planName'] ?? id) as String,
      description: (map['description'] ?? '') as String,
      price: (map['price'] as num?)?.toDouble(),
      isActive: (map['isActive'] ?? true) as bool,
      tier: (map['tier'] as num?)?.toInt() ?? 0,
      durationOptions: durations,
      enabledFeatures: enabledFeatures,
      pricingModel: PricingModelType.fromString((map['pricingModel'] ?? 'fixedPackage') as String),
      addonFeatures: addonFeatures,
      modulePrices: (map['modulePrices'] as Map?)?.cast<String, double>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'planName': planName,
      'description': description,
      'price': price,
      'isActive': isActive,
      'tier': tier,
      'durationOptions': durationOptions.map((d) => d.label).toList(),
      'enabledFeatures': enabledFeatures,
      'pricingModel': pricingModel.name,
      'addonFeatures': addonFeatures,
      'modulePrices': modulePrices,
    };
  }

  SubscriptionPlan copyWith({
    String? planId,
    String? planName,
    String? description,
    double? price,
    bool? isActive,
    int? tier,
    List<SubscriptionDurationType>? durationOptions,
    List<String>? enabledFeatures,
    PricingModelType? pricingModel,
    List<String>? addonFeatures,
    Map<String, double>? modulePrices,
  }) {
    return SubscriptionPlan(
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      description: description ?? this.description,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      tier: tier ?? this.tier,
      durationOptions: durationOptions ?? this.durationOptions,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
      pricingModel: pricingModel ?? this.pricingModel,
      addonFeatures: addonFeatures ?? this.addonFeatures,
      modulePrices: modulePrices ?? this.modulePrices,
    );
  }
}

/// Centralized Configurable Default Subscription Plans (Examples: Basic, Professional, Enterprise).
class DefaultSubscriptionPlans {
  static final SubscriptionPlan basic = SubscriptionPlan(
    planId: 'basic',
    planName: 'Basic',
    description: 'Core personnel, attendance, task, and leave tracking',
    price: null, // Nullable/configurable for future pricing
    isActive: true,
    tier: 1, // Tier 1 = lowest/entry plan
    enabledFeatures: const [
      CompanyModules.employees,
      CompanyModules.attendance,
      CompanyModules.tasks,
      CompanyModules.leaves,
      CompanyModules.notifications,
      CompanyModules.documents,
    ],
  );

  static final SubscriptionPlan professional = SubscriptionPlan(
    planId: 'professional',
    planName: 'Professional',
    description: 'Complete ERP operations including sales, inventory, purchase, and project tracker',
    price: null,
    isActive: true,
    tier: 2, // Tier 2 = mid plan
    enabledFeatures: const [
      CompanyModules.employees,
      CompanyModules.attendance,
      CompanyModules.tasks,
      CompanyModules.leaves,
      CompanyModules.production,
      CompanyModules.inventory,
      CompanyModules.lowStock,
      CompanyModules.purchase,
      CompanyModules.sales,
      CompanyModules.inwardOutward,
      CompanyModules.billing,
      CompanyModules.reports,
      CompanyModules.notifications,
      CompanyModules.documents,
      CompanyModules.projectTracker,
    ],
  );

  static final SubscriptionPlan enterprise = SubscriptionPlan(
    planId: 'enterprise',
    planName: 'Enterprise',
    description: 'Full suite including advanced engineering, tooling, CNC programs, machines, and analytics',
    price: null,
    isActive: true,
    tier: 3, // Tier 3 = highest/enterprise plan
    enabledFeatures: List<String>.unmodifiable(CompanyModules.all),
  );

  static final List<SubscriptionPlan> initialPlans = [
    basic,
    professional,
    enterprise,
  ];
}
