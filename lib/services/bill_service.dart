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
                  pw.Text('ST GEORGE CAFE',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Addis Ababa, Ethiopia'),
                  pw.SizedBox(height: 8),
                  pw.Text('CUSTOMER BILL',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: $dateStr'),
                pw.Text('Table: $tableName'),
              ],
            ),
            pw.Text('Waiter: $waiterName'),
            pw.Text('Cashier: $cashierName'),
            pw.Text('Order #${order.id}'),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(
                  flex: 1,
                  child: pw.Text('Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center)),
              pw.Expanded(
                  flex: 2,
                  child: pw.Text('Price',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right)),
              pw.Expanded(
                  flex: 2,
                  child: pw.Text('Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right)),
            ]),
            pw.SizedBox(height: 4),
            ...items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        pw.Expanded(
                            flex: 3, child: pw.Text(item.productName)),
                        pw.Expanded(
                            flex: 1,
                            child: pw.Text('${item.quantity}',
                                textAlign: pw.TextAlign.center)),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                item.unitPrice.toStringAsFixed(2),
                                textAlign: pw.TextAlign.right)),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                item.subtotal.toStringAsFixed(2),
                                textAlign: pw.TextAlign.right)),
                      ]),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 8),
                          child: pw.Text('* ${item.notes}',
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                    ],
                  ),
                )),
            pw.Divider(),
            pw.SizedBox(height: 4),
            _billRow('Subtotal:', subtotal.toStringAsFixed(2)),
            _billRow(
                'Service Charge (${serviceChargePercent.toStringAsFixed(0)}%):',
                serviceCharge.toStringAsFixed(2)),
            if (discountAmount > 0)
              _billRow('Discount:', '- ${discountAmount.toStringAsFixed(2)}'),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(grandTotal.toStringAsFixed(2),
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text('Thank you for visiting!')),
            pw.Center(child: pw.Text('Please come again.')),
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
