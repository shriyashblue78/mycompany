import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/clearance_type_model.dart';
import '../../domain/repositories/clearance_type_repository.dart';

class ClearanceTypeRepositoryImpl implements ClearanceTypeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clearanceRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('clearance_types');
  }

  @override
  Future<void> createClearanceType(String companyId, ClearanceTypeModel clearance) async {
    final docRef = clearance.clearanceId.isEmpty
        ? _clearanceRef(companyId).doc()
        : _clearanceRef(companyId).doc(clearance.clearanceId);

    await docRef.set(clearance.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateClearanceType(String companyId, ClearanceTypeModel clearance) async {
    await _clearanceRef(companyId)
        .doc(clearance.clearanceId)
        .update(clearance.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteClearanceType(String companyId, String clearanceId) async {
    await _clearanceRef(companyId).doc(clearanceId).delete();
  }

  @override
  Stream<List<ClearanceTypeModel>> streamClearanceTypes(String companyId) {
    return _clearanceRef(companyId)
        .orderBy('clearanceType')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClearanceTypeModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isDuplicate(String companyId, String clearanceType, {String? excludeId}) async {
    final cleanType = clearanceType.trim().toLowerCase();
    final snap = await _clearanceRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final existing = (doc.data()['clearanceType'] ?? '').toString().trim().toLowerCase();
      if (existing == cleanType) {
        return true;
      }
    }
    return false;
  }
}
