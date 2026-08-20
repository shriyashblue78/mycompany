import '../models/machine_model.dart';

abstract class MachineRepository {
  Future<void> createMachine(String companyId, MachineModel machine);
  Future<void> updateMachine(String companyId, MachineModel machine);
  Future<void> deleteMachine(String companyId, String machineId);
  Stream<List<MachineModel>> streamMachines(String companyId);
  Stream<MachineModel?> streamMachineById(String companyId, String machineId);
  Future<bool> isMachineCodeUnique(String companyId, String machineCode, {String? excludeMachineId});
}
