import 'package:flutter/material.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/settings.dart';
import 'package:st_george_pos/services/enhanced_print_service.dart';
import 'package:st_george_pos/services/order_workflow_service.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:intl/intl.dart';

class EnhancedBillService {
  /// Print order list when items are sent to kitchen
  static Future<void> printOrderListForKitchen({
    required OrderModel order,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    try {
      await EnhancedPrintService.printOrderList(
        order: order,
        settings: settings,
        t: t,
        isCombined: false,
      );
    } catch (e) {
      throw Exception('Failed to print order list: $e');
    }
  }

  /// Print combined order list for multiple sessions
  static Future<void> printCombinedOrderList({
    required List<OrderModel> sessions,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    try {
      await EnhancedPrintService.printCombinedOrderList(
        sessions: sessions,
        settings: settings,
        t: t,
      );
    } catch (e) {
      throw Exception('Failed to print combined order list: $e');
    }
  }

  /// Print final receipt combining all sessions for a table
  static Future<void> printFinalReceiptForTable({
    required int tableId,
    required List<OrderModel> sessions,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    try {
      // Create combined order for final receipt
      final combinedOrder = OrderWorkflowService.combineSessionsForBilling(
        tableId: tableId,
        sessions: sessions,
        zones: [], // Will be populated by workflow service
        waiters: [],
      );

      await EnhancedPrintService.printFinalReceipt(
        combinedOrder: combinedOrder,
        sessions: sessions,
        settings: settings,
        t: t,
      );
    } catch (e) {
      throw Exception('Failed to print final receipt: $e');
    }
  }

  /// Generate and download bill for combined orders
  static Future<void> generateAndDownloadBill({
    required int tableId,
    required List<OrderModel> sessions,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    try {
      // Create combined order
      final combinedOrder = OrderWorkflowService.combineSessionsForBilling(
        tableId: tableId,
        sessions: sessions,
        zones: [],
        waiters: [],
      );

      // Generate PDF
      final pdf = await _generateBillPDF(combinedOrder, sessions, settings, t);
      
      // Download logic would go here
      // For now, just print the receipt
      await EnhancedPrintService.printFinalReceipt(
        combinedOrder: combinedOrder,
        sessions: sessions,
        settings: settings,
        t: t,
      );
    } catch (e) {
      throw Exception('Failed to generate bill: $e');
    }
  }

  /// Calculate totals for combined orders
  static Map<String, dynamic> calculateCombinedTotals({
    required List<OrderModel> sessions,
    required Map<String, String> settings,
  }) {
    final allItems = <OrderItem>[];
    for (final session in sessions) {
      allItems.addAll(session.items);
    }

    final subtotal = allItems.fold(0.0, (sum, item) => sum + item.subtotal);
    final serviceChargeRate = double.tryParse(settings['serviceCharge'] ?? '0') ?? 0.0;
    final serviceCharge = subtotal * (serviceChargeRate / 100);
    final totalDiscount = sessions.fold(0.0, (sum, session) => sum + session.discountAmount);
    final grandTotal = subtotal + serviceCharge - totalDiscount;

    return {
      'subtotal': subtotal,
      'serviceCharge': serviceCharge,
      'serviceChargeRate': serviceChargeRate,
      'discount': totalDiscount,
      'grandTotal': grandTotal,
      'itemCount': allItems.length,
      'sessionCount': sessions.length,
    };
  }

  /// Get session summary for display
  static List<Map<String, dynamic>> getSessionSummaries(List<OrderModel> sessions) {
    return sessions.map((session) => {
      'sessionId': session.sessionId,
      'createdAt': session.createdAt,
      'itemCount': session.items.length,
      'total': session.totalAmount,
      'status': session.status.name,
      'waiter': session.waiterName,
    }).toList();
  }

  /// Validate that all sessions can be combined
  static List<String> validateSessionsForCombination(List<OrderModel> sessions) {
    final errors = <String>[];
    
    if (sessions.isEmpty) {
      errors.add('No sessions to combine');
      return errors;
    }

    // Check if all sessions belong to the same table
    final tableIds = sessions.map((s) => s.tableId).toSet();
    if (tableIds.length > 1) {
      errors.add('Sessions belong to different tables');
    }

    // Check if any session is already completed
    final completedSessions = sessions.where((s) => s.status == OrderStatus.completed);
    if (completedSessions.isNotEmpty) {
      errors.add('Some sessions are already completed');
    }

    // Check if any session has no items
    final emptySessions = sessions.where((s) => s.items.isEmpty);
    if (emptySessions.isNotEmpty) {
      errors.add('Some sessions have no items');
    }

    return errors;
  }

  /// Generate bill PDF (internal method)
  static Future<pw.Document> _generateBillPDF(
    OrderModel combinedOrder,
    List<OrderModel> sessions,
    Map<String, String> settings,
    String Function(String) t,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            _buildPDFHeader(settings, t, now),
            pw.SizedBox(height: 20),
            
            // Order Info
            _buildPDFOrderInfo(combinedOrder, sessions, t),
            pw.SizedBox(height: 20),
            
            // Sessions Summary
            if (sessions.length > 1) ...[
              _buildPDFSessionSummary(sessions, t),
              pw.SizedBox(height: 20),
            ],
            
            // Items
            _buildPDFItems(combinedOrder.items, t),
            pw.SizedBox(height: 20),
            
            // Totals
            _buildPDFTotals(combinedOrder, settings, t),
            pw.SizedBox(height: 20),
            
            // Footer
            _buildPDFFooter(t, now),
          ],
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _buildPDFHeader(Map<String, String> settings, String Function(String) t, DateTime now) {
    return pw.Column(
      children: [
        pw.Text(
          settings['restaurantName'] ?? 'ST. GEORGE CAFE',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (settings['address'] != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            settings['address']!,
            style: const pw.TextStyle(fontSize: 14),
            textAlign: pw.TextAlign.center,
          ),
        ],
        if (settings['phone'] != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            settings['phone']!,
            style: const pw.TextStyle(fontSize: 14),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Text(
          t('print.receipt'),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm').format(now),
          style: const pw.TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  static pw.Widget _buildPDFOrderInfo(OrderModel combinedOrder, List<OrderModel> sessions, String Function(String) t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${t('print.table')}: ${combinedOrder.tableName}',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${t('print.waiter')}: ${combinedOrder.waiterName}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${t('print.sessions')}: ${sessions.length}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                '${t('print.items')}: ${combinedOrder.items.length}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (sessions.length > 1) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              '${t('print.sessionDetails')}: ${sessions.map((s) => DateFormat('HH:mm').format(s.createdAt)).join(', ')}',
              style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPDFSessionSummary(List<OrderModel> sessions, String Function(String) t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            t('print.sessionDetails'),
            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          ...sessions.map((session) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    DateFormat('HH:mm').format(session.createdAt),
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    '${session.items.length} ${t('print.items')}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    session.totalAmount.toStringAsFixed(2),
                    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  static pw.Widget _buildPDFItems(List<OrderItem> items, String Function(String) t) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t('print.items'),
          style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPDFCell(t('print.items'), isHeader: true),
                _buildPDFCell(t('print.quantity'), isHeader: true),
                _buildPDFCell(t('print.price'), isHeader: true),
                _buildPDFCell(t('print.total'), isHeader: true),
              ],
            ),
            // Items
            ...items.map((item) => pw.TableRow(
              children: [
                _buildPDFCell(item.productName),
                _buildPDFCell(item.quantity.toString()),
                _buildPDFCell(item.unitPrice.toStringAsFixed(2)),
                _buildPDFCell(item.subtotal.toStringAsFixed(2)),
              ],
            )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPDFCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildPDFTotals(OrderModel order, Map<String, String> settings, String Function(String) t) {
    final serviceChargeRate = double.tryParse(settings['serviceCharge'] ?? '0') ?? 0.0;
    final serviceCharge = order.totalAmount * (serviceChargeRate / 100);
    final grandTotal = order.totalAmount + serviceCharge - order.discountAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                t('print.subtotal'),
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                order.totalAmount.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (serviceCharge > 0) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${t('print.serviceCharge')} ($serviceChargeRate%)',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  serviceCharge.toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
          if (order.discountAmount > 0) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  t('print.discount'),
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  '-${order.discountAmount.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                t('print.total'),
                style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                grandTotal.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            _numberToWords(grandTotal, t),
            style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPDFFooter(String Function(String) t, DateTime now) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),
        pw.Text(
          t('print.thankYou'),
          style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          t('print.visitAgain'),
          style: const pw.TextStyle(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
          style: const pw.TextStyle(fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static String _numberToWords(double amount, String Function(String) t) {
    // This would use the same logic as in the print service
    // For brevity, returning a simple implementation
    return '${amount.toStringAsFixed(2)} ${t('numbers.only')}';
  }
}
