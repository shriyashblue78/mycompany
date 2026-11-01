import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/clearance_type_model.dart';
import '../../domain/repositories/clearance_type_repository.dart';
import '../../data/repositories/clearance_type_repository_impl.dart';

final clearanceTypeRepositoryProvider = Provider<ClearanceTypeRepository>((ref) {
  return ClearanceTypeRepositoryImpl();
});

final clearanceTypeSearchQueryProvider = StateProvider<String>((ref) => '');

final companyClearanceTypesStreamProvider = StreamProvider<List<ClearanceTypeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(clearanceTypeRepositoryProvider).streamClearanceTypes(companyId);
});

final filteredClearanceTypesProvider = Provider<AsyncValue<List<ClearanceTypeModel>>>((ref) {
  final listAsync = ref.watch(companyClearanceTypesStreamProvider);
  final query = ref.watch(clearanceTypeSearchQueryProvider).trim().toLowerCase();

  return listAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((c) {
      return c.clearanceType.toLowerCase().contains(query) ||
          (c.remark != null && c.remark!.toLowerCase().contains(query));
    }).toList();
  });
});
