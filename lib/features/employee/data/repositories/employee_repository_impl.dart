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
  Stream<List<EmployeeModel>> streamEmployees(String companyId, {int? limit, bool includeDeleted = false}) {
    var query = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => EmployeeModel.fromMap(doc.data()))
          .where((emp) => includeDeleted ? emp.isDeleted : !emp.isDeleted)
          .toList();
    });
  }

  @override
  Stream<List<EmployeeModel>> streamArchivedEmployees(String companyId) {
    return streamEmployees(companyId, includeDeleted: true);
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
      final res = await FirebaseFunctions.instance.httpsCallable('createEmployee').call({
        'companyId': companyId,
        'name': employee.name,
        'email': employee.email,
        'phone': employee.phone,
        'role': employee.role,
        'department': employee.department,
        'designation': employee.designation,
        'temporaryPassword': password,
        'photoUrl': employee.photoUrl,
      });

      final createdEmpId = (res.data as Map?)?['employeeId'] as String? ?? employee.employeeId;

      if (employee.photoUrl != null && employee.photoUrl!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('employees')
            .doc(createdEmpId)
            .set({'photoUrl': employee.photoUrl}, SetOptions(merge: true));
      }
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
        'photoUrl': employee.photoUrl,
      });

      // Also ensure photoUrl is directly updated on the employee document
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .doc(employee.employeeId)
          .set({
        'photoUrl': employee.photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (employee.uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(employee.uid)
            .set({
          'photoUrl': employee.photoUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
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

  @override
  Future<void> softDeleteEmployee({
    required String companyId,
    required String employeeId,
    required String deletedByUid,
    required String deletedByName,
    String? reason,
  }) async {
    final empDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .get();

    if (!empDoc.exists) throw Exception('Employee record not found.');
    final uid = empDoc.data()?['uid'] as String?;
    final nowStr = DateTime.now().toIso8601String();

    // 1. Mark employee as soft-deleted in company subcollection
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .update({
      'isDeleted': true,
      'status': 'Inactive',
      'deletedAt': nowStr,
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deletionReason': reason,
      'updatedAt': nowStr,
    });

    // 2. Mark user document as inactive if present
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'status': 'Inactive',
        'isDeleted': true,
        'updatedAt': nowStr,
      }, SetOptions(merge: true));

      // 3. Disable user login in Firebase Auth
      try {
        await FirebaseFunctions.instance.httpsCallable('disableUser').call({
          'uid': uid,
          'companyId': companyId,
          'employeeId': employeeId,
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> restoreEmployee({
    required String companyId,
    required String employeeId,
  }) async {
    // 1. Capacity check
    final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
    final maxEmployees = companyDoc.data()?['maxEmployees'] as int? ?? 50;

    final activeEmployeesSnap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .get();

    final activeCount = activeEmployeesSnap.docs.where((doc) {
      final data = doc.data();
      return (data['isDeleted'] ?? false) == false && (data['status'] ?? 'Active') == 'Active';
    }).length;

    if (activeCount >= maxEmployees) {
      throw Exception(
        'Cannot restore employee: Seat limit reached ($activeCount/$maxEmployees). Please upgrade your employee seat capacity or remove an active employee first.',
      );
    }

    final empDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .get();

    if (!empDoc.exists) throw Exception('Employee record not found.');
    final uid = empDoc.data()?['uid'] as String?;
    final nowStr = DateTime.now().toIso8601String();

    // 2. Mark employee document as active again
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .update({
      'isDeleted': false,
      'status': 'Active',
      'deletedAt': null,
      'deletedByUid': null,
      'deletedByName': null,
      'deletionReason': null,
      'updatedAt': nowStr,
    });

    // 3. Re-enable user in Firestore and Firebase Auth
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'status': 'Active',
        'isDeleted': false,
        'updatedAt': nowStr,
      }, SetOptions(merge: true));

      try {
        await FirebaseFunctions.instance.httpsCallable('enableUser').call({
          'uid': uid,
          'companyId': companyId,
          'employeeId': employeeId,
        });
      } catch (_) {}
    }
  }
}
