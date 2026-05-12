import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/order.dart';

class ExportService {
  static Future<void> exportOrdersToCSV(List<OrderModel> orders) async {
    if (orders.isEmpty) return;

    final StringBuffer csv = StringBuffer();
    
    // Header
    csv.writeln('Order ID,Date,Time,Table,Waiter,Cashier,Subtotal,Service Charge,Discount,Grand Total,Payment Method,Status');

    for (final o in orders) {
      csv.writeln([
        o.id,
        DateFormat('yyyy-MM-dd').format(o.createdAt),
        DateFormat('HH:mm').format(o.createdAt),
        '"${o.tableName}"',
        '"${o.waiterName}"',
        '"${o.cashierName}"',
        o.totalAmount.toStringAsFixed(2),
        o.serviceCharge.toStringAsFixed(2),
        o.discountAmount.toStringAsFixed(2),
        o.grandTotal.toStringAsFixed(2),
        o.paymentMethod.toUpperCase(),
        o.status.name.toUpperCase(),
      ].join(','));
    }

    final Uint8List bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'st_george_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }
}
