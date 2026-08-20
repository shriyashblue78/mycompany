import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/drawing_model.dart';
import '../../domain/repositories/drawing_repository.dart';
import '../../data/repositories/drawing_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Repository Provider
final drawingRepositoryProvider = Provider<DrawingRepository>((ref) {
  return DrawingRepositoryImpl();
});

// Search query provider (for drawing name search)
final drawingSearchQueryProvider = StateProvider<String>((ref) => '');

// File type filter provider (All, PDF, Image)
final drawingTypeFilterProvider = StateProvider<String>((ref) => 'All');

// Real-time stream of all drawings for the company
final companyDrawingsStreamProvider = StreamProvider<List<DrawingModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty || authState.user?.role == 'super_admin') {
    return Stream.value([]);
  }
  return ref.watch(drawingRepositoryProvider).streamDrawings(companyId);
});

// Stream of filtered drawings
final filteredDrawingsProvider = StreamProvider<List<DrawingModel>>((ref) {
  final query = ref.watch(drawingSearchQueryProvider).trim().toLowerCase();
  final typeFilter = ref.watch(drawingTypeFilterProvider);
  final drawingsStream = ref.watch(companyDrawingsStreamProvider);

  return drawingsStream.when(
    loading: () => Stream.value(<DrawingModel>[]),
    error: (err, stack) => Stream.value(<DrawingModel>[]),
    data: (list) {
      final filteredList = list.where((drawing) {
        // 1. Search Query (matches name)
        if (query.isNotEmpty) {
          final matchesName = drawing.drawingName.toLowerCase().contains(query);
          if (!matchesName) {
            return false;
          }
        }

        // 2. Type Filter (PDF, Image)
        if (typeFilter != 'All') {
          if (typeFilter == 'PDF' && drawing.fileType != 'pdf') {
            return false;
          }
          if (typeFilter == 'Image' && drawing.fileType != 'image') {
            return false;
          }
        }

        return true;
      }).toList();

      return Stream.value(filteredList);
    },
  );
});
