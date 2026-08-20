import '../models/tool_model.dart';

abstract class ToolRepository {
  Future<void> createTool(String companyId, ToolModel tool);
  Future<void> updateTool(String companyId, ToolModel tool);
  Future<void> deleteTool(String companyId, String toolId);
  Stream<List<ToolModel>> streamTools(String companyId);
  Stream<ToolModel?> streamToolById(String companyId, String toolId);
  Future<bool> isToolCodeUnique(String companyId, String toolCode, {String? excludeToolId});
}
