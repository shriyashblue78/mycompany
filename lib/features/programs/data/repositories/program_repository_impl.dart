import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/program_model.dart';
import '../../domain/repositories/program_repository.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createProgram(String companyId, ProgramModel program) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('programs')
        .doc(program.programId)
        .set(program.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateProgram(String companyId, ProgramModel program) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('programs')
        .doc(program.programId)
        .update(program.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteProgram(String companyId, String programId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('programs')
        .doc(programId)
        .delete();
  }

  @override
  Stream<List<ProgramModel>> streamPrograms(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('programs')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProgramModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}
