import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/sale_model.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createSale(String companyId, SaleModel sale) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales')
        .doc(sale.saleId)
        .set(sale.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateSale(String companyId, SaleModel sale) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales')
        .doc(sale.saleId)
        .update(sale.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteSale(String companyId, String saleId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales')
        .doc(saleId)
        .delete();
  }

  @override
  Stream<List<SaleModel>> streamSales(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SaleModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<SaleModel?> streamSaleById(String companyId, String saleId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales')
        .doc(saleId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return SaleModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
