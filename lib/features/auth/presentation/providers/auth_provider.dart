import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../employee/domain/repositories/employee_repository.dart';
import '../../../employee/data/repositories/employee_repository_impl.dart';

// Services Providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// Repository Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return AuthRepositoryImpl(authService, firestoreService);
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return EmployeeRepositoryImpl(firestoreService);
});

class AuthState {
  final bool isLoggedIn;
  final bool isInitialized;
  final UserModel? user;
  final String? companyName;
  final String? companyLogoUrl;

  AuthState({
    this.isLoggedIn = false,
    this.isInitialized = false,
    this.user,
    this.companyName,
    this.companyLogoUrl,
  });

  // Preserve compatibility getters for routes/dashboards
  String? get selectedCompany => companyName ?? user?.companyId;
  String? get selectedRole => user?.role;
  String? get userName => user?.name;
  String? get userId => user?.uid;

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isInitialized,
    UserModel? user,
    String? companyName,
    String? companyLogoUrl,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isInitialized: isInitialized ?? this.isInitialized,
      user: user ?? this.user,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final AuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;

  AuthNotifier(this._authRepository, this._authService) : super(AuthState()) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    _authStateSubscription?.cancel();
    final completer = Completer<void>();
    _authStateSubscription = _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        try {
          final userProfile = await _authRepository.getUserProfile(firebaseUser.uid);
          if (userProfile.status == 'Active' || userProfile.role == 'super_admin') {
            String? companyName;
            String? companyLogoUrl;
            if (userProfile.role != 'super_admin') {
              final companyDoc = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(userProfile.companyId)
                  .get();
              if (companyDoc.exists) {
                companyName = companyDoc.data()?['companyName'] ?? companyDoc.data()?['name'];
                companyLogoUrl = companyDoc.data()?['companyLogoUrl'] as String?;
              }
            }
            state = AuthState(
              isLoggedIn: true,
              isInitialized: true,
              user: userProfile,
              companyName: companyName,
              companyLogoUrl: companyLogoUrl,
            );
          } else {
            // Account exists but is not Active
            state = AuthState(isLoggedIn: false, isInitialized: true, user: null);
          }
        } catch (_) {
          state = AuthState(isLoggedIn: false, isInitialized: true, user: null);
        }
      } else {
        state = AuthState(isLoggedIn: false, isInitialized: true, user: null);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate the user
      final uid = await _authRepository.signInWithEmailAndPassword(email, password);
      
      // 2. Fetch the user's profile from Firestore
      final userProfile = await _authRepository.getUserProfile(uid);

      // 4. Verify account status is Active
      if (userProfile.status != 'Active' && userProfile.role != 'super_admin') {
        throw Exception('Account is inactive. Please contact HR or Owner.');
      }

      // Update lastLogin timestamp in both User profile and Employee record
      try {
        final nowStr = DateTime.now().toIso8601String();
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(uid),
          {'lastLogin': nowStr},
        );
        if (userProfile.role != 'super_admin') {
          batch.update(
            FirebaseFirestore.instance
                .collection('companies')
                .doc(userProfile.companyId)
                .collection('employees')
                .doc(userProfile.employeeId),
            {'lastLogin': nowStr},
          );
        }
        await batch.commit();
      } catch (_) {
        // Safe fallback if database updates fail (e.g. permission or offline)
      }

      // Fetch company name and logo
      String? companyName;
      String? companyLogoUrl;
      if (userProfile.role != 'super_admin') {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(userProfile.companyId)
            .get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?['companyName'] ?? companyDoc.data()?['name'];
          companyLogoUrl = companyDoc.data()?['companyLogoUrl'] as String?;
        }
      }

      // 5. Store the user session in Riverpod
      state = AuthState(
        isLoggedIn: true,
        isInitialized: true,
        user: userProfile,
        companyName: companyName,
        companyLogoUrl: companyLogoUrl,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> forgotPassword({required String email}) async {
    await _authService.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    state = AuthState(isLoggedIn: false, isInitialized: true, user: null);
  }

  Future<void> refreshProfile() async {
    if (state.user != null) {
      final updatedProfile = await _authRepository.getUserProfile(state.user!.uid);
      state = state.copyWith(user: updatedProfile);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(repository, authService);
});
