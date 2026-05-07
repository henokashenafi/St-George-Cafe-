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
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text('KITCHEN ORDER',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('Round #$roundNumber',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),

            // ── Info ─────────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Table: ${order.tableName}',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Order #${order.id ?? "—"}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 4),
            _infoRow('Waiter', order.waiterName),
            _infoRow('Time', '$timeStr  |  $dateStr'),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 6),

            // ── Items ─────────────────────────────────────────────────────
            ...items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${item.quantity} x  ${item.productName}',
                        style: pw.TextStyle(
                            fontSize: 15, fontWeight: pw.FontWeight.bold),
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 20, top: 2),
                          child: pw.Text(
                            '>> ${item.notes}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                )),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),
            pw.Center(
              child: pw.Text(
                '${items.length} item(s)  —  Round #$roundNumber',
                style: const pw.TextStyle(fontSize: 11),
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

  // ── Customer Receipt PDF (A4 Invoice — matches sample image) ─────────────

  static Future<void> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required CafeSettings settings,
    required String cashierName,
    required double serviceChargePercent,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final voucherNo =
        'RCS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(order.id ?? 0).toString().padLeft(3, '0')}';

    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    final serviceCharge = subtotal * (serviceChargePercent / 100);
    final discount = order.discountAmount;
    final grandTotal = subtotal + serviceCharge - discount;
    final amountWords = _numberToWords(grandTotal);

    final cafeName =
        settings.name.isNotEmpty ? settings.name : 'ST GEORGE CAFE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Cafe name ────────────────────────────────────────────────
            pw.Text(cafeName,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            if (settings.address.isNotEmpty)
              pw.Text(settings.address,
                  style: const pw.TextStyle(fontSize: 10)),
            if (settings.phone.isNotEmpty)
              pw.Text('Tel: ${settings.phone}',
                  style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 6),

            // ── Title ─────────────────────────────────────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Cash Sales Invoice',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),

            // ── Info box (2-column) ───────────────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left column
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          right: pw.BorderSide(width: 0.5),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('To',
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 4),
                          _infoRow('Prep By', cashierName, fontSize: 10),
                          _infoRow('Waiter', order.waiterName, fontSize: 10),
                          _infoRow('Table', order.tableName, fontSize: 10),
                        ],
                      ),
                    ),
                  ),
                  // Right column
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Vouc.', voucherNo, fontSize: 10),
                          _infoRow('Date', dateStr, fontSize: 10),
                          _infoRow('Order', '#${order.id ?? "—"}',
                              fontSize: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // ── Items table ───────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(5), // Description
                1: const pw.FixedColumnWidth(40), // Qty
                2: const pw.FixedColumnWidth(80), // Unit Price
                3: const pw.FixedColumnWidth(80), // Total
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    _cell('Description',
                        bold: true, fontSize: 10),
                    _cell('Qty',
                        bold: true,
                        fontSize: 10,
                        align: pw.TextAlign.center),
                    _cell('U. Amount',
                        bold: true,
                        fontSize: 10,
                        align: pw.TextAlign.right),
                    _cell('Total',
                        bold: true,
                        fontSize: 10,
                        align: pw.TextAlign.right),
                  ],
                ),
                // Item rows
                ...items.map((item) => pw.TableRow(
                      children: [
                        _cell(
                            '${item.productName}${item.notes != null && item.notes!.isNotEmpty ? " (${item.notes})" : ""}',
                            fontSize: 11),
                        _cell('${item.quantity}',
                            fontSize: 11,
                            align: pw.TextAlign.center),
                        _cell(
                            _fmt(item.unitPrice),
                            fontSize: 11,
                            align: pw.TextAlign.right),
                        _cell(
                            _fmt(item.subtotal),
                            fontSize: 11,
                            align: pw.TextAlign.right),
                      ],
                    )),
              ],
            ),

            pw.SizedBox(height: 10),

            // ── Amount in words + totals side-by-side ─────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Amount in words (left)
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.5)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          amountWords,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Totals (right)
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      _totalRow('Sub Total', subtotal),
                      _totalRow(
                          'Service Charge (${serviceChargePercent.toStringAsFixed(0)}%)',
                          serviceCharge),
                      if (discount > 0)
                        _totalRow('Discount', -discount),
                      pw.Divider(thickness: 1),
                      _totalRow('Grand Total', grandTotal, bold: true),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // ── Footer ────────────────────────────────────────────────────
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                settings.address.isNotEmpty
                    ? settings.address
                    : 'Thank you for visiting ${cafeName}!',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            if (settings.vatNumber.isNotEmpty)
              pw.Center(
                child: pw.Text('TIN: ${settings.vatNumber}',
                    style: const pw.TextStyle(fontSize: 9)),
              ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Invoice_${voucherNo}.pdf',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _infoRow(String label, String value,
      {double fontSize = 11}) =>
      pw.Row(
        children: [
          pw.Text('$label  ', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _cell(String text,
      {bool bold = false,
      double fontSize = 11,
      pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          style: bold
              ? pw.TextStyle(
                  fontSize: fontSize, fontWeight: pw.FontWeight.bold)
              : pw.TextStyle(fontSize: fontSize),
          textAlign: align,
        ),
      );

  static pw.Widget _totalRow(String label, double value,
      {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: bold
                    ? pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)
                    : const pw.TextStyle(fontSize: 11)),
            pw.Text(_fmt(value.abs()),
                style: bold
                    ? pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)
                    : const pw.TextStyle(fontSize: 11)),
          ],
        ),
      );

  static String _fmt(double v) =>
      NumberFormat('#,##0.00', 'en_US').format(v);

  /// Converts a number to Ethiopian-style English words
  static String _numberToWords(double amount) {
    final int whole = amount.truncate();
    final int cents = ((amount - whole) * 100).round();
    final words = _intToWords(whole);
    final centsStr = cents > 0
        ? ' And ${_intToWords(cents)} Cents'
        : ' And Zero Cents';
    return '$words$centsStr Only';
  }

  static String _intToWords(int n) {
    if (n == 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
      'Eighty', 'Ninety'
    ];

    String result = '';
    if (n >= 1000000) {
      result += '${_intToWords(n ~/ 1000000)} Million ';
      n %= 1000000;
    }
    if (n >= 1000) {
      result += '${_intToWords(n ~/ 1000)} Thousand ';
      n %= 1000;
    }
    if (n >= 100) {
      result += '${ones[n ~/ 100]} Hundred ';
      n %= 100;
    }
    if (n >= 20) {
      result += '${tens[n ~/ 10]} ';
      n %= 10;
    }
    if (n > 0) result += ones[n];
    return result.trim();
  }
}
