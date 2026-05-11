import 'dart:convert';

class ZReportModel {
  final int? id;
  final int shiftId;
  final int zCount;
  final Map<String, dynamic> reportData;
  final DateTime createdAt;

  ZReportModel({
    this.id,
    required this.shiftId,
    required this.zCount,
    required this.reportData,
    required this.createdAt,
  });

  factory ZReportModel.fromMap(Map<String, dynamic> map) {
    return ZReportModel(
      id: map['id'],
      shiftId: map['shift_id'] ?? 0,
      zCount: map['z_count'] ?? 0,
      reportData: jsonDecode(map['report_data'] ?? '{}'),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shift_id': shiftId,
      'z_count': zCount,
      'report_data': jsonEncode(reportData),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
