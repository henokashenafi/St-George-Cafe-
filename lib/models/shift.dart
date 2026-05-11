class ShiftModel {
  final int? id;
  final int cashierId;
  final String cashierName;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingCash;
  final double? actualCashDeclared;
  final String status; // open, closed

  ShiftModel({
    this.id,
    required this.cashierId,
    this.cashierName = '',
    required this.startTime,
    this.endTime,
    this.startingCash = 0.0,
    this.actualCashDeclared,
    this.status = 'open',
  });

  bool get isOpen => status == 'open';

  ShiftModel copyWith({
    int? id,
    int? cashierId,
    String? cashierName,
    DateTime? startTime,
    DateTime? endTime,
    double? startingCash,
    double? actualCashDeclared,
    String? status,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startingCash: startingCash ?? this.startingCash,
      actualCashDeclared: actualCashDeclared ?? this.actualCashDeclared,
      status: status ?? this.status,
    );
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'],
      cashierId: map['cashier_id'] ?? 0,
      cashierName: map['cashier_name'] ?? '',
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      startingCash: (map['starting_cash'] as num? ?? 0).toDouble(),
      actualCashDeclared: map['actual_cash_declared'] != null 
          ? (map['actual_cash_declared'] as num).toDouble() 
          : null,
      status: map['status'] ?? 'open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cashier_id': cashierId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'starting_cash': startingCash,
      'actual_cash_declared': actualCashDeclared,
      'status': status,
    };
  }
}
