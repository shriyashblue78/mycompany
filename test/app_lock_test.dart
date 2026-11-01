import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:projectbtt/features/app_lock/domain/models/app_lock_state.dart';
import 'package:projectbtt/features/app_lock/data/services/app_lock_storage_service.dart';
import 'package:projectbtt/features/app_lock/data/services/biometric_auth_service.dart';
import 'package:projectbtt/features/app_lock/presentation/providers/app_lock_provider.dart';
import 'package:projectbtt/features/app_lock/presentation/screens/app_lock_screen.dart';
import 'package:projectbtt/features/app_lock/presentation/screens/app_lock_setup_sheet.dart';
import 'package:projectbtt/features/auth/presentation/providers/auth_provider.dart';
import 'package:projectbtt/features/auth/domain/models/user_model.dart';
import 'package:projectbtt/features/auth/domain/repositories/auth_repository.dart';
import 'package:projectbtt/core/services/auth_service.dart';

// In-memory fake secure storage for fast, reliable unit testing
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    return _data.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    _data.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic appleOptions,
  }) async {
    return Map.from(_data);
  }
}

// Fake Biometric AuthService for testing
class FakeBiometricAuthService extends BiometricAuthService {
  bool supported = true;
  bool canCheck = true;
  List<BiometricType> biometrics = [BiometricType.fingerprint];
  bool authSuccess = true;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<BiometricResult> authenticate({String reason = ''}) async {
    if (!supported) return BiometricResult.fail('Not supported');
    if (!canCheck) return BiometricResult.fail('Cannot check');
    if (authSuccess) {
      return BiometricResult.ok();
    } else {
      return BiometricResult.fail('Fingerprint not recognized');
    }
  }
}

class FakeAuthRepository extends Fake implements AuthRepository {}

