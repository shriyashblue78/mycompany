import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/unit_model.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../data/repositories/unit_repository_impl.dart';

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return UnitRepositoryImpl();
});

final unitSearchQueryProvider = StateProvider<String>((ref) => '');

final companyUnitsStreamProvider = StreamProvider<List<UnitModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(unitRepositoryProvider).streamUnits(companyId);
});

final filteredUnitsProvider = Provider<AsyncValue<List<UnitModel>>>((ref) {
  final unitsAsync = ref.watch(companyUnitsStreamProvider);
  final query = ref.watch(unitSearchQueryProvider).trim().toLowerCase();

  return unitsAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((u) {
      final unitMatch = u.unit.toLowerCase().contains(query);
      final descMatch = u.description.toLowerCase().contains(query);
      return unitMatch || descMatch;
    }).toList();
  });
});
