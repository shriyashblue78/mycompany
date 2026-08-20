import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/machine_model.dart';
import '../../domain/repositories/machine_repository.dart';

class MachineRepositoryImpl implements MachineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createMachine(String companyId, MachineModel machine) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .doc(machine.machineId)
        .set(machine.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateMachine(String companyId, MachineModel machine) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .doc(machine.machineId)
        .update(machine.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteMachine(String companyId, String machineId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .doc(machineId)
        .delete();
  }

  @override
  Stream<List<MachineModel>> streamMachines(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MachineModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<MachineModel?> streamMachineById(String companyId, String machineId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .doc(machineId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return MachineModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<bool> isMachineCodeUnique(
    String companyId,
    String machineCode, {
    String? excludeMachineId,
  }) async {
    final querySnapshot = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('machines')
        .where('machineCode', isEqualTo: machineCode.trim())
        .get();

    for (final doc in querySnapshot.docs) {
      if (excludeMachineId == null || doc.id != excludeMachineId) {
        return false;
      }
    }
    return true;
  }
}
