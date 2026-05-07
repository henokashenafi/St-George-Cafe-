import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';

class BillService {
  static Future<void> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required String tableName,
    required String waiterName,
    required String cashierName,
    required double serviceCharge,
    required double serviceChargePercent,
    required double discountAmount,
    required String Function(String key, {Map<String, String>? replacements}) t,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    final subtotal = items.fold(0.0, (s, i) => s + i.subtotal);
    final grandTotal = subtotal + serviceCharge - discountAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    t('bill.stGeorgeCafe'),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(t('bill.address')),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    t('bill.title'),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${t('bill.date')}: $dateStr'),
                pw.Text('${t('bill.table')}: $tableName'),
              ],
            ),
            pw.Text('${t('bill.waiter')}: $waiterName'),
            pw.Text('${t('bill.cashier')}: $cashierName'),
            pw.Text(t('bill.orderNumber', replacements: {'id': '${order.id}'})),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    t('bill.item'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    t('bill.qty'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    t('bill.price'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    t('bill.total'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(flex: 3, child: pw.Text(item.productName)),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            item.unitPrice.toStringAsFixed(2),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            item.subtotal.toStringAsFixed(2),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Text(
                          '* ${item.notes}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 4),
            _billRow('${t('bill.subtotal')}:', subtotal.toStringAsFixed(2)),
            _billRow(
              '${t('bill.serviceCharge', replacements: {'percent': serviceChargePercent.toStringAsFixed(0)})}:',
              serviceCharge.toStringAsFixed(2),
            ),
            if (discountAmount > 0)
              _billRow(
                '${t('bill.discount')}:',
                '- ${discountAmount.toStringAsFixed(2)}',
              ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${t('bill.grandTotal')}:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  grandTotal.toStringAsFixed(2),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text(t('bill.thankYou'))),
            pw.Center(child: pw.Text(t('bill.comeAgain'))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Bill_${order.id}_${tableName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _billRow(String label, String value) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(label), pw.Text(value)],
  );
}
