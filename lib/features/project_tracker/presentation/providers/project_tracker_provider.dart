import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';
import '../../domain/repositories/project_tracker_repository.dart';
import '../../data/repositories/project_tracker_repository_impl.dart';

final projectTrackerRepositoryProvider = Provider<ProjectTrackerRepository>((ref) {
  return ProjectTrackerRepositoryImpl(ref);
});

final projectSearchQueryProvider = StateProvider<String>((ref) => '');
final projectStatusFilterProvider = StateProvider<String?>((ref) => null);

final projectsStreamProvider = StreamProvider<List<ProjectModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(projectTrackerRepositoryProvider).streamProjects(companyId);
});

final filteredProjectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.when(
    loading: () => Stream.value(<ProjectModel>[]),
    error: (err, stack) => Stream.value(<ProjectModel>[]),
    data: (projects) {
      final query = ref.watch(projectSearchQueryProvider).trim().toLowerCase();
      final statusFilter = ref.watch(projectStatusFilterProvider);

      var list = projects;
      if (statusFilter != null && statusFilter != 'All') {
        list = list.where((p) => p.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }

      if (query.isNotEmpty) {
        list = list.where((p) {
          final nameMatch = p.projectName.toLowerCase().contains(query);
          final descMatch = p.description.toLowerCase().contains(query);
          return nameMatch || descMatch;
        }).toList();
      }

      return Stream.value(list);
    },
  );
});

final projectDetailsStreamProvider = StreamProvider.family<ProjectModel?, String>((ref, projectId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(projectTrackerRepositoryProvider).streamProjectById(companyId, projectId);
});
