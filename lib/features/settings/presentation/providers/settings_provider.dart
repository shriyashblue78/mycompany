import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/company_model.dart';

// Stream of the logged-in user's company profile
final currentCompanyStreamProvider = StreamProvider<CompanyModel?>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return CompanyModel.fromMap(doc.data()!, doc.id);
      });
});

// Stream of the raw user document data (to fetch name, phone, etc. directly and reactively)
final currentUserProfileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data());
});
