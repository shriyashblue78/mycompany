import '../models/task_model.dart';

abstract class TaskRepository {
  Future<void> createTask(String companyId, TaskModel task);
  Future<void> updateTask(String companyId, TaskModel task);
  Future<void> deleteTask(String companyId, String taskId);
  Stream<List<TaskModel>> streamTasks(String companyId);
  Stream<TaskModel?> streamTaskById(String companyId, String taskId);
}
