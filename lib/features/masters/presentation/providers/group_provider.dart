import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/group_model.dart';
import '../../domain/repositories/group_repository.dart';
import '../../data/repositories/group_repository_impl.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl();
});

final groupSearchQueryProvider = StateProvider<String>((ref) => '');

final companyGroupsStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(groupRepositoryProvider).streamGroups(companyId);
});

final filteredGroupsProvider = Provider<AsyncValue<List<GroupModel>>>((ref) {
  final groupsAsync = ref.watch(companyGroupsStreamProvider);
  final query = ref.watch(groupSearchQueryProvider).trim().toLowerCase();

  return groupsAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((g) {
      final nameMatch = g.groupName.toLowerCase().contains(query);
      final parentMatch = (g.parentGroupName ?? '').toLowerCase().contains(query);
      return nameMatch || parentMatch;
    }).toList();
  });
});
