import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/settings.dart';

class BillService {
  // ── Kitchen Slip PDF (A5 compact) ────────────────────────────────────────

  static Future<void> generateKitchenSlip({
    required OrderModel order,
    required List<OrderItem> items,
    required int roundNumber,
    required String Function(String key, {Map<String, String>? replacements}) t,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text(
                'KITCHEN ORDER',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Round: $roundNumber',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1),

            // Info
            _receiptRow('Table:', order.tableName),
            _receiptRow('Order:', '#${order.id ?? "—"}'),
            _receiptRow('Waiter:', order.waiterName),
            _receiptRow('Time:', '$timeStr | $dateStr'),
            pw.Divider(thickness: 1),

            // Items
            pw.SizedBox(height: 4),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${item.quantity} x ${item.productName}',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, top: 1),
                        child: pw.Text('>> ${item.notes}', style: const pw.TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1),
            pw.Center(
              child: pw.Text(
                'Items: ${items.length} | Round: $roundNumber',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Kitchen_Round${roundNumber}_Order${order.id}.pdf',
    );
  }

  // ── Customer Receipt PDF (80mm Roll - Compact) ───────────────────────────

  static Future<void> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required CafeSettings settings,
    required String cashierName,
    required double serviceChargePercent,
    required String Function(String key, {Map<String, String>? replacements}) t,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final voucherNo =
        'RCS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(order.id ?? 0).toString().padLeft(3, '0')}';

    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    final serviceCharge = subtotal * (serviceChargePercent / 100);
    final discount = order.discountAmount;
    final grandTotal = subtotal + serviceCharge - discount;

    final cafeName = settings.name.isNotEmpty
        ? settings.name
        : 'ST GEORGE CAFE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text(
                cafeName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.address,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'Tel: ${settings.phone}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'CASH SALES INVOICE',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.5),

            // Info
            _receiptRow('Voucher:', voucherNo),
            _receiptRow('Date:', dateStr),
            _receiptRow('Table:', order.tableName),
            _receiptRow('Waiter:', order.waiterName),
            _receiptRow('Cashier:', cashierName),
            pw.Divider(thickness: 0.5),

            // Items Table
            pw.Row(
              children: [
                pw.Expanded(flex: 4, child: pw.Text('Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
              ],
            ),
            pw.SizedBox(height: 4),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 9))),
                    pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text(_fmt(item.unitPrice), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text(_fmt(item.subtotal), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
            ),
            pw.Divider(thickness: 0.5),

            // Totals
            _totalRowReceipt('Subtotal:', subtotal),
            _totalRowReceipt('Service Charge (${serviceChargePercent.toStringAsFixed(0)}%):', serviceCharge),
            if (discount > 0) _totalRowReceipt('Discount:', -discount),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(_fmt(grandTotal), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'THANK YOU!',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (settings.vatNumber.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'TIN: ${settings.vatNumber}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Receipt_${voucherNo}.pdf',
    );
  }

  static pw.Widget _receiptRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _totalRowReceipt(String label, double value) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(_fmt(value.abs()), style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _infoRow(
    String label,
    String value, {
    double fontSize = 11,
  }) => pw.Row(
    children: [
      pw.Text('$label  ', style: const pw.TextStyle(fontSize: 10)),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    double fontSize = 11,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: bold
          ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
          : pw.TextStyle(fontSize: fontSize),
      textAlign: align,
    ),
  );

  static pw.Widget _totalRow(String label, double value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: bold
                  ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
                  : const pw.TextStyle(fontSize: 11),
            ),
            pw.Text(
              _fmt(value.abs()),
              style: bold
                  ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
                  : const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      );

  static String _fmt(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

  /// Converts a number to localized words
  static String _numberToWords(double amount, String Function(String key, {Map<String, String>? replacements}) t) {
    final int whole = amount.truncate();
    final int cents = ((amount - whole) * 100).round();
    final words = _intToWords(whole, t);
    final centsStr = cents > 0
        ? ' ${t('numbers.and')} ${_intToWords(cents, t)} ${t('numbers.cents')}'
        : ' ${t('numbers.and')} ${t('numbers.zero')} ${t('numbers.cents')}';
    return '$words$centsStr ${t('numbers.only')}';
  }

  static String _intToWords(int n, String Function(String key, {Map<String, String>? replacements}) t) {
    if (n == 0) return t('numbers.zero');
    const ones = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    String result = '';
    if (n >= 1000000) {
      result += '${_intToWords(n ~/ 1000000, t)} ${t('numbers.million')} ';
      n %= 1000000;
    }
    if (n >= 1000) {
      result += '${_intToWords(n ~/ 1000, t)} ${t('numbers.thousand')} ';
      n %= 1000;
    }
    if (n >= 100) {
      result += '${t('numbers.' + ones[n ~/ 100])} ${t('numbers.hundred')} ';
      n %= 100;
    }
    if (n > 19) {
      result += '${t('numbers.' + tens[n ~/ 10])} ';
      if (n % 10 > 0) {
        result += t('numbers.' + ones[n % 10]);
      }
    } else if (n > 0) {
      result += t('numbers.' + ones[n]);
    }
    return result.trim();
  }
}
