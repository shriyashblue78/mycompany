import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/state_master_model.dart';
import '../../domain/repositories/state_master_repository.dart';
import '../../data/repositories/state_master_repository_impl.dart';

final stateMasterRepositoryProvider = Provider<StateMasterRepository>((ref) {
  return StateMasterRepositoryImpl();
});

final stateMasterSearchQueryProvider = StateProvider<String>((ref) => '');

final companyStatesStreamProvider = StreamProvider<List<StateMasterModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }

  final repo = ref.watch(stateMasterRepositoryProvider);
  // Auto-seed if empty
  repo.seedDefaultIndianStatesIfEmpty(companyId);

  return repo.streamStates(companyId);
});

final filteredStatesProvider = Provider<AsyncValue<List<StateMasterModel>>>((ref) {
  final statesAsync = ref.watch(companyStatesStreamProvider);
  final query = ref.watch(stateMasterSearchQueryProvider).trim().toLowerCase();

  return statesAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((s) {
      return s.stateName.toLowerCase().contains(query) ||
          s.stateCode.toLowerCase().contains(query);
    }).toList();
  });
});
