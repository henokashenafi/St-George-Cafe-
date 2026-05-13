import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_html/html.dart' as html;
import '../models/order.dart';
import '../models/order_item.dart';

class ExportService {
  /// Exports the given orders to an Excel file.
  /// Handles both Web (Chrome download) and Desktop (Local file) automatically.
  static Future<String?> exportOrdersToExcel(
    List<OrderModel> orders, {
    String dateLabel = '',
  }) async {
    if (orders.isEmpty) return null;

    try {
      final excel = Excel.createExcel();

      // ── Sheet 1: Order Summary ──────────────────────────────────────────
      final summarySheet = excel['Order Summary'];
      excel.setDefaultSheet('Order Summary');

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D4AF37'),
        fontColorHex: ExcelColor.fromHexString('#000000'),
      );

      final summaryHeaders = [
        TextCellValue('Order ID'),
        TextCellValue('Date'),
        TextCellValue('Time'),
        TextCellValue('Table'),
        TextCellValue('Waiter'),
        TextCellValue('Cashier'),
        TextCellValue('Subtotal'),
        TextCellValue('Service Charge'),
        TextCellValue('Discount'),
        TextCellValue('Grand Total'),
        TextCellValue('Payment Method'),
        TextCellValue('Status'),
      ];

      summarySheet.appendRow(summaryHeaders);
      for (int i = 0; i < summaryHeaders.length; i++) {
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      for (final o in orders) {
        summarySheet.appendRow([
          IntCellValue(o.id ?? 0),
          TextCellValue(DateFormat('yyyy-MM-dd').format(o.createdAt)),
          TextCellValue(DateFormat('HH:mm').format(o.createdAt)),
          TextCellValue(o.tableName),
          TextCellValue(o.waiterName),
          TextCellValue(o.cashierName),
          DoubleCellValue(o.totalAmount),
          DoubleCellValue(o.serviceCharge),
          DoubleCellValue(o.discountAmount),
          DoubleCellValue(o.grandTotal),
          TextCellValue(o.paymentMethod),
          TextCellValue(o.status.name),
        ]);
      }

      // ── Sheet 2: Waiter Performance ────────────────────────────────────
      final waiterSheet = excel['Waiter Performance'];
      final waiterHeaders = [
        TextCellValue('Waiter Name'),
        TextCellValue('Total Sales'),
        TextCellValue('Order Count'),
        TextCellValue('Avg Order Value'),
      ];
      waiterSheet.appendRow(waiterHeaders);
      for (int i = 0; i < waiterHeaders.length; i++) {
        waiterSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      final waiterStats = <String, Map<String, dynamic>>{};
      for (final o in orders) {
        if (!waiterStats.containsKey(o.waiterName)) {
          waiterStats[o.waiterName] = {'sales': 0.0, 'count': 0};
        }
        waiterStats[o.waiterName]!['sales'] += o.grandTotal;
        waiterStats[o.waiterName]!['count'] += 1;
      }

      waiterStats.forEach((name, data) {
        final sales = data['sales'] as double;
        final count = data['count'] as int;
        waiterSheet.appendRow([
          TextCellValue(name),
          DoubleCellValue(sales),
          IntCellValue(count),
          DoubleCellValue(count > 0 ? sales / count : 0.0),
        ]);
      });

      // ── Sheet 3: Table Performance ─────────────────────────────────────
      final tableSheet = excel['Table Performance'];
      final tableHeaders = [
        TextCellValue('Table Name'),
        TextCellValue('Total Revenue'),
        TextCellValue('Order Count'),
      ];
      tableSheet.appendRow(tableHeaders);
      for (int i = 0; i < tableHeaders.length; i++) {
        tableSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      final tableStats = <String, Map<String, dynamic>>{};
      for (final o in orders) {
        if (!tableStats.containsKey(o.tableName)) {
          tableStats[o.tableName] = {'sales': 0.0, 'count': 0};
        }
        tableStats[o.tableName]!['sales'] += o.grandTotal;
        tableStats[o.tableName]!['count'] += 1;
      }

      tableStats.forEach((name, data) {
        tableSheet.appendRow([
          TextCellValue(name),
          DoubleCellValue(data['sales'] as double),
          IntCellValue(data['count'] as int),
        ]);
      });

      // ── Sheet 4: Hourly Sales ──────────────────────────────────────────
      final hourlySheet = excel['Hourly Sales'];
      final hourlyHeaders = [
        TextCellValue('Hour (24h)'),
        TextCellValue('Sales Amount'),
        TextCellValue('Order Count'),
      ];
      hourlySheet.appendRow(hourlyHeaders);
      for (int i = 0; i < hourlyHeaders.length; i++) {
        hourlySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      final hourlyStats = List.generate(24, (_) => {'sales': 0.0, 'count': 0});
      for (final o in orders) {
        final hour = o.createdAt.hour;
        hourlyStats[hour]['sales'] = (hourlyStats[hour]['sales'] as double) + o.grandTotal;
        hourlyStats[hour]['count'] = (hourlyStats[hour]['count'] as int) + 1;
      }

      for (int h = 0; h < 24; h++) {
        if (hourlyStats[h]['count'] as int > 0) {
          hourlySheet.appendRow([
            TextCellValue('$h:00'),
            DoubleCellValue(hourlyStats[h]['sales'] as double),
            IntCellValue(hourlyStats[h]['count'] as int),
          ]);
        }
      }

      // ── Sheet 5: Item Sales (PMIX) ─────────────────────────────────────
      final itemSheet = excel['Item Sales (PMIX)'];
      final itemHeaders = [
        TextCellValue('Item Name'),
        TextCellValue('Category'),
        TextCellValue('Qty Sold'),
        TextCellValue('Unit Price'),
        TextCellValue('Total Revenue'),
      ];
      itemSheet.appendRow(itemHeaders);
      for (int i = 0; i < itemHeaders.length; i++) {
        itemSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      final aggMap = <String, Map<String, dynamic>>{};
      for (final o in orders) {
        for (final item in o.items) {
          final key = item.productName;
          if (!aggMap.containsKey(key)) {
            aggMap[key] = {
              'category': item.categoryName ?? 'General',
              'qty': 0,
              'unitPrice': item.unitPrice,
              'revenue': 0.0,
            };
          }
          aggMap[key]!['qty'] = (aggMap[key]!['qty'] as int) + item.quantity;
          aggMap[key]!['revenue'] = (aggMap[key]!['revenue'] as double) + item.subtotal;
        }
      }

      final sortedAgg = aggMap.entries.toList()
        ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

      for (final entry in sortedAgg) {
        itemSheet.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value['category'] as String),
          IntCellValue(entry.value['qty'] as int),
          DoubleCellValue(entry.value['unitPrice'] as double),
          DoubleCellValue(entry.value['revenue'] as double),
        ]);
      }

      // ── Export Handling ────────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) return null;

      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final label = dateLabel.isNotEmpty ? '_${dateLabel.replaceAll(' ', '_')}' : '';
      final fileName = 'StGeorgeCafe_AdvancedReport${label}_$timestamp.xlsx';

      if (kIsWeb) {
        // Handle Web Download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Download Started: $fileName';
      } else {
        // Handle Desktop Save
        final dir = await _getSaveDirectory();
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      }
    } catch (e) {
      debugPrint('[Export] Error: $e');
      return null;
    }
  }

  static Future<Directory> _getSaveDirectory() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
        if (home.isNotEmpty) {
          final docs = Directory('$home/Documents');
          if (await docs.exists()) return docs;
        }
      }
    } catch (_) {}
    return await getApplicationDocumentsDirectory();
  }
}
