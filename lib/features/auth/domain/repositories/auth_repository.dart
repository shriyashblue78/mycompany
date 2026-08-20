import '../models/user_model.dart';

abstract class AuthRepository {
  /// Authenticates user with email and password
  /// // TODO: Connect to Firebase Authentication
  Future<String> signInWithEmailAndPassword(String email, String password);

  /// Retrieves user profile details from Firestore
  /// // TODO: Connect to Firestore collection 'users'
  Future<UserModel> getUserProfile(String uid);

  /// Sign out the current user session
  /// // TODO: Connect to Firebase Authentication signout
  Future<void> signOut();
}
