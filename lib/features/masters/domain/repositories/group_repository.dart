import '../../domain/models/group_model.dart';

abstract class GroupRepository {
  Future<void> createGroup(String companyId, GroupModel group);
  Future<void> updateGroup(String companyId, GroupModel group);
  Future<void> deleteGroup(String companyId, String groupId);
  Stream<List<GroupModel>> streamGroups(String companyId);
  Future<bool> isGroupNameTaken(String companyId, String groupName, {String? excludeGroupId});
  Future<bool> hasChildGroups(String companyId, String groupId);
  Future<bool> isGroupReferenced(String companyId, String groupId, String groupName);
  Future<bool> wouldCreateCycle(String companyId, String targetGroupId, String prospectiveParentId);
}
