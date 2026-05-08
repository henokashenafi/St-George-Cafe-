import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:intl/intl.dart';

class EnhancedPrintService {
  static const _paperWidth = 80.0; // mm for thermal printer
  static const _paperHeight = 297.0; // mm A4

  /// Print order list (kitchen copy) - prints as items are added
  static Future<void> printOrderList({
    required OrderModel order,
    required Map<String, String> settings,
    required String Function(String) t,
    bool isCombined = false,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_paperWidth * PdfPageFormat.mm, _paperHeight * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            _buildKitchenHeader(settings, t, now, isCombined),
            pw.SizedBox(height: 10),
            
            // Order Info
            _buildKitchenOrderInfo(order, t),
            pw.SizedBox(height: 10),
            
            // Items
            _buildKitchenItems(order.items, t),
            pw.SizedBox(height: 10),
            
            // Footer
            _buildKitchenFooter(t, now),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Order_List_${order.tableName}_${now.millisecondsSinceEpoch}',
    );
  }

  /// Print final receipt - combines all sessions for a table
  static Future<void> printFinalReceipt({
    required OrderModel combinedOrder,
    required List<OrderModel> sessions,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_paperWidth * PdfPageFormat.mm, _paperHeight * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            _buildReceiptHeader(settings, t, now),
            pw.SizedBox(height: 10),
            
            // Order Info
            _buildReceiptOrderInfo(combinedOrder, sessions, t),
            pw.SizedBox(height: 10),
            
            // Items
            _buildReceiptItems(combinedOrder.items, t),
            pw.SizedBox(height: 10),
            
            // Totals
            _buildReceiptTotals(combinedOrder, settings, t),
            pw.SizedBox(height: 10),
            
            // Footer
            _buildReceiptFooter(t, now),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Final_Receipt_${combinedOrder.tableName}_${now.millisecondsSinceEpoch}',
    );
  }

  /// Print combined order list for multiple sessions
  static Future<void> printCombinedOrderList({
    required List<OrderModel> sessions,
    required Map<String, String> settings,
    required String Function(String) t,
  }) async {
    if (sessions.isEmpty) return;

    // Combine all items from all sessions
    final allItems = <OrderItem>[];
    for (final session in sessions) {
      allItems.addAll(session.items);
    }

    // Create a temporary combined order for printing
    final combinedOrder = OrderModel(
      tableId: sessions.first.tableId,
      tableName: sessions.first.tableName,
      waiterId: sessions.first.waiterId,
      waiterName: sessions.first.waiterName,
      status: OrderStatus.pending,
      createdAt: sessions.first.createdAt,
      updatedAt: DateTime.now(),
      items: allItems,
      totalAmount: allItems.fold(0.0, (sum, item) => sum + item.subtotal),
      sessionId: 'combined_${sessions.map((s) => s.sessionId).join('_')}',
    );

    await printOrderList(
      order: combinedOrder,
      settings: settings,
      t: t,
      isCombined: true,
    );
  }

