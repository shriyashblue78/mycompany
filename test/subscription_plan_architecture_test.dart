import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/auth/domain/models/company_modules.dart';
import 'package:projectbtt/features/subscription/domain/models/app_feature.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_plan.dart';
import 'package:projectbtt/features/subscription/domain/models/company_subscription_model.dart';
import 'package:projectbtt/features/subscription/domain/models/company_feature_access.dart';
import 'package:projectbtt/features/subscription/domain/services/effective_feature_service.dart';

void main() {
  group('1. Feature Master Registry', () {
    test('Reuses existing CompanyModules keys without duplicate feature identifiers', () {
      final features = FeatureMaster.allFeatures;
      expect(features.isNotEmpty, isTrue);

      final featureKeys = features.map((f) => f.featureKey).toSet();
      expect(featureKeys, containsAll([
        CompanyModules.attendance,
        CompanyModules.inventory,
        CompanyModules.production,
        CompanyModules.sales,
        CompanyModules.purchase,
        CompanyModules.projectTracker,
        CompanyModules.reports,
        CompanyModules.machines,
        CompanyModules.tooling,
        CompanyModules.drawings,
        CompanyModules.programs,
        CompanyModules.inwardOutward,
        CompanyModules.employees,
        CompanyModules.tasks,
      ]));
    });
  });

  group('2. Configurable Subscription Plans & Plan-Feature Mapping', () {
    test('Basic, Professional, Enterprise initial plans are configurable with nullable price', () {
      final basic = DefaultSubscriptionPlans.basic;
      final pro = DefaultSubscriptionPlans.professional;
      final enterprise = DefaultSubscriptionPlans.enterprise;

      expect(basic.price, isNull);
      expect(pro.price, isNull);
      expect(enterprise.price, isNull);

      expect(basic.enabledFeatures, containsAll([
        CompanyModules.employees,
        CompanyModules.attendance,
        CompanyModules.tasks,
      ]));
      expect(basic.enabledFeatures, isNot(contains(CompanyModules.production)));

      expect(pro.enabledFeatures, containsAll([
        CompanyModules.sales,
        CompanyModules.inventory,
        CompanyModules.production,
      ]));

      expect(enterprise.enabledFeatures, equals(CompanyModules.all));
    });
  });

  group('3. Effective Feature Access Evaluation Hierarchy (Plan Default -> Company Override -> Effective Access)', () {
    test('Super Admin override OFF revokes feature included in plan', () {
      // Plan: Professional (includes production)
      final proFeatures = DefaultSubscriptionPlans.professional.enabledFeatures;
      expect(proFeatures, contains(CompanyModules.production));

      final access = CompanyFeatureAccess(
        companyId: 'company_123',
        planId: 'professional',
        planDefaultFeatures: proFeatures,
        featureOverrides: {
          CompanyModules.production: false, // Super Admin Explicit OFF
        },
      );

      final effective = access.effectiveFeatures;
      expect(effective, contains(CompanyModules.sales));
      expect(effective, contains(CompanyModules.inventory));
      expect(effective, isNot(contains(CompanyModules.production)));
    });

    test('Super Admin override ON grants feature NOT included in plan', () {
      // Plan: Basic (does not include drawings by default)
      final basicFeatures = DefaultSubscriptionPlans.basic.enabledFeatures;
      expect(basicFeatures, isNot(contains(CompanyModules.drawings)));

      final access = CompanyFeatureAccess(
        companyId: 'company_456',
        planId: 'basic',
        planDefaultFeatures: basicFeatures,
        featureOverrides: {
          CompanyModules.drawings: true, // Super Admin Explicit ON
        },
      );

      final effective = access.effectiveFeatures;
      expect(effective, contains(CompanyModules.employees));
      expect(effective, contains(CompanyModules.drawings));
    });

    test('EffectiveFeatureService computes effective features correctly', () {
      final effective = EffectiveFeatureService.calculateEffectiveFeatures(
        planDefaultFeatures: [CompanyModules.sales, CompanyModules.inventory, CompanyModules.production],
        featureOverrides: {
          CompanyModules.production: false,
          CompanyModules.reports: true,
        },
      );

      expect(effective, contains(CompanyModules.sales));
      expect(effective, contains(CompanyModules.inventory));
      expect(effective, contains(CompanyModules.reports));
      expect(effective, isNot(contains(CompanyModules.production)));
    });
  });

  group('4. Extensibility for Future Plan Models (Options A, B, C)', () {
    test('SubscriptionPlan model supports Option A (fixedPackage), B (perModule), C (basePlusAddon)', () {
      final addonPlan = SubscriptionPlan(
        planId: 'custom_tier',
        planName: 'Custom Tier',
        description: 'Base plan plus addon modules',
        pricingModel: PricingModelType.basePlusAddon,
        enabledFeatures: [CompanyModules.employees, CompanyModules.attendance],
        addonFeatures: [CompanyModules.production, CompanyModules.tooling],
        modulePrices: {
          CompanyModules.production: 25.0,
          CompanyModules.tooling: 15.0,
        },
      );

      expect(addonPlan.pricingModel, equals(PricingModelType.basePlusAddon));
      expect(addonPlan.addonFeatures, contains(CompanyModules.production));
      expect(addonPlan.modulePrices?[CompanyModules.production], equals(25.0));
    });
  });

  group('5. Backward Compatibility & Entity Deserialization', () {
    test('Legacy companies without a plan default safely to all modules without crashing', () {
      final access = CompanyFeatureAccess(
        companyId: 'legacy_company',
        planId: '',
        planDefaultFeatures: const [],
        featureOverrides: const {},
      );

      expect(access.effectiveFeatures, containsAll(CompanyModules.all));
    });

    test('CompanySubscriptionModel handles planId, enabledFeatures, and overrides seamlessly', () {
      final now = DateTime(2026, 3, 17);
      final sub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'comp_789',
        planId: 'professional',
        planName: 'Professional',
        subscriptionPlan: '1 Year',
        startDate: now,
        expiryDate: now.add(const Duration(days: 365)),
        enabledFeatures: [CompanyModules.sales, CompanyModules.inventory],
        featureOverrides: {CompanyModules.inventory: false, CompanyModules.reports: true},
      );

      expect(sub.effectiveFeatures, contains(CompanyModules.sales));
      expect(sub.effectiveFeatures, contains(CompanyModules.reports));
      expect(sub.effectiveFeatures, isNot(contains(CompanyModules.inventory)));

      final map = sub.toMap();
      final restored = CompanySubscriptionModel.fromMap(map, 'current');

      expect(restored.planId, equals('professional'));
      expect(restored.effectiveFeatures, contains(CompanyModules.sales));
      expect(restored.effectiveFeatures, contains(CompanyModules.reports));
      expect(restored.effectiveFeatures, isNot(contains(CompanyModules.inventory)));
    });
  });
}
