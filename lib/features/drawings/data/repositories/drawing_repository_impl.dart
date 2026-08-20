import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/drawing_model.dart';
import '../../domain/repositories/drawing_repository.dart';

class DrawingRepositoryImpl implements DrawingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createDrawing(String companyId, DrawingModel drawing) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('drawings')
        .doc(drawing.drawingId)
        .set(drawing.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> deleteDrawing(String companyId, String drawingId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('drawings')
        .doc(drawingId)
        .delete();
  }

  @override
  Stream<List<DrawingModel>> streamDrawings(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('drawings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DrawingModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}
