import 'dart:math';
import 'package:sqflite_common/sqlite_api.dart';

class MockDataSeeder {
  static Future<void> seedDetailedMockData(Database db) async {
    final random = Random();
    final now = DateTime.now();
    
    final products = await db.query('products');
    final tables = await db.query('tables');
    final waiters = await db.query('waiters');
    final users = await db.query('users');

    print('DEBUG: Seeder counts - Products: ${products.length}, Tables: ${tables.length}, Waiters: ${waiters.length}, Users: ${users.length}');

    if (products.isEmpty || tables.isEmpty || waiters.isEmpty || users.isEmpty) {
      print('DEBUG: Seeder returning early - missing core data.');
      return;
    }

    // Seed 200+ orders over last 30 days
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      // Random number of orders per day (5 to 15)
      final ordersCount = 5 + random.nextInt(10);

      for (int j = 0; j < ordersCount; j++) {
        // Random hour (8 AM to 9 PM)
        final hour = 8 + random.nextInt(13);
        final minute = random.nextInt(60);
        final orderTime = DateTime(date.year, date.month, date.day, hour, minute);
        
        final table = tables[random.nextInt(tables.length)];
        final waiter = waiters[random.nextInt(waiters.length)];
        final cashier = users[random.nextInt(users.length)];
        
        // Insert Order
        final orderId = await db.insert('orders', {
          'table_id': table['id'],
          'waiter_id': waiter['id'],
          'cashier_id': cashier['id'],
          'status': random.nextDouble() < 0.9 ? 'completed' : 'cancelled',
          'created_at': orderTime.toIso8601String(),
          'updated_at': orderTime.add(const Duration(minutes: 30)).toIso8601String(),
          'total_amount': 0.0, // Will update after items
          'service_charge': 0.0,
          'discount_amount': 0.0,
        });

        // Add 2 to 6 random items
        double subtotal = 0.0;
        final itemCount = 2 + random.nextInt(5);
        for (int k = 0; k < itemCount; k++) {
          final prod = products[random.nextInt(products.length)];
          final qty = 1 + random.nextInt(3);
          final price = (prod['price'] as num).toDouble();
          final lineTotal = price * qty;
          subtotal += lineTotal;

          await db.insert('order_items', {
            'order_id': orderId,
            'product_id': prod['id'],
            'quantity': qty,
            'unit_price': price,
            'subtotal': lineTotal,
            'is_printed_to_kitchen': 1,
            'created_at': orderTime.toIso8601String(),
          });
        }

        // Apply service charge (5%) and random discount
        final sc = subtotal * 0.05;
        final discount = random.nextDouble() < 0.2 ? (subtotal * 0.1) : 0.0;

        await db.update(
          'orders',
          {
            'total_amount': subtotal,
            'service_charge': sc,
            'discount_amount': discount,
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }
    }
  }

  static Future<void> clearAllTransactions(Database db) async {
    await db.delete('order_items');
    await db.delete('orders');
    // Also reset table statuses
    await db.update('tables', {'status': 'available'});
  }
}
