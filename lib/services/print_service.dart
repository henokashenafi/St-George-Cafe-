import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:intl/intl.dart';

class PrintService {
  Future<List<int>> generateKitchenReceipt(OrderModel order, List<OrderItem> newItems) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text('KITCHEN ORDER', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.hr();
    bytes += generator.text('Table: ${order.tableName}', styles: const PosStyles(bold: true));
    bytes += generator.text('Waiter: ${order.waiterName}');
    bytes += generator.text('Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}');
    bytes += generator.hr();

    for (var item in newItems) {
      bytes += generator.text('${item.quantity} x ${item.productName}', styles: const PosStyles(bold: true));
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += generator.text('  * ${item.notes}');
      }
    }

    bytes += generator.hr();
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> generateCustomerBill(OrderModel order) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text('ST GEORGE CAFE', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text('Addis Ababa, Ethiopia', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // Info
    bytes += generator.row([
      PosColumn(text: 'Table: ${order.tableName}', width: 6),
      PosColumn(text: 'Order: #${order.id}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.text('Waiter: ${order.waiterName}');
    bytes += generator.text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}');
    bytes += generator.hr();

    // Items
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Total', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    for (var item in order.items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6),
        PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: item.subtotal.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // Total
    bytes += generator.row([
      PosColumn(text: 'GRAND TOTAL', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: '${order.totalAmount.toStringAsFixed(2)} ETB', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);

    bytes += generator.hr();
    bytes += generator.text('Thank you for visiting!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}
