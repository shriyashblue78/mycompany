enum MessageSender {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  sent,
  failed,
}

class FormPrefillActionData {
  final String module;
  final String operation;
  final String route;
  final String? recordId;
  final String? recordTitle;
  final Map<String, dynamic> fields;
  final List<String> missingFields;
  final String title;

  const FormPrefillActionData({
    required this.module,
    required this.operation,
    required this.route,
    this.recordId,
    String? recordTitle,
    String? recordName,
    required this.fields,
    List<String> missingFields = const [],
    List<String>? missingMandatoryFields,
    String? title,
    String? moduleTitle,
    String? actionType,
  })  : recordTitle = recordTitle ?? recordName,
        missingFields = missingMandatoryFields ?? missingFields,
        title = title ?? moduleTitle ?? 'Review & Save Form';

  bool get isEdit => operation == 'edit';
  String? get recordName => recordTitle;
  String get moduleTitle => title;
  List<String> get missingMandatoryFields => missingFields;

  static FormPrefillActionData? fromMap(Map<String, dynamic> map) {
    final actionType = map['action_type'] ?? map['action'];
    if (actionType != 'prepare_form' && actionType != 'prefill_form') {
      return null;
    }
    final route = map['route'] as String?;
    if (route == null || !route.startsWith('/')) {
      return null;
    }
    const allowedPrefixes = [
      '/parties/add',
      '/parties/edit/',
      '/inventory/add',
      '/inventory/edit/',
      '/employees/add',
      '/employees/',
      '/sales/add',
      '/sales/edit/',
      '/purchase/add',
      '/purchase/edit/',
    ];
    final isAllowed = allowedPrefixes.any((prefix) => route.startsWith(prefix));
    if (!isAllowed) {
      return null;
    }

    final module = (map['module'] as String?)?.toLowerCase() ?? '';
    final operation = (map['operation'] as String?)?.toLowerCase() ?? 'create';
    final fields = map['fields'] is Map<String, dynamic>
        ? map['fields'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rawMissing = (map['missing_mandatory_fields'] ?? map['missing_fields']) as List<dynamic>? ?? [];
    final missingFields = rawMissing.map((e) => e.toString()).toList();

    return FormPrefillActionData(
      module: module,
      operation: operation,
      route: route,
      recordId: map['record_id'] as String?,
      recordTitle: map['record_title'] as String? ?? map['record_name'] as String?,
      fields: fields,
      missingFields: missingFields,
      title: map['title'] as String? ?? map['module_title'] as String? ?? 'Review & Save Form',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': 'prefill_form',
      'action_type': 'prefill_form',
      'module': module,
      'operation': operation,
      'route': route,
      'record_id': recordId,
      'record_title': recordTitle,
      'fields': fields,
      'missing_fields': missingFields,
      'missing_mandatory_fields': missingFields,
      'title': title,
    };
  }
}

class BusinessReportActionData {
  final String reportType;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;

  const BusinessReportActionData({
    required this.reportType,
    required this.title,
    this.subtitle = '',
    required this.data,
  });

  static BusinessReportActionData? fromMap(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    if (action != 'business_report') return null;

    final reportType = map['report_type'] as String? ?? 'general_report';
    final title = map['title'] as String? ?? 'Business Report';
    final subtitle = map['subtitle'] as String? ?? '';
    final data = map['data'] is Map<String, dynamic>
        ? map['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return BusinessReportActionData(
      reportType: reportType,
      title: title,
      subtitle: subtitle,
      data: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': 'business_report',
      'report_type': reportType,
      'title': title,
      'subtitle': subtitle,
      'data': data,
    };
  }
}

class WorkflowStepData {
  final int stepNumber;
  final String title;
  final String description;
  final String status;
  final String actionType;
  final String? route;
  final Map<String, dynamic> payload;

  const WorkflowStepData({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.status = 'pending',
    required this.actionType,
    this.route,
    this.payload = const {},
  });

  static WorkflowStepData fromMap(Map<String, dynamic> map) {
    return WorkflowStepData(
      stepNumber: map['step_number'] is int ? map['step_number'] as int : 1,
      title: map['title'] as String? ?? 'Workflow Step',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      actionType: map['action_type'] as String? ?? 'info',
      route: map['route'] as String?,
      payload: map['payload'] is Map<String, dynamic>
          ? map['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'step_number': stepNumber,
      'title': title,
      'description': description,
      'status': status,
      'action_type': actionType,
      'route': route,
      'payload': payload,
    };
  }
}

class WorkflowActionData {
  final String workflowId;
  final String title;
  final String summary;
  final List<WorkflowStepData> steps;
  final bool requiresApproval;

  const WorkflowActionData({
    required this.workflowId,
    required this.title,
    required this.summary,
    required this.steps,
    this.requiresApproval = true,
  });

  static WorkflowActionData? fromMap(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    if (action != 'workflow_automation') return null;

    final rawSteps = map['steps'] as List<dynamic>? ?? [];
    final steps = rawSteps.map((s) => WorkflowStepData.fromMap(s as Map<String, dynamic>)).toList();

    return WorkflowActionData(
      workflowId: map['workflow_id'] as String? ?? 'wf_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Workflow Automation',
      summary: map['summary'] as String? ?? '',
      steps: steps,
      requiresApproval: map['requires_approval'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': 'workflow_automation',
      'workflow_id': workflowId,
      'title': title,
      'summary': summary,
      'steps': steps.map((s) => s.toMap()).toList(),
      'requires_approval': requiresApproval,
    };
  }
}

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final String? errorMessage;
  final String? navigationRoute;
  final String? navigationTitle;
  final FormPrefillActionData? prefillAction;
  final BusinessReportActionData? reportAction;
  final WorkflowActionData? workflowAction;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.navigationRoute,
    this.navigationTitle,
    this.prefillAction,
    this.reportAction,
    this.workflowAction,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    String? errorMessage,
    String? navigationRoute,
    String? navigationTitle,
    FormPrefillActionData? prefillAction,
    BusinessReportActionData? reportAction,
    WorkflowActionData? workflowAction,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      navigationRoute: navigationRoute ?? this.navigationRoute,
      navigationTitle: navigationTitle ?? this.navigationTitle,
      prefillAction: prefillAction ?? this.prefillAction,
      reportAction: reportAction ?? this.reportAction,
      workflowAction: workflowAction ?? this.workflowAction,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'error_message': errorMessage,
      'navigation_route': navigationRoute,
      'navigation_title': navigationTitle,
      'prefill_action': prefillAction?.toMap(),
      'report_action': reportAction?.toMap(),
      'workflow_action': workflowAction?.toMap(),
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: map['text'] as String? ?? '',
      sender: MessageSender.values.firstWhere(
        (s) => s.name == map['sender'],
        orElse: () => MessageSender.assistant,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      errorMessage: map['error_message'] as String?,
      navigationRoute: map['navigation_route'] as String?,
      navigationTitle: map['navigation_title'] as String?,
      prefillAction: map['prefill_action'] is Map<String, dynamic>
          ? FormPrefillActionData.fromMap(map['prefill_action'] as Map<String, dynamic>)
          : null,
      reportAction: map['report_action'] is Map<String, dynamic>
          ? BusinessReportActionData.fromMap(map['report_action'] as Map<String, dynamic>)
          : null,
      workflowAction: map['workflow_action'] is Map<String, dynamic>
          ? WorkflowActionData.fromMap(map['workflow_action'] as Map<String, dynamic>)
          : null,
    );
  }
}
