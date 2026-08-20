import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/task_model.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createTask(String companyId, TaskModel task) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(task.taskId)
        .set(task.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateTask(String companyId, TaskModel task) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(task.taskId)
        .update(task.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteTask(String companyId, String taskId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  @override
  Stream<List<TaskModel>> streamTasks(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TaskModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<TaskModel?> streamTaskById(String companyId, String taskId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return TaskModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
