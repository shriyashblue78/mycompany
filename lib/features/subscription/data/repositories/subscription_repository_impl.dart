import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/company_subscription_model.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final FirebaseFirestore _firestore;

  SubscriptionRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<CompanySubscriptionModel?> getCompanySubscription(String companyId) async {
    if (companyId.isEmpty) return null;
    try {
      final doc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('subscription')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        return CompanySubscriptionModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // Safe fallback for backward compatibility
      return null;
    }
  }

  @override
  Stream<CompanySubscriptionModel?> streamCompanySubscription(String companyId) {
    if (companyId.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('subscription')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanySubscriptionModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    }).handleError((_) => null);
  }

  @override
  Future<void> setCompanySubscription(CompanySubscriptionModel subscription) async {
    if (subscription.companyId.isEmpty) {
      throw ArgumentError('companyId cannot be empty when setting subscription.');
    }
    await _firestore
        .collection('companies')
        .doc(subscription.companyId)
        .collection('subscription')
        .doc('current')
        .set(subscription.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> updateCompanySubscription(CompanySubscriptionModel subscription) async {
    if (subscription.companyId.isEmpty) {
      throw ArgumentError('companyId cannot be empty when updating subscription.');
    }
    await _firestore
        .collection('companies')
        .doc(subscription.companyId)
        .collection('subscription')
        .doc('current')
        .update(subscription.toMap());
  }
}
