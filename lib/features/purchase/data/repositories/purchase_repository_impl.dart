import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/repositories/purchase_repository.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createPurchase(String companyId, PurchaseModel purchase) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('purchases')
        .doc(purchase.purchaseId)
        .set(purchase.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updatePurchase(String companyId, PurchaseModel purchase) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('purchases')
        .doc(purchase.purchaseId)
        .update(purchase.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deletePurchase(String companyId, String purchaseId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('purchases')
        .doc(purchaseId)
        .delete();
  }

  @override
  Stream<List<PurchaseModel>> streamPurchases(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('purchases')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PurchaseModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<PurchaseModel?> streamPurchaseById(String companyId, String purchaseId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('purchases')
        .doc(purchaseId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return PurchaseModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
