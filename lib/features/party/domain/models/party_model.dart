import 'package:cloud_firestore/cloud_firestore.dart';

class PartyModel {
  final String partyId;
  final String companyId;
  final String partyName;
  final String partyType; // 'Supplier' or 'Customer'
  final String vendorCode;
  final String address;
  final String contactNumber;
  final String contactPersonName;
  final String email;
  final String gstin;
  final String state;
  final String stateCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PartyModel({
    required this.partyId,
    required this.companyId,
    required this.partyName,
    required this.partyType,
    required this.vendorCode,
    required this.address,
    required this.contactNumber,
    required this.contactPersonName,
    required this.email,
    required this.gstin,
    required this.state,
    required this.stateCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartyModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return PartyModel(
      partyId: id,
      companyId: (map['companyId'] ?? '') as String,
      partyName: (map['partyName'] ?? '') as String,
      partyType: (map['partyType'] ?? 'Customer') as String,
      vendorCode: (map['vendorCode'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      contactNumber: (map['contactNumber'] ?? '') as String,
      contactPersonName: (map['contactPersonName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      gstin: (map['gstin'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      stateCode: (map['stateCode'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partyId': partyId,
      'companyId': companyId,
      'partyName': partyName,
      'partyType': partyType,
      'vendorCode': vendorCode,
      'address': address,
      'contactNumber': contactNumber,
      'contactPersonName': contactPersonName,
      'email': email,
      'gstin': gstin,
      'state': state,
      'stateCode': stateCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map.remove('createdAt');
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  PartyModel copyWith({
    String? partyId,
    String? companyId,
    String? partyName,
    String? partyType,
    String? vendorCode,
    String? address,
    String? contactNumber,
    String? contactPersonName,
    String? email,
    String? gstin,
    String? state,
    String? stateCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartyModel(
      partyId: partyId ?? this.partyId,
      companyId: companyId ?? this.companyId,
      partyName: partyName ?? this.partyName,
      partyType: partyType ?? this.partyType,
      vendorCode: vendorCode ?? this.vendorCode,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
