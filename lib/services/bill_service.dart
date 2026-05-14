import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/core/widgets/top_toaster.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/charge.dart';
import 'package:st_george_pos/models/settings.dart';
import 'package:st_george_pos/models/z_report.dart';
import 'package:st_george_pos/services/audit_service.dart';
import 'package:st_george_pos/services/system_log_service.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

class BillService {
  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;
  static bool _useEnglishFallback = false;

  /// Call this to clear cached fonts (e.g. after a hot restart in dev)
  static void resetFontCache() {
    SystemLogService.log('Resetting font cache');
    _fontRegular = null;
    _fontBold = null;
    _useEnglishFallback = false;
  }

  static Future<pw.ThemeData> _getEthiopicTheme() async {
    if (_fontRegular == null || _fontBold == null) {
      try {
        final regularData =
            await rootBundle.load('assets/fonts/NotoSansEthiopic-Regular.ttf');
        final boldData =
            await rootBundle.load('assets/fonts/NotoSansEthiopic-Bold.ttf');
        // Pre-flight check to see if parsing succeeds
        _fontRegular = pw.Font.ttf(regularData);
        _fontBold = pw.Font.ttf(boldData);
        _useEnglishFallback = false;
      } catch (e) {
        debugPrint('Failed to load Ethiopic font: $e');
        _fontRegular = pw.Font.helvetica();
        _fontBold = pw.Font.helveticaBold();
        _useEnglishFallback = true;
      }
    }
    return pw.ThemeData.withFont(
      base: _fontRegular!,
      bold: _fontBold!,
      italic: _fontRegular!,
    );
  }

  static String _ln(String? en, String? am) {
    if (_useEnglishFallback) return en ?? '';
    // For printing, we prioritize Amharic if available, otherwise fallback to English
    if (am != null && am.trim().isNotEmpty) return am;
    return en ?? '';
  }

  // ── Kitchen Slip PDF (A5 compact) ────────────────────────────────────────

