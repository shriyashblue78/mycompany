import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/process_model.dart';
import '../../domain/repositories/process_repository.dart';
import '../../data/repositories/process_repository_impl.dart';

final processRepositoryProvider = Provider<ProcessRepository>((ref) {
  return ProcessRepositoryImpl();
});

final processSearchQueryProvider = StateProvider<String>((ref) => '');

final companyProcessesStreamProvider = StreamProvider<List<ProcessModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(processRepositoryProvider).streamProcesses(companyId);
});

final filteredProcessesProvider = Provider<AsyncValue<List<ProcessModel>>>((ref) {
  final listAsync = ref.watch(companyProcessesStreamProvider);
  final query = ref.watch(processSearchQueryProvider).trim().toLowerCase();

  return listAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((p) {
      final nameMatch = p.processName.toLowerCase().contains(query);
      final sacMatch = (p.sac ?? '').toLowerCase().contains(query);
      return nameMatch || sacMatch;
    }).toList();
  });
});
