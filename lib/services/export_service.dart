import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_html/html.dart' as html;
import '../models/order.dart';
import '../models/order_item.dart';

class ExportService {
  /// Exports a focused X-Report to Excel (only Summary and Item Sales).
  static Future<String?> exportXReportToExcel(
    List<OrderModel> orders, {
    String dateLabel = '',
  }) async {
    if (orders.isEmpty) return null;
    try {
      final excel = Excel.createExcel();
      _addShiftSummarySheet(excel, orders, dateLabel);
      _addItemSalesSheet(excel, orders);
      
      // Remove default Sheet1 if empty
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
      
      return await _saveExcelFile(excel, 'XReport', dateLabel);
    } catch (e) {
      debugPrint('[Export X] Error: $e');
      return null;
    }
  }

  static Future<String?> exportOrdersToExcel(
    List<OrderModel> orders, {
    String dateLabel = '',
  }) async {
    if (orders.isEmpty) return null;

    try {
      final excel = Excel.createExcel();
      
      _addShiftSummarySheet(excel, orders, dateLabel);
      _addOrderSummarySheet(excel, orders);
      _addWaiterPerformanceSheet(excel, orders);
      _addTablePerformanceSheet(excel, orders);
      _addHourlySalesSheet(excel, orders);
      _addItemSalesSheet(excel, orders);
      _addAuditLogSheet(excel, orders);

      // Remove default Sheet1 if empty
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      return await _saveExcelFile(excel, 'AdvancedReport', dateLabel);
    } catch (e) {
      debugPrint('[Export] Error: $e');
      return null;
    }
  }

