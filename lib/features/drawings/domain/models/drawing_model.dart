import 'package:cloud_firestore/cloud_firestore.dart';

class DrawingModel {
  final String drawingId;
  final String companyId;
  final String drawingName;
  final String fileUrl;
  final String fileType; // 'pdf' or 'image'
  final String uploadedBy; // Uploader user name
  final String storagePath; // Path in Firebase Storage to prevent orphaned files on deletion
  final DateTime createdAt;

  const DrawingModel({
    required this.drawingId,
    required this.companyId,
    required this.drawingName,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedBy,
    required this.storagePath,
    required this.createdAt,
  });

  factory DrawingModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return DrawingModel(
      drawingId: id,
      companyId: (map['companyId'] ?? '') as String,
      drawingName: (map['drawingName'] ?? '') as String,
      fileUrl: (map['fileUrl'] ?? '') as String,
      fileType: (map['fileType'] ?? 'image') as String,
      uploadedBy: (map['uploadedBy'] ?? '') as String,
      storagePath: (map['storagePath'] ?? '') as String,
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'drawingId': drawingId,
      'companyId': companyId,
      'drawingName': drawingName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'storagePath': storagePath,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map.remove('createdAt');
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  DrawingModel copyWith({
    String? drawingId,
    String? companyId,
    String? drawingName,
    String? fileUrl,
    String? fileType,
    String? uploadedBy,
    String? storagePath,
    DateTime? createdAt,
  }) {
    return DrawingModel(
      drawingId: drawingId ?? this.drawingId,
      companyId: companyId ?? this.companyId,
      drawingName: drawingName ?? this.drawingName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
