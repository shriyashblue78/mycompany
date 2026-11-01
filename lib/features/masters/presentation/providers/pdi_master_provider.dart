import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/pdi_master_model.dart';
import '../../domain/repositories/pdi_master_repository.dart';
import '../../data/repositories/pdi_master_repository_impl.dart';

final pdiMasterRepositoryProvider = Provider<PdiMasterRepository>((ref) {
  return PdiMasterRepositoryImpl();
});

final pdiMasterSearchQueryProvider = StateProvider<String>((ref) => '');

final companyPdiMasterStreamProvider = StreamProvider<List<PdiMasterModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(pdiMasterRepositoryProvider).streamPdiList(companyId);
});

final filteredPdiMasterProvider = Provider<AsyncValue<List<PdiMasterModel>>>((ref) {
  final pdiAsync = ref.watch(companyPdiMasterStreamProvider);
  final query = ref.watch(pdiMasterSearchQueryProvider).trim().toLowerCase();

  return pdiAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((p) {
      return p.itemName.toLowerCase().contains(query) ||
          p.partNo.toLowerCase().contains(query);
    }).toList();
  });
});
