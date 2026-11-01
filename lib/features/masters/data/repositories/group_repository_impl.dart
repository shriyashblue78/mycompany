import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/group_model.dart';
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _groupsRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('groups');
  }

  @override
  Future<void> createGroup(String companyId, GroupModel group) async {
    final docRef = group.groupId.isEmpty
        ? _groupsRef(companyId).doc()
        : _groupsRef(companyId).doc(group.groupId);

    await docRef.set(group.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateGroup(String companyId, GroupModel group) async {
    await _groupsRef(companyId)
        .doc(group.groupId)
        .update(group.toFirestoreMap(isUpdate: true));

    // Update parentGroupName in direct children if the group name changed
    final childrenSnap = await _groupsRef(companyId)
        .where('parentGroupId', isEqualTo: group.groupId)
        .get();

    if (childrenSnap.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in childrenSnap.docs) {
        batch.update(doc.reference, {
          'parentGroupName': group.groupName.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteGroup(String companyId, String groupId) async {
    await _groupsRef(companyId).doc(groupId).delete();
  }

  @override
  Stream<List<GroupModel>> streamGroups(String companyId) {
    return _groupsRef(companyId)
        .orderBy('groupName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return GroupModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isGroupNameTaken(String companyId, String groupName, {String? excludeGroupId}) async {
    final nameLower = groupName.trim().toLowerCase();
    final snap = await _groupsRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeGroupId != null && doc.id == excludeGroupId) continue;
      final existingName = (doc.data()['groupName'] ?? '').toString().trim().toLowerCase();
      if (existingName == nameLower) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> hasChildGroups(String companyId, String groupId) async {
    final snap = await _groupsRef(companyId)
        .where('parentGroupId', isEqualTo: groupId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<bool> isGroupReferenced(String companyId, String groupId, String groupName) async {
    final cleanName = groupName.trim();
    try {
      // 1. Check inventory / item master
      final inventorySnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('group', isEqualTo: cleanName)
          .limit(1)
          .get();
      if (inventorySnap.docs.isNotEmpty) return true;

      // Also check groupId in inventory if stored as groupId
      final invGroupSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('groupId', isEqualTo: groupId)
          .limit(1)
          .get();
      if (invGroupSnap.docs.isNotEmpty) return true;

      // 2. Check parties or other masters
      final partySnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('parties')
          .where('group', isEqualTo: cleanName)
          .limit(1)
          .get();
      if (partySnap.docs.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> wouldCreateCycle(String companyId, String targetGroupId, String prospectiveParentId) async {
    if (targetGroupId == prospectiveParentId) return true;

    // Traverse upwards from prospectiveParentId
    String? currentId = prospectiveParentId;
    final visited = <String>{targetGroupId};

    while (currentId != null && currentId.isNotEmpty) {
      if (visited.contains(currentId)) {
        return true; // cycle detected
      }
      visited.add(currentId);

      final doc = await _groupsRef(companyId).doc(currentId).get();
      if (!doc.exists) break;
      final data = doc.data();
      currentId = data?['parentGroupId'] as String?;
    }

    return false;
  }
}
