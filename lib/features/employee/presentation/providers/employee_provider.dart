import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/employee_model.dart';

final employeeSearchQueryProvider = StateProvider<String>((ref) => '');
final employeeDepartmentFilterProvider = StateProvider<String?>((ref) => null);
final employeeRoleFilterProvider = StateProvider<String?>((ref) => null);
final employeeStatusFilterProvider = StateProvider<String?>((ref) => null);
final employeeLimitProvider = StateProvider<int>((ref) => 15);

const List<String> kDepartments = [
  'Engineering',
  'Human Resources',
  'Sales',
  'Marketing',
  'Finance',
  'Operations',
];

const List<String> kRoles = [
  'Employee',
  'HR',
  'Supervisor',
  'Owner',
];

const List<String> kStatuses = [
  'Active',
  'Inactive',
];

final filteredEmployeesProvider = StreamProvider<List<EmployeeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;

  if (companyId == null) {
    return Stream.value([]);
  }

  final limit = ref.watch(employeeLimitProvider);
  final repository = ref.watch(employeeRepositoryProvider);
  final employeesStream = repository.streamEmployees(companyId, limit: limit);

  final query = ref.watch(employeeSearchQueryProvider).trim().toLowerCase();
  final dept = ref.watch(employeeDepartmentFilterProvider);
  final role = ref.watch(employeeRoleFilterProvider);
  final status = ref.watch(employeeStatusFilterProvider);

  return employeesStream.map((list) {
    return list.where((emp) {
      // 1. Search Query (Matches: Name, ID, Email, Phone)
      if (query.isNotEmpty) {
        final nameMatch = emp.name.toLowerCase().contains(query);
        final idMatch = emp.employeeId.toLowerCase().contains(query);
        final emailMatch = emp.email.toLowerCase().contains(query);
        final phoneMatch = emp.phone.toLowerCase().contains(query);
        if (!nameMatch && !idMatch && !emailMatch && !phoneMatch) {
          return false;
        }
      }

      // 2. Department Filter
      if (dept != null && dept != 'All' && emp.department != dept) {
        return false;
      }

      // 3. Role Filter
      if (role != null && role != 'All' && emp.role != role) {
        return false;
      }

      // 4. Status Filter
      if (status != null && status != 'All' && emp.status != status) {
        return false;
      }

      return true;
    }).toList();
  });
});

final employeeStreamProvider = StreamProvider.family<EmployeeModel?, String>((ref, employeeId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('employees')
      .doc(employeeId)
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return EmployeeModel.fromMap(doc.data()!);
      });
});
