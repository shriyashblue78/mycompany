import '../models/payment_transaction_model.dart';
import '../models/subscription_history_model.dart';

abstract class PaymentRepository {
  Future<void> createPaymentTransaction(PaymentTransactionModel payment);
  Future<void> updatePaymentStatus({
    required String companyId,
    required String paymentId,
    required PaymentStatus status,
    String? transactionReference,
  });
  Stream<List<PaymentTransactionModel>> streamCompanyPayments(String companyId);
  Future<void> addSubscriptionHistory(SubscriptionHistoryModel history);
  Stream<List<SubscriptionHistoryModel>> streamSubscriptionHistory(String companyId);
}
