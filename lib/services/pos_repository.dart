import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:st_george_pos/core/database_helper.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/table_zone.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:st_george_pos/models/settings.dart';

class PosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Legacy Web Storage Hack (Used because sqflite_ffi_web requires external .wasm/.js binaries)
  static Map<String, List<Map<String, dynamic>>> _webStorage = {
    'categories': [],
    'products': [],
    'tables': [],
    'table_zones': [],
    'orders': [],
    'order_items': [],
    'waiters': [],
    'users': [
      {
        'id': 1,
        'username': 'Director',
        'password_hash': DatabaseHelper.hashPassword('director123'),
        'role': 'director',
        'is_active': 1,
      },
      {
        'id': 2,
        'username': 'Cashier 1',
        'password_hash': DatabaseHelper.hashPassword('cashier123'),
        'role': 'cashier',
        'is_active': 1,
      },
    ],
    'app_settings': [
      {'key': 'service_charge_percent', 'value': '5.0', 'updated_by': null},
      {'key': 'discount_enabled', 'value': 'true', 'updated_by': null},
    ],
  };

  PosRepository();

  Future<void> init() async {
    if (kIsWeb) {
      await _loadWebData();
      if (_webStorage['categories']!.isEmpty) {
        await _seedWebData();
      }
    } else {
      // Eagerly initialize DB to fail fast on startup
      await _dbHelper.database;
    }
  }

  Future<void> _seedWebData() async {
    // Categories
    _webStorage['categories'] = [
      {'id': 1, 'name': 'Coffee'},
      {'id': 2, 'name': 'Tea'},
      {'id': 3, 'name': 'Pastries'},
      {'id': 4, 'name': 'Soft Drinks'},
    ];

    // Products
    _webStorage['products'] = [
      {'id': 1, 'category_id': 1, 'name': 'Macchiato', 'price': 35.0},
      {'id': 2, 'category_id': 1, 'name': 'Black Coffee', 'price': 25.0},
      {'id': 3, 'category_id': 2, 'name': 'Black Tea', 'price': 15.0},
      {'id': 4, 'category_id': 3, 'name': 'Croissant', 'price': 55.0},
      {'id': 5, 'category_id': 4, 'name': 'Coca Cola', 'price': 30.0},
    ];

    // Waiters
    _webStorage['waiters'] = [
      {'id': 1, 'name': 'Abebe Kebede', 'code': 'W001'},
      {'id': 2, 'name': 'Almaz Wondimu', 'code': 'W002'},
      {'id': 3, 'name': 'Tadesse Hailu', 'code': 'W003'},
      {'id': 4, 'name': 'Mekdes Alemu', 'code': 'W004'},
      {'id': 5, 'name': 'Biruk Tadese', 'code': 'W005'},
    ];

    // Zones
    _webStorage['table_zones'] = [
      {'id': 1, 'name': 'Main Hall', 'waiter_id': 1},
      {'id': 2, 'name': 'Terrace', 'waiter_id': 2},
      {'id': 3, 'name': 'VIP Lounge', 'waiter_id': 3},
      {'id': 4, 'name': 'Garden', 'waiter_id': 4},
      {'id': 5, 'name': 'Balcony', 'waiter_id': 5},
    ];

    // Assign tables to zones (2 tables per zone)
    _webStorage['tables'] = [
      {'id': 1, 'name': 'Table 1', 'status': 'available', 'zone_id': 1},
      {'id': 2, 'name': 'Table 2', 'status': 'available', 'zone_id': 1},
      {'id': 3, 'name': 'Table 3', 'status': 'available', 'zone_id': 2},
      {'id': 4, 'name': 'Table 4', 'status': 'available', 'zone_id': 2},
      {'id': 5, 'name': 'Table 5', 'status': 'available', 'zone_id': 3},
      {'id': 6, 'name': 'Table 6', 'status': 'available', 'zone_id': 3},
      {'id': 7, 'name': 'Table 7', 'status': 'available', 'zone_id': 4},
      {'id': 8, 'name': 'Table 8', 'status': 'available', 'zone_id': 4},
      {'id': 9, 'name': 'Table 9', 'status': 'available', 'zone_id': 5},
      {'id': 10, 'name': 'Table 10', 'status': 'available', 'zone_id': 5},
    ];

    await _saveWebData();
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
        _webStorage = Map<String, List<Map<String, dynamic>>>.from(
          (decoded as Map).map(
            (key, value) => MapEntry(
              key as String,
              List<Map<String, dynamic>>.from(
                (value as List).map((e) => Map<String, dynamic>.from(e)),
              ),
            ),
          ),
        );
        // Ensure all storage keys exist
        _webStorage.putIfAbsent('users', () => []);
        _webStorage.putIfAbsent('app_settings', () => []);
        _webStorage.putIfAbsent('categories', () => []);
        _webStorage.putIfAbsent('products', () => []);
        _webStorage.putIfAbsent('waiters', () => []);
        _webStorage.putIfAbsent('table_zones', () => []);
        _webStorage.putIfAbsent('tables', () => []);
        _webStorage.putIfAbsent('orders', () => []);
        _webStorage.putIfAbsent('order_items', () => []);
      }
    } catch (e) {
      // fallback to defaults
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<AppUser?> login(String username, String password) async {
    final hash = DatabaseHelper.hashPassword(password);
    if (kIsWeb) {
      final map = _webStorage['users']!.firstWhere(
        (u) =>
            u['username'] == username &&
            u['password_hash'] == hash &&
            u['is_active'] == 1,
        orElse: () => {},
      );
      if (map.isEmpty) return null;
      return AppUser.fromMap(map);
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [username, hash],
    );
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  Future<List<AppUser>> getUsers() async {
    if (kIsWeb)
      return _webStorage['users']!.map((u) => AppUser.fromMap(u)).toList();
    final db = await _dbHelper.database;
    final maps = await db.query('users', orderBy: 'username ASC');
    return maps.map((m) => AppUser.fromMap(m)).toList();
  }

  Future<int> addUser(AppUser user) async {
    if (kIsWeb) {
      final id =
          (_webStorage['users']!.isEmpty
              ? 0
              : _webStorage['users']!
                    .map((u) => u['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final map = user.toMap();
      map['id'] = id;
      _webStorage['users']!.add(map);
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('users', user.toMap());
  }

  Future<void> updateUser(AppUser user) async {
    if (kIsWeb) {
      final index = _webStorage['users']!.indexWhere((u) => u['id'] == user.id);
      if (index != -1) _webStorage['users']![index] = user.toMap();
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> deleteUser(int id) async {
    if (kIsWeb) {
      _webStorage['users']!.removeWhere((u) => u['id'] == id);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> getSettings() async {
    if (kIsWeb)
      return {
        for (var s in _webStorage['app_settings']!)
          s['key'] as String: s['value'] as String,
      };
    final db = await _dbHelper.database;
    final maps = await db.query('app_settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  Future<void> setSetting(String key, String value, int updatedBy) async {
    if (kIsWeb) {
      final index = _webStorage['app_settings']!.indexWhere(
        (s) => s['key'] == key,
      );
      if (index != -1) {
        _webStorage['app_settings']![index]['value'] = value;
        _webStorage['app_settings']![index]['updated_by'] = updatedBy;
      } else {
        _webStorage['app_settings']!.add({
          'key': key,
          'value': value,
          'updated_by': updatedBy,
        });
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Table Zones ───────────────────────────────────────────────────────────

  Future<List<TableZone>> getTableZones() async {
    if (kIsWeb)
      return _webStorage['table_zones']!
          .map((z) => TableZone.fromMap(z))
          .toList();
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT tz.*, w.name as waiter_name
      FROM table_zones tz
      LEFT JOIN waiters w ON tz.waiter_id = w.id
      ORDER BY tz.name ASC
    ''');
    return maps.map((m) => TableZone.fromMap(m)).toList();
  }

  Future<int> addTableZone(String name, {int? waiterId}) async {
    if (kIsWeb) {
      final id =
          (_webStorage['table_zones']!.isEmpty
              ? 0
              : _webStorage['table_zones']!
                    .map((z) => z['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      _webStorage['table_zones']!.add({
        'id': id,
        'name': name,
        'waiter_id': waiterId,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('table_zones', {
      'name': name,
      'waiter_id': waiterId,
    });
  }

  Future<void> updateTableZone(int id, String name, {int? waiterId}) async {
    if (kIsWeb) {
      final index = _webStorage['table_zones']!.indexWhere(
        (z) => z['id'] == id,
      );
      if (index != -1) {
        _webStorage['table_zones']![index]['name'] = name;
        _webStorage['table_zones']![index]['waiter_id'] = waiterId;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'table_zones',
      {'name': name, 'waiter_id': waiterId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTableZone(int id) async {
    if (kIsWeb) {
      _webStorage['table_zones']!.removeWhere((z) => z['id'] == id);
      for (var t in _webStorage['tables']!)
        if (t['zone_id'] == id) t['zone_id'] = null;
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'tables',
        {'zone_id': null},
        where: 'zone_id = ?',
        whereArgs: [id],
      );
      await txn.delete('table_zones', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── Tables ────────────────────────────────────────────────────────────────

  Future<List<TableModel>> getTables({int? zoneId}) async {
    if (kIsWeb) {
      var list = _webStorage['tables']!;
      if (zoneId != null)
        list = list.where((t) => t['zone_id'] == zoneId).toList();
      return list.map((t) => TableModel.fromMap(t)).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT t.*, tz.name as zone_name
      FROM tables t
      LEFT JOIN table_zones tz ON t.zone_id = tz.id
      ${zoneId != null ? 'WHERE t.zone_id = ?' : ''}
      ORDER BY t.name ASC
    ''', zoneId != null ? [zoneId] : []);
    return maps.map((m) => TableModel.fromMap(m)).toList();
  }

  Future<int> addTable(String name, {int? zoneId}) async {
    if (kIsWeb) {
      final id =
          (_webStorage['tables']!.isEmpty
              ? 0
              : _webStorage['tables']!
                    .map((t) => t['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      _webStorage['tables']!.add({
        'id': id,
        'name': name,
        'status': 'available',
        'zone_id': zoneId,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('tables', {'name': name, 'zone_id': zoneId});
  }

  Future<void> updateTable(int id, String name, {int? zoneId}) async {
    if (kIsWeb) {
      final index = _webStorage['tables']!.indexWhere((t) => t['id'] == id);
      if (index != -1) {
        _webStorage['tables']![index]['name'] = name;
        _webStorage['tables']![index]['zone_id'] = zoneId;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'tables',
      {'name': name, 'zone_id': zoneId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTable(int id) async {
    if (kIsWeb) {
      _webStorage['tables']!.removeWhere((t) => t['id'] == id);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTableStatus(int tableId, TableStatus status) async {
    if (kIsWeb) {
      final index = _webStorage['tables']!.indexWhere(
        (e) => e['id'] == tableId,
      );
      if (index != -1)
        _webStorage['tables']![index]['status'] = status
            .toString()
            .split('.')
            .last;
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

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> getCategories() async {
    if (kIsWeb)
      return _webStorage['categories']!
          .map((c) => Category.fromMap(c))
          .toList();
    final db = await _dbHelper.database;
    final maps = await db.query('categories');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> addCategory(String name) async {
    if (kIsWeb) {
      final id =
          (_webStorage['categories']!.isEmpty
              ? 0
              : _webStorage['categories']!
                    .map((c) => c['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
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

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({int? categoryId}) async {
    if (kIsWeb) {
      final list = _webStorage['products']!;
      final filtered = categoryId != null
          ? list.where((e) => e['category_id'] == categoryId).toList()
          : list;
      return filtered.map((p) => Product.fromMap(p)).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<bool> isProductNameTaken(String name, {int? excludeId}) async {
    if (kIsWeb) {
      final match = _webStorage['products']!.where(
        (p) => p['name'] == name && (excludeId == null || p['id'] != excludeId),
      );
      return match.isNotEmpty;
    }
    final db = await _dbHelper.database;
    final query = excludeId != null
        ? 'SELECT COUNT(*) FROM products WHERE name = ? AND id != ?'
        : 'SELECT COUNT(*) FROM products WHERE name = ?';
    final args = excludeId != null ? [name, excludeId] : [name];
    final result = await db.rawQuery(query, args);
    return (result.first.values.first as int) > 0;
  }

  Future<int> addProduct(Product product) async {
    if (await isProductNameTaken(product.name)) {
      throw Exception('Product name "${product.name}" already exists');
    }
    if (kIsWeb) {
      final id =
          (_webStorage['products']!.isEmpty
              ? 0
              : _webStorage['products']!
                    .map((p) => p['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
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

  // ── Waiters ───────────────────────────────────────────────────────────────

  Future<List<Waiter>> getWaiters() async {
    if (kIsWeb)
      return _webStorage['waiters']!.map((w) => Waiter.fromMap(w)).toList();
    final db = await _dbHelper.database;
    final maps = await db.query('waiters');
    return maps.map((m) => Waiter.fromMap(m)).toList();
  }

  Future<int> addWaiter(String name) async {
    if (kIsWeb) {
      final id =
          (_webStorage['waiters']!.isEmpty
              ? 0
              : _webStorage['waiters']!
                    .map((w) => w['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      _webStorage['waiters']!.add({'id': id, 'name': name, 'code': 'W$id'});
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('waiters', {
      'name': name,
      'code': 'W${DateTime.now().millisecond}',
    });
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

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<int> createOrder(OrderModel order) async {
    if (kIsWeb) {
      final orderId =
          (_webStorage['orders']!.isEmpty
              ? 0
              : _webStorage['orders']!
                    .map((o) => o['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final newOrder = order.toMap();
      newOrder['id'] = orderId;
      _webStorage['orders']!.add(newOrder);
      if (order.tableId != 0)
        await updateTableStatus(order.tableId, TableStatus.occupied);
      await _saveWebData();
      return orderId;
    }
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap());
      if (order.tableId != 0)
        await txn.update(
          'tables',
          {'status': 'occupied'},
          where: 'id = ?',
          whereArgs: [order.tableId],
        );
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
    final maps = await db.rawQuery(
      'SELECT o.*, t.name as table_name, w.name as waiter_name, u.username as cashier_name FROM orders o JOIN tables t ON o.table_id = t.id JOIN waiters w ON o.waiter_id = w.id LEFT JOIN users u ON o.cashier_id = u.id WHERE o.table_id = ? AND o.status = \'pending\' LIMIT 1',
      [tableId],
    );
    if (maps.isEmpty) return null;
    final orderId = maps.first['id'];
    final itemMaps = await db.rawQuery(
      'SELECT oi.*, p.name as product_name, c.name as category_name FROM order_items oi JOIN products p ON oi.product_id = p.id JOIN categories c ON p.category_id = c.id WHERE oi.order_id = ?',
      [orderId],
    );
    final items = itemMaps.map((i) => OrderItem.fromMap(i)).toList();
    return OrderModel.fromMap(maps.first, items: items);
  }

  Future<int> addItemsToOrder(
    int orderId,
    List<OrderItem> items, [
    int? tableId,
  ]) async {
    if (kIsWeb) {
      final existingItems = _webStorage['order_items']!.where(
        (i) => i['order_id'] == orderId,
      );
      final nextRound = existingItems.isEmpty
          ? 1
          : existingItems
                    .map((i) => (i['kitchen_round'] as int?) ?? 0)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      double totalToAdd = 0;
      for (var item in items) {
        final p = _webStorage['products']!.firstWhere((p) => p['id'] == item.productId);
        final c = _webStorage['categories']!.firstWhere((c) => c['id'] == p['category_id']);
        final itemMap = item
            .copyWith(orderId: orderId, kitchenRound: nextRound, categoryName: c['name'])
            .toMap();
        itemMap['id'] =
            (_webStorage['order_items']!.isEmpty
                ? 0
                : _webStorage['order_items']!
                      .map((i) => i['id'] as int)
                      .reduce((a, b) => a > b ? a : b)) +
            1;
        _webStorage['order_items']!.add(itemMap);
        totalToAdd += item.subtotal;
      }
      final oIndex = _webStorage['orders']!.indexWhere(
        (o) => o['id'] == orderId,
      );
      if (oIndex != -1)
        _webStorage['orders']![oIndex]['total_amount'] =
            (_webStorage['orders']![oIndex]['total_amount'] as num).toDouble() +
            totalToAdd;
      await _saveWebData();
      return nextRound;
    }
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> roundResult = await txn.rawQuery(
        'SELECT MAX(kitchen_round) as max_round FROM order_items WHERE order_id = ?',
        [orderId],
      );
      final nextRound = ((roundResult.first['max_round'] as int?) ?? 0) + 1;
      double totalToAdd = 0;
      for (var item in items) {
        await txn.insert(
          'order_items',
          item.copyWith(orderId: orderId, kitchenRound: nextRound).toMap(),
        );
        totalToAdd += item.subtotal;
      }
      await txn.execute(
        'UPDATE orders SET total_amount = total_amount + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [totalToAdd, orderId],
      );
      return nextRound;
    });
  }

  Future<void> markItemsAsPrinted(List<int> itemIds) async {
    if (kIsWeb) {
      for (var id in itemIds) {
        final index = _webStorage['order_items']!.indexWhere(
          (e) => e['id'] == id,
        );
        if (index != -1)
          _webStorage['order_items']![index]['is_printed_to_kitchen'] = 1;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update('order_items', {
      'is_printed_to_kitchen': 1,
    }, where: 'id IN (${itemIds.join(',')})');
  }

  Future<void> voidOrderItem(int itemId, int orderId) async {
    if (kIsWeb) {
      final item = _webStorage['order_items']!.firstWhere(
        (i) => i['id'] == itemId,
        orElse: () => {},
      );
      if (item.isEmpty) return;
      final subtotal = (item['subtotal'] as num).toDouble();
      final tableId = _webStorage['orders']!.firstWhere(
        (o) => o['id'] == orderId,
      )['table_id'];
      _webStorage['order_items']!.removeWhere((i) => i['id'] == itemId);
      final remainingCount = _webStorage['order_items']!
          .where((i) => i['order_id'] == orderId)
          .length;
      final oIndex = _webStorage['orders']!.indexWhere(
        (o) => o['id'] == orderId,
      );
      if (remainingCount == 0 && oIndex != -1) {
        _webStorage['orders']!.removeAt(oIndex);
        await updateTableStatus(tableId, TableStatus.available);
      } else if (oIndex != -1) {
        _webStorage['orders']![oIndex]['total_amount'] =
            ((_webStorage['orders']![oIndex]['total_amount'] as num)
                        .toDouble() -
                    subtotal)
                .clamp(0, double.infinity);
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'order_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (rows.isEmpty) return;
      final subtotal = (rows.first['subtotal'] as num).toDouble();
      final orderRows = await txn.query(
        'orders',
        columns: ['table_id'],
        where: 'id = ?',
        whereArgs: [orderId],
      );
      final tableId = orderRows.first['table_id'] as int;
      await txn.delete('order_items', where: 'id = ?', whereArgs: [itemId]);
      final remainingRows = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM order_items WHERE order_id = ?',
        [orderId],
      );
      if (remainingRows.first['count'] == 0) {
        await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
        await txn.update(
          'tables',
          {'status': 'available'},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      } else {
        await txn.execute(
          'UPDATE orders SET total_amount = MAX(0, total_amount - ?), updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [subtotal, orderId],
        );
      }
    });
  }

  Future<void> completeOrder(
    int orderId,
    int tableId, {
    double serviceCharge = 0,
    double discountAmount = 0,
  }) async {
    if (kIsWeb) {
      final oIndex = _webStorage['orders']!.indexWhere(
        (o) => o['id'] == orderId,
      );
      if (oIndex != -1) {
        _webStorage['orders']![oIndex]['status'] = 'completed';
        _webStorage['orders']![oIndex]['service_charge'] = serviceCharge;
        _webStorage['orders']![oIndex]['discount_amount'] = discountAmount;
      }
      await updateTableStatus(tableId, TableStatus.available);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'status': 'completed',
          'service_charge': serviceCharge,
          'discount_amount': discountAmount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await txn.update(
        'tables',
        {'status': 'available'},
        where: 'id = ?',
        whereArgs: [tableId],
      );
    });
  }

  Future<void> updateProduct(Product product) async {
    if (await isProductNameTaken(product.name, excludeId: product.id)) {
      throw Exception('Product name "${product.name}" already exists');
    }
    if (kIsWeb) {
      final index = _webStorage['products']!.indexWhere(
        (p) => p['id'] == product.id,
      );
      if (index != -1) _webStorage['products']![index] = product.toMap();
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<List<OrderModel>> getAllOrders({DateTime? from, DateTime? to}) async {
    if (kIsWeb) {
      var list = _webStorage['orders']!;
      if (from != null)
        list = list
            .where((o) => DateTime.parse(o['created_at']).isAfter(from))
            .toList();
      if (to != null)
        list = list
            .where((o) => DateTime.parse(o['created_at']).isBefore(to))
            .toList();
      return list.map((o) {
        final items = _webStorage['order_items']!
            .where((i) => i['order_id'] == o['id'])
            .map((i) => OrderItem.fromMap(i))
            .toList();
        return OrderModel.fromMap(o, items: items);
      }).toList();
    }
    final db = await _dbHelper.database;
    String whereClause = '';
    List<dynamic> args = [];
    if (from != null && to != null) {
      whereClause = 'WHERE o.created_at BETWEEN ? AND ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      whereClause = 'WHERE o.created_at >= ?';
      args = [from.toIso8601String()];
    } else if (to != null) {
      whereClause = 'WHERE o.created_at <= ?';
      args = [to.toIso8601String()];
    }
    final maps = await db.rawQuery(
      'SELECT o.*, t.name as table_name, w.name as waiter_name, u.username as cashier_name FROM orders o JOIN tables t ON o.table_id = t.id JOIN waiters w ON o.waiter_id = w.id LEFT JOIN users u ON o.cashier_id = u.id $whereClause ORDER BY o.created_at DESC',
      args,
    );
    List<OrderModel> orders = [];
    for (var map in maps) {
      final itemMaps = await db.rawQuery(
        'SELECT oi.*, p.name as product_name, c.name as category_name FROM order_items oi JOIN products p ON oi.product_id = p.id JOIN categories c ON p.category_id = c.id WHERE oi.order_id = ?',
        [map['id']],
      );
      orders.add(
        OrderModel.fromMap(
          map,
          items: itemMaps.map((i) => OrderItem.fromMap(i)).toList(),
        ),
      );
    }
    return orders;
  }

  Future<CafeSettings> getCafeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cafe_settings');
    if (data != null) return CafeSettings.fromMap(jsonDecode(data));
    return CafeSettings();
  }

  Future<void> saveSettings(CafeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cafe_settings', jsonEncode(settings.toMap()));
  }
}
