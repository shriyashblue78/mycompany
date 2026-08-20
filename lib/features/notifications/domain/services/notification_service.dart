import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:projectbtt/features/notifications/domain/models/notification_model.dart';
import 'package:projectbtt/features/notifications/domain/repositories/notification_repository.dart';
import 'package:projectbtt/features/employee/domain/repositories/employee_repository.dart';
import 'package:projectbtt/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:projectbtt/features/auth/presentation/providers/auth_provider.dart';
import 'package:projectbtt/core/routing/app_router.dart';

class NotificationService {
  final NotificationRepository _notificationRepository;
  final EmployeeRepository _employeeRepository;
  final Ref _ref;
  bool _initialized = false;
  bool _fcmSetupDone = false;

  NotificationService({
    required NotificationRepository notificationRepository,
    required EmployeeRepository employeeRepository,
    required Ref ref,
  })  : _notificationRepository = notificationRepository,
        _employeeRepository = employeeRepository,
        _ref = ref;

  /// Request notification permissions and register the FCM token
  Future<void> setupFCM(String companyId, String employeeId) async {
    if (_fcmSetupDone) return;
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Request notifications permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Set foreground notification options (avoid duplicate alert banner when open)
        await messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );

        _fcmSetupDone = true;

        // 2. Fetch the token
        String? token = await messaging.getToken();

        if (token != null) {
          // 3. Save to employee's fcmTokens subcollection
          await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('employees')
              .doc(employeeId)
              .collection('fcmTokens')
              .doc(token)
              .set({
            'token': token,
            'deviceType': kIsWeb ? 'web' : 'mobile',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 4. Listen for token refreshes
        messaging.onTokenRefresh.listen((newToken) async {
          await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('employees')
              .doc(employeeId)
              .collection('fcmTokens')
              .doc(newToken)
              .set({
            'token': newToken,
            'deviceType': kIsWeb ? 'web' : 'mobile',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    } catch (e) {
      debugPrint('Error setting up FCM in NotificationService: $e');
    }
  }

  /// Initialize global click handlers for background/terminated app launches
  Future<void> initNotifications() async {
    if (_initialized) return;
    _initialized = true;

    // Handle when app is in the background and opened by clicking a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageClick(message);
    });

    // Check if the app was opened from a terminated state via a notification click
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageClick(initialMessage);
    }
  }

  Future<void> _handleMessageClick(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = data['type'] as String?;
      final relatedDocumentId = data['relatedDocumentId'] as String?;
      final companyId = data['companyId'] as String?;

      if (type == null || relatedDocumentId == null || companyId == null) {
        debugPrint('FCM Click: Missing payload details.');
        return;
      }

      // Check if document exists before navigating
      final exists = await checkDocumentExists(type, companyId, relatedDocumentId);
      if (!exists) {
        _showNotAvailableMessage();
        return;
      }

      final route = getRouteForNotification(type, relatedDocumentId);
      if (route == null) return;

      final auth = _ref.read(authProvider);
      if (auth.isLoggedIn && auth.user != null) {
        // Navigate immediately!
        final router = _ref.read(routerProvider);
        router.push(route);
      } else {
        // Store the pending route
        _ref.read(pendingNotificationRouteProvider.notifier).state = route;
      }
    } catch (e) {
      debugPrint('Error handling FCM notification click: $e');
    }
  }

  void _showNotAvailableMessage() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not Available'),
          content: const Text('This item is no longer available.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      debugPrint('FCM Click: Document not available, and navigator context is null.');
    }
  }

