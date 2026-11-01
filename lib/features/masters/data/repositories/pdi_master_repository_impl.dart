import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/pdi_master_model.dart';
import '../../domain/repositories/pdi_master_repository.dart';

class PdiMasterRepositoryImpl implements PdiMasterRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _pdiRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('pdi_master');
  }

  @override
  Future<void> createPdi(String companyId, PdiMasterModel pdi) async {
    final docRef = pdi.pdiId.isEmpty
        ? _pdiRef(companyId).doc()
        : _pdiRef(companyId).doc(pdi.pdiId);

    await docRef.set(pdi.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updatePdi(String companyId, PdiMasterModel pdi) async {
    await _pdiRef(companyId)
        .doc(pdi.pdiId)
        .update(pdi.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deletePdi(String companyId, String pdiId) async {
    await _pdiRef(companyId).doc(pdiId).delete();
  }

  @override
  Stream<List<PdiMasterModel>> streamPdiList(String companyId) {
    return _pdiRef(companyId)
        .orderBy('itemName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PdiMasterModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isDuplicate(String companyId, String itemName, String partNo, {String? excludePdiId}) async {
    final nameLower = itemName.trim().toLowerCase();
    final partLower = partNo.trim().toLowerCase();
    final snap = await _pdiRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludePdiId != null && doc.id == excludePdiId) continue;
      final existingName = (doc.data()['itemName'] ?? '').toString().trim().toLowerCase();
      final existingPart = (doc.data()['partNo'] ?? '').toString().trim().toLowerCase();
      if (existingName == nameLower && existingPart == partLower) {
        return true;
      }
    }
    return false;
  }
}
