import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/payment_transaction_model.dart';
import '../../domain/models/subscription_history_model.dart';
import '../../domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createPaymentTransaction(PaymentTransactionModel payment) async {
    if (payment.companyId.isEmpty) {
      throw ArgumentError('companyId cannot be empty when creating payment transaction.');
    }
    await _firestore
        .collection('companies')
        .doc(payment.companyId)
        .collection('payments')
        .doc(payment.paymentId)
        .set(payment.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> updatePaymentStatus({
    required String companyId,
    required String paymentId,
    required PaymentStatus status,
    String? transactionReference,
  }) async {
    if (companyId.isEmpty || paymentId.isEmpty) return;

    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (transactionReference != null) {
      updates['transactionReference'] = transactionReference;
    }

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('payments')
        .doc(paymentId)
        .update(updates);
  }

  @override
  Stream<List<PaymentTransactionModel>> streamCompanyPayments(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentTransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    }).handleError((_) => <PaymentTransactionModel>[]);
  }

  @override
  Future<void> addSubscriptionHistory(SubscriptionHistoryModel history) async {
    if (history.companyId.isEmpty) return;
    await _firestore
        .collection('companies')
        .doc(history.companyId)
        .collection('subscription_history')
        .doc(history.historyId)
        .set(history.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<List<SubscriptionHistoryModel>> streamSubscriptionHistory(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('subscription_history')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubscriptionHistoryModel.fromMap(doc.data(), doc.id))
          .toList();
    }).handleError((_) => <SubscriptionHistoryModel>[]);
  }
}
