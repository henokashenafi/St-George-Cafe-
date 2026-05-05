import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:st_george_pos/core/database_helper.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class PosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // In-memory mock storage for Web fallback
  static Map<String, List<Map<String, dynamic>>> _webStorage = {
    'categories': [
      {'id': 1, 'name': 'Food'},
      {'id': 2, 'name': 'Drinks'},
      {'id': 3, 'name': 'Desserts'},
    ],
    'products': [
      {'id': 1, 'category_id': 1, 'name': 'Classic Burger', 'price': 250.0},
      {'id': 2, 'category_id': 1, 'name': 'Cheeseburger', 'price': 280.0},
      {'id': 3, 'category_id': 1, 'name': 'Veggie Pizza', 'price': 450.0},
      {'id': 4, 'category_id': 2, 'name': 'Cappuccino', 'price': 65.0},
      {'id': 5, 'category_id': 2, 'name': 'Fresh Orange Juice', 'price': 120.0},
      {'id': 6, 'category_id': 3, 'name': 'Chocolate Cake', 'price': 180.0},
    ],
    'tables': List.generate(20, (i) => {
      'id': i + 1,
      'name': 'Table ${i + 1}',
      'status': i % 5 == 0 ? 'occupied' : 'available'
    }),
    'orders': [],
    'order_items': [],
    'waiters': [{'id': 1, 'name': 'Default Waiter', 'code': '0000'}],
  };

  PosRepository();

  Future<void> init() async {
    if (kIsWeb) {
      await _loadWebData();
    }
  }

  Future<void> _saveWebData() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_web_storage', jsonEncode(_webStorage));
  }

  Future<void> _loadWebData() async {
    if (!kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('pos_web_storage');
      if (data != null) {
        final decoded = jsonDecode(data);
        // Cast everything to correct types
        _webStorage = Map<String, List<Map<String, dynamic>>>.from(
          (decoded as Map).map((key, value) => MapEntry(
            key as String, 
            List<Map<String, dynamic>>.from((value as List).map((e) => Map<String, dynamic>.from(e)))
          ))
        );
      }
    } catch (e) {
      print('Error loading web storage: $e');
    }
  }

  // Categories
  Future<List<Category>> getCategories() async {
    if (kIsWeb) {
      return List.generate(_webStorage['categories']!.length, (i) => Category.fromMap(_webStorage['categories']![i]));
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> addCategory(String name) async {
    if (kIsWeb) {
      final id = _webStorage['categories']!.length + 1;
      _webStorage['categories']!.add({'id': id, 'name': name});
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('categories', {'name': name});
  }

  Future<void> deleteCategory(int id) async {
    if (kIsWeb) {
      _webStorage['categories']!.removeWhere((e) => e['id'] == id);
      _webStorage['products']!.removeWhere((e) => e['category_id'] == id);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await db.delete('products', where: 'category_id = ?', whereArgs: [id]);
  }

  // Products
  Future<List<Product>> getProducts({int? categoryId}) async {
    if (kIsWeb) {
      final list = _webStorage['products']!;
      final filtered = categoryId != null ? list.where((e) => e['category_id'] == categoryId).toList() : list;
      return List.generate(filtered.length, (i) => Product.fromMap(filtered[i]));
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> addProduct(Product product) async {
    if (kIsWeb) {
      final id = _webStorage['products']!.length + 1;
      final map = product.toMap();
      map['id'] = id;
      _webStorage['products']!.add(map);
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('products', product.toMap());
  }

  Future<void> deleteProduct(int id) async {
    if (kIsWeb) {
      _webStorage['products']!.removeWhere((e) => e['id'] == id);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Waiters
  Future<List<Waiter>> getWaiters() async {
    if (kIsWeb) {
      return List.generate(_webStorage['waiters']!.length, (i) => Waiter.fromMap(_webStorage['waiters']![i]));
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('waiters');
    return List.generate(maps.length, (i) => Waiter.fromMap(maps[i]));
  }

  Future<int> addWaiter(String name) async {
    if (kIsWeb) {
      final id = _webStorage['waiters']!.length + 1;
      _webStorage['waiters']!.add({'id': id, 'name': name, 'code': 'W$id'});
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('waiters', {'name': name, 'code': 'W${DateTime.now().millisecond}'});
  }

  Future<void> deleteWaiter(int id) async {
    if (kIsWeb) {
      _webStorage['waiters']!.removeWhere((e) => e['id'] == id);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('waiters', where: 'id = ?', whereArgs: [id]);
  }

  // Tables
  Future<List<TableModel>> getTables() async {
    if (kIsWeb) {
      return List.generate(_webStorage['tables']!.length, (i) => TableModel.fromMap(_webStorage['tables']![i]));
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('tables');
    return List.generate(maps.length, (i) => TableModel.fromMap(maps[i]));
  }

  Future<void> updateTableStatus(int tableId, TableStatus status) async {
    if (kIsWeb) {
      final index = _webStorage['tables']!.indexWhere((e) => e['id'] == tableId);
      if (index != -1) {
        _webStorage['tables']![index]['status'] = status.toString().split('.').last;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'tables',
      {'status': status.toString().split('.').last},
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  // Orders
  Future<int> createOrder(OrderModel order) async {
    if (kIsWeb) {
      final orderId = _webStorage['orders']!.length + 1;
      final newOrder = order.toMap();
      newOrder['id'] = orderId;
      _webStorage['orders']!.add(newOrder);
      await updateTableStatus(order.tableId, TableStatus.occupied);
      await _saveWebData();
      return orderId;
    }
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap());
      await txn.update('tables', {'status': 'occupied'}, where: 'id = ?', whereArgs: [order.tableId]);
      return orderId;
    });
  }

  Future<OrderModel?> getActiveOrderForTable(int tableId) async {
    if (kIsWeb) {
      final orderMap = _webStorage['orders']!.firstWhere(
        (o) => o['table_id'] == tableId && o['status'] == 'pending',
        orElse: () => {},
      );
      if (orderMap.isEmpty) return null;
      
      final items = _webStorage['order_items']!
          .where((i) => i['order_id'] == orderMap['id'])
          .map((i) => OrderItem.fromMap(i))
          .toList();
      
      return OrderModel.fromMap(orderMap, items: items);
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT o.*, t.name as table_name, w.name as waiter_name 
      FROM orders o
      JOIN tables t ON o.table_id = t.id
      JOIN waiters w ON o.waiter_id = w.id
      WHERE o.table_id = ? AND o.status = 'pending'
      LIMIT 1
    ''', [tableId]);

    if (maps.isEmpty) return null;

    final orderId = maps.first['id'];
    final List<Map<String, dynamic>> itemMaps = await db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);

    final items = List.generate(itemMaps.length, (i) => OrderItem.fromMap(itemMaps[i]));
    return OrderModel.fromMap(maps.first, items: items);
  }

  Future<void> addItemsToOrder(int orderId, List<OrderItem> items, [int? tableId]) async {
    if (kIsWeb) {
      for (var item in items) {
        final itemMap = item.copyWith(orderId: orderId).toMap();
        itemMap['id'] = _webStorage['order_items']!.length + 1;
        _webStorage['order_items']!.add(itemMap);
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      double totalToAdd = 0;
      for (var item in items) {
        await txn.insert('order_items', item.copyWith(orderId: orderId).toMap());
        totalToAdd += item.subtotal;
      }
      await txn.execute(
        'UPDATE orders SET total_amount = total_amount + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [totalToAdd, orderId],
      );
    });
  }

  Future<void> markItemsAsPrinted(List<int> itemIds) async {
    if (kIsWeb) {
      for (var id in itemIds) {
        final index = _webStorage['order_items']!.indexWhere((e) => e['id'] == id);
        if (index != -1) _webStorage['order_items']![index]['is_printed_to_kitchen'] = 1;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update('order_items', {'is_printed_to_kitchen': 1}, where: 'id IN (${itemIds.join(',')})');
  }

  Future<void> completeOrder(int orderId, int tableId) async {
    if (kIsWeb) {
      final oIndex = _webStorage['orders']!.indexWhere((o) => o['id'] == orderId);
      if (oIndex != -1) {
        _webStorage['orders']![oIndex]['status'] = 'completed';
      }
      await updateTableStatus(tableId, TableStatus.available);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('orders', {'status': 'completed', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [orderId]);
      await txn.update('tables', {'status': 'available'}, where: 'id = ?', whereArgs: [tableId]);
    });
  }

  Future<List<OrderModel>> getAllOrders() async {
    if (kIsWeb) {
      return _webStorage['orders']!.map((o) {
        final items = _webStorage['order_items']!
            .where((i) => i['order_id'] == o['id'])
            .map((i) => OrderItem.fromMap(i))
            .toList();
        return OrderModel.fromMap(o, items: items);
      }).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query('orders', orderBy: 'created_at DESC');
    List<OrderModel> orders = [];
    for (var map in maps) {
      final itemMaps = await db.query('order_items', where: 'order_id = ?', whereArgs: [map['id']]);
      final items = itemMaps.map((i) => OrderItem.fromMap(i)).toList();
      orders.add(OrderModel.fromMap(map, items: items));
    }
    return orders;
  }
}
