import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:intl/intl.dart';

class PrintService {
  Future<List<int>> generateKitchenReceipt(
    OrderModel order,
    List<OrderItem> newItems, {
    required String Function(String key, {Map<String, String>? replacements}) t,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text(
      t('print.kitchenOrder'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.hr();
    bytes += generator.text(
      '${t('print.table')}: ${order.tableName}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text('${t('print.waiter')}: ${order.waiterName}');
    bytes += generator.text(
      '${t('print.time')}: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
    );
    bytes += generator.hr();

    for (var item in newItems) {
      bytes += generator.text(
        '${item.quantity} x ${item.productName}',
        styles: const PosStyles(bold: true),
      );
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += generator.text('  * ${item.notes}');
      }
    }

    bytes += generator.hr();
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> generateCustomerBill(
    OrderModel order, {
    required String Function(String key, {Map<String, String>? replacements}) t,
    String? currency,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text(
      t('print.stGeorgeCafe'),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      t('print.address'),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: '${t('print.table')}: ${order.tableName}', width: 6),
      PosColumn(
        text: '${t('print.orderNumber')}: #${order.id}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text('${t('print.waiter')}: ${order.waiterName}');
    bytes += generator.text(
      '${t('print.time')}: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}',
    );
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        text: t('print.item'),
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: t('print.qty'),
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: t('print.total'),
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    for (var item in order.items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6),
        PosColumn(
          text: item.quantity.toString(),
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: item.subtotal.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    final curr = currency ?? (t != null ? t('common.currency') : 'ETB');
    bytes += generator.row([
      PosColumn(
        text: t('print.grandTotal'),
        width: 8,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: '${order.totalAmount.toStringAsFixed(2)} $curr',
        width: 4,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      t('print.thankYou'),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}
