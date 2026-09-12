class EmployeeModel {
  final String employeeId;
  final String uid;
  final String companyId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department;
  final String designation;
  final String status; // 'Active', 'Inactive'
  final String? photoUrl;
  final DateTime joiningDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  final String panCardNumber;
  final String aadhaarCardNumber;
  final String permanentAddress;
  final String currentAddress;
  final String alternatePhone;

  const EmployeeModel({
    required this.employeeId,
    required this.uid,
    required this.companyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.designation,
    required this.status,
    this.photoUrl,
    required this.joiningDate,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
    this.panCardNumber = '',
    this.aadhaarCardNumber = '',
    this.permanentAddress = '',
    this.currentAddress = '',
    this.alternatePhone = '',
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      employeeId: (map['employeeId'] ?? map['id'] ?? '') as String,
      uid: (map['uid'] ?? '') as String,
      companyId: (map['companyId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: (map['role'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      designation: (map['designation'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      photoUrl: map['photoUrl'] as String?,
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
      panCardNumber: (map['panCardNumber'] ?? '') as String,
      aadhaarCardNumber: (map['aadhaarCardNumber'] ?? '') as String,
      permanentAddress: (map['permanentAddress'] ?? '') as String,
      currentAddress: (map['currentAddress'] ?? '') as String,
      alternatePhone: (map['alternatePhone'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'uid': uid,
      'companyId': companyId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'designation': designation,
      'status': status,
      'photoUrl': photoUrl,
      'joiningDate': joiningDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'panCardNumber': panCardNumber,
      'aadhaarCardNumber': aadhaarCardNumber,
      'permanentAddress': permanentAddress,
      'currentAddress': currentAddress,
      'alternatePhone': alternatePhone,
    };
  }

  EmployeeModel copyWith({
    String? employeeId,
    String? uid,
    String? companyId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    String? designation,
    String? status,
    String? photoUrl,
    DateTime? joiningDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    String? panCardNumber,
    String? aadhaarCardNumber,
    String? permanentAddress,
    String? currentAddress,
    String? alternatePhone,
  }) {
    return EmployeeModel(
      employeeId: employeeId ?? this.employeeId,
      uid: uid ?? this.uid,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      joiningDate: joiningDate ?? this.joiningDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      panCardNumber: panCardNumber ?? this.panCardNumber,
      aadhaarCardNumber: aadhaarCardNumber ?? this.aadhaarCardNumber,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      currentAddress: currentAddress ?? this.currentAddress,
      alternatePhone: alternatePhone ?? this.alternatePhone,
    );
  }
}
