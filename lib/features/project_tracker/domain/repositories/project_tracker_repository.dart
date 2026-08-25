import '../../../auth/domain/models/user_model.dart';
import '../models/project_model.dart';

abstract class ProjectTrackerRepository {
  Stream<List<ProjectModel>> streamProjects(String companyId);
  Stream<ProjectModel?> streamProjectById(String companyId, String projectId);
  Future<void> createProject(String companyId, ProjectModel project, UserModel user);
  Future<void> updateProject(String companyId, ProjectModel project, UserModel user);
  Future<void> deleteProject(String companyId, String projectId, UserModel user);
}
