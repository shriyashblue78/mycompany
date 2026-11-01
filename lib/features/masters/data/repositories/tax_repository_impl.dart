import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/tax_model.dart';
import '../../domain/repositories/tax_repository.dart';

class TaxRepositoryImpl implements TaxRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _taxesRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('taxes');
  }

  @override
  Future<void> createTax(String companyId, TaxModel tax) async {
    final docRef = tax.taxId.isEmpty
        ? _taxesRef(companyId).doc()
        : _taxesRef(companyId).doc(tax.taxId);

    await docRef.set(tax.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateTax(String companyId, TaxModel tax) async {
    await _taxesRef(companyId)
        .doc(tax.taxId)
        .update(tax.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteTax(String companyId, String taxId) async {
    await _taxesRef(companyId).doc(taxId).delete();
  }

  @override
  Stream<List<TaxModel>> streamTaxes(String companyId) {
    return _taxesRef(companyId)
        .orderBy('taxCategory')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TaxModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<TaxModel?> streamTaxById(String companyId, String taxId) {
    return _taxesRef(companyId).doc(taxId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return TaxModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<bool> isTaxCategoryTaken(String companyId, String taxCategory, {String? excludeTaxId}) async {
    final clean = taxCategory.trim().toLowerCase();
    final snap = await _taxesRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeTaxId != null && doc.id == excludeTaxId) continue;
      final existing = (doc.data()['taxCategory'] ?? doc.data()['taxName'] ?? '').toString().trim().toLowerCase();
      if (existing == clean) return true;
    }
    return false;
  }

  @override
  Future<bool> isTaxReferenced(String companyId, String taxId, String taxCategory) async {
    final cleanCategory = taxCategory.trim();
    try {
      // 1. Check sales
      final salesSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('sales')
          .where('taxCategory', isEqualTo: cleanCategory)
          .limit(1)
          .get();
      if (salesSnap.docs.isNotEmpty) return true;

      // 2. Check purchases
      final purchaseSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('purchases')
          .where('taxCategory', isEqualTo: cleanCategory)
          .limit(1)
          .get();
      if (purchaseSnap.docs.isNotEmpty) return true;

      // 3. Check items / inventory
      final invSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('taxCategory', isEqualTo: cleanCategory)
          .limit(1)
          .get();
      if (invSnap.docs.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}