  static Future<bool> generateKitchenSlip({
    required OrderModel order,
    required List<OrderItem> items,
    required int roundNumber,
    String? printerName,
    String? stationName,
  }) async {
    SystemLogService.log('Generating Kitchen Slip: Order #${order.id}, Round $roundNumber');
    debugPrint('Starting Kitchen Slip PDF Generation...');
    // Use active locale for receipts (Amharic when set)
    String t(String key, {Map<String, String>? replacements}) =>
        AppLocalizations.getAmharic(key, replacements: replacements);

    final pdf = pw.Document();
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    final theme = await _getEthiopicTheme();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        margin: const pw.EdgeInsets.all(12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                (stationName ?? t('print.kitchenOrder')).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
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
                  '${t('print.table')}: ${_ln(order.tableName, order.tableNameAmharic)}',
                  style: pw.TextStyle(
                    fontSize: 12,
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
            _infoRow(t('print.waiter'), _ln(order.waiterName, order.waiterNameAmharic)),
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
                      '${item.quantity} x  ${_ln(item.productName, item.productNameAmharic)}',
                      style: pw.TextStyle(
                        fontSize: 12,
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
                t('reports.poweredBy'),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    debugPrint('PDF layout complete. Sending to printer...');
    return _printDocument(
      pdf: pdf,
      documentName: 'Kitchen_Round${roundNumber}_Order${order.id}.pdf',
      printerName: printerName,
      format: PdfPageFormat.roll80,
    );
  }

  // ── Customer Receipt PDF (A4 Invoice — matches sample image) ─────────────

  static Future<bool> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required CafeSettings settings,
    required String cashierName,
    required List<ChargeModel> activeCharges,
    String? printerName,
  }) async {
    SystemLogService.log('Generating Bill: Order #${order.id} for Table ${order.tableName}');
    // Use active locale for receipts (Amharic when set)
    String t(String key, {Map<String, String>? replacements}) =>
        AppLocalizations.getAmharic(key, replacements: replacements);

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final voucherNo =
        'RCS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(order.id ?? 0).toString().padLeft(3, '0')}';

    final theme = await _getEthiopicTheme();

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
        : 'LDA CAFE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        margin: const pw.EdgeInsets.all(10),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                cafeName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
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
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                t('bill.cashSalesInvoice').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Divider(thickness: 0.5),

            // ── Info ─────────────────────────────────────────────────────
            _infoRow(t('bill.date'), dateStr, fontSize: 9),
            _infoRow(t('bill.voucher'), voucherNo, fontSize: 9),
            _infoRow(t('bill.waiter'), _ln(order.waiterName, order.waiterNameAmharic), fontSize: 9),
            _infoRow(t('bill.table'), _ln(order.tableName, order.tableNameAmharic), fontSize: 9),
            pw.Divider(thickness: 0.5),

            // ── Items Table (Thermal Style) ──────────────────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    t('bill.description'),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 20,
                  child: pw.Text(
                    t('bill.qty'),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 36,
                  child: pw.Text(
                    t('bill.price'),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 40,
                  child: pw.Text(
                    t('bill.total'),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        _ln(item.productName, item.productNameAmharic),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 20,
                      child: pw.Text(
                        '${item.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 36,
                      child: pw.Text(
                        _fmt(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text(
                        _fmt(item.subtotal),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.Divider(thickness: 0.5),

            // ── Totals ───────────────────────────────────────────────────
            _totalRow(t('bill.subtotal'), subtotal, fontSize: 9),
            ...appliedCharges.where((c) => (c['amount'] as num).abs() > 0.01).map(
              (c) => _totalRow(c['name'], c['amount'], fontSize: 9),
            ),
            if (discount > 0)
              _totalRow(t('bill.discount'), -discount, fontSize: 9),
            pw.SizedBox(height: 4),
            _totalRow(
              t('bill.grandTotal'),
              grandTotal,
              bold: true,
              fontSize: 12,
            ),
            pw.Divider(thickness: 1),

            // ── Footer ────────────────────────────────────────────────────
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                t('bill.thankYou'),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                t('reports.poweredBy'),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );

    return _printDocument(
      pdf: pdf,
      documentName: 'Invoice_${voucherNo}.pdf',
      printerName: printerName,
      format: PdfPageFormat.roll80,
    );
  }

  static pw.Widget _buildStationSlip(
    String stationName,
    List<OrderItem> stationItems,
    int roundNumber,
    OrderModel order,
    String Function(String, {Map<String, String>? replacements}) t,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            stationName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            t('print.roundNumber', replacements: {'n': '$roundNumber'}),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${t('print.table')}: ${order.tableName}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '#${order.id ?? "—"}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        ...stationItems.map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${item.quantity} x  ${_ln(item.productName, item.productNameAmharic)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 15, top: 1),
                    child: pw.Text(
                      '>> ${item.notes}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildCustomerReceipt(
    List<OrderItem> receiptItems,
    OrderModel order,
    CafeSettings settings,
    String voucherNo,
    String dateStr,
    double subtotal,
    double discount,
    double grandTotal,
    List<Map<String, dynamic>> appliedCharges,
    String cafeName,
    String Function(String, {Map<String, String>? replacements}) t,
  ) {
    return [
      pw.Center(
        child: pw.Text(
          cafeName.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
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
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Text(
          t('bill.cashSalesInvoice').toUpperCase(),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Divider(thickness: 0.5),
      _infoRow(t('bill.date'), dateStr, fontSize: 9),
      _infoRow(t('bill.voucher'), voucherNo, fontSize: 9),
      _infoRow(t('bill.waiter'), _ln(order.waiterName, order.waiterNameAmharic), fontSize: 9),
      _infoRow(t('bill.table'), _ln(order.tableName, order.tableNameAmharic), fontSize: 9),
      pw.Divider(thickness: 0.5),
      pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              t('bill.description'),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 20,
            child: pw.Text(
              t('bill.qty'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 36,
            child: pw.Text(
              t('bill.price'),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 40,
            child: pw.Text(
              t('bill.total'),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      ...receiptItems.map(
        (item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  _ln(item.productName, item.productNameAmharic),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(
                width: 20,
                child: pw.Text(
                  '${item.quantity}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(
                width: 36,
                child: pw.Text(
                  _fmt(item.unitPrice),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(
                width: 40,
                child: pw.Text(
                  _fmt(item.subtotal),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
      pw.Divider(thickness: 0.5),
      _totalRow(t('bill.subtotal'), subtotal, fontSize: 9),
      ...appliedCharges.where((c) => (c['amount'] as num).abs() > 0.01).map(
        (c) => _totalRow(c['name'], c['amount'], fontSize: 9),
      ),
      if (discount > 0)
        _totalRow(t('bill.discount'), -discount, fontSize: 9),
      pw.SizedBox(height: 4),
      _totalRow(
        t('bill.grandTotal'),
        grandTotal,
        bold: true,
        fontSize: 12,
      ),
      pw.Divider(thickness: 1),
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Text(
          t('bill.thankYou'),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Center(
        child: pw.Text(
          t('reports.poweredBy'),
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
    ];
  }

  static Future<bool> generateCombinedSlipAndBill({
    required OrderModel order,
    required List<OrderItem> kitchenItems,
    required List<OrderItem> receiptItems,
    required int roundNumber,
    required CafeSettings settings,
    required String cashierName,
    required List<ChargeModel> activeCharges,
    String? printerName,
  }) async {
    // Use active locale for receipts (Amharic when set)
    String t(String key, {Map<String, String>? replacements}) =>
        AppLocalizations.getAmharic(key, replacements: replacements);

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final voucherNo =
        'RCS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(order.id ?? 0).toString().padLeft(3, '0')}';

    final theme = await _getEthiopicTheme();

    // Group items by stationId for combined slip part
    final Map<int?, List<OrderItem>> groupedKitchen = {};
    for (final item in kitchenItems) {
      groupedKitchen.putIfAbsent(item.stationId, () => []).add(item);
    }

    final subtotal = receiptItems.fold(0.0, (s, i) => s + i.subtotal);
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

    final cafeName = settings.name.isNotEmpty
        ? settings.name
        : 'ST GEORGE CAFE';

    final bool isSilentPrinting = !kIsWeb && printerName != null && printerName.isNotEmpty;
    bool allSuccess = true;

    if (isSilentPrinting) {
      // ── SEQUENTIAL PRINTING (One job per station/receipt to force hardware cut) ──
      for (final entry in groupedKitchen.entries) {
        final stationItems = entry.value;
        final stationName = stationItems.first.stationName ?? t('print.kitchenOrder');

        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            theme: theme,
            margin: const pw.EdgeInsets.all(10),
            build: (ctx) => _buildStationSlip(stationName, stationItems, roundNumber, order, t),
          ),
        );

        final success = await _printDocument(
          pdf: pdf,
          documentName: 'Station_${stationName}_${voucherNo}.pdf',
          printerName: printerName,
          format: PdfPageFormat.roll80,
        );
        if (!success) allSuccess = false;
        
        // Brief delay to ensure OS print spooler sequences them cleanly
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (receiptItems.isNotEmpty) {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            theme: theme,
            margin: const pw.EdgeInsets.all(10),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildCustomerReceipt(
                receiptItems, order, settings, voucherNo, dateStr,
                subtotal, discount, grandTotal, appliedCharges, cafeName, t
              ),
            ),
          ),
        );

        final success = await _printDocument(
          pdf: pdf,
          documentName: 'Receipt_${voucherNo}.pdf',
          printerName: printerName,
          format: PdfPageFormat.roll80,
        );
        if (!success) allSuccess = false;
      }
    } else {
      // ── COMBINED PRINTING (Fallback to single document to avoid multiple UI popups) ──
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          theme: theme,
          margin: const pw.EdgeInsets.all(10),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (kitchenItems.isNotEmpty) ...[
                ...groupedKitchen.entries.map((entry) {
                  final stationItems = entry.value;
                  final stationName = stationItems.first.stationName ?? t('print.kitchenOrder');
                  
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildStationSlip(stationName, stationItems, roundNumber, order, t),
                      pw.SizedBox(height: 10),
                      pw.Center(
                        child: pw.Text(
                          '-------------------- ✂ --------------------',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                        ),
                      ),
                      pw.SizedBox(height: 15),
                    ],
                  );
                }),
              ],
              if (receiptItems.isNotEmpty) ...[
                ..._buildCustomerReceipt(
                  receiptItems, order, settings, voucherNo, dateStr,
                  subtotal, discount, grandTotal, appliedCharges, cafeName, t
                ),
              ],
            ],
          ),
        ),
      );

      allSuccess = await _printDocument(
        pdf: pdf,
        documentName: 'CombinedPrint_${voucherNo}.pdf',
        printerName: printerName,
        format: PdfPageFormat.roll80,
      );
    }

    return allSuccess;
  }

  // ── X/Z Report Printing ──────────────────────────────────────────────────

  static Future<void> reprintZReport({
    required ZReportModel report,
    required CafeSettings settings,
  }) async {
    await printReport(
      reportData: report.reportData,
      settings: settings,
      isZReport: true,
    );
  }

  static Future<void> printReport({
    required Map<String, dynamic> reportData,
    required CafeSettings settings,
    bool isZReport = false,
  }) async {
    SystemLogService.log('Generating ${isZReport ? 'Z' : 'Shift'} Report');
    // FORCE Amharic for printing
    String t(String key, {Map<String, String>? replacements}) => 
        AppLocalizations.getAmharic(key, replacements: replacements);

    final pdf = pw.Document();
    final theme = await _getEthiopicTheme();

    final header = reportData['report_header'] as Map<String, dynamic>;
    final sales = reportData['sales_totals'] as Map<String, dynamic>;
    final payments = reportData['payment_methods'] as Map<String, dynamic>;
    final items = reportData['items'] as Map<String, dynamic>;
    final cashRec = reportData['cash_reconciliation'] as Map<String, dynamic>;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        margin: const pw.EdgeInsets.all(10),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                settings.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: isZReport ? PdfColors.black : PdfColors.white,
                  border: isZReport ? null : pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Text(
                  isZReport ? 'Z REPORT (FINAL)' : 'X REPORT (PROVISIONAL)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: isZReport ? PdfColors.white : PdfColors.black,
                  ),
                ),
              ),
            ),
            pw.Divider(),

            // ── Report Info ──────────────────────────────────────────────
            _infoRow('Shift #', '#${header['shift_number']}', fontSize: 9),
            _infoRow('Cashier', header['cashier_name'], fontSize: 9),
            _infoRow(
              'Opened',
              DateFormat(
                'dd/MM HH:mm',
              ).format(DateTime.parse(header['opening_time'])),
              fontSize: 9,
            ),
            if (isZReport)
              _infoRow(
                'Closed',
                DateFormat(
                  'dd/MM HH:mm',
                ).format(DateTime.parse(header['closing_time'])),
                fontSize: 9,
              ),
            pw.Divider(),

            // ── Financial Totals ─────────────────────────────────────────
            _sectionHeader(t('reports.financialTotals')),
            _totalRow('Gross Sales', sales['gross_sales'], fontSize: 9),
            _totalRow('Discounts', -sales['discounts'], fontSize: 9),
            _totalRow('Service Chg', sales['service_charge'], fontSize: 9),
            if (sales['vat'] > 0)
              _totalRow(
                'VAT (${sales['vat_rate'] ?? 0}%)',
                sales['vat'],
                fontSize: 9,
              ),
            pw.SizedBox(height: 4),
            _totalRow(
              'GRAND TOTAL',
              sales['grand_total'],
              bold: true,
              fontSize: 11,
            ),
            pw.Divider(),

            // ── Payments ─────────────────────────────────────────────────
            _sectionHeader(t('reports.paymentMethods')),
            ...payments.entries.map(
              (e) => _totalRow(e.key.toUpperCase(), e.value, fontSize: 9),
            ),
            pw.Divider(),

            // ── Item Sales ───────────────────────────────────────────────
            _sectionHeader(t('reports.topItemSales')),
            ...items.entries.take(15).map((e) {
              final val = e.value as Map<String, dynamic>;
              return pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      e.key,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Text(
                    'x${val['qty']}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    _fmt(val['revenue']),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              );
            }),
            pw.Divider(),

            // ── Order Details (by Waiter) ──────────────────────────────
            if (reportData.containsKey('orders_detail') &&
                (reportData['orders_detail'] as List).isNotEmpty) ...[
              _sectionHeader(t('reports.orderDetailsByWaiter')),
              pw.SizedBox(height: 4),
              ...() {
                final ordersList = (reportData['orders_detail'] as List)
                    .cast<Map<String, dynamic>>();
                final waiterGroups = <String, List<Map<String, dynamic>>>{};
                for (final o in ordersList) {
                  final wName = o['waiter_name'] as String? ?? 'Unknown';
                  waiterGroups.putIfAbsent(wName, () => []).add(o);
                }
                return waiterGroups.entries.expand((entry) {
                  final widgets = <pw.Widget>[];
                  widgets.add(pw.SizedBox(height: 6));
                  widgets.add(
                    pw.Container(
                      color: PdfColors.grey800,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'WAITER: ${entry.key.toUpperCase()}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.Text(
                            '${entry.value.length} ${t('order.items')}',
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  for (final o in entry.value) {
                    final items = (o['items'] as List)
                        .cast<Map<String, dynamic>>();
                    widgets.add(pw.SizedBox(height: 3));
                    widgets.add(
                      pw.Text(
                        'Order #${o['id']}  |  ${o['table_name']}  |  ${_fmtTime(o['created_at'] as String)}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    );
                    if (o['cashier_name'] != null &&
                        (o['cashier_name'] as String).isNotEmpty) {
                      widgets.add(
                        pw.Text(
                          'Cashier: ${o['cashier_name']}',
                          style: const pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.grey600,
                          ),
                        ),
                      );
                    }
                    // Items header
                    widgets.add(
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 2),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 4,
                              child: pw.Text(
                                'Item',
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                            pw.SizedBox(
                              width: 20,
                              child: pw.Text(
                                'Qty',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                            pw.SizedBox(
                              width: 22,
                              child: pw.Text(
                                'Price',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                            pw.SizedBox(
                              width: 24,
                              child: pw.Text(
                                'Total',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    // Item rows
                    for (final item in items) {
                      widgets.add(
                        pw.Container(
                          margin: const pw.EdgeInsets.only(left: 2),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 4,
                                child: pw.Text(
                                  item['product_name'] as String? ?? '',
                                  style: const pw.TextStyle(fontSize: 6),
                                ),
                              ),
                              pw.SizedBox(
                                width: 20,
                                child: pw.Text(
                                  '${item['quantity']}',
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 6),
                                ),
                              ),
                              pw.SizedBox(
                                width: 22,
                                child: pw.Text(
                                  _fmt(
                                    (item['unit_price'] as num?)?.toDouble() ??
                                        0,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 6),
                                ),
                              ),
                              pw.SizedBox(
                                width: 24,
                                child: pw.Text(
                                  _fmt(
                                    (item['subtotal'] as num?)?.toDouble() ?? 0,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                  style: const pw.TextStyle(fontSize: 6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    // Order total
                    widgets.add(
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 1),
                        child: pw.Row(
                          children: [
                            pw.Spacer(),
                            pw.Text(
                              'Order: ${_fmt((o['grand_total'] as num?)?.toDouble() ?? 0)}',
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    widgets.add(
                      pw.Divider(thickness: 0.3, color: PdfColors.grey400),
                    );
                  }

                  // Waiter subtotal
                  final waiterTotal = entry.value.fold<double>(
                    0,
                    (s, o) => s + ((o['grand_total'] as num?)?.toDouble() ?? 0),
                  );
                  widgets.add(
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${entry.key} Total',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            _fmt(waiterTotal),
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  widgets.add(pw.SizedBox(height: 4));
                  return widgets;
                });
              }(),
              pw.Divider(),
            ],

            // ── Cash Reconciliation ──────────────────────────────────────
            _sectionHeader(t('reports.cashReconciliation')),
            _totalRow('Opening Float', cashRec['opening_float'], fontSize: 9),
            _totalRow('Expected Cash', cashRec['expected_cash'], fontSize: 9),
            if (isZReport) ...[
              _totalRow(
                'Actual Counted',
                cashRec['actual_counted'],
                fontSize: 9,
              ),
              pw.SizedBox(height: 4),
              _totalRow(
                'VARIANCE',
                cashRec['difference'],
                bold: true,
                fontSize: 10,
                color: (cashRec['difference'] as num) < 0
                    ? PdfColors.red
                    : PdfColors.green,
              ),
            ],
            pw.Divider(),

            // ── Footer ────────────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                'Printed at: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
            pw.Center(
              child: pw.Text(
                t('reports.poweredBy'),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    await _printDocument(
      pdf: pdf,
      documentName:
          '${isZReport ? 'Z' : 'X'}_Report_Shift_${header['shift_number']}.pdf',
      printerName: settings.defaultPrinterName,
      format: PdfPageFormat.roll80,
    );
  }

  // ── Shared Helpers ───────────────────────────────────────────────────────

  static Future<bool> _printDocument({
    required pw.Document pdf,
    required String documentName,
    String? printerName,
    PdfPageFormat format = PdfPageFormat.roll80,
  }) async {
    final pdfBytes = await pdf.save();

    // ── Web: always use browser print dialog ────────────────────────────────
    if (kIsWeb) {
      SystemLogService.log('[Print] Web detected, using layoutPdf for browser dialog...');
      try {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: documentName,
          // On Web, sometimes roll80 causes preview issues in standard browsers.
          // We provide the format but allow the browser to adapt.
          format: format,
          dynamicLayout: false, // Prevents re-layout which can lose gesture context
        );
        return true;
      } catch (e) {
        SystemLogService.log('[Print] layoutPdf error on Web: $e');
        return false;
      }
    }

    // ── Desktop: try directPrintPdf if a printer is configured ──────────────
    // This sends silently to the Windows print spooler with no dialog.
    if (printerName != null && printerName.isNotEmpty) {
      try {
        SystemLogService.log('[Print] Listing printers for direct print...');
        final printers = await Printing.listPrinters().timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            SystemLogService.log('[Print] listPrinters timed out after 4s');
            return [];
          },
        );
        SystemLogService.log('[Print] Found ${printers.length} printer(s): '
            '${printers.map((p) => p.name).join(', ')}');

        if (printers.isNotEmpty) {
          // Smart printer selection:
          //  1. Exact name match (case-insensitive)
          //  2. Partial name match (case-insensitive)
          //  3. System default printer
          //  4. First printer in the list
          Printer? target;
          final lower = printerName.toLowerCase();
          for (final p in printers) {
            if (p.name.toLowerCase() == lower) { target = p; break; }
          }
          if (target == null) {
            for (final p in printers) {
              if (p.name.toLowerCase().contains(lower)) { target = p; break; }
            }
          }
          if (target == null) {
            for (final p in printers) {
              if (p.isDefault) { target = p; break; }
            }
          }
          target ??= printers.first;

          SystemLogService.log('[Print] Sending to: "${target.name}" with 6s timeout...');
          
          bool success = false;
          try {
            // directPrintPdf returns FutureOr<bool>. We wrap it in Future.value
            // to ensure we can use the .timeout() method.
            success = await Future.value(Printing.directPrintPdf(
              printer: target,
              onLayout: (_) async => pdfBytes,
              name: documentName,
              format: format,
            )).timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                SystemLogService.log('[Print] directPrintPdf timed out after 6s');
                return false;
              },
            );
          } catch (e) {
            SystemLogService.log('[Print] directPrintPdf error: $e');
            success = false;
          }

          SystemLogService.log('[Print] directPrintPdf result: $success');
          if (success) return true;
          SystemLogService.log('[Print] directPrintPdf did not succeed, falling back to layoutPdf');
        }
      } catch (e) {
        SystemLogService.log('[Print] Error in direct print flow: $e — falling back to layoutPdf');
      }
    }

    // ── Fallback: layoutPdf opens the system print dialog ───────────────────
    // This is the original working behaviour before the POS config change.
    // Used when: no printer configured, printer not found, or direct print fails.
    SystemLogService.log('[Print] Opening system print dialog via layoutPdf...');
    try {
      // NOTE: On some Windows versions, this dialog might appear BEHIND the main window.
      // We log it so the user knows to check the taskbar.
      SystemLogService.log('[Print] NOTE: If no window appears, check the taskbar.');
      
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: documentName,
        // IMPORTANT: On Windows Desktop, forcing the 'format' (like roll80) in the 
        // fallback dialog can sometimes cause the preview to crash or fail to 
        // appear if the system default printer doesn't support that size.
        // On Desktop fallback, we use A4 which is globally supported.
        format: kIsWeb ? format : PdfPageFormat.a4,
      );
      return true;
    } catch (e) {
      SystemLogService.log('[Print] layoutPdf fatal error: $e');
      return false;
    }
  }

  static pw.Widget _sectionHeader(String title) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey700,
      ),
    ),
  );

  static pw.Widget _infoRow(
    String label,
    String value, {
    double fontSize = 11,
  }) => pw.Row(
    children: [
      pw.Text('$label: ', style: pw.TextStyle(fontSize: fontSize - 1)),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  static pw.Widget _totalRow(
    String label,
    double value, {
    bool bold = false,
    double fontSize = 11,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: bold
              ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
              : pw.TextStyle(fontSize: fontSize),
        ),
        pw.Text(
          _fmt(value),
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    ),
  );

  static String _fmt(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

  static String _fmtTime(String iso) {
    try {
      return DateFormat('dd/MM HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  /// Converts a number to localized words
  static String _numberToWords(
    double amount,
    String Function(String key, {Map<String, String>? replacements}) t,
  ) {
    final int whole = amount.truncate();
    final int cents = ((amount - whole) * 100).round();
    final words = _intToWords(whole);
    final centsStr = cents > 0
        ? ' ${t('common.numbers.and')} ${_intToWords(cents)} ${t('common.numbers.cents')}'
        : ' ${t('common.numbers.and')} ${t('common.numbers.zero')} ${t('common.numbers.cents')}';
    return '$words $centsStr ${t('common.numbers.only')}';
  }

  static String _intToWords(int n) {
    String t(String key, {Map<String, String>? replacements}) => 
        AppLocalizations.getAmharic(key, replacements: replacements);

    if (n == 0) return t('common.numbers.zero');
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
      result +=
          '${_intToWords(n ~/ 1000000)} ${t('common.numbers.million')} ';
      n %= 1000000;
    }
    if (n >= 1000) {
      result += '${_intToWords(n ~/ 1000)} ${t('common.numbers.thousand')} ';
      n %= 1000;
    }
    if (n >= 100) {
      result +=
          '${t('common.numbers.' + ones[n ~/ 100])} ${t('common.numbers.hundred')} ';
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
