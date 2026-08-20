import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_model.dart';
import '../../domain/repositories/machine_repository.dart';
import '../../data/repositories/machine_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Repository Provider
final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  return MachineRepositoryImpl();
});

// Search query provider (for machine name or code search)
final machineSearchQueryProvider = StateProvider<String>((ref) => '');

// Status filter provider (All, Active, Inactive, Under Maintenance)
final machineStatusFilterProvider = StateProvider<String>((ref) => 'All');

// Real-time stream of all machines for the company
final companyMachinesStreamProvider = StreamProvider<List<MachineModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value([]);
  }
  return ref.watch(machineRepositoryProvider).streamMachines(companyId);
});

// Stream of filtered machines
final filteredMachinesProvider = StreamProvider<List<MachineModel>>((ref) {
  final query = ref.watch(machineSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(machineStatusFilterProvider);
  final machinesStream = ref.watch(companyMachinesStreamProvider);

  return machinesStream.when(
    loading: () => Stream.value(<MachineModel>[]),
    error: (err, stack) => Stream.value(<MachineModel>[]),
    data: (list) {
      final filteredList = list.where((mch) {
        // 1. Search Query (matches name or code)
        if (query.isNotEmpty) {
          final matchesName = mch.machineName.toLowerCase().contains(query);
          final matchesCode = mch.machineCode.toLowerCase().contains(query);
          if (!matchesName && !matchesCode) {
            return false;
          }
        }

        // 2. Status Filter
        if (statusFilter != 'All' && mch.status != statusFilter) {
          return false;
        }

        return true;
      }).toList();

      return Stream.value(filteredList);
    },
  );
});

// Single Machine details stream
final machineDetailsStreamProvider = StreamProvider.family<MachineModel?, String>((ref, machineId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value(null);
  }
  return ref.watch(machineRepositoryProvider).streamMachineById(companyId, machineId);
});
