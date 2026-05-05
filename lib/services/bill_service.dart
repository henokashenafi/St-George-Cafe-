import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/table_model.dart';

class BillService {
  static Future<void> generateAndDownloadBill({
    required OrderModel order,
    required List<OrderItem> items,
    required String tableName,
    required String waiterName,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt);
    
    double subtotal = items.fold(0, (sum, item) => sum + item.subtotal);
    double vat = subtotal * 0.05;
    double total = subtotal + vat;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal printer style
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('ST GEORGE CAFE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Addis Ababa, Ethiopia'),
                    pw.SizedBox(height: 10),
                    pw.Text('CUSTOMER BILL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $dateStr'),
                  pw.Text('Table: $tableName'),
                ],
              ),
              pw.Text('Waiter: $waiterName'),
              pw.Text('Order ID: #${order.id}'),
              pw.Divider(),
              pw.SizedBox(height: 5),
              // Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 5),
              // Items
              ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(item.productName)),
                    pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text(item.unitPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text(item.subtotal.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                  ],
                ),
              )),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:'),
                  pw.Text(subtotal.toStringAsFixed(2)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VAT (5%):'),
                  pw.Text(vat.toStringAsFixed(2)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(total.toStringAsFixed(2), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Thank you for visiting!')),
              pw.Center(child: pw.Text('Please come again.')),
            ],
          );
        },
      ),
    );

    // On Web, this will download the PDF. On Desktop, it will open the print dialog.
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bill_${order.id}_${tableName.replaceAll(' ', '_')}.pdf',
    );
  }
}
