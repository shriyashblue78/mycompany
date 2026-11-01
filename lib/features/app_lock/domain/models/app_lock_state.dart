import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricCapability {
  none,
  fingerprint,
  face,
  both,
}

@immutable
class AppLockState {
  final bool isInitialized;
  final bool isEnabled;
  final bool hasPin;
  final int pinLength; // 4 or 6
  final bool biometricsEnabled;
  final bool isDeviceSupported;
  final bool canCheckBiometrics;
  final List<BiometricType> availableBiometrics;
  final bool isLocked;
  final int failedAttempts;
  final DateTime? lockoutEndTime;
  final String? errorMessage;
  final bool isAuthenticating;

  const AppLockState({
    this.isInitialized = false,
    this.isEnabled = false,
    this.hasPin = false,
    this.pinLength = 4,
    this.biometricsEnabled = false,
    this.isDeviceSupported = false,
    this.canCheckBiometrics = false,
    this.availableBiometrics = const [],
    this.isLocked = false,
    this.failedAttempts = 0,
    this.lockoutEndTime,
    this.errorMessage,
    this.isAuthenticating = false,
  });

  bool get isLockoutActive {
    if (lockoutEndTime == null) return false;
    return DateTime.now().isBefore(lockoutEndTime!);
  }

  int get remainingLockoutSeconds {
    if (lockoutEndTime == null) return 0;
    final diff = lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  BiometricCapability get biometricCapability {
    if (!canCheckBiometrics || availableBiometrics.isEmpty) {
      return BiometricCapability.none;
    }
    final hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint) ||
        availableBiometrics.contains(BiometricType.strong);
    final hasFace = availableBiometrics.contains(BiometricType.face);

    if (hasFingerprint && hasFace) return BiometricCapability.both;
    if (hasFace) return BiometricCapability.face;
    if (hasFingerprint) return BiometricCapability.fingerprint;
    return BiometricCapability.fingerprint;
  }

  String get biometricName {
    switch (biometricCapability) {
      case BiometricCapability.face:
        return 'Face ID';
      case BiometricCapability.fingerprint:
      case BiometricCapability.both:
      case BiometricCapability.none:
        return 'Fingerprint';
    }
  }

  AppLockState copyWith({
    bool? isInitialized,
    bool? isEnabled,
    bool? hasPin,
    int? pinLength,
    bool? biometricsEnabled,
    bool? isDeviceSupported,
    bool? canCheckBiometrics,
    List<BiometricType>? availableBiometrics,
    bool? isLocked,
    int? failedAttempts,
    DateTime? lockoutEndTime,
    bool clearLockout = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isAuthenticating,
  }) {
    return AppLockState(
      isInitialized: isInitialized ?? this.isInitialized,
      isEnabled: isEnabled ?? this.isEnabled,
      hasPin: hasPin ?? this.hasPin,
      pinLength: pinLength ?? this.pinLength,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      isDeviceSupported: isDeviceSupported ?? this.isDeviceSupported,
      canCheckBiometrics: canCheckBiometrics ?? this.canCheckBiometrics,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutEndTime: clearLockout ? null : (lockoutEndTime ?? this.lockoutEndTime),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }
}
