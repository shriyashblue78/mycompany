import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricResult {
  final bool success;
  final String? errorMessage;
  final bool isCanceled;
  final bool isNotEnrolled;
  final bool isLockedOut;

  const BiometricResult({
    required this.success,
    this.errorMessage,
    this.isCanceled = false,
    this.isNotEnrolled = false,
    this.isLockedOut = false,
  });

  factory BiometricResult.ok() => const BiometricResult(success: true);

  factory BiometricResult.fail(
    String message, {
    bool isCanceled = false,
    bool isNotEnrolled = false,
    bool isLockedOut = false,
  }) {
    return BiometricResult(
      success: false,
      errorMessage: message,
      isCanceled: isCanceled,
      isNotEnrolled: isNotEnrolled,
      isLockedOut: isLockedOut,
    );
  }
}

class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<BiometricResult> authenticate({
    String reason = 'Authenticate to unlock MyCompany ERP',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return BiometricResult.fail('Biometric authentication is not supported on this device.');
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return BiometricResult.fail('Biometrics are not set up or not available on this device.');
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        return BiometricResult.ok();
      } else {
        return BiometricResult.fail('Authentication canceled.', isCanceled: true);
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancel') ||
          errorStr.contains('usercanceled') ||
          errorStr.contains('systemcanceled')) {
        return BiometricResult.fail('Authentication canceled.', isCanceled: true);
      } else if (errorStr.contains('lockedout')) {
        return BiometricResult.fail(
          'Biometrics temporarily locked due to failed attempts. Use PIN.',
          isLockedOut: true,
        );
      } else if (errorStr.contains('notenrolled') || errorStr.contains('no_biometrics')) {
        return BiometricResult.fail(
          'No biometrics enrolled. Use PIN.',
          isNotEnrolled: true,
          isCanceled: true,
        );
      } else if (errorStr.contains('passcode')) {
        return BiometricResult.fail('Device passcode is not set.', isCanceled: true);
      } else {
        return BiometricResult.fail(
          'Biometric verification unavailable. Use PIN.',
          isCanceled: true,
        );
      }
    }
  }

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
