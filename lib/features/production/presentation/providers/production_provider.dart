import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/production_model.dart';
import '../../domain/repositories/production_repository.dart';
import '../../data/repositories/production_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../employee/presentation/providers/employee_provider.dart';

// Repository Provider
final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  return ProductionRepositoryImpl();
});

// Search query provider (for product name search)
final productionSearchQueryProvider = StateProvider<String>((ref) => '');

// Real-time stream of all productions for the company
final companyProductionsStreamProvider = StreamProvider<List<ProductionModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(productionRepositoryProvider).streamProductions(companyId);
});

// Stream of filtered productions
final filteredProductionsProvider = StreamProvider<List<ProductionModel>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(<ProductionModel>[]);
  }

  final role = user.role;
  final isEmployee = role == 'Employee';

  final productionsStream = ref.watch(companyProductionsStreamProvider);

  final query = ref.watch(productionSearchQueryProvider).trim().toLowerCase();

  return productionsStream.when(
    loading: () => Stream.value(<ProductionModel>[]),
    error: (err, stack) => Stream.value(<ProductionModel>[]),
    data: (list) {
      final filteredList = list.where((prod) {
        // 1. Employee access restriction: Employee sees only their assigned productions
        if (isEmployee && !prod.assignedEmployees.contains(user.employeeId)) {
          return false;
        }

        // 2. Search Query (Matches Product Name only, as requested in changes)
        if (query.isNotEmpty && !prod.productName.toLowerCase().contains(query)) {
          return false;
        }

        return true;
      }).toList();

      return Stream.value(filteredList);
    },
  );
});

// Single Production details stream
final productionDetailsStreamProvider = StreamProvider.family<ProductionModel?, String>((ref, productionId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(productionRepositoryProvider).streamProductionById(companyId, productionId);
});

// Production stats model
class ProductionStats {
  final int todayQuantity;
  final int runningCount;
  final int completedCount;
  final int totalRejected;

  const ProductionStats({
    required this.todayQuantity,
    required this.runningCount,
    required this.completedCount,
    required this.totalRejected,
  });
}

// Production stats provider
final productionStatsProvider = StreamProvider<ProductionStats>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(const ProductionStats(todayQuantity: 0, runningCount: 0, completedCount: 0, totalRejected: 0));
  }

  final isEmployee = user.role == 'Employee';
  final productionsStream = ref.watch(companyProductionsStreamProvider);

  return productionsStream.when(
    loading: () => Stream.value(const ProductionStats(todayQuantity: 0, runningCount: 0, completedCount: 0, totalRejected: 0)),
    error: (err, stack) => Stream.value(const ProductionStats(todayQuantity: 0, runningCount: 0, completedCount: 0, totalRejected: 0)),
    data: (list) {
      final userProductions = isEmployee
          ? list.where((prod) => prod.assignedEmployees.contains(user.employeeId)).toList()
          : list;

      int todayQuantity = 0;
      int runningCount = 0;
      int completedCount = 0;
      int totalRejected = 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final prod in userProductions) {
        final prodDate = DateTime(prod.productionDate.year, prod.productionDate.month, prod.productionDate.day);
        if (prodDate == today) {
          todayQuantity += prod.quantity;
        }

        if (prod.status == 'In Progress') {
          runningCount++;
        } else if (prod.status == 'Completed') {
          completedCount++;
        }

        totalRejected += prod.rejectedQuantity;
      }

      return Stream.value(ProductionStats(
        todayQuantity: todayQuantity,
        runningCount: runningCount,
        completedCount: completedCount,
        totalRejected: totalRejected,
      ));
    },
  );
});

// Helper stream of all employees for dropdown selections
final productionEmployeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  // Load up to 100 employees to ensure supervisors/employees are visible
  return ref.watch(employeeRepositoryProvider).streamEmployees(companyId, limit: 100);
});
