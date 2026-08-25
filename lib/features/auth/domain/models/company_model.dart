import 'package:cloud_firestore/cloud_firestore.dart';
import 'company_modules.dart';

class CompanyModel {
  final String companyId;
  final String companyCode;
  final String companyName;
  final String industry;
  final String gstNumber;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String country;
  final String timezone;
  final String workingHours;
  final String logoUrl;
  final String? companyLogoUrl;
  final String status; // Active, Suspended, Trial, Expired, Archived
  final String subscriptionPlan; // Trial, Starter, Professional, Enterprise
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String ownerUid;
  final String ownerStatus; // Active, Inactive, Suspended
  final DateTime createdAt;
  final DateTime updatedAt;
  final int performanceDeductionPerMinute;
  final int maxEmployees;
  final List<String> enabledModules;

  // Seat request fields
  final int? requestedSeats;
  final int? requestCurrentLimit;
  final int? requestNewLimit;
  final String? requestStatus; // pending, approved, rejected, or null
  final DateTime? requestedAt;

  const CompanyModel({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    required this.industry,
    required this.gstNumber,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.timezone,
    required this.workingHours,
    required this.logoUrl,
    this.companyLogoUrl,
    required this.status,
    required this.subscriptionPlan,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.ownerUid,
    required this.ownerStatus,
    required this.createdAt,
    required this.updatedAt,
    this.performanceDeductionPerMinute = 1,
    this.maxEmployees = 50,
    this.enabledModules = CompanyModules.all,
    this.requestedSeats,
    this.requestCurrentLimit,
    this.requestNewLimit,
    this.requestStatus,
    this.requestedAt,
  });

  // Backward compatibility getters
  String get id => companyId;
  String get name => companyName;

  factory CompanyModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return CompanyModel(
      companyId: docId,
      companyCode: (map['companyCode'] ?? '') as String,
      companyName: (map['companyName'] ?? map['name'] ?? '') as String,
      industry: (map['industry'] ?? '') as String,
      gstNumber: (map['gstNumber'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      country: (map['country'] ?? '') as String,
      timezone: (map['timezone'] ?? '') as String,
      workingHours: (map['workingHours'] ?? '') as String,
      logoUrl: (map['logoUrl'] ?? '') as String,
      companyLogoUrl: map['companyLogoUrl'] as String?,
      status: (map['status'] ?? 'Trial') as String,
      subscriptionPlan: (map['subscriptionPlan'] ?? 'Trial') as String,
      ownerName: (map['ownerName'] ?? '') as String,
      ownerEmail: (map['ownerEmail'] ?? '') as String,
      ownerPhone: (map['ownerPhone'] ?? '') as String,
      ownerUid: (map['ownerUid'] ?? '') as String,
      ownerStatus: (map['ownerStatus'] ?? 'Active') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      performanceDeductionPerMinute: (map['performanceDeductionPerMinute'] ?? 1) as int,
      maxEmployees: (map['maxEmployees'] ?? 50) as int,
      enabledModules: map['enabledModules'] != null
          ? List<String>.from(map['enabledModules'] as List)
          : CompanyModules.all,
      requestedSeats: map['requestedSeats'] as int?,
      requestCurrentLimit: map['requestCurrentLimit'] as int?,
      requestNewLimit: map['requestNewLimit'] as int?,
      requestStatus: map['requestStatus'] as String?,
      requestedAt: map['requestedAt'] != null ? parseDate(map['requestedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyCode': companyCode,
      'companyName': companyName,
      'industry': industry,
      'gstNumber': gstNumber,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'timezone': timezone,
      'workingHours': workingHours,
      'logoUrl': logoUrl,
      'companyLogoUrl': companyLogoUrl,
      'status': status,
      'subscriptionPlan': subscriptionPlan,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'ownerUid': ownerUid,
      'ownerStatus': ownerStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'performanceDeductionPerMinute': performanceDeductionPerMinute,
      'maxEmployees': maxEmployees,
      'enabledModules': enabledModules,
      'requestedSeats': requestedSeats,
      'requestCurrentLimit': requestCurrentLimit,
      'requestNewLimit': requestNewLimit,
      'requestStatus': requestStatus,
      'requestedAt': requestedAt != null ? Timestamp.fromDate(requestedAt!) : null,
    };
  }

  CompanyModel copyWith({
    String? companyId,
    String? companyCode,
    String? companyName,
    String? industry,
    String? gstNumber,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? timezone,
    String? workingHours,
    String? logoUrl,
    String? companyLogoUrl,
    String? status,
    String? subscriptionPlan,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? ownerUid,
    String? ownerStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? performanceDeductionPerMinute,
    int? maxEmployees,
    List<String>? enabledModules,
    int? requestedSeats,
    int? requestCurrentLimit,
    int? requestNewLimit,
    String? requestStatus,
    DateTime? requestedAt,
  }) {
    return CompanyModel(
      companyId: companyId ?? this.companyId,
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      gstNumber: gstNumber ?? this.gstNumber,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
      workingHours: workingHours ?? this.workingHours,
      logoUrl: logoUrl ?? this.logoUrl,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      status: status ?? this.status,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerStatus: ownerStatus ?? this.ownerStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      performanceDeductionPerMinute: performanceDeductionPerMinute ?? this.performanceDeductionPerMinute,
      maxEmployees: maxEmployees ?? this.maxEmployees,
      enabledModules: enabledModules ?? this.enabledModules,
      requestedSeats: requestedSeats ?? this.requestedSeats,
      requestCurrentLimit: requestCurrentLimit ?? this.requestCurrentLimit,
      requestNewLimit: requestNewLimit ?? this.requestNewLimit,
      requestStatus: requestStatus ?? this.requestStatus,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }
}
