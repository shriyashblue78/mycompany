import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/tool_model.dart';
import '../../domain/repositories/tool_repository.dart';
import '../../data/repositories/tool_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Repository Provider
final toolRepositoryProvider = Provider<ToolRepository>((ref) {
  return ToolRepositoryImpl();
});

// Search query provider (for tool name or code search)
final toolSearchQueryProvider = StateProvider<String>((ref) => '');

// Status filter provider (All, Active, Inactive)
final toolStatusFilterProvider = StateProvider<String>((ref) => 'All');

// Real-time stream of all tools for the company
final companyToolsStreamProvider = StreamProvider<List<ToolModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value([]);
  }
  return ref.watch(toolRepositoryProvider).streamTools(companyId);
});

// Stream of filtered tools
final filteredToolsProvider = StreamProvider<List<ToolModel>>((ref) {
  final query = ref.watch(toolSearchQueryProvider).trim().toLowerCase();
  final statusFilter = ref.watch(toolStatusFilterProvider);
  final toolsStream = ref.watch(companyToolsStreamProvider);

  return toolsStream.when(
    loading: () => Stream.value(<ToolModel>[]),
    error: (err, stack) => Stream.value(<ToolModel>[]),
    data: (list) {
      final filteredList = list.where((tool) {
        // 1. Search Query (matches name or code)
        if (query.isNotEmpty) {
          final matchesName = tool.toolName.toLowerCase().contains(query);
          final matchesCode = tool.toolCode.toLowerCase().contains(query);
          if (!matchesName && !matchesCode) {
            return false;
          }
        }

        // 2. Status Filter
        if (statusFilter != 'All' && tool.status != statusFilter) {
          return false;
        }

        return true;
      }).toList();

      return Stream.value(filteredList);
    },
  );
});

// Single Tool details stream
final toolDetailsStreamProvider = StreamProvider.family<ToolModel?, String>((ref, toolId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value(null);
  }
  return ref.watch(toolRepositoryProvider).streamToolById(companyId, toolId);
});
