import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/account_provisioning_service.dart';
import '../../data/services/cloud_function_account_provisioning_service.dart';

final accountProvisioningServiceProvider = Provider<AccountProvisioningService>((ref) {
  return CloudFunctionAccountProvisioningService();
});
