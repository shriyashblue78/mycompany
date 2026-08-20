import '../models/drawing_model.dart';

abstract class DrawingRepository {
  Future<void> createDrawing(String companyId, DrawingModel drawing);
  Future<void> deleteDrawing(String companyId, String drawingId);
  Stream<List<DrawingModel>> streamDrawings(String companyId);
}
