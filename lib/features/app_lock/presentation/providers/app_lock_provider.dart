import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_lock_state.dart';
import '../../data/services/app_lock_storage_service.dart';
import '../../data/services/biometric_auth_service.dart';

final appLockStorageServiceProvider = Provider<AppLockStorageService>((ref) {
  return AppLockStorageService();
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

class AppLockNotifier extends StateNotifier<AppLockState> {
  final AppLockStorageService _storageService;
  final BiometricAuthService _biometricService;

  bool _suppressNextLifecycleLock = false;
  Timer? _lockoutTimer;

  AppLockNotifier(this._storageService, this._biometricService)
      : super(const AppLockState()) {
    init();
  }

  bool get isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() async {
    if (!isMobilePlatform) {
      state = state.copyWith(isInitialized: true);
      return;
    }

    try {
      final isEnabled = await _storageService.isEnabled();
      final hasPin = await _storageService.hasPin();
      final pinLength = await _storageService.getPinLength();
      final biometricsEnabled = await _storageService.isBiometricsEnabled();

      final isDeviceSupported = await _biometricService.isDeviceSupported();
      final canCheckBiometrics = await _biometricService.canCheckBiometrics();
      final availableBiometrics = await _biometricService.getAvailableBiometrics();

      state = state.copyWith(
        isInitialized: true,
        isEnabled: isEnabled,
        hasPin: hasPin,
        pinLength: pinLength,
        biometricsEnabled: biometricsEnabled,
        isDeviceSupported: isDeviceSupported,
        canCheckBiometrics: canCheckBiometrics,
        availableBiometrics: availableBiometrics,
        // If app lock is enabled, initially lock the app
        isLocked: isEnabled && hasPin,
      );

      // If locked and biometrics enabled, trigger biometric prompt on cold start
      if (state.isLocked && state.biometricsEnabled && state.canCheckBiometrics) {
        authenticateWithBiometrics();
      }
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Called when app goes into background / pause
  void onAppPaused() {
    if (!isMobilePlatform || !state.isEnabled || !state.hasPin) return;
    if (_suppressNextLifecycleLock) return;

    // Immediately lock app to shield sensitive information from app switcher
    state = state.copyWith(isLocked: true, clearErrorMessage: true);
  }

  /// Called when app returns to foreground / resumed
  void onAppResumed({bool isUserLoggedIn = true}) {
    if (!isMobilePlatform || !state.isEnabled || !state.hasPin || !isUserLoggedIn) return;

    if (_suppressNextLifecycleLock) {
      _suppressNextLifecycleLock = false;
      return;
    }

    if (!state.isLocked) {
      state = state.copyWith(isLocked: true, clearErrorMessage: true);
    }

    // Auto-prompt biometrics if enabled and available
    if (state.isLocked && state.biometricsEnabled && state.canCheckBiometrics && !state.isLockoutActive) {
      authenticateWithBiometrics();
    }
  }

  /// Suppress the next lock cycle (e.g. while opening external file picker or camera)
  void suppressNextLock() {
    _suppressNextLifecycleLock = true;
  }

  /// Authenticate using biometric (Fingerprint / Face ID)
  Future<bool> authenticateWithBiometrics({String? reason, bool isUserInitiated = false}) async {
    if (!isMobilePlatform || !state.canCheckBiometrics || state.isLockoutActive) {
      return false;
    }

    if (state.isAuthenticating) return false;

    state = state.copyWith(isAuthenticating: true, clearErrorMessage: true);
    _suppressNextLifecycleLock = true;

    try {
      final result = await _biometricService.authenticate(
        reason: reason ?? 'Unlock MyCompany ERP with ${state.biometricName}',
      );

      if (result.success) {
        state = state.copyWith(
          isLocked: false,
          failedAttempts: 0,
          clearLockout: true,
          clearErrorMessage: true,
          isAuthenticating: false,
        );
        return true;
      } else {
        if (!result.isCanceled && (isUserInitiated || result.isLockedOut)) {
          state = state.copyWith(
            errorMessage: result.isLockedOut
                ? 'Biometrics locked. Please enter your PIN.'
                : 'Biometric verification failed. Please enter your PIN.',
            isAuthenticating: false,
          );
        } else {
          state = state.copyWith(isAuthenticating: false, clearErrorMessage: true);
        }
        return false;
      }
    } finally {
      if (mounted && state.isAuthenticating) {
        state = state.copyWith(isAuthenticating: false);
      }
    }
  }

  /// Verify entered PIN
  Future<bool> verifyPin(String enteredPin) async {
    if (state.isLockoutActive) {
      state = state.copyWith(
        errorMessage: 'Too many attempts. Wait ${state.remainingLockoutSeconds}s.',
      );
      return false;
    }

    state = state.copyWith(clearErrorMessage: true);
    final isValid = await _storageService.verifyPin(enteredPin);

    if (isValid) {
      _lockoutTimer?.cancel();
      state = state.copyWith(
        isLocked: false,
        failedAttempts: 0,
        clearLockout: true,
        clearErrorMessage: true,
      );
      return true;
    } else {
      final newFailed = state.failedAttempts + 1;
      if (newFailed >= 5) {
        final lockoutEnd = DateTime.now().add(const Duration(seconds: 30));
        state = state.copyWith(
          failedAttempts: newFailed,
          lockoutEndTime: lockoutEnd,
          errorMessage: 'Too many failed attempts. Try again in 30 seconds.',
        );
        _startLockoutCountdown();
      } else {
        final remaining = 5 - newFailed;
        state = state.copyWith(
          failedAttempts: newFailed,
          errorMessage: 'Incorrect PIN. $remaining ${remaining == 1 ? "attempt" : "attempts"} left.',
        );
      }
      return false;
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!state.isLockoutActive) {
        timer.cancel();
        state = state.copyWith(clearLockout: true, clearErrorMessage: true);
      } else {
        // Trigger state rebuild to update countdown UI
        state = state.copyWith(
          errorMessage: 'Too many failed attempts. Try again in ${state.remainingLockoutSeconds}s.',
        );
      }
    });
  }

  /// Setup new App Lock PIN
  Future<void> setupPin(String pin, {bool enableBiometrics = true}) async {
    if (pin.length != 4 && pin.length != 6) {
      throw ArgumentError('PIN must be 4 or 6 digits');
    }

    await _storageService.savePin(pin, enableBiometrics: enableBiometrics);

    state = state.copyWith(
      isEnabled: true,
      hasPin: true,
      pinLength: pin.length,
      biometricsEnabled: enableBiometrics,
      isLocked: false,
      failedAttempts: 0,
      clearLockout: true,
      clearErrorMessage: true,
    );
  }

  /// Change existing App Lock PIN
  Future<bool> changePin({required String oldPin, required String newPin}) async {
    if (newPin.length != 4 && newPin.length != 6) {
      throw ArgumentError('PIN must be 4 or 6 digits');
    }

    final isOldValid = await _storageService.verifyPin(oldPin);
    if (!isOldValid) {
      return false;
    }

    await _storageService.savePin(newPin, enableBiometrics: state.biometricsEnabled);

    state = state.copyWith(
      pinLength: newPin.length,
      failedAttempts: 0,
      clearErrorMessage: true,
    );
    return true;
  }

  /// Toggle App Lock enabled state
  Future<void> setAppLockEnabled(bool enabled) async {
    await _storageService.setEnabled(enabled);
    state = state.copyWith(
      isEnabled: enabled,
      isLocked: enabled && state.hasPin ? false : false,
      clearErrorMessage: true,
    );
  }

  /// Toggle Biometrics enabled state
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storageService.setBiometricsEnabled(enabled);
    state = state.copyWith(
      biometricsEnabled: enabled,
      clearErrorMessage: true,
    );
  }

  /// Manually trigger lock
  void lock() {
    if (state.isEnabled && state.hasPin) {
      state = state.copyWith(isLocked: true, clearErrorMessage: true);
    }
  }

  /// Manually unlock (e.g. after internal verification)
  void unlock() {
    state = state.copyWith(
      isLocked: false,
      failedAttempts: 0,
      clearLockout: true,
      clearErrorMessage: true,
    );
  }

  /// Completely remove App Lock and PIN credentials
  Future<void> disableAndRemovePin() async {
    await _storageService.clearAll();
    _lockoutTimer?.cancel();
    state = state.copyWith(
      isEnabled: false,
      hasPin: false,
      pinLength: 4,
      biometricsEnabled: false,
      isLocked: false,
      failedAttempts: 0,
      clearLockout: true,
      clearErrorMessage: true,
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  final storage = ref.watch(appLockStorageServiceProvider);
  final biometric = ref.watch(biometricAuthServiceProvider);
  return AppLockNotifier(storage, biometric);
});