class FakeAuthService extends Fake implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(AuthState initialState)
      : super(FakeAuthRepository(), FakeAuthService()) {
    state = initialState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockStorageService Tests', () {
    late FakeSecureStorage fakeStorage;
    late AppLockStorageService storageService;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      storageService = AppLockStorageService(storage: fakeStorage);
    });

    test('Saving PIN never stores plaintext and enables verification', () async {
      await storageService.savePin('1234', enableBiometrics: true);

      // Verify plaintext PIN '1234' is NEVER stored in storage
      final storedHash = await fakeStorage.read(key: 'app_lock_pin_hash');
      final storedSalt = await fakeStorage.read(key: 'app_lock_pin_salt');
      expect(storedHash, isNotNull);
      expect(storedSalt, isNotNull);
      expect(storedHash, isNot(equals('1234')));
      expect(storedSalt, isNot(equals('1234')));

      // Test verification
      final correct = await storageService.verifyPin('1234');
      final wrong = await storageService.verifyPin('9999');

      expect(correct, isTrue);
      expect(wrong, isFalse);
    });

    test('Supports 6-digit PIN as well', () async {
      await storageService.savePin('987654', enableBiometrics: false);

      expect(await storageService.getPinLength(), equals(6));
      expect(await storageService.verifyPin('987654'), isTrue);
      expect(await storageService.verifyPin('123456'), isFalse);
      expect(await storageService.isBiometricsEnabled(), isFalse);
    });

    test('Toggling enabled and clearing credentials', () async {
      await storageService.savePin('4321');
      expect(await storageService.isEnabled(), isTrue);

      await storageService.setEnabled(false);
      expect(await storageService.isEnabled(), isFalse);

      await storageService.clearAll();
      expect(await storageService.hasPin(), isFalse);
    });
  });

  group('AppLockNotifier Workflow Tests', () {
    late FakeSecureStorage fakeStorage;
    late AppLockStorageService storageService;
    late FakeBiometricAuthService fakeBiometric;
    late AppLockNotifier notifier;

    setUp(() async {
      fakeStorage = FakeSecureStorage();
      storageService = AppLockStorageService(storage: fakeStorage);
      fakeBiometric = FakeBiometricAuthService();
      notifier = AppLockNotifier(storageService, fakeBiometric);
      await notifier.init();
    });

    test('First activation PIN setup creates PIN and unlocks', () async {
      expect(notifier.state.hasPin, isFalse);
      expect(notifier.state.isEnabled, isFalse);

      await notifier.setupPin('2580', enableBiometrics: true);

      expect(notifier.state.hasPin, isTrue);
      expect(notifier.state.isEnabled, isTrue);
      expect(notifier.state.pinLength, equals(4));
      expect(notifier.state.biometricsEnabled, isTrue);
      expect(notifier.state.isLocked, isFalse);
    });

    test('Incorrect PIN increments failed attempts and triggers lockout after 5 fails', () async {
      await notifier.setupPin('1111');
      notifier.lock();
      expect(notifier.state.isLocked, isTrue);

      // Attempt 1 to 4: Incorrect
      for (int i = 1; i <= 4; i++) {
        final res = await notifier.verifyPin('0000');
        expect(res, isFalse);
        expect(notifier.state.failedAttempts, equals(i));
        expect(notifier.state.isLockoutActive, isFalse);
      }

      // Attempt 5: Triggers 30s lockout
      final res5 = await notifier.verifyPin('0000');
      expect(res5, isFalse);
      expect(notifier.state.failedAttempts, equals(5));
      expect(notifier.state.isLockoutActive, isTrue);
      expect(notifier.state.remainingLockoutSeconds, greaterThan(0));

      // Attempt during lockout is rejected immediately
      final lockoutAttempt = await notifier.verifyPin('1111');
      expect(lockoutAttempt, isFalse);
      expect(notifier.state.isLocked, isTrue);
    });

    test('Correct PIN resets failed attempts and unlocks', () async {
      await notifier.setupPin('7777');
      notifier.lock();

      await notifier.verifyPin('0000'); // 1 fail
      expect(notifier.state.failedAttempts, equals(1));

      final success = await notifier.verifyPin('7777');
      expect(success, isTrue);
      expect(notifier.state.isLocked, isFalse);
      expect(notifier.state.failedAttempts, equals(0));
    });

    test('Biometric authentication unlocks successfully', () async {
      await notifier.setupPin('5555', enableBiometrics: true);
      notifier.lock();
      expect(notifier.state.isLocked, isTrue);

      fakeBiometric.authSuccess = true;
      final unlocked = await notifier.authenticateWithBiometrics();

      expect(unlocked, isTrue);
      expect(notifier.state.isLocked, isFalse);
    });

    test('Biometric fallback to PIN when biometrics fail', () async {
      await notifier.setupPin('5555', enableBiometrics: true);
      notifier.lock();

      fakeBiometric.authSuccess = false;
      final unlocked = await notifier.authenticateWithBiometrics(isUserInitiated: true);

      expect(unlocked, isFalse);
      expect(notifier.state.isLocked, isTrue);
      expect(notifier.state.errorMessage, isNotNull);

      // Auto-prompt failure keeps screen clean for PIN entry
      notifier.lock();
      final autoUnlocked = await notifier.authenticateWithBiometrics(isUserInitiated: false);
      expect(autoUnlocked, isFalse);
      expect(notifier.state.isLocked, isTrue);
      expect(notifier.state.errorMessage, isNull);

      // PIN fallback succeeds
      final pinUnlocked = await notifier.verifyPin('5555');
      expect(pinUnlocked, isTrue);
      expect(notifier.state.isLocked, isFalse);
    });

    test('Changing PIN verifies old PIN first', () async {
      await notifier.setupPin('1234');

      final failedChange = await notifier.changePin(oldPin: '0000', newPin: '4321');
      expect(failedChange, isFalse);

      final successChange = await notifier.changePin(oldPin: '1234', newPin: '4321');
      expect(successChange, isTrue);

      expect(await storageService.verifyPin('1234'), isFalse);
      expect(await storageService.verifyPin('4321'), isTrue);
    });
  });

  group('AppLockScreen Widget UI Tests', () {
    late FakeSecureStorage fakeStorage;
    late AppLockStorageService storageService;
    late FakeBiometricAuthService fakeBiometric;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      storageService = AppLockStorageService(storage: fakeStorage);
      fakeBiometric = FakeBiometricAuthService();
    });

    testWidgets('AppLockScreen displays branding, keypad, and unlocks on PIN entry', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final mockUser = UserModel(
          uid: 'test_uid',
          companyId: 'comp_1',
          employeeId: 'emp_1',
          name: 'John Doe',
          email: 'john@apex.com',
          phone: '9876543210',
          role: 'Owner',
          department: 'Management',
          designation: 'CEO',
          status: 'Active',
          joiningDate: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
        );

        final container = ProviderContainer(
          overrides: [
            appLockStorageServiceProvider.overrideWithValue(storageService),
            biometricAuthServiceProvider.overrideWithValue(fakeBiometric),
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                AuthState(
                  isLoggedIn: true,
                  isInitialized: true,
                  companyName: 'Apex Industries',
                  user: mockUser,
                ),
              ),
            ),
          ],
        );

        final notifier = container.read(appLockProvider.notifier);
        await notifier.init();
        await notifier.setupPin('1234', enableBiometrics: true);
        notifier.lock();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AppLockScreen(),
            ),
          ),
        );
        await tester.pump();

        // Verify branding and PIN header
        expect(find.text('Enter App PIN'), findsOneWidget);
        expect(find.text('Apex Industries'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

        // Tap 1, 2, 3, 4
        await tester.tap(find.text('1'));
        await tester.pump();
        await tester.tap(find.text('2'));
        await tester.pump();
        await tester.tap(find.text('3'));
        await tester.pump();
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();

        // App should be unlocked!
        expect(container.read(appLockProvider).isLocked, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('AppLockSetupSheet creates and confirms PIN successfully', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final container = ProviderContainer(
          overrides: [
            appLockStorageServiceProvider.overrideWithValue(storageService),
            biometricAuthServiceProvider.overrideWithValue(fakeBiometric),
          ],
        );

        final notifier = container.read(appLockProvider.notifier);
        await notifier.init();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: AppLockSetupSheet(mode: AppLockSetupMode.create),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Create App PIN'), findsOneWidget);

        // Step 1: Enter 4-digit PIN 2, 4, 6, 8
        await tester.tap(find.text('2'));
        await tester.pump();
        await tester.tap(find.text('4'));
        await tester.pump();
        await tester.tap(find.text('6'));
        await tester.pump();
        await tester.tap(find.text('8'));
        await tester.pumpAndSettle();

        // Step 2: Confirm App PIN
        expect(find.text('Confirm App PIN'), findsOneWidget);

        // Re-enter 2, 4, 6, 8
        await tester.tap(find.text('2'));
        await tester.pump();
        await tester.tap(find.text('4'));
        await tester.pump();
        await tester.tap(find.text('6'));
        await tester.pump();
        await tester.tap(find.text('8'));
        await tester.pumpAndSettle();

        // Step 3: Biometric prompt
        expect(find.textContaining('Enable Fingerprint Unlock?'), findsOneWidget);

        // Tap "Enable Fingerprint"
        await tester.tap(find.text('Enable Fingerprint'));
        await tester.pumpAndSettle();

        // Verify App Lock state has PIN configured and biometrics enabled
        final updatedState = container.read(appLockProvider);
        expect(updatedState.hasPin, isTrue);
        expect(updatedState.isEnabled, isTrue);
        expect(updatedState.biometricsEnabled, isTrue);
        expect(await storageService.verifyPin('2468'), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
