import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/services/firestore_service.dart';
import '../../domain/models/employee_model.dart';
import '../../domain/repositories/employee_repository.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final FirestoreService _firestoreService;

  EmployeeRepositoryImpl(this._firestoreService);

  @override
  Future<List<EmployeeModel>> getEmployees(String companyId) async {
    final snapshot = await _firestoreService.getCompanySubcollection(
      companyId: companyId,
      subcollection: 'employees',
    );

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return EmployeeModel.fromMap(data);
    }).toList();
  }

  @override
  Stream<List<EmployeeModel>> streamEmployees(String companyId, {int? limit}) {
    var query = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return EmployeeModel.fromMap(doc.data());
      }).toList();
    });
  }

  @override
  Future<void> createEmployee({
    required String companyId,
    required EmployeeModel employee,
    required String password,
  }) async {
    if (employee.companyId != companyId) {
      throw Exception('Security Violation: Employee must belong to your company.');
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('createEmployee').call({
        'companyId': companyId,
        'name': employee.name,
        'email': employee.email,
        'phone': employee.phone,
        'role': employee.role,
        'department': employee.department,
        'designation': employee.designation,
        'temporaryPassword': password,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to create employee.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> updateEmployee({
    required String companyId,
    required EmployeeModel employee,
  }) async {
    if (employee.companyId != companyId) {
      throw Exception('Security Violation: Employee must belong to your company.');
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('updateUser').call({
        'uid': employee.uid,
        'companyId': companyId,
        'employeeId': employee.employeeId,
        'name': employee.name,
        'phone': employee.phone,
        'department': employee.department,
        'designation': employee.designation,
        'status': employee.status,
        'role': employee.role,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update employee details.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> updateEmployeeStatus({
    required String companyId,
    required String employeeId,
    required String status,
  }) async {
    final empDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .get();

    if (!empDoc.exists) return;
    final uid = empDoc.data()?['uid'] as String?;

    if (uid == null || uid.isEmpty) {
      throw Exception('Employee profile has no associated UID.');
    }

    try {
      final functionName = status == 'Active' ? 'enableUser' : 'disableUser';
      await FirebaseFunctions.instance.httpsCallable(functionName).call({
        'uid': uid,
        'companyId': companyId,
        'employeeId': employeeId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to update employee status.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> resetEmployeePassword({
    required String companyId,
    required String employeeId,
    required String newPassword,
  }) async {
    final empDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .get();

    if (!empDoc.exists) throw Exception('Employee not found.');
    final email = empDoc.data()?['email'] as String;

    try {
      await FirebaseFunctions.instance.httpsCallable('resetUserPassword').call({
        'email': email,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send password reset email.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<bool> isEmployeeIdExists(String companyId, String employeeId) async {
    final doc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .get();
    return doc.exists;
  }

  @override
  Future<bool> isEmailExists(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }
}
