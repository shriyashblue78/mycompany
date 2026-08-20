class UserModel {
  final String uid;
  final String companyId;
  final String employeeId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department;
  final String designation;
  final String status; // e.g., 'Active', 'Inactive'
  final DateTime joiningDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.companyId,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.designation,
    required this.status,
    required this.joiningDate,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? '') as String,
      companyId: (map['companyId'] ?? '') as String,
      employeeId: (map['employeeId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: (map['role'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      designation: (map['designation'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      joiningDate: map['joiningDate'] != null
          ? DateTime.parse(map['joiningDate'] as String)
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? DateTime.parse(map['lastLogin'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'companyId': companyId,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'designation': designation,
      'status': status,
      'joiningDate': joiningDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? companyId,
    String? employeeId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    String? designation,
    String? status,
    DateTime? joiningDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
