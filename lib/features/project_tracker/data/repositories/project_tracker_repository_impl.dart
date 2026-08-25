import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../domain/models/project_model.dart';
import '../../domain/repositories/project_tracker_repository.dart';

class ProjectTrackerRepositoryImpl implements ProjectTrackerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref _ref;

  ProjectTrackerRepositoryImpl(this._ref);

  @override
  Stream<List<ProjectModel>> streamProjects(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProjectModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<ProjectModel?> streamProjectById(String companyId, String projectId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ProjectModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<void> createProject(String companyId, ProjectModel project, UserModel user) async {
    final bool isManager = user.role == 'Owner' || user.role == 'HR' || user.role == 'Supervisor';
    if (!isManager) {
      throw Exception('Permission Denied: Only managers can create projects.');
    }

    // Initialize in Marketing stage
    final initialHistory = List<StageHistoryEntry>.from(project.stageHistory);
    initialHistory.add(StageHistoryEntry(
      department: 'Marketing',
      status: 'Pending',
      responsiblePerson: user.name,
      timestamp: DateTime.now(),
      remarks: 'Project created & initialized at Marketing stage.',
    ));

    final initializedProject = project.copyWith(
      currentStage: 'Marketing',
      stageHistory: initialHistory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .doc(initializedProject.projectId)
        .set(initializedProject.toMap());

    // Send transition notification for the starting stage
    try {
      await _ref.read(notificationServiceProvider).notifyProjectStageTransition(
            companyId: companyId,
            projectId: initializedProject.projectId,
            projectName: initializedProject.projectName,
            stageName: 'Marketing',
            status: 'Pending',
            userUid: user.uid,
            userName: user.name,
          );
    } catch (e) {
      // Suppress or log notification errors to prevent transaction failure
    }
  }

  @override
  Future<void> updateProject(String companyId, ProjectModel project, UserModel user) async {
    final bool isManager = user.role == 'Owner' || user.role == 'HR' || user.role == 'Supervisor';

    // 1. Fetch existing project state
    final doc = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .doc(project.projectId)
        .get();
    if (!doc.exists) {
      throw Exception('Project not found.');
    }
    final existing = ProjectModel.fromMap(doc.data()!, doc.id);

    // 2. Identify modified stage
    String? modifiedStageName;
    ProjectStage? newStageValue;
    ProjectStage? oldStageValue;

    if (project.marketingStage != existing.marketingStage) {
      modifiedStageName = 'Marketing';
      newStageValue = project.marketingStage;
      oldStageValue = existing.marketingStage;
    }
    if (project.designStage != existing.designStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Design';
      newStageValue = project.designStage;
      oldStageValue = existing.designStage;
    }
    if (project.purchaseStage != existing.purchaseStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Purchase';
      newStageValue = project.purchaseStage;
      oldStageValue = existing.purchaseStage;
    }
    if (project.machiningStage != existing.machiningStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Machining';
      newStageValue = project.machiningStage;
      oldStageValue = existing.machiningStage;
    }
    if (project.assemblyStage != existing.assemblyStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Assembly';
      newStageValue = project.assemblyStage;
      oldStageValue = existing.assemblyStage;
    }
    if (project.qualityStage != existing.qualityStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Quality';
      newStageValue = project.qualityStage;
      oldStageValue = existing.qualityStage;
    }
    if (project.accountsStage != existing.accountsStage) {
      if (modifiedStageName != null) throw Exception('Cannot modify multiple stages simultaneously.');
      modifiedStageName = 'Accounts';
      newStageValue = project.accountsStage;
      oldStageValue = existing.accountsStage;
    }

    // 3. Enforce access rules
    if (!isManager) {
      if (modifiedStageName == null) {
        throw Exception('Permission Denied: Only managers can edit project metadata.');
      }

      // Check if user belongs to that department
      final userDept = user.department.trim().toLowerCase();
      bool deptMatches = false;
      if (modifiedStageName == 'Accounts' && userDept == 'accountant') {
        deptMatches = true;
      } else {
        deptMatches = userDept == modifiedStageName.toLowerCase();
      }
      if (!deptMatches) {
        throw Exception('Permission Denied: You do not belong to the $modifiedStageName department.');
      }

      // Check if it is the current active stage
      if (existing.currentStage != modifiedStageName) {
        throw Exception('Permission Denied: $modifiedStageName is not the current active stage. Current active stage is ${existing.currentStage}.');
      }
    }

    // 4. Compute next active stage
    String computedCurrentStage = 'Marketing';
    if (project.marketingStage.status != 'Completed') {
      computedCurrentStage = 'Marketing';
    } else if (project.designStage.status != 'Completed') {
      computedCurrentStage = 'Design';
    } else if (project.purchaseStage.status != 'Completed') {
      computedCurrentStage = 'Purchase';
    } else if (project.machiningStage.status != 'Completed') {
      computedCurrentStage = 'Machining';
    } else if (project.assemblyStage.status != 'Completed') {
      computedCurrentStage = 'Assembly';
    } else if (project.qualityStage.status != 'Completed') {
      computedCurrentStage = 'Quality';
    } else if (project.accountsStage.status != 'Completed') {
      computedCurrentStage = 'Accounts';
    } else {
      computedCurrentStage = 'Completed';
    }

    // Determine overall project status
    String computedStatus = project.status;
    if (computedCurrentStage == 'Completed') {
      computedStatus = 'Completed';
    } else if (project.marketingStage.status == 'In Progress' ||
        project.marketingStage.status == 'Completed' ||
        project.status == 'In Progress') {
      computedStatus = 'In Progress';
    }

    var finalProject = project.copyWith(
      currentStage: computedCurrentStage,
      status: computedStatus,
    );

    // 5. Trigger notifications on stage transitions
    if (modifiedStageName != null && newStageValue != null && oldStageValue != null) {
      final transitionOccurred = newStageValue.status != oldStageValue.status;

      if (transitionOccurred) {
        final ns = _ref.read(notificationServiceProvider);
        try {
          if (computedCurrentStage == 'Completed') {
            await ns.notifyProjectFullyCompleted(
              companyId: companyId,
              projectId: project.projectId,
              projectName: project.projectName,
              userUid: user.uid,
              userName: user.name,
            );
          } else if (computedCurrentStage != existing.currentStage) {
            // Stage advanced to next department
            await ns.notifyProjectStageTransition(
              companyId: companyId,
              projectId: project.projectId,
              projectName: project.projectName,
              stageName: computedCurrentStage,
              status: 'Pending',
              userUid: user.uid,
              userName: user.name,
            );
          } else if (newStageValue.status == 'In Progress') {
            // Stage marked in progress
            await ns.notifyProjectStageTransition(
              companyId: companyId,
              projectId: project.projectId,
              projectName: project.projectName,
              stageName: modifiedStageName,
              status: 'In Progress',
              userUid: user.uid,
              userName: user.name,
            );
          }
        } catch (e) {
          // Suppress notification dispatch exceptions
        }
      }
    }

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .doc(project.projectId)
        .update(finalProject.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
  }

  @override
  Future<void> deleteProject(String companyId, String projectId, UserModel user) async {
    final bool isManager = user.role == 'Owner' || user.role == 'HR' || user.role == 'Supervisor';
    if (!isManager) {
      throw Exception('Permission Denied: Only managers can delete projects.');
    }
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('projects')
        .doc(projectId)
        .delete();
  }
}
