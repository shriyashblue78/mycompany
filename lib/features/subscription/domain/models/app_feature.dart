import '../../../auth/domain/models/company_modules.dart';

/// Represents a master application feature/module registered in the system.
class AppFeature {
  final String featureKey;
  final String displayName;
  final String description;
  final String category;
  final String groupName;
  final bool defaultEnabled;

  const AppFeature({
    required this.featureKey,
    required this.displayName,
    required this.description,
    required this.category,
    this.groupName = 'Other',
    this.defaultEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'featureKey': featureKey,
      'displayName': displayName,
      'description': description,
      'category': category,
      'groupName': groupName,
      'defaultEnabled': defaultEnabled,
    };
  }

  factory AppFeature.fromMap(Map<String, dynamic> map) {
    return AppFeature(
      featureKey: map['featureKey'] as String,
      displayName: map['displayName'] as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? 'General') as String,
      groupName: (map['groupName'] ?? map['category'] ?? 'Other') as String,
      defaultEnabled: (map['defaultEnabled'] ?? true) as bool,
    );
  }
}

/// Centralized Master Registry of all application features, reusing CompanyModules keys.
class FeatureMaster {
  /// Predefined feature groups for grouping and filtering UI displays
  static const List<String> featureGroups = [
    'Workforce',
    'Attendance',
    'Tasks',
    'Inventory',
    'Production',
    'Machines',
    'Tooling',
    'Programs',
    'Sales',
    'Project Tracker',
    'Reports',
    'Analytics',
    'Other',
  ];

  static const List<AppFeature> allFeatures = [
    AppFeature(
      featureKey: CompanyModules.employees,
      displayName: 'Employee Management',
      description: 'Manage employee profiles, roles, and departments',
      category: 'HR & Personnel',
      groupName: 'Workforce',
    ),
    AppFeature(
      featureKey: CompanyModules.attendance,
      displayName: 'Attendance Tracking',
      description: 'Track employee clock-in, clock-out, and shift logs',
      category: 'HR & Personnel',
      groupName: 'Attendance',
    ),
    AppFeature(
      featureKey: CompanyModules.leaves,
      displayName: 'Leave Management',
      description: 'Process employee leave requests and balances',
      category: 'HR & Personnel',
      groupName: 'Workforce',
    ),
    AppFeature(
      featureKey: CompanyModules.tasks,
      displayName: 'Task Management',
      description: 'Assign, track, and manage employee daily tasks',
      category: 'Operations',
      groupName: 'Tasks',
    ),
    AppFeature(
      featureKey: CompanyModules.production,
      displayName: 'Production Management',
      description: 'Manage shop floor work orders and production batches',
      category: 'Operations',
      groupName: 'Production',
    ),
    AppFeature(
      featureKey: CompanyModules.machines,
      displayName: 'Machine & Equipment',
      description: 'Monitor CNC machines, status, and maintenance',
      category: 'Operations',
      groupName: 'Machines',
    ),
    AppFeature(
      featureKey: CompanyModules.tooling,
      displayName: 'Tooling & Fixtures',
      description: 'Track tooling inventory, condition, and issue logs',
      category: 'Engineering',
      groupName: 'Tooling',
    ),
    AppFeature(
      featureKey: CompanyModules.drawings,
      displayName: 'Engineering Drawings',
      description: 'Centralized CAD & part drawing management',
      category: 'Engineering',
      groupName: 'Programs',
    ),
    AppFeature(
      featureKey: CompanyModules.programs,
      displayName: 'CNC Programs',
      description: 'Manage CNC G-code programs and revisions',
      category: 'Engineering',
      groupName: 'Programs',
    ),
    AppFeature(
      featureKey: CompanyModules.inventory,
      displayName: 'Inventory Control',
      description: 'Raw materials and finished goods inventory tracking',
      category: 'Supply Chain',
      groupName: 'Inventory',
    ),
    AppFeature(
      featureKey: CompanyModules.lowStock,
      displayName: 'Low Stock Alerts',
      description: 'Automated warnings for minimum stock levels',
      category: 'Supply Chain',
      groupName: 'Inventory',
    ),
    AppFeature(
      featureKey: CompanyModules.purchase,
      displayName: 'Purchase Orders',
      description: 'Vendor management and procurement workflow',
      category: 'Supply Chain',
      groupName: 'Inventory',
    ),
    AppFeature(
      featureKey: CompanyModules.sales,
      displayName: 'Sales Orders',
      description: 'Customer order quotes, invoices, and sales tracking',
      category: 'Commercial',
      groupName: 'Sales',
    ),
    AppFeature(
      featureKey: CompanyModules.inwardOutward,
      displayName: 'Inward / Outward Dispatch',
      description: 'Challan and goods movement tracking',
      category: 'Supply Chain',
      groupName: 'Inventory',
    ),
    AppFeature(
      featureKey: CompanyModules.billing,
      displayName: 'Billing & Invoicing',
      description: 'Invoice generation and party accounts',
      category: 'Commercial',
      groupName: 'Sales',
    ),
    AppFeature(
      featureKey: CompanyModules.reports,
      displayName: 'Analytics & Reports',
      description: 'Executive dashboards, export reports, and performance stats',
      category: 'Analytics',
      groupName: 'Reports',
    ),
    AppFeature(
      featureKey: CompanyModules.documents,
      displayName: 'Document Storage',
      description: 'Central file vault for company documents',
      category: 'General',
      groupName: 'Other',
    ),
    AppFeature(
      featureKey: CompanyModules.notifications,
      displayName: 'Notifications System',
      description: 'In-app and email alert notifications',
      category: 'General',
      groupName: 'Other',
    ),
    AppFeature(
      featureKey: CompanyModules.comparison,
      displayName: 'Comparison Analytics',
      description: 'Production vs target comparative benchmarks',
      category: 'Analytics',
      groupName: 'Analytics',
    ),
    AppFeature(
      featureKey: CompanyModules.projectTracker,
      displayName: 'Project Tracker',
      description: 'Stage-by-stage project dashboard tracking',
      category: 'Operations',
      groupName: 'Project Tracker',
    ),
  ];

  static Map<String, AppFeature> get featureMap {
    return {for (var feat in allFeatures) feat.featureKey: feat};
  }

  static AppFeature? getFeature(String featureKey) {
    return featureMap[featureKey];
  }

  static List<String> get allFeatureKeys {
    return allFeatures.map((f) => f.featureKey).toList();
  }

  /// Groups all features by their assigned groupName
  static Map<String, List<AppFeature>> get groupedFeatures {
    final Map<String, List<AppFeature>> grouped = {};
    for (var group in featureGroups) {
      grouped[group] = [];
    }
    for (var feat in allFeatures) {
      final group = grouped.containsKey(feat.groupName) ? feat.groupName : 'Other';
      grouped.putIfAbsent(group, () => []).add(feat);
    }
    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }
}

