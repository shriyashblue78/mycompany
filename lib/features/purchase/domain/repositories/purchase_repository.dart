import '../models/purchase_model.dart';

abstract class PurchaseRepository {
  Future<void> createPurchase(String companyId, PurchaseModel purchase);
  Future<void> updatePurchase(String companyId, PurchaseModel purchase);
  Future<void> deletePurchase(String companyId, String purchaseId);
  Stream<List<PurchaseModel>> streamPurchases(String companyId);
  Stream<PurchaseModel?> streamPurchaseById(String companyId, String purchaseId);
}
