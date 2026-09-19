import '../models/subscription_plan.dart';

abstract class SubscriptionPlanRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans();
  Future<SubscriptionPlan?> getPlanById(String planId);
  Stream<List<SubscriptionPlan>> streamSubscriptionPlans();
  Future<void> savePlan(SubscriptionPlan plan);
  Future<void> updatePlan(SubscriptionPlan plan);
}
