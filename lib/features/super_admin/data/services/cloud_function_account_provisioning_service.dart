import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/services/account_provisioning_service.dart';

class CloudFunctionAccountProvisioningService implements AccountProvisioningService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  Future<String> createOwner({
    required String companyId,
    required String name,
    required String email,
    required String phone,
    required String temporaryPassword,
  }) async {
    try {
      final result = await _functions.httpsCallable('createOwner').call({
        'companyId': companyId,
        'ownerName': name,
        'ownerEmail': email,
        'ownerPhone': phone,
        'temporaryPassword': temporaryPassword,
      });

      final uid = result.data['uid'] as String?;
      if (uid == null) {
        throw Exception('Server failed to return user UID.');
      }
      return uid;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Provisioning owner failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> updateOwner({
    required String companyId,
    required String ownerUid,
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      await _functions.httpsCallable('updateUser').call({
        'uid': ownerUid,
        'companyId': companyId,
        'employeeId': 'EMP0001',
        'name': name,
        'phone': phone,
        'department': 'Management',
        'designation': 'Owner',
        'status': 'Active',
        'role': 'Owner',
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Updating owner details failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> disableOwner({
    required String companyId,
    required String ownerUid,
  }) async {
    try {
      await _functions.httpsCallable('disableUser').call({
        'uid': ownerUid,
        'companyId': companyId,
        'employeeId': 'EMP0001',
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Disabling owner account failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  @override
  Future<void> enableOwner({
    required String companyId,
    required String ownerUid,
  }) async {
    try {
      await _functions.httpsCallable('enableUser').call({
        'uid': ownerUid,
        'companyId': companyId,
        'employeeId': 'EMP0001',
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Enabling owner account failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
