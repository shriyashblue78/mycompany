import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/company_modules.dart';
import '../../domain/models/company_subscription_model.dart';
import '../../domain/models/subscription_plan.dart';
import '../../domain/models/subscription_plan_config.dart';
import '../../domain/models/app_feature.dart';
import '../../domain/models/payment_transaction_model.dart';
import '../../domain/models/subscription_history_model.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/repositories/subscription_plan_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../data/repositories/subscription_plan_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';

/// Provider for SubscriptionRepository instance
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl();
});

/// Provider for SubscriptionPlanRepository instance
final subscriptionPlanRepositoryProvider = Provider<SubscriptionPlanRepository>((ref) {
  return SubscriptionPlanRepositoryImpl();
});

/// Provider for PaymentRepository instance
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl();
});

/// Master feature list provider
final masterFeaturesProvider = Provider<List<AppFeature>>((ref) {
  return FeatureMaster.allFeatures;
});

/// Centralized duration configurations (legacy support)
final availableSubscriptionPlansProvider = Provider<List<SubscriptionPlanConfig>>((ref) {
  return CentralizedSubscriptionConfig.initialPlans;
});

/// Stream of all configurable subscription plans (Basic, Professional, Enterprise, etc.)
final subscriptionPlansStreamProvider = StreamProvider<List<SubscriptionPlan>>((ref) {
  return ref.watch(subscriptionPlanRepositoryProvider).streamSubscriptionPlans();
});

/// Family StreamProvider to get subscription by companyId
final companySubscriptionStreamProvider = StreamProvider.family<CompanySubscriptionModel?, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(null);
  return ref.watch(subscriptionRepositoryProvider).streamCompanySubscription(companyId);
});

/// StreamProvider for current logged-in user's company subscription
final currentCompanySubscriptionProvider = StreamProvider<CompanySubscriptionModel?>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(subscriptionRepositoryProvider).streamCompanySubscription(companyId);
});

/// Stream of effective enabled features for a specific company following:
/// PLAN DEFAULT → COMPANY OVERRIDE → EFFECTIVE FEATURE ACCESS
final companyEffectiveFeaturesStreamProvider = StreamProvider.family<List<String>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(CompanyModules.all);
  final subAsync = ref.watch(companySubscriptionStreamProvider(companyId));
  return subAsync.when(
    data: (sub) {
      if (sub == null) return Stream.value(CompanyModules.all); // Backward compatibility
      return Stream.value(sub.effectiveFeatures);
    },
    loading: () => Stream.value(CompanyModules.all),
    error: (_, __) => Stream.value(CompanyModules.all),
  );
});

/// Stream of payment transactions for a company
final companyPaymentsStreamProvider = StreamProvider.family<List<PaymentTransactionModel>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  return ref.watch(paymentRepositoryProvider).streamCompanyPayments(companyId);
});

/// Stream of subscription history entries for a company
final companySubscriptionHistoryStreamProvider = StreamProvider.family<List<SubscriptionHistoryModel>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  return ref.watch(paymentRepositoryProvider).streamSubscriptionHistory(companyId);
});
