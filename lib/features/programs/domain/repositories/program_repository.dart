import '../models/program_model.dart';

abstract class ProgramRepository {
  Future<void> createProgram(String companyId, ProgramModel program);
  Future<void> updateProgram(String companyId, ProgramModel program);
  Future<void> deleteProgram(String companyId, String programId);
  Stream<List<ProgramModel>> streamPrograms(String companyId);
}
