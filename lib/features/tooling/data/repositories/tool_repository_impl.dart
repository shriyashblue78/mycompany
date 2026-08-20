import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/tool_model.dart';
import '../../domain/repositories/tool_repository.dart';

class ToolRepositoryImpl implements ToolRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createTool(String companyId, ToolModel tool) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .doc(tool.toolId)
        .set(tool.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateTool(String companyId, ToolModel tool) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .doc(tool.toolId)
        .update(tool.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteTool(String companyId, String toolId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .doc(toolId)
        .delete();
  }

  @override
  Stream<List<ToolModel>> streamTools(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ToolModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<ToolModel?> streamToolById(String companyId, String toolId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .doc(toolId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ToolModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<bool> isToolCodeUnique(
    String companyId,
    String toolCode, {
    String? excludeToolId,
  }) async {
    final querySnapshot = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tooling')
        .where('toolCode', isEqualTo: toolCode.trim())
        .get();

    for (final doc in querySnapshot.docs) {
      if (excludeToolId == null || doc.id != excludeToolId) {
        return false;
      }
    }
    return true;
  }
}
