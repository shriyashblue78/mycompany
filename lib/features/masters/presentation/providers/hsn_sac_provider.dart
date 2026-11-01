import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/hsn_sac_model.dart';
import '../../domain/repositories/hsn_sac_repository.dart';
import '../../data/repositories/hsn_sac_repository_impl.dart';

final hsnSacRepositoryProvider = Provider<HsnSacRepository>((ref) {
  return HsnSacRepositoryImpl();
});

final hsnSacSearchQueryProvider = StateProvider<String>((ref) => '');

final companyHsnSacStreamProvider = StreamProvider<List<HsnSacModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(hsnSacRepositoryProvider).streamHsnSac(companyId);
});

final filteredHsnSacProvider = Provider<AsyncValue<List<HsnSacModel>>>((ref) {
  final listAsync = ref.watch(companyHsnSacStreamProvider);
  final query = ref.watch(hsnSacSearchQueryProvider).trim().toLowerCase();

  return listAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((item) {
      final codeMatch = item.code.toLowerCase().contains(query);
      final descMatch = item.description.toLowerCase().contains(query);
      final gstMatch = (item.gstCategory ?? '').toLowerCase().contains(query);
      return codeMatch || descMatch || gstMatch;
    }).toList();
  });
});
