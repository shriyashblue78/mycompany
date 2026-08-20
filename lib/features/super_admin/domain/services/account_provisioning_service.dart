abstract class AccountProvisioningService {
  /// Provision an owner account (Ready for Cloud Functions).
  /// Returns the generated ownerUid string.
  Future<String> createOwner({
    required String companyId,
    required String name,
    required String email,
    required String phone,
    required String temporaryPassword,
  });

  /// Update owner contact details.
  Future<void> updateOwner({
    required String companyId,
    required String ownerUid,
    required String name,
    required String email,
    required String phone,
  });

  /// Disable owner account (suspends logins).
  Future<void> disableOwner({
    required String companyId,
    required String ownerUid,
  });

  /// Enable owner account.
  Future<void> enableOwner({
    required String companyId,
    required String ownerUid,
  });
}
