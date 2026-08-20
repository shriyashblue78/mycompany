import '../models/employee_model.dart';

abstract class EmployeeRepository {
  /// Fetch list of employees belonging strictly to the current logged-in company (Multi-Tenancy)
  Future<List<EmployeeModel>> getEmployees(String companyId);

  /// Real-time stream of employees for a company
  Stream<List<EmployeeModel>> streamEmployees(String companyId, {int? limit});

  /// Create an employee account (Owner / HR operation)
  Future<void> createEmployee({
    required String companyId,
    required EmployeeModel employee,
    required String password,
  });

  /// Update employee details (Name, Phone, Department, Designation, Role, Status)
  Future<void> updateEmployee({
    required String companyId,
    required EmployeeModel employee,
  });

  /// Activate or deactivate an employee account
  Future<void> updateEmployeeStatus({
    required String companyId,
    required String employeeId,
    required String status,
  });

  /// Reset employee password
  Future<void> resetEmployeePassword({
    required String companyId,
    required String employeeId,
    required String newPassword,
  });

  /// Check if an employee ID already exists within the company
  Future<bool> isEmployeeIdExists(String companyId, String employeeId);

  /// Check if an email is already registered in the system
  Future<bool> isEmailExists(String email);
}
