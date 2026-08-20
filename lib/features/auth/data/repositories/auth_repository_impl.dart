import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthRepositoryImpl(this._authService, this._firestoreService);

  @override
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    final credentials = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credentials.user == null) {
      throw Exception('Failed to sign in. User is null.');
    }
    return credentials.user!.uid;
  }

  @override
  Future<UserModel> getUserProfile(String uid) async {
    final docSnapshot = await _firestoreService.getDoc('users/$uid');
    if (!docSnapshot.exists || docSnapshot.data() == null) {
      throw Exception('User profile not found in database.');
    }
    return UserModel.fromMap(docSnapshot.data()!);
  }

  @override
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