  Future<bool> checkDocumentExists(String type, String companyId, String relatedDocumentId) async {
    try {
      String collectionPath;
      switch (type) {
        case 'Task Update':
          collectionPath = 'tasks';
          break;
        case 'Production Update':
          collectionPath = 'production';
          break;
        case 'Leave Update':
          collectionPath = 'leaves';
          break;
        case 'Purchase Update':
          collectionPath = 'purchases';
          break;
        case 'Sales Update':
          collectionPath = 'sales';
          break;
        case 'Inventory Alert':
          collectionPath = 'inventory';
          break;
        case 'Machine Update':
          collectionPath = 'machines';
          break;
        case 'Tooling Update':
          collectionPath = 'tooling';
          break;
        case 'Employee Update':
          collectionPath = 'employees';
          break;
        case 'Announcement':
        case 'General':
        case 'Attendance Reminder':
          collectionPath = 'notifications';
          break;
        default:
          return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection(collectionPath)
          .doc(relatedDocumentId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking document existence: $e');
      return false;
    }
  }

  String? getRouteForNotification(String type, String relatedDocumentId) {
    switch (type) {
      case 'Task Update':
        return '/tasks/$relatedDocumentId';
      case 'Production Update':
        return '/production/$relatedDocumentId';
      case 'Leave Update':
        return '/leaves/$relatedDocumentId';
      case 'Inventory Alert':
        return '/inventory/$relatedDocumentId';
      case 'Purchase Update':
        return '/purchases/$relatedDocumentId';
      case 'Sales Update':
        return '/sales/$relatedDocumentId';
      case 'Machine Update':
        return '/machines/detail/$relatedDocumentId';
      case 'Tooling Update':
        return '/tooling/$relatedDocumentId';
      case 'Employee Update':
        return '/employees/$relatedDocumentId';
      case 'Announcement':
      case 'General':
      case 'Attendance Reminder':
        return '/notifications/$relatedDocumentId';
      default:
        return null;
    }
  }

  /// Send a notification to specific recipients by writing to the Firestore collection
  Future<void> sendNotification({
    required String companyId,
    required String title,
    required String message,
    required String type, // e.g. 'Task Update', 'Leave Update', etc.
    required String priority, // 'Low', 'Medium', 'High', 'Critical'
    required String targetType, // 'Company', 'Department', 'Employee'
    String? targetDepartment,
    List<String> targetEmployeeIds = const [],
    List<String> targetRoles = const [],
    required String createdByUid,
    required String createdByName,
    required String relatedDocumentId,
    required String actionOrStatus, // e.g. 'created', 'Accepted', 'Completed', etc.
  }) async {
    // Generate deterministic notification ID to prevent duplicates
    final notificationId = "${relatedDocumentId}_$actionOrStatus";

    // Resolve target employee IDs based on targetRoles
    final List<String> finalTargetEmployeeIds = List.from(targetEmployeeIds);
    if (targetRoles.isNotEmpty) {
      try {
        final employees = await _employeeRepository.getEmployees(companyId);
        for (final emp in employees) {
          if (targetRoles.contains(emp.role) && emp.status == 'Active') {
            if (!finalTargetEmployeeIds.contains(emp.employeeId)) {
              finalTargetEmployeeIds.add(emp.employeeId);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching employees for role targets: $e');
      }
    }

    final notification = NotificationModel(
      notificationId: notificationId,
      companyId: companyId,
      title: title,
      message: message,
      type: type,
      priority: priority,
      targetType: targetType,
      targetDepartment: targetDepartment,
      targetEmployeeIds: finalTargetEmployeeIds,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      isPinned: false,
      relatedDocumentId: relatedDocumentId,
      actionOrStatus: actionOrStatus,
    );

    // Creates or overwrites/merges (deduplication)
    await _notificationRepository.createNotification(companyId, notification);
  }

  // --- Task Events ---
  Future<void> notifyNewTaskAssigned({
    required String companyId,
    required String taskId,
    required String taskTitle,
    required String assignedToEmployeeId,
    required String managerUid,
    required String managerName,
  }) async {
    await sendNotification(
      companyId: companyId,
      title: 'New Task Assigned: $taskTitle',
      message: 'You have been assigned a new task by $managerName. Please review and accept/reject it.',
      type: 'Task Update',
      priority: 'High',
      targetType: 'Employee',
      targetEmployeeIds: [assignedToEmployeeId],
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: managerUid,
      createdByName: managerName,
      relatedDocumentId: taskId,
      actionOrStatus: 'created',
    );
  }

  Future<void> notifyTaskStatusChanged({
    required String companyId,
    required String taskId,
    required String taskTitle,
    required String status, // 'Accepted', 'Rejected', 'Completed'
    required String employeeUid,
    required String employeeName,
    String? reason,
  }) async {
    String title = 'Task $status: $taskTitle';
    String message = 'Task was marked as $status by $employeeName.';
    String priority = 'Medium';

    if (status == 'Accepted') {
      message = 'Task accepted by $employeeName. Countdown started.';
    } else if (status == 'Rejected') {
      priority = 'High';
      message = 'Task rejected by $employeeName. Reason: ${reason ?? "None"}';
    } else if (status == 'Completed') {
      message = 'Task completed by $employeeName.';
    }

    await sendNotification(
      companyId: companyId,
      title: title,
      message: message,
      type: 'Task Update',
      priority: priority,
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: employeeUid,
      createdByName: employeeName,
      relatedDocumentId: taskId,
      actionOrStatus: status,
    );
  }

  Future<void> notifyTaskCompletedLate({
    required String companyId,
    required String taskId,
    required String taskTitle,
    required int lateDurationMinutes,
    required String reason,
    required String employeeUid,
    required String employeeName,
  }) async {
    await sendNotification(
      companyId: companyId,
      title: 'Task Completed LATE: $taskTitle',
      message: 'Task completed LATE by $employeeName (Late by $lateDurationMinutes mins). Reason: $reason',
      type: 'Task Update',
      priority: 'High',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: employeeUid,
      createdByName: employeeName,
      relatedDocumentId: taskId,
      actionOrStatus: 'CompletedLate',
    );
  }

  // --- Purchase Events ---
  Future<void> notifyPurchaseAddedOrReceived({
    required String companyId,
    required String purchaseId,
    required String purchaseNumber,
    required String itemName,
    required String supplierName,
    required String status, // 'Pending', 'Received'
    required String userUid,
    required String userName,
  }) async {
    final title = 'Purchase $status: $purchaseNumber';
    final message = 'Purchase record $purchaseNumber ($itemName) from $supplierName was marked as $status by $userName.';
    await sendNotification(
      companyId: companyId,
      title: title,
      message: message,
      type: 'Purchase Update',
      priority: 'Medium',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: purchaseId,
      actionOrStatus: status,
    );
  }

  // --- Sales Events ---
  Future<void> notifySaleAddedOrDelivered({
    required String companyId,
    required String saleId,
    required String saleNumber,
    required String itemName,
    required String customerName,
    required String status, // 'Pending', 'Delivered'
    required double totalAmount,
    required String userUid,
    required String userName,
  }) async {
    final title = 'Sale $status: $saleNumber';
    final message = 'Sale record $saleNumber ($itemName) for $customerName of amount \$$totalAmount was marked as $status by $userName.';
    await sendNotification(
      companyId: companyId,
      title: title,
      message: message,
      type: 'Sales Update',
      priority: 'Medium',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: saleId,
      actionOrStatus: status,
    );
  }

  // --- Production Events ---
  Future<void> notifyProductionAddedUpdatedCompleted({
    required String companyId,
    required String productionId,
    required String productName,
    required double quantity,
    required String status, // 'Planned', 'In Progress', 'Completed'
    required String userUid,
    required String userName,
    required bool isEdit,
  }) async {
    final action = isEdit ? (status == 'Completed' ? 'Completed' : 'Updated') : 'Created';
    final title = 'Production $action: $productName';
    final message = 'Production log of $quantity for $productName was $action by $userName. Status: $status.';
    await sendNotification(
      companyId: companyId,
      title: title,
      message: message,
      type: 'Production Update',
      priority: status == 'Completed' ? 'Medium' : 'Low',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: productionId,
      actionOrStatus: '${status}_$action',
    );
  }

  Future<void> notifyProductionRejection({
    required String companyId,
    required String productionId,
    required String productName,
    required String employeeName,
    required String reason,
    required String userUid,
  }) async {
    final title = 'Production Assignment Rejected: $productName';
    final message = 'Production assignment for $productName was rejected by $employeeName. Reason: $reason';
    await sendNotification(
      companyId: companyId,
      title: title,
      message: message,
      type: 'Production Update',
      priority: 'High',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: userUid,
      createdByName: employeeName,
      relatedDocumentId: productionId,
      actionOrStatus: 'Rejected',
    );
  }

  // --- Employee Events ---
  Future<void> notifyNewEmployeeAdded({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String designation,
    required String department,
    required String userUid,
    required String userName,
  }) async {
    await sendNotification(
      companyId: companyId,
      title: 'New Employee: $employeeName',
      message: '$employeeName has been registered as $designation in $department department by $userName.',
      type: 'Employee Update',
      priority: 'Medium',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: employeeId,
      actionOrStatus: 'created',
    );
  }

  // --- Leave Events ---
  Future<void> notifyLeaveSubmitted({
    required String companyId,
    required String leaveId,
    required String employeeName,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String userUid,
  }) async {
    final startStr = "${startDate.day}/${startDate.month}/${startDate.year}";
    final endStr = "${endDate.day}/${endDate.month}/${endDate.year}";
    await sendNotification(
      companyId: companyId,
      title: 'Leave Request: $employeeName',
      message: '$employeeName has requested leave ($leaveType) from $startStr to $endStr.',
      type: 'Leave Update',
      priority: 'High',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR'],
      createdByUid: userUid,
      createdByName: employeeName,
      relatedDocumentId: leaveId,
      actionOrStatus: 'submitted',
    );
  }

  Future<void> notifyLeaveStatusChanged({
    required String companyId,
    required String leaveId,
    required String targetEmployeeId,
    required String status, // 'Approved', 'Rejected'
    required DateTime startDate,
    required DateTime endDate,
    required String managerUid,
    required String managerName,
  }) async {
    final startStr = "${startDate.day}/${startDate.month}/${startDate.year}";
    final endStr = "${endDate.day}/${endDate.month}/${endDate.year}";
    await sendNotification(
      companyId: companyId,
      title: 'Leave Request $status',
      message: 'Your leave request from $startStr to $endStr has been $status by $managerName.',
      type: 'Leave Update',
      priority: status == 'Approved' ? 'Medium' : 'High',
      targetType: 'Employee',
      targetEmployeeIds: [targetEmployeeId],
      createdByUid: managerUid,
      createdByName: managerName,
      relatedDocumentId: leaveId,
      actionOrStatus: status,
    );
  }

  // --- Inventory & Stock Events ---
  Future<void> notifyInventoryItemCreated({
    required String companyId,
    required String itemId,
    required String itemName,
    required String category,
    required String userUid,
    required String userName,
  }) async {
    await sendNotification(
      companyId: companyId,
      title: 'New Inventory Item: $itemName',
      message: 'Inventory item $itemName ($category) was added by $userName.',
      type: 'Inventory Alert',
      priority: 'Low',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: itemId,
      actionOrStatus: 'created',
    );
  }

  Future<void> notifyInventoryLowStock({
    required String companyId,
    required String itemId,
    required String itemName,
    required double currentStock,
    required double minimumStock,
    required String unit,
  }) async {
    await sendNotification(
      companyId: companyId,
      title: 'Low Stock Alert: $itemName',
      message: 'Item $itemName has fallen below its minimum stock level. Current stock: $currentStock $unit (Minimum required: $minimumStock $unit).',
      type: 'Inventory Alert',
      priority: 'Critical',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: 'system',
      createdByName: 'Inventory System',
      relatedDocumentId: itemId,
      actionOrStatus: 'low_stock',
    );
  }

  // --- Machine Events ---
  Future<void> notifyMachineAddedUpdated({
    required String companyId,
    required String machineId,
    required String machineName,
    required String machineCode,
    required String status,
    required String userUid,
    required String userName,
    required bool isEdit,
  }) async {
    final action = isEdit ? 'Updated' : 'Added';
    await sendNotification(
      companyId: companyId,
      title: 'Machine $action: $machineName',
      message: 'Machine $machineName ($machineCode) was $action by $userName. Status: $status.',
      type: 'Machine Update',
      priority: 'Low',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: machineId,
      actionOrStatus: isEdit ? 'updated' : 'created',
    );
  }

  // --- Tooling Events ---
  Future<void> notifyToolingAddedUpdated({
    required String companyId,
    required String toolId,
    required String toolName,
    required String toolCode,
    required String status,
    required String userUid,
    required String userName,
    required bool isEdit,
  }) async {
    final action = isEdit ? 'Updated' : 'Added';
    await sendNotification(
      companyId: companyId,
      title: 'Tooling $action: $toolName',
      message: 'Tooling $toolName ($toolCode) was $action by $userName. Status: $status.',
      type: 'Tooling Update',
      priority: 'Low',
      targetType: 'Company',
      targetRoles: ['Owner', 'HR', 'Supervisor'],
      createdByUid: userUid,
      createdByName: userName,
      relatedDocumentId: toolId,
      actionOrStatus: isEdit ? 'updated' : 'created',
    );
  }
}
