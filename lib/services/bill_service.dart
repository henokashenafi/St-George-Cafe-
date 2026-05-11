import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/charge.dart';
import 'package:st_george_pos/models/settings.dart';

class BillService {
  // ── Kitchen Slip PDF (A5 compact) ────────────────────────────────────────

  static Future<void> generateKitchenSlip({
    required OrderModel order,
    required List<OrderItem> items,
    required int roundNumber,
    required String Function(String key, {Map<String, String>? replacements}) t,
    String? printerName,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    
    // Use Helvetica as fallback (Ethiopic requires bundled TTF)
    final font = pw.Font.helvetica();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(base: font),
        margin: const pw.EdgeInsets.all(12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                t('print.kitchenOrder'),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                t('print.roundNumber', replacements: {'n': '$roundNumber'}),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),

            // ── Info ─────────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${t('print.table')}: ${order.tableName}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${t('print.orderNumber')}: #${order.id ?? "—"}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            _infoRow(t('print.waiter'), order.waiterName),
            _infoRow(t('print.time'), '$timeStr  |  $dateStr'),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 6),

            // ── Items ─────────────────────────────────────────────────────
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${item.quantity} x  ${item.productName}',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 20, top: 2),
                        child: pw.Text(
                          '>> ${item.notes}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),
            pw.Center(
              child: pw.Text(
                '${t('print.items', replacements: {'count': '${items.length}'})} - ${t('print.roundNumber', replacements: {'n': '$roundNumber'})}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Powered by Askuala',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    await _printDocument(
      pdf: pdf,
      documentName: 'Kitchen_Round${roundNumber}_Order${order.id}.pdf',
      printerName: printerName,
    );
  }

  // ── Customer Receipt PDF (A4 Invoice — matches sample image) ─────────────

  static Future<void> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required CafeSettings settings,
    required String cashierName,
    required List<ChargeModel> activeCharges,
    required String Function(String key, {Map<String, String>? replacements}) t,
    String? printerName,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final voucherNo =
        'RCS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(order.id ?? 0).toString().padLeft(3, '0')}';
    
    // Use Helvetica as fallback (Ethiopic requires bundled TTF)
    final font = pw.Font.helvetica();

    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    
    // Calculate dynamic charges
    final appliedCharges = <Map<String, dynamic>>[];
    double totalAdditions = 0;
    double totalDeductions = 0;

    for (final c in activeCharges) {
      if (!c.isActive) continue;
      final amount = subtotal * (c.value / 100);
      appliedCharges.add({
        'name': '${c.name} (${c.value}%)',
        'amount': (c.type == 'addition' ? 1 : -1) * amount,
      });
      if (c.type == 'addition') {
        totalAdditions += amount;
      } else {
        totalDeductions += amount;
      }
    }

    final discount = order.discountAmount;
    final grandTotal = subtotal + totalAdditions - totalDeductions - discount;
    final amountWords = _numberToWords(grandTotal, t);

    final cafeName = settings.name.isNotEmpty
        ? settings.name
        : 'ST GEORGE CAFE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(base: font),
        margin: const pw.EdgeInsets.all(12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Cafe name ────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                cafeName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (settings.address.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.address,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (settings.phone.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  '${t('bill.tel')}: ${settings.phone}',
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            pw.SizedBox(height: 10),

            // ── Title ─────────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                t('bill.cashSalesInvoice').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Info box ───────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow(t('bill.date'), dateStr, fontSize: 9),
                  _infoRow(t('bill.voucher'), voucherNo, fontSize: 9),
                  _infoRow(t('bill.orderNumber'), '#${order.id ?? "—"}', fontSize: 9),
                  pw.Divider(thickness: 0.5, height: 8),
                  _infoRow(t('bill.preparedBy'), cashierName, fontSize: 9),
                  _infoRow(t('bill.waiter'), order.waiterName, fontSize: 9),
                  _infoRow(t('bill.table'), order.tableName, fontSize: 9),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // ── Items table ───────────────────────────────────────────────
            pw.Column(
              children: [
                // Header row
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(t('bill.description'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Expanded(flex: 1, child: pw.Text(t('bill.qty'), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Expanded(flex: 2, child: pw.Text(t('bill.total'), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                ),
                pw.Divider(height: 1, thickness: 0.5),
                // Item rows
                ...items.map(
                  (item) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.2, color: PdfColors.grey400)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            '${item.productName}${item.notes != null && item.notes!.isNotEmpty ? " (${item.notes})" : ""}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                        pw.Expanded(flex: 2, child: pw.Text(_fmt(item.subtotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // ── Totals ─────────────────────
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _totalRow(t('bill.subtotal'), subtotal),
                ...appliedCharges.map((c) => _totalRow(c['name'], c['amount'])),
                if (discount > 0)
                  _totalRow(t('bill.discount'), -discount),
                pw.Divider(thickness: 1),
                _totalRow(t('bill.grandTotal'), grandTotal, bold: true),
              ],
            ),
            pw.SizedBox(height: 10),
            // Amount in words
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5),
              ),
              child: pw.Text(
                amountWords,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),

            pw.SizedBox(height: 24),

            // ── Footer ────────────────────────────────────────────────────
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'Come again to St George Cafe - Thank you for visiting!',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Powered by Askuala',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey900, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    await _printDocument(
      pdf: pdf,
      documentName: 'Invoice_$voucherNo.pdf',
      printerName: printerName,
    );
  }

  static Future<void> _printDocument({
    required pw.Document pdf,
    required String documentName,
    String? printerName,
  }) async {
    final pdfBytes = await pdf.save();
    
    if (kIsWeb || printerName == null || printerName.isEmpty) {
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: documentName,
      );
      return;
    }

    try {
      final printers = await Printing.listPrinters();
      final printer = printers.cast<Printer?>().firstWhere((p) => p?.name == printerName, orElse: () => null);
      
      if (printer != null) {
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => pdfBytes,
          name: documentName,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: documentName,
        );
      }
    } catch (e) {
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: documentName,
      );
    }
  }

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
        ? ' ${t('common.numbers.and')} ${_intToWords(cents, t)} ${t('common.numbers.cents')}'
        : ' ${t('common.numbers.and')} ${t('common.numbers.zero')} ${t('common.numbers.cents')}';
    return '$words $centsStr ${t('common.numbers.only')}';
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
      result += '${_intToWords(n ~/ 1000000, t)} ${t('common.numbers.million')} ';
      n %= 1000000;
    }
    if (n >= 1000) {
      result += '${_intToWords(n ~/ 1000, t)} ${t('common.numbers.thousand')} ';
      n %= 1000;
    }
    if (n >= 100) {
      result += '${t('common.numbers.' + ones[n ~/ 100])} ${t('common.numbers.hundred')} ';
      n %= 100;
    }
    if (n > 19) {
      result += '${t('common.numbers.' + tens[n ~/ 10])} ';
      if (n % 10 > 0) {
        result += t('common.numbers.' + ones[n % 10]);
      }
    } else if (n > 0) {
      result += t('common.numbers.' + ones[n]);
    }
    return result.trim();
  }
}