  static void _addShiftSummarySheet(Excel excel, List<OrderModel> orders, String dateLabel) {
    final sheet = excel['Shift Summary'];
    excel.setDefaultSheet('Shift Summary');

    // Set Column Widths
    sheet.setColumnWidth(0, 35.0); // Labels / Item Names
    sheet.setColumnWidth(1, 15.0); // Values / Quantities
    sheet.setColumnWidth(2, 20.0); // Revenue

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#D4AF37'),
    );
    final sectionHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
    );
    final labelStyle = CellStyle(bold: true);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('ST GEORGE CAFE POS - SHIFT REPORT');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
    
    sheet.appendRow([TextCellValue('Generated At:'), TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()))]);
    sheet.appendRow([TextCellValue('Date Range:'), TextCellValue(dateLabel)]);
    sheet.appendRow([]);

    double totalGross = 0;
    double totalService = 0;
    double totalDiscount = 0;
    final paymentTotals = <String, double>{};
    final itemTotals = <String, Map<String, dynamic>>{};

    for (final o in orders) {
      totalGross += o.totalAmount;
      totalService += o.serviceCharge;
      totalDiscount += o.discountAmount;
      paymentTotals[o.paymentMethod] = (paymentTotals[o.paymentMethod] ?? 0) + o.grandTotal;
      for (final item in o.items) {
        final key = item.productName;
        if (!itemTotals.containsKey(key)) {
          itemTotals[key] = {'qty': 0, 'rev': 0.0};
        }
        itemTotals[key]!['qty'] = (itemTotals[key]!['qty'] as int) + item.quantity;
        itemTotals[key]!['rev'] = (itemTotals[key]!['rev'] as double) + item.subtotal;
      }
    }

    sheet.appendRow([TextCellValue('FINANCIAL SUMMARY')]);
    for (int i = 0; i < 3; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: sheet.maxRows - 1)).cellStyle = sectionHeaderStyle;
    }
    sheet.appendRow([TextCellValue('Gross Sales:'), DoubleCellValue(totalGross)]);
    sheet.appendRow([TextCellValue('Service Charge:'), DoubleCellValue(totalService)]);
    sheet.appendRow([TextCellValue('Discounts:'), DoubleCellValue(totalDiscount)]);
    sheet.appendRow([TextCellValue('Net Sales (Grand Total):'), DoubleCellValue(totalGross + totalService - totalDiscount)]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('PAYMENT BREAKDOWN')]);
    for (int i = 0; i < 3; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: sheet.maxRows - 1)).cellStyle = sectionHeaderStyle;
    }
    paymentTotals.forEach((method, val) {
      sheet.appendRow([TextCellValue(method.toUpperCase()), DoubleCellValue(val)]);
    });
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('ITEM BREAKDOWN'), TextCellValue('QTY'), TextCellValue('AMOUNT')]);
    for (int i = 0; i < 3; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: sheet.maxRows - 1)).cellStyle = sectionHeaderStyle;
    }
    
    // Sort items by revenue
    final sortedItems = itemTotals.entries.toList()..sort((a, b) => (b.value['rev'] as double).compareTo(a.value['rev'] as double));
    
    for (final entry in sortedItems) {
      sheet.appendRow([
        TextCellValue(entry.key),
        IntCellValue(entry.value['qty'] as int),
        DoubleCellValue(entry.value['rev'] as double)
      ]);
    }
  }

  static void _addOrderSummarySheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Order Summary'];
    // Set Column Widths
    sheet.setColumnWidth(0, 10.0); // ID
    sheet.setColumnWidth(1, 15.0); // Date
    sheet.setColumnWidth(2, 10.0); // Time
    sheet.setColumnWidth(3, 15.0); // Table
    sheet.setColumnWidth(4, 20.0); // Table AM
    sheet.setColumnWidth(5, 15.0); // Waiter
    sheet.setColumnWidth(6, 20.0); // Waiter AM
    sheet.setColumnWidth(7, 15.0); // Cashier
    sheet.setColumnWidth(8, 12.0); // Subtotal
    sheet.setColumnWidth(9, 15.0); // Service
    sheet.setColumnWidth(10, 12.0); // Discount
    sheet.setColumnWidth(11, 15.0); // Grand Total
    sheet.setColumnWidth(12, 15.0); // Method
    sheet.setColumnWidth(13, 12.0); // Status

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'), fontColorHex: ExcelColor.fromHexString('#000000'));
    
    final headers = [
      TextCellValue('Order ID'), TextCellValue('Date'), TextCellValue('Time'), TextCellValue('Table'),
      TextCellValue('Table (አማርኛ)'), TextCellValue('Waiter'), TextCellValue('Waiter (አማርኛ)'), TextCellValue('Cashier'),
      TextCellValue('Subtotal'), TextCellValue('Service Charge'), TextCellValue('Discount'), TextCellValue('Grand Total'),
      TextCellValue('Payment Method'), TextCellValue('Status'),
    ];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final o in orders) {
      sheet.appendRow([
        IntCellValue(o.id ?? 0), TextCellValue(DateFormat('yyyy-MM-dd').format(o.createdAt)),
        TextCellValue(DateFormat('HH:mm').format(o.createdAt)), TextCellValue(o.tableName),
        TextCellValue(o.tableNameAmharic ?? ''), TextCellValue(o.waiterName),
        TextCellValue(o.waiterNameAmharic ?? ''), TextCellValue(o.cashierName),
        DoubleCellValue(o.totalAmount), DoubleCellValue(o.serviceCharge),
        DoubleCellValue(o.discountAmount), DoubleCellValue(o.grandTotal),
        TextCellValue(o.paymentMethod), TextCellValue(o.status.name),
      ]);
    }
  }

  static void _addWaiterPerformanceSheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Waiter Performance'];
    // Set Column Widths
    sheet.setColumnWidth(0, 20.0);
    sheet.setColumnWidth(1, 25.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 15.0);
    sheet.setColumnWidth(4, 15.0);

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'));
    final headers = [TextCellValue('Waiter Name'), TextCellValue('Waiter (አማርኛ)'), TextCellValue('Total Sales'), TextCellValue('Order Count'), TextCellValue('Avg Order Value')];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;

    final stats = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      if (!stats.containsKey(o.waiterName)) stats[o.waiterName] = {'amharic': o.waiterNameAmharic ?? '', 'sales': 0.0, 'count': 0};
      stats[o.waiterName]!['sales'] += o.grandTotal;
      stats[o.waiterName]!['count'] += 1;
    }
    stats.forEach((name, data) {
      final sales = data['sales'] as double; final count = data['count'] as int;
      sheet.appendRow([TextCellValue(name), TextCellValue(data['amharic'] as String), DoubleCellValue(sales), IntCellValue(count), DoubleCellValue(count > 0 ? sales / count : 0.0)]);
    });
  }

  static void _addTablePerformanceSheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Table Performance'];
    // Set Column Widths
    sheet.setColumnWidth(0, 15.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 15.0);

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'));
    final headers = [TextCellValue('Table Name'), TextCellValue('Table (አማርኛ)'), TextCellValue('Total Revenue'), TextCellValue('Order Count')];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;

    final stats = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      if (!stats.containsKey(o.tableName)) stats[o.tableName] = {'amharic': o.tableNameAmharic ?? '', 'sales': 0.0, 'count': 0};
      stats[o.tableName]!['sales'] += o.grandTotal;
      stats[o.tableName]!['count'] += 1;
    }
    stats.forEach((name, data) {
      sheet.appendRow([TextCellValue(name), TextCellValue(data['amharic'] as String), DoubleCellValue(data['sales'] as double), IntCellValue(data['count'] as int)]);
    });
  }

  static void _addHourlySalesSheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Hourly Sales'];
    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'));
    final headers = [TextCellValue('Hour (24h)'), TextCellValue('Sales Amount'), TextCellValue('Order Count')];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;

    final stats = List.generate(24, (_) => {'sales': 0.0, 'count': 0});
    for (final o in orders) {
      final hour = o.createdAt.hour;
      stats[hour]['sales'] = (stats[hour]['sales'] as double) + o.grandTotal;
      stats[hour]['count'] = (stats[hour]['count'] as int) + 1;
    }
    for (int h = 0; h < 24; h++) {
      if (stats[h]['count'] as int > 0) sheet.appendRow([TextCellValue('$h:00'), DoubleCellValue(stats[h]['sales'] as double), IntCellValue(stats[h]['count'] as int)]);
    }
  }

  static void _addItemSalesSheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Item Sales (PMIX)'];
    // Set Column Widths
    sheet.setColumnWidth(0, 25.0); // Name
    sheet.setColumnWidth(1, 30.0); // Name AM
    sheet.setColumnWidth(2, 15.0); // Category
    sheet.setColumnWidth(3, 20.0); // Category AM
    sheet.setColumnWidth(4, 10.0); // Qty
    sheet.setColumnWidth(5, 12.0); // Price
    sheet.setColumnWidth(6, 15.0); // Revenue

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'));
    final headers = [TextCellValue('Item Name'), TextCellValue('Item (አማርኛ)'), TextCellValue('Category'), TextCellValue('Category (አማርኛ)'), TextCellValue('Qty Sold'), TextCellValue('Unit Price'), TextCellValue('Total Revenue')];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;

    final aggMap = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      for (final item in o.items) {
        final key = item.productName;
        if (!aggMap.containsKey(key)) {
          aggMap[key] = {'amharic': item.productNameAmharic ?? '', 'category': item.categoryName ?? 'General', 'categoryAmharic': item.categoryNameAmharic ?? '', 'qty': 0, 'unitPrice': item.unitPrice, 'revenue': 0.0};
        }
        aggMap[key]!['qty'] = (aggMap[key]!['qty'] as int) + item.quantity;
        aggMap[key]!['revenue'] = (aggMap[key]!['revenue'] as double) + item.subtotal;
      }
    }
    final sortedAgg = aggMap.entries.toList()..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));
    for (final entry in sortedAgg) {
      sheet.appendRow([TextCellValue(entry.key), TextCellValue(entry.value['amharic'] as String), TextCellValue(entry.value['category'] as String), TextCellValue(entry.value['categoryAmharic'] as String), IntCellValue(entry.value['qty'] as int), DoubleCellValue(entry.value['unitPrice'] as double), DoubleCellValue(entry.value['revenue'] as double)]);
    }
  }

  static void _addAuditLogSheet(Excel excel, List<OrderModel> orders) {
    final sheet = excel['Transaction Audit Log'];
    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D4AF37'));
    final headers = [TextCellValue('Order ID'), TextCellValue('Timestamp'), TextCellValue('Item Name'), TextCellValue('Item (አማርኛ)'), TextCellValue('Category'), TextCellValue('Qty'), TextCellValue('Unit Price'), TextCellValue('Subtotal'), TextCellValue('Table'), TextCellValue('Waiter'), TextCellValue('Payment')];
    sheet.appendRow(headers);
    for (int i = 0; i < headers.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;

    for (final o in orders) {
      for (final item in o.items) {
        sheet.appendRow([IntCellValue(o.id ?? 0), TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(o.createdAt)), TextCellValue(item.productName), TextCellValue(item.productNameAmharic ?? ''), TextCellValue(item.categoryName ?? 'General'), IntCellValue(item.quantity), DoubleCellValue(item.unitPrice), DoubleCellValue(item.subtotal), TextCellValue(o.tableName), TextCellValue(o.waiterName), TextCellValue(o.paymentMethod)]);
      }
    }
  }

  static Future<String?> _saveExcelFile(Excel excel, String prefix, String dateLabel) async {
    final bytes = excel.encode();
    if (bytes == null) return null;

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final label = dateLabel.isNotEmpty ? '_${dateLabel.replaceAll(' ', '_')}' : '';
    final fileName = 'StGeorgeCafe_${prefix}${label}_$timestamp.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
      html.Url.revokeObjectUrl(url);
      return 'Download Started: $fileName';
    } else {
      final dir = await _getSaveDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return filePath;
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
