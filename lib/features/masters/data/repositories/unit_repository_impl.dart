import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/unit_model.dart';
import '../../domain/repositories/unit_repository.dart';

class UnitRepositoryImpl implements UnitRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _unitsRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('units');
  }

  @override
  Future<void> createUnit(String companyId, UnitModel unit) async {
    final docRef = unit.unitId.isEmpty
        ? _unitsRef(companyId).doc()
        : _unitsRef(companyId).doc(unit.unitId);

    await docRef.set(unit.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateUnit(String companyId, UnitModel unit) async {
    await _unitsRef(companyId)
        .doc(unit.unitId)
        .update(unit.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteUnit(String companyId, String unitId) async {
    await _unitsRef(companyId).doc(unitId).delete();
  }

  @override
  Stream<List<UnitModel>> streamUnits(String companyId) {
    return _unitsRef(companyId)
        .orderBy('unit')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UnitModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isUnitReferenced(String companyId, String unitName) async {
    if (unitName.trim().isEmpty) return false;
    try {
      final snap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('unit', isEqualTo: unitName.trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
