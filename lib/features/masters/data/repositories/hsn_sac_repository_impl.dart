import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/hsn_sac_model.dart';
import '../../domain/repositories/hsn_sac_repository.dart';

class HsnSacRepositoryImpl implements HsnSacRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('hsn_sac');
  }

  @override
  Future<void> createHsnSac(String companyId, HsnSacModel item) async {
    final docRef = item.hsnSacId.isEmpty
        ? _ref(companyId).doc()
        : _ref(companyId).doc(item.hsnSacId);

    await docRef.set(item.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateHsnSac(String companyId, HsnSacModel item) async {
    await _ref(companyId)
        .doc(item.hsnSacId)
        .update(item.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteHsnSac(String companyId, String hsnSacId) async {
    await _ref(companyId).doc(hsnSacId).delete();
  }

  @override
  Stream<List<HsnSacModel>> streamHsnSac(String companyId) {
    return _ref(companyId)
        .orderBy('code')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return HsnSacModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isCodeTaken(String companyId, String code, {String? excludeId}) async {
    final clean = code.trim().toLowerCase();
    final snap = await _ref(companyId).get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final existing = (doc.data()['code'] ?? '').toString().trim().toLowerCase();
      if (existing == clean) return true;
    }
    return false;
  }

  @override
  Future<bool> isHsnSacReferenced(String companyId, String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return false;
    try {
      // 1. Check inventory items
      final invSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('hsnSac', isEqualTo: clean)
          .limit(1)
          .get();
      if (invSnap.docs.isNotEmpty) return true;

      // 2. Check processes
      final procSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('processes')
          .where('sac', isEqualTo: clean)
          .limit(1)
          .get();
      if (procSnap.docs.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}
