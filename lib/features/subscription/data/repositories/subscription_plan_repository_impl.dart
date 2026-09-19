import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/subscription_plan.dart';
import '../../domain/repositories/subscription_plan_repository.dart';

class SubscriptionPlanRepositoryImpl implements SubscriptionPlanRepository {
  final FirebaseFirestore _firestore;

  SubscriptionPlanRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    try {
      final snapshot = await _firestore.collection('subscription_plans').get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => SubscriptionPlan.fromMap(doc.data(), doc.id))
            .toList();
      }
    } catch (_) {}
    return DefaultSubscriptionPlans.initialPlans;
  }

  @override
  Future<SubscriptionPlan?> getPlanById(String planId) async {
    try {
      final doc = await _firestore.collection('subscription_plans').doc(planId).get();
      if (doc.exists && doc.data() != null) {
        return SubscriptionPlan.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    for (final plan in DefaultSubscriptionPlans.initialPlans) {
      if (plan.planId == planId) return plan;
    }
    return DefaultSubscriptionPlans.basic;
  }

  @override
  Stream<List<SubscriptionPlan>> streamSubscriptionPlans() {
    return _firestore
        .collection('subscription_plans')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => SubscriptionPlan.fromMap(doc.data(), doc.id))
            .toList();
      }
      return DefaultSubscriptionPlans.initialPlans;
    }).handleError((_) => DefaultSubscriptionPlans.initialPlans);
  }

  @override
  Future<void> savePlan(SubscriptionPlan plan) async {
    await _firestore
        .collection('subscription_plans')
        .doc(plan.planId)
        .set(plan.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> updatePlan(SubscriptionPlan plan) async {
    await _firestore
        .collection('subscription_plans')
        .doc(plan.planId)
        .update(plan.toMap());
  }
}
