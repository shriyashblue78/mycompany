class ProjectTrackerConfig {
  /// Ordered list of stages in the workflow
  static const List<String> stages = [
    'Marketing',
    'Design',
    'Purchase',
    'Machining',
    'Assembly',
    'Quality',
    'Accounts',
  ];

  /// Departments mapped to their respective workflow stage
  static const Map<String, String> departmentToStageMap = {
    'marketing': 'Marketing',
    'design': 'Design',
    'purchase': 'Purchase',
    'machining': 'Machining',
    'assembly': 'Assembly',
    'quality': 'Quality',
    'accountant': 'Accounts',
    'accounts': 'Accounts',
  };

  /// Roles that have full administrative/management rights
  static const List<String> managerRoles = [
    'Owner',
    'HR',
    'Supervisor',
    'super_admin',
  ];

  /// Check if a user has access to Project Tracker based on role or department
  static bool hasAccess(String? role, String? department) {
    if (role == null) return false;
    if (managerRoles.contains(role)) return true;
    if (department == null) return false;
    return departmentToStageMap.containsKey(department.trim().toLowerCase());
  }

  /// Map user department string to the stage name
  static String getStageNameFromDepartment(String department) {
    return departmentToStageMap[department.trim().toLowerCase()] ?? '';
  }

  /// Check if a user has permission to edit a specific stage
  static bool canEditStage(String? role, String? userDepartment, String stageName) {
    if (role == null) return false;
    if (managerRoles.contains(role)) return true;
    if (userDepartment == null) return false;
    return getStageNameFromDepartment(userDepartment).toLowerCase() == stageName.toLowerCase();
  }
}
