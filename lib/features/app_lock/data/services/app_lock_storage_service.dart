import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyEnabled = 'app_lock_enabled';
  static const String _keyBiometrics = 'app_lock_biometrics_enabled';
  static const String _keyPinHash = 'app_lock_pin_hash';
  static const String _keyPinSalt = 'app_lock_pin_salt';
  static const String _keyPinLength = 'app_lock_pin_length';

  AppLockStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  /// Generates a cryptographically secure 16-byte random salt encoded as hex
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes PIN with salt using SHA-256. Plaintext PIN is never stored.
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Check if an app lock PIN is configured
  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Check if app lock is enabled
  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _keyEnabled);
    return val == 'true';
  }

  /// Check if biometrics is enabled for app lock
  Future<bool> isBiometricsEnabled() async {
    final val = await _storage.read(key: _keyBiometrics);
    return val == 'true';
  }

  /// Get configured PIN length (4 or 6)
  Future<int> getPinLength() async {
    final val = await _storage.read(key: _keyPinLength);
    return int.tryParse(val ?? '4') ?? 4;
  }

  /// Save new PIN securely with a random salt
  Future<void> savePin(String pin, {bool enableBiometrics = true}) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPinHash, value: hash);
    await _storage.write(key: _keyPinLength, value: pin.length.toString());
    await _storage.write(key: _keyEnabled, value: 'true');
    await _storage.write(key: _keyBiometrics, value: enableBiometrics ? 'true' : 'false');
  }

  /// Verify entered PIN against stored hashed PIN
  Future<bool> verifyPin(String enteredPin) async {
    final salt = await _storage.read(key: _keyPinSalt);
    final storedHash = await _storage.read(key: _keyPinHash);

    if (salt == null || storedHash == null) {
      return false;
    }

    final enteredHash = _hashPin(enteredPin, salt);
    return enteredHash == storedHash;
  }

  /// Set app lock enabled state
  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _keyEnabled, value: enabled ? 'true' : 'false');
  }

  /// Set biometrics enabled state
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometrics, value: enabled ? 'true' : 'false');
  }

  /// Clear all lock credentials and settings
  Future<void> clearAll() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    await _storage.delete(key: _keyPinLength);
    await _storage.delete(key: _keyEnabled);
    await _storage.delete(key: _keyBiometrics);
  }
}
