import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/program_model.dart';
import '../../domain/repositories/program_repository.dart';
import '../../data/repositories/program_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Repository Provider
final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepositoryImpl();
});

// Search query provider (for program name search)
final programSearchQueryProvider = StateProvider<String>((ref) => '');

// Selected machine filter provider (All, or a specific machineId)
final programSelectedMachineFilterProvider = StateProvider<String>((ref) => 'All');

// Real-time stream of all programs for the company
final companyProgramsStreamProvider = StreamProvider<List<ProgramModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value([]);
  }
  return ref.watch(programRepositoryProvider).streamPrograms(companyId);
});

// Stream of filtered programs
final filteredProgramsProvider = StreamProvider<List<ProgramModel>>((ref) {
  final query = ref.watch(programSearchQueryProvider).trim().toLowerCase();
  final machineFilter = ref.watch(programSelectedMachineFilterProvider);
  final programsStream = ref.watch(companyProgramsStreamProvider);

  return programsStream.when(
    loading: () => Stream.value(<ProgramModel>[]),
    error: (err, stack) => Stream.value(<ProgramModel>[]),
    data: (list) {
      final filteredList = list.where((prog) {
        // 1. Search Query (matches name)
        if (query.isNotEmpty) {
          final matchesName = prog.programName.toLowerCase().contains(query);
          if (!matchesName) {
            return false;
          }
        }

        // 2. Machine Filter
        if (machineFilter != 'All' && prog.machineId != machineFilter) {
          return false;
        }

        return true;
      }).toList();

      return Stream.value(filteredList);
    },
  );
});