  static pw.Widget _buildKitchenHeader(Map<String, String> settings, String Function(String) t, DateTime now, bool isCombined) {
    return pw.Column(
      children: [
        pw.Text(
          settings['restaurantName'] ?? 'ST. GEORGE CAFE',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          isCombined ? t('print.combinedOrderList') : t('print.orderList'),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm').format(now),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildKitchenOrderInfo(OrderModel order, String Function(String) t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${t('print.table')}: ${order.tableName}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${t('print.waiter')}: ${order.waiterName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (order.sessionId.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              '${t('print.session')}: ${order.sessionId}',
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildKitchenItems(List<OrderItem> items, String Function(String) t) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t('print.items'),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...items.map((item) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${item.quantity}x ${item.productName}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Text(
                        '  Note: ${item.notes}',
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Container(
                width: 30,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  item.subtotal.toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  static pw.Widget _buildKitchenFooter(String Function(String) t, DateTime now) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.Text(
          t('print.kitchenCopy'),
          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptHeader(Map<String, String> settings, String Function(String) t, DateTime now) {
    return pw.Column(
      children: [
        pw.Text(
          settings['restaurantName'] ?? 'ST. GEORGE CAFE',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (settings['address'] != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            settings['address']!,
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ],
        if (settings['phone'] != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            settings['phone']!,
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 5),
        pw.Text(
          t('print.receipt'),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm').format(now),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(thickness: 1),
      ],
    );
  }

  static pw.Widget _buildReceiptOrderInfo(OrderModel combinedOrder, List<OrderModel> sessions, String Function(String) t) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${t('print.table')}: ${combinedOrder.tableName}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${t('print.waiter')}: ${combinedOrder.waiterName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${t('print.sessions')}: ${sessions.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                '${t('print.items')}: ${combinedOrder.items.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (sessions.length > 1) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              '${t('print.sessionDetails')}: ${sessions.map((s) => DateFormat('HH:mm').format(s.createdAt)).join(', ')}',
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptItems(List<OrderItem> items, String Function(String) t) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t('print.items'),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...items.map((item) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${item.quantity}x ${item.productName}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Text(
                        '  Note: ${item.notes}',
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Container(
                width: 25,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  item.unitPrice.toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Container(
                width: 30,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  item.subtotal.toStringAsFixed(2),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  static pw.Widget _buildReceiptTotals(OrderModel order, Map<String, String> settings, String Function(String) t) {
    final serviceChargeRate = double.tryParse(settings['serviceCharge'] ?? '0') ?? 0.0;
    final serviceCharge = order.totalAmount * (serviceChargeRate / 100);
    final grandTotal = order.totalAmount + serviceCharge - order.discountAmount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                t('print.subtotal'),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                order.totalAmount.toStringAsFixed(2),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (serviceCharge > 0) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${t('print.serviceCharge')} ($serviceChargeRate%)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  serviceCharge.toStringAsFixed(2),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
          if (order.discountAmount > 0) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  t('print.discount'),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  '-${order.discountAmount.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                t('print.total'),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                grandTotal.toStringAsFixed(2),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            _numberToWords(grandTotal, t),
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptFooter(String Function(String) t, DateTime now) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.Text(
          t('print.thankYou'),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          t('print.visitAgain'),
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static String _numberToWords(double amount, String Function(String) t) {
    final wholePart = amount.floor();
    final decimalPart = ((amount - wholePart) * 100).round();
    
    String words = _convertNumberToWords(wholePart, t);
    
    if (decimalPart > 0) {
      words += ' ${t('numbers.and')} ${_convertNumberToWords(decimalPart, t)} ${t('numbers.cents')}';
    }
    
    return '${words} ${t('numbers.only')}';
  }

  static String _convertNumberToWords(int number, String Function(String) t) {
    if (number == 0) return t('numbers.zero');
    
    final units = [
      '', t('numbers.one'), t('numbers.two'), t('numbers.three'), t('numbers.four'),
      t('numbers.five'), t('numbers.six'), t('numbers.seven'), t('numbers.eight'), t('numbers.nine')
    ];
    
    final teens = [
      t('numbers.ten'), t('numbers.eleven'), t('numbers.twelve'), t('numbers.thirteen'), t('numbers.fourteen'),
      t('numbers.fifteen'), t('numbers.sixteen'), t('numbers.seventeen'), t('numbers.eighteen'), t('numbers.nineteen')
    ];
    
    final tens = [
      '', t('numbers.ten'), t('numbers.twenty'), t('numbers.thirty'), t('numbers.forty'),
      t('numbers.fifty'), t('numbers.sixty'), t('numbers.seventy'), t('numbers.eighty'), t('numbers.ninety')
    ];
    
    if (number < 10) return units[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      final tenPart = tens[number ~/ 10];
      final unitPart = number % 10;
      return unitPart > 0 ? '$tenPart ${units[unitPart]}' : tenPart;
    }
    if (number < 1000) {
      final hundredPart = units[number ~/ 100];
      final remainder = number % 100;
      return remainder > 0 
          ? '$hundredPart ${t('numbers.hundred')} ${_convertNumberToWords(remainder, t)}'
          : '$hundredPart ${t('numbers.hundred')}';
    }
    if (number < 1000000) {
      final thousandPart = number ~/ 1000;
      final remainder = number % 1000;
      final thousandWords = thousandPart == 1 
          ? t('numbers.thousand') 
          : '${_convertNumberToWords(thousandPart, t)} ${t('numbers.thousand')}';
      return remainder > 0 
          ? '$thousandWords ${_convertNumberToWords(remainder, t)}'
          : thousandWords;
    }
    
    return number.toString();
  }
}
