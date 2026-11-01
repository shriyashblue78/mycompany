import '../../domain/models/process_model.dart';

abstract class ProcessRepository {
  Future<void> createProcess(String companyId, ProcessModel process);
  Future<void> updateProcess(String companyId, ProcessModel process);
  Future<void> deleteProcess(String companyId, String processId);
  Stream<List<ProcessModel>> streamProcesses(String companyId);
  Future<bool> isProcessNameTaken(String companyId, String processName, {String? excludeId});
  Future<bool> isProcessReferenced(String companyId, String processName);
}
