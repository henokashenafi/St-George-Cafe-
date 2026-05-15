import 'dart:convert';
import 'dart:math';
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
import 'package:st_george_pos/models/shift.dart';
import 'package:st_george_pos/models/z_report.dart';
import 'package:st_george_pos/models/station.dart';

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
    'serving_stations': [],
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
    'pos_charges': [
      {
        'id': 1,
        'name': 'VAT',
        'type': 'addition',
        'value': 0.0,
        'is_active': 1,
      },
      {
        'id': 2,
        'name': 'Service Charge',
        'type': 'addition',
        'value': 5.0,
        'is_active': 1,
      },
    ],
    'audit_logs': [],
    'shifts': [],
    'z_reports': [],
  };

  PosRepository();

  Future<void> init() async {
    if (kIsWeb) {
      await _loadWebData();
      if (_webStorage['categories']!.isEmpty) {
        await _seedWebData();
      }
    }
  }

  Future<void> _seedWebData() async {
    // Categories
    _webStorage['categories'] = [
      {'id': 1, 'name': 'Coffee', 'name_amharic': 'ቡና'},
      {'id': 2, 'name': 'Tea', 'name_amharic': 'ሻይ'},
      {'id': 3, 'name': 'Pastries', 'name_amharic': 'መክሰስ'},
      {'id': 4, 'name': 'Soft Drinks', 'name_amharic': 'ለስላሳ'},
    ];

    // Stations
    _webStorage['serving_stations'] = [
      {'id': 1, 'name': 'Kitchen', 'name_amharic': 'ወጥ ቤት'},
      {'id': 2, 'name': 'Bar', 'name_amharic': 'ባር'},
    ];

    // Products
    _webStorage['products'] = [
      {'id': 1, 'category_id': 1, 'name': 'Macchiato', 'name_amharic': 'ማኪያቶ', 'price': 35.0, 'station_id': 1},
      {'id': 2, 'category_id': 1, 'name': 'Black Coffee', 'name_amharic': 'ጥቁር ቡና', 'price': 25.0, 'station_id': 1},
      {'id': 3, 'category_id': 2, 'name': 'Black Tea', 'name_amharic': 'ጥቁር ሻይ', 'price': 15.0, 'station_id': 1},
      {'id': 4, 'category_id': 3, 'name': 'Croissant', 'name_amharic': 'ክሮይሰንት', 'price': 55.0, 'station_id': 1},
      {'id': 5, 'category_id': 4, 'name': 'Coca Cola', 'name_amharic': 'ኮካ ኮላ', 'price': 30.0, 'station_id': 2},
    ];

    // Tables
    _webStorage['tables'] = List.generate(
      10,
      (i) => {
        'id': i + 1,
        'name': 'Table ${i + 1}',
        'status': 'available',
        'zone_id': null,
      },
    );

    // Waiters
    _webStorage['waiters'] = [
      {'id': 1, 'name': 'Default Waiter', 'name_amharic': 'መደበኛ አስተናጋጅ', 'code': 'W001'},
      {'id': 2, 'name': 'Abebe', 'name_amharic': 'አበበ', 'code': 'W002'},
      {'id': 3, 'name': 'Kebe', 'name_amharic': 'ከበደ', 'code': 'W003'},
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
        // Ensure all required keys exist
        final requiredKeys = [
          'categories',
          'products',
          'tables',
          'table_zones',
          'orders',
          'order_items',
          'waiters',
          'users',
          'app_settings',
          'pos_charges',
          'audit_logs',
          'shifts',
          'z_reports',
        ];
        for (final key in requiredKeys) {
          _webStorage.putIfAbsent(key, () => []);
        }

        // Seed charges if empty
        if (_webStorage['pos_charges']!.isEmpty) {
          _webStorage['pos_charges'] = [
            {
              'id': 1,
              'name': 'VAT',
              'type': 'addition',
              'value': 0.0,
              'is_active': 1,
            },
            {
              'id': 2,
              'name': 'Service Charge',
              'type': 'addition',
              'value': 5.0,
              'is_active': 1,
            },
          ];
        }
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

  // ── Audit Logs ────────────────────────────────────────────────────────────

  Future<void> addAuditLog(
    int? userId,
    String action, {
    String? details,
  }) async {
    final map = {
      'user_id': userId,
      'action': action,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (kIsWeb) {
      _webStorage.putIfAbsent('audit_logs', () => []);
      final id =
          (_webStorage['audit_logs']!.isEmpty
              ? 0
              : _webStorage['audit_logs']!
                    .map((l) => l['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final webMap = Map<String, dynamic>.from(map);
      webMap['id'] = id;
      _webStorage['audit_logs']!.add(webMap);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.insert('audit_logs', map);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(
        _webStorage['audit_logs'] ?? [],
      ).reversed.toList();
    }
    final db = await _dbHelper.database;
    return await db.query('audit_logs', orderBy: 'created_at DESC', limit: 100);
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

  Future<int> addTableZone(String name, {int? waiterId, String? nameAmharic}) async {
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
        'name_amharic': nameAmharic,
        'waiter_id': waiterId,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('table_zones', {
      'name': name,
      'name_amharic': nameAmharic,
      'waiter_id': waiterId,
    });
  }

  Future<void> updateTableZone(int id, String name,
      {int? waiterId, String? nameAmharic}) async {
    if (kIsWeb) {
      final index = _webStorage['table_zones']!.indexWhere(
        (z) => z['id'] == id,
      );
      if (index != -1) {
        _webStorage['table_zones']![index] = {
          'id': id,
          'name': name,
          'name_amharic': nameAmharic,
          'waiter_id': waiterId,
        };
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'table_zones',
      {
        'name': name,
        'name_amharic': nameAmharic,
        'waiter_id': waiterId,
      },
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
      var list = List<Map<String, dynamic>>.from(_webStorage['tables']!);
      if (zoneId != null) {
        list = list.where((t) => t['zone_id'] == zoneId).toList();
      }
      // Populate zone_name for Web
      final zones = _webStorage['table_zones']!;
      final result = list.map((t) {
        final tableMap = Map<String, dynamic>.from(t);
        if (tableMap['zone_id'] != null) {
          final zoneMatch = zones.where((z) => z['id'] == tableMap['zone_id']);
          if (zoneMatch.isNotEmpty) {
            tableMap['zone_name'] = zoneMatch.first['name'];
          }
        }
        return TableModel.fromMap(tableMap);
      }).toList();
      return result;
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

  Future<int> addTable(String name, {int? zoneId, String? nameAmharic}) async {
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
        'name_amharic': nameAmharic,
        'status': 'available',
        'zone_id': zoneId,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('tables', {
      'name': name,
      'name_amharic': nameAmharic,
      'status': 'available',
      'zone_id': zoneId,
    });
  }

  Future<void> updateTable(int id, String name, {int? zoneId, String? nameAmharic}) async {
    if (kIsWeb) {
      final idx = _webStorage['tables']!.indexWhere((t) => t['id'] == id);
      if (idx != -1) {
        _webStorage['tables']![idx]['name'] = name;
        _webStorage['tables']![idx]['name_amharic'] = nameAmharic;
        _webStorage['tables']![idx]['zone_id'] = zoneId;
        await _saveWebData();
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'tables',
      {'name': name, 'name_amharic': nameAmharic, 'zone_id': zoneId},
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

  Future<int> addCategory(String name, {String? nameAmharic}) async {
    if (kIsWeb) {
      final id =
          (_webStorage['categories']!.isEmpty
              ? 0
              : _webStorage['categories']!
                    .map((c) => c['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      _webStorage['categories']!.add({
        'id': id,
        'name': name,
        'name_amharic': nameAmharic,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('categories', {
      'name': name,
      'name_amharic': nameAmharic,
    });
  }

  Future<void> updateCategory(Category category) async {
    if (kIsWeb) {
      final idx = _webStorage['categories']!.indexWhere((e) => e['id'] == category.id);
      if (idx != -1) {
        _webStorage['categories']![idx] = category.toMap();
        await _saveWebData();
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
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

  // ── Stations ──────────────────────────────────────────────────────────────

  Future<List<Station>> getStations() async {
    if (kIsWeb) {
      return _webStorage['serving_stations']!
          .map((s) => Station.fromMap(s))
          .toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query('serving_stations');
    return maps.map((m) => Station.fromMap(m)).toList();
  }

  Future<int> addStation(String name, {String? nameAmharic, String? printerName}) async {
    if (kIsWeb) {
      final id = (_webStorage['serving_stations']!.isEmpty
              ? 0
              : _webStorage['serving_stations']!
                  .map((s) => s['id'] as int)
                  .reduce((a, b) => a > b ? a : b)) + 1;
      _webStorage['serving_stations']!.add({
        'id': id,
        'name': name,
        'name_amharic': nameAmharic,
        'printer_name': printerName,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('serving_stations', {
      'name': name,
      'name_amharic': nameAmharic,
      'printer_name': printerName,
    });
  }

  Future<void> updateStation(Station station) async {
    if (kIsWeb) {
      final idx = _webStorage['serving_stations']!
          .indexWhere((e) => e['id'] == station.id);
      if (idx != -1) {
        _webStorage['serving_stations']![idx] = station.toMap();
        await _saveWebData();
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'serving_stations',
      station.toMap(),
      where: 'id = ?',
      whereArgs: [station.id],
    );
  }

  Future<void> deleteStation(int id) async {
    if (kIsWeb) {
      _webStorage['serving_stations']!.removeWhere((e) => e['id'] == id);
      for (var p in _webStorage['products']!) {
        if (p['station_id'] == id) p['station_id'] = null;
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('serving_stations', where: 'id = ?', whereArgs: [id]);
    await db.update('products', {'station_id': null},
        where: 'station_id = ?', whereArgs: [id]);
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({int? categoryId}) async {
    if (kIsWeb) {
      final list = _webStorage['products']!;
      final filtered = categoryId != null
          ? list.where((e) {
              if (e['category_id'] == categoryId) return true;
              if (e['category_ids'] != null) {
                final ids = e['category_ids'].toString().split(',').map((x) => x.trim());
                if (ids.contains(categoryId.toString())) return true;
              }
              return false;
            }).toList()
          : list;
      return filtered.map((p) => Product.fromMap(p)).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: categoryId != null 
          ? "category_id = ? OR category_ids = ? OR category_ids LIKE ? OR category_ids LIKE ? OR category_ids LIKE ?" 
          : null,
      whereArgs: categoryId != null 
          ? [categoryId, '$categoryId', '$categoryId,%', '%,$categoryId', '%,$categoryId,%'] 
          : null,
    );

    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> addProduct(Product product) async {
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

  Future<void> clearAllMenuData() async {
    if (kIsWeb) {
      _webStorage['products'] = [];
      _webStorage['categories'] = [];
      await _saveWebData();
    } else {
      final db = await _dbHelper.database;
      await db.delete('products');
      await db.delete('categories');
    }
  }

  // ── Waiters ───────────────────────────────────────────────────────────────

  Future<List<Waiter>> getWaiters() async {
    if (kIsWeb)
      return _webStorage['waiters']!.map((w) => Waiter.fromMap(w)).toList();
    final db = await _dbHelper.database;
    final maps = await db.query('waiters');
    return maps.map((m) => Waiter.fromMap(m)).toList();
  }

  Future<int> addWaiter(String name, {String? nameAmharic}) async {
    if (kIsWeb) {
      final id =
          (_webStorage['waiters']!.isEmpty
              ? 0
              : _webStorage['waiters']!
                    .map((w) => w['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final code = 'W${id.toString().padLeft(3, '0')}';
      _webStorage['waiters']!.add({
        'id': id,
        'name': name,
        'name_amharic': nameAmharic,
        'code': code,
      });
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    final res = await db.query('waiters', orderBy: 'id DESC', limit: 1);
    int nextId = 1;
    if (res.isNotEmpty) {
      nextId = (res.first['id'] as int) + 1;
    }
    final code = 'W${nextId.toString().padLeft(3, '0')}';

    return await db.insert('waiters', {
      'name': name,
      'name_amharic': nameAmharic,
      'code': code,
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
      final enrichedMap = Map<String, dynamic>.from(orderMap);
      if (enrichedMap['table_name'] == null) {
        final table = _webStorage['tables']!.firstWhere(
          (t) => t['id'] == enrichedMap['table_id'],
          orElse: () => {},
        );
        enrichedMap['table_name'] = table['name'] ?? 'Unknown';
        enrichedMap['table_name_amharic'] = table['name_amharic'];
      }
      if (enrichedMap['waiter_name'] == null) {
        final waiter = _webStorage['waiters']!.firstWhere(
          (w) => w['id'] == enrichedMap['waiter_id'],
          orElse: () => {},
        );
        enrichedMap['waiter_name'] = waiter['name'] ?? 'Unknown';
        enrichedMap['waiter_name_amharic'] = waiter['name_amharic'];
      }
      if (enrichedMap['cashier_name'] == null) {
        final cashier = _webStorage['users']!.firstWhere(
          (u) => u['id'] == enrichedMap['cashier_id'],
          orElse: () => {},
        );
        enrichedMap['cashier_name'] = cashier['username'] ?? '';
      }
      return OrderModel.fromMap(enrichedMap, items: items);
    }
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      'SELECT o.*, t.name as table_name, t.name_amharic as table_name_amharic, w.name as waiter_name, w.name_amharic as waiter_name_amharic, u.username as cashier_name FROM orders o JOIN tables t ON o.table_id = t.id JOIN waiters w ON o.waiter_id = w.id LEFT JOIN users u ON o.cashier_id = u.id WHERE o.table_id = ? AND o.status = \'pending\' LIMIT 1',
      [tableId],
    );
    if (maps.isEmpty) return null;
    final orderId = maps.first['id'];
    final itemMaps = await db.rawQuery(
      'SELECT oi.*, p.name as product_name, p.name_amharic as product_name_amharic, c.name as category_name, c.name_amharic as category_name_amharic FROM order_items oi JOIN products p ON oi.product_id = p.id JOIN categories c ON p.category_id = c.id WHERE oi.order_id = ?',
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
        final itemMap = item
            .copyWith(orderId: orderId, kitchenRound: nextRound)
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
    int? cashierId,
    double serviceCharge = 0,
    double discountAmount = 0,
    String paymentMethod = 'cash',
    String? customerTin,
  }) async {
    if (kIsWeb) {
      final oIndex = _webStorage['orders']!.indexWhere(
        (o) => o['id'] == orderId,
      );
      if (oIndex != -1) {
        _webStorage['orders']![oIndex]['status'] = 'completed';
        _webStorage['orders']![oIndex]['service_charge'] = serviceCharge;
        _webStorage['orders']![oIndex]['discount_amount'] = discountAmount;
        _webStorage['orders']![oIndex]['payment_method'] = paymentMethod;
        _webStorage['orders']![oIndex]['customer_tin'] = customerTin;
        if (cashierId != null) {
          _webStorage['orders']![oIndex]['cashier_id'] = cashierId;
          final user = _webStorage['users']!.firstWhere(
            (u) => u['id'] == cashierId,
            orElse: () => {},
          );
          _webStorage['orders']![oIndex]['cashier_name'] =
              user['username'] ?? '';
        }
      }
      await updateTableStatus(tableId, TableStatus.available);
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final Map<String, dynamic> updateData = {
        'status': 'completed',
        'service_charge': serviceCharge,
        'discount_amount': discountAmount,
        'payment_method': paymentMethod,
        'customer_tin': customerTin,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (cashierId != null) updateData['cashier_id'] = cashierId;
      await txn.update(
        'orders',
        updateData,
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
            .where(
              (o) =>
                  o['created_at'] != null &&
                  DateTime.parse(o['created_at']).isAfter(from),
            )
            .toList();
      if (to != null)
        list = list
            .where(
              (o) =>
                  o['created_at'] != null &&
                  DateTime.parse(o['created_at']).isBefore(to),
            )
            .toList();
      return list.map((o) {
        final items = _webStorage['order_items']!
            .where((i) => i['order_id'] == o['id'])
            .map((i) => OrderItem.fromMap(i))
            .toList();

        final enrichedMap = Map<String, dynamic>.from(o);
        if (enrichedMap['table_name'] == null) {
          final table = _webStorage['tables']!.firstWhere(
            (t) => t['id'] == enrichedMap['table_id'],
            orElse: () => {},
          );
          enrichedMap['table_name'] = table['name'] ?? 'Unknown';
        }
        if (enrichedMap['waiter_name'] == null) {
          final waiter = _webStorage['waiters']!.firstWhere(
            (w) => w['id'] == enrichedMap['waiter_id'],
            orElse: () => {},
          );
          enrichedMap['waiter_name'] = waiter['name'] ?? 'Unknown';
        }
        if (enrichedMap['cashier_name'] == null) {
          final cashier = _webStorage['users']!.firstWhere(
            (u) => u['id'] == enrichedMap['cashier_id'],
            orElse: () => {},
          );
          enrichedMap['cashier_name'] = cashier['username'] ?? '';
        }

        return OrderModel.fromMap(enrichedMap, items: items);
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
      'SELECT o.*, t.name as table_name, t.name_amharic as table_name_amharic, w.name as waiter_name, w.name_amharic as waiter_name_amharic, u.username as cashier_name FROM orders o JOIN tables t ON o.table_id = t.id JOIN waiters w ON o.waiter_id = w.id LEFT JOIN users u ON o.cashier_id = u.id $whereClause ORDER BY o.created_at DESC',
      args,
    );
    List<OrderModel> orders = [];
    for (var map in maps) {
      final itemMaps = await db.rawQuery(
        'SELECT oi.*, p.name as product_name, p.name_amharic as product_name_amharic, c.name as category_name, c.name_amharic as category_name_amharic FROM order_items oi JOIN products p ON oi.product_id = p.id JOIN categories c ON p.category_id = c.id WHERE oi.order_id = ?',
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
    final settings = await getSettings();
    if (settings.containsKey('cafe_name')) {
      return CafeSettings(
        name: settings['cafe_name'] ?? 'LDA CAFE',
        address: settings['cafe_address'] ?? '',
        phone: settings['cafe_phone'] ?? '',
        vatNumber: settings['cafe_vat_number'] ?? '',
        vatRate: double.tryParse(settings['cafe_vat_rate'] ?? '5.0') ?? 5.0,
        currency: settings['cafe_currency'] ?? 'ETB',
      );
    }

    // Fallback to legacy shared prefs for migration
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cafe_settings');
    if (data != null) {
      final s = CafeSettings.fromMap(jsonDecode(data));
      await saveSettings(s); // Migrate to DB
      return s;
    }
    return CafeSettings();
  }

  Future<void> saveSettings(CafeSettings settings) async {
    await setSetting('cafe_name', settings.name, 0);
    await setSetting('cafe_address', settings.address, 0);
    await setSetting('cafe_phone', settings.phone, 0);
    await setSetting('cafe_vat_number', settings.vatNumber, 0);
    await setSetting('cafe_vat_rate', settings.vatRate.toString(), 0);
    await setSetting('cafe_currency', settings.currency, 0);
  }

  // --- Dynamic Charges ---
  Future<List<Map<String, dynamic>>> getCharges() async {
    if (kIsWeb) return _webStorage['pos_charges'] ?? [];
    final db = await _dbHelper.database;
    return await db.query('pos_charges');
  }

  Future<int> addCharge(Map<String, dynamic> charge) async {
    if (kIsWeb) {
      _webStorage.putIfAbsent('pos_charges', () => []);
      final id = _webStorage['pos_charges']!.length + 1;
      final newCharge = {...charge, 'id': id};
      _webStorage['pos_charges']!.add(newCharge);
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('pos_charges', charge);
  }

  Future<int> updateCharge(int id, Map<String, dynamic> charge) async {
    if (kIsWeb) {
      _webStorage.putIfAbsent('pos_charges', () => []);
      final index = _webStorage['pos_charges']!.indexWhere(
        (c) => c['id'] == id,
      );
      if (index != -1) {
        _webStorage['pos_charges']![index] = {...charge, 'id': id};
        await _saveWebData();
        return 1;
      }
      return 0;
    }
    final db = await _dbHelper.database;
    return await db.update(
      'pos_charges',
      charge,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCharge(int id) async {
    if (kIsWeb) {
      _webStorage.putIfAbsent('pos_charges', () => []);
      _webStorage['pos_charges']!.removeWhere((c) => c['id'] == id);
      await _saveWebData();
      return 1;
    }
    final db = await _dbHelper.database;
    return await db.delete('pos_charges', where: 'id = ?', whereArgs: [id]);
  }

  // ── Shift Management ──────────────────────────────────────────────────────

  Future<int> startShift(int cashierId, double startingCash) async {
    final shift = ShiftModel(
      cashierId: cashierId,
      startTime: DateTime.now(),
      startingCash: startingCash,
    );

    if (kIsWeb) {
      final id =
          (_webStorage['shifts']!.isEmpty
              ? 0
              : _webStorage['shifts']!
                    .map((s) => s['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final map = shift.toMap();
      map['id'] = id;
      _webStorage['shifts']!.add(map);
      await _saveWebData();
      return id;
    }
    final db = await _dbHelper.database;
    return await db.insert('shifts', shift.toMap());
  }

  Future<ShiftModel?> getActiveShift(int cashierId) async {
    if (kIsWeb) {
      final map = _webStorage['shifts']!.firstWhere(
        (s) => s['cashier_id'] == cashierId && s['status'] == 'open',
        orElse: () => {},
      );
      if (map.isEmpty) return null;
      final user = _webStorage['users']!.firstWhere(
        (u) => u['id'] == map['cashier_id'],
        orElse: () => {},
      );
      final enriched = Map<String, dynamic>.from(map);
      enriched['cashier_name'] = user['username'] ?? '';
      return ShiftModel.fromMap(enriched);
    }
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT s.*, u.username as cashier_name 
      FROM shifts s 
      JOIN users u ON s.cashier_id = u.id 
      WHERE s.cashier_id = ? AND s.status = 'open' 
      LIMIT 1
    ''',
      [cashierId],
    );
    if (maps.isEmpty) return null;
    return ShiftModel.fromMap(maps.first);
  }

  Future<void> endShift(int shiftId, double actualCash) async {
    final now = DateTime.now();
    if (kIsWeb) {
      final index = _webStorage['shifts']!.indexWhere(
        (s) => s['id'] == shiftId,
      );
      if (index != -1) {
        _webStorage['shifts']![index]['end_time'] = now.toIso8601String();
        _webStorage['shifts']![index]['actual_cash_declared'] = actualCash;
        _webStorage['shifts']![index]['status'] = 'closed';
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'shifts',
      {
        'end_time': now.toIso8601String(),
        'actual_cash_declared': actualCash,
        'status': 'closed',
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  // ── Reporting Logic ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getShiftReportData(int shiftId) async {
    // 1. Fetch Shift
    ShiftModel? shift;
    if (kIsWeb) {
      final map = _webStorage['shifts']!.firstWhere(
        (s) => s['id'] == shiftId,
        orElse: () => {},
      );
      if (map.isNotEmpty) {
        final user = _webStorage['users']!.firstWhere(
          (u) => u['id'] == map['cashier_id'],
          orElse: () => {},
        );
        final enriched = Map<String, dynamic>.from(map);
        enriched['cashier_name'] = user['username'] ?? '';
        shift = ShiftModel.fromMap(enriched);
      }
    } else {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery(
        '''
        SELECT s.*, u.username as cashier_name 
        FROM shifts s 
        JOIN users u ON s.cashier_id = u.id 
        WHERE s.id = ? 
        LIMIT 1
      ''',
        [shiftId],
      );
      if (maps.isNotEmpty) shift = ShiftModel.fromMap(maps.first);
    }

    // 2. Fetch Open Tables
    int openTables = 0;
    if (kIsWeb) {
      openTables = _webStorage['tables']!
          .where((t) => t['status'] == 'occupied')
          .length;
    } else {
      final db = await _dbHelper.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as c FROM tables WHERE status = 'occupied'",
      );
      openTables = res.first['c'] as int;
    }

    // 3. Fetch Audit Logs for the shift
    List<Map<String, dynamic>> shiftAuditLogs = [];
    if (shift != null) {
      final startTime = shift.startTime;
      final endTime = shift.endTime ?? DateTime.now();
      if (kIsWeb) {
        shiftAuditLogs = (_webStorage['audit_logs'] ?? []).where((l) {
          final time = DateTime.parse(l['created_at']);
          return time.isAfter(startTime) && time.isBefore(endTime);
        }).toList();
      } else {
        final db = await _dbHelper.database;
        shiftAuditLogs = await db.rawQuery(
          'SELECT * FROM audit_logs WHERE created_at BETWEEN ? AND ?',
          [startTime.toIso8601String(), endTime.toIso8601String()],
        );
      }
    }

    final orders = await getOrdersByShift(shiftId);
    final completed = orders
        .where((o) => o.status == OrderStatus.completed)
        .toList();
    final cancelled = orders
        .where((o) => o.status == OrderStatus.cancelled)
        .toList();

    double totalGrossSales = 0;
    double totalServiceCharge = 0;
    double totalDiscount = 0;

    final paymentMethodBreakdown = <String, double>{};
    final waiterStats = <String, Map<String, dynamic>>{};
    final itemSales = <String, Map<String, dynamic>>{};
    final categoryBreakdown = <String, double>{};
    final orderTypeBreakdown = <String, double>{
      'Dine-in': 0,
      'Takeaway': 0,
      'Delivery': 0,
    };
    final hourlySales = <int, int>{}; // hour -> count

    final settings = await getCafeSettings();

    for (final o in completed) {
      totalGrossSales += o.totalAmount;
      totalServiceCharge += o.serviceCharge;
      totalDiscount += o.discountAmount;

      paymentMethodBreakdown[o.paymentMethod] =
          (paymentMethodBreakdown[o.paymentMethod] ?? 0) + o.grandTotal;

      // Order Type (heuristic based on table name)
      final tName = o.tableName.toLowerCase();
      if (tName.contains('takeaway')) {
        orderTypeBreakdown['Takeaway'] =
            orderTypeBreakdown['Takeaway']! + o.grandTotal;
      } else if (tName.contains('delivery')) {
        orderTypeBreakdown['Delivery'] =
            orderTypeBreakdown['Delivery']! + o.grandTotal;
      } else {
        orderTypeBreakdown['Dine-in'] =
            orderTypeBreakdown['Dine-in']! + o.grandTotal;
      }

      // Time Analytics
      final hour = o.createdAt.hour;
      hourlySales[hour] = (hourlySales[hour] ?? 0) + 1;

      // Waiter performance
      if (!waiterStats.containsKey(o.waiterName)) {
        waiterStats[o.waiterName] = {'orders': 0, 'sales': 0.0};
      }
      waiterStats[o.waiterName]!['orders']++;
      waiterStats[o.waiterName]!['sales'] += o.grandTotal;

      // Item Sales
      for (final item in o.items) {
        if (!itemSales.containsKey(item.productName)) {
          itemSales[item.productName] = {'qty': 0, 'revenue': 0.0};
        }
        itemSales[item.productName]!['qty'] += item.quantity;
        itemSales[item.productName]!['revenue'] += item.subtotal;

        final product = await getProductById(item.productId);
        if (product != null) {
          final int catId = product.categoryId;
          final catName = await getCategoryName(catId);
          categoryBreakdown[catName] =
              (categoryBreakdown[catName] ?? 0) + item.subtotal;
        }
      }
    }

    // Force VAT to 0% as per user request
    const double vatRate = 0.0;
    final totalNetSales = totalGrossSales + totalServiceCharge - totalDiscount;
    final totalVat = 0.0;

    int peakHour = 0;
    int maxOrders = 0;
    hourlySales.forEach((hour, count) {
      if (count > maxOrders) {
        maxOrders = count;
        peakHour = hour;
      }
    });

    final expectedCash =
        (shift?.startingCash ?? 0) + (paymentMethodBreakdown['cash'] ?? 0);
    final actualCash = shift?.actualCashDeclared ?? 0;

    // Find voids in audit logs
    int voidCount = cancelled.length;
    final voidLogs = shiftAuditLogs
        .where((l) => l['action'].toString().toLowerCase().contains('void'))
        .toList();
    voidCount += voidLogs.length;

    return {
      'report_header': {
        'restaurant_name': settings.name,
        'branch': 'Main Branch',
        'address': settings.address,
        'report_type': shiftId == -1 ? 'GENERIC REPORT' : 'Z REPORT',
        'shift_number': shiftId == -1 ? 'N/A' : shiftId,
        'cashier_name': shift?.cashierName ?? 'Admin',
        'opening_time': shift?.startTime.toIso8601String(),
        'closing_time':
            shift?.endTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'generated_timestamp': DateTime.now().toIso8601String(),
      },
      'shift_summary': {
        'total_orders': orders.length,
        'completed_orders': completed.length,
        'canceled_orders': cancelled.length,
        'refund_count': voidLogs.length,
        'open_tables_remaining': openTables,
        'closed_tables': completed.length,
      },
      'sales_totals': {
        'gross_sales': totalGrossSales,
        'discounts': totalDiscount,
        'service_charge': totalServiceCharge,
        'vat': totalVat,
        'vat_rate': vatRate,
        'net_sales': totalNetSales,
        'grand_total': totalNetSales,
        'refunds': 0,
        'void_totals': cancelled.fold<double>(
          0.0,
          (sum, o) => sum + o.grandTotal,
        ),
      },
      'payment_methods': paymentMethodBreakdown,
      'cash_reconciliation': {
        'opening_float': shift?.startingCash ?? 0,
        'expected_cash': expectedCash,
        'actual_counted': actualCash,
        'difference': actualCash - expectedCash,
      },
      'waiters': waiterStats,
      'items': itemSales,
      'categories': categoryBreakdown,
      'cancellations': {
        'total_canceled_items': voidCount,
        'details': cancelled
            .map(
              (o) => {
                'canceled_item': 'Order #${o.id}',
                'by': o.cashierName,
                'reason': 'Order Cancelled',
                'approval_manager': 'Manager',
              },
            )
            .toList(),
      },
      'discounts_summary': {'total': totalDiscount},
      'tax_information': {
        'vat_totals': totalVat,
        'taxable_sales': totalNetSales,
        'exempt_sales': totalNetSales,
      },
      'orders_detail': completed
          .map(
            (o) => {
              'id': o.id,
              'table_name': o.tableName,
              'waiter_name': o.waiterName,
              'waiter_id': o.waiterId,
              'cashier_name': o.cashierName,
              'created_at': o.createdAt.toIso8601String(),
              'total_amount': o.totalAmount,
              'service_charge': o.serviceCharge,
              'discount_amount': o.discountAmount,
              'grand_total': o.grandTotal,
              'items': o.items
                  .map(
                    (i) => {
                      'product_name': i.productName,
                      'quantity': i.quantity,
                      'unit_price': i.unitPrice,
                      'subtotal': i.subtotal,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'order_type_breakdown': orderTypeBreakdown,
      'time_analytics': {
        'peak_hour':
            "${peakHour.toString().padLeft(2, '0')}:00 - ${(peakHour + 1).toString().padLeft(2, '0')}:00",
        'average_order_value': completed.isNotEmpty
            ? totalNetSales / completed.length
            : 0,
      },
      'audit_log_summary': shiftAuditLogs
          .map(
            (l) => {
              'action': l['action'],
              'details': l['details'],
              'time': l['created_at'],
            },
          )
          .toList(),
    };
  }

  Future<List<OrderModel>> getOrdersByShift(int shiftId) async {
    if (kIsWeb) {
      final list = _webStorage['orders']!
          .where((o) => o['shift_id'] == shiftId)
          .toList();
      return list.map((o) {
        final items = _webStorage['order_items']!
            .where((i) => i['order_id'] == o['id'])
            .map((i) {
          final product = _webStorage['products']!.firstWhere(
            (p) => p['id'] == i['product_id'],
            orElse: () => {},
          );
          final catId = product['category_id'] ??
              (product['category_ids'] != null
                  ? int.tryParse(product['category_ids'].toString())
                  : null);
          final category = _webStorage['categories']!.firstWhere(
            (c) => c['id'] == catId,
            orElse: () => {},
          );
          return OrderItem.fromMap({
            ...i,
            'product_name': product['name'] ?? '',
            'product_name_amharic': product['name_amharic'],
            'category_name': category['name'] ?? 'General',
            'category_name_amharic': category['name_amharic'],
          });
        }).toList();
        return OrderModel.fromMap(o, items: items);
      }).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      'SELECT o.*, t.name as table_name, t.name_amharic as table_name_amharic, w.name as waiter_name, w.name_amharic as waiter_name_amharic, u.username as cashier_name FROM orders o JOIN tables t ON o.table_id = t.id JOIN waiters w ON o.waiter_id = w.id LEFT JOIN users u ON o.cashier_id = u.id WHERE o.shift_id = ? ORDER BY o.created_at DESC',
      [shiftId],
    );
    List<OrderModel> orders = [];
    for (var map in maps) {
      final itemMaps = await db.rawQuery(
        'SELECT oi.*, p.name as product_name, p.name_amharic as product_name_amharic, c.name as category_name, c.name_amharic as category_name_amharic FROM order_items oi JOIN products p ON oi.product_id = p.id JOIN categories c ON p.category_id = c.id WHERE oi.order_id = ?',
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

  Future<Product?> getProductById(int id) async {
    if (kIsWeb) {
      final map = _webStorage['products']!.firstWhere(
        (p) => p['id'] == id,
        orElse: () => {},
      );
      return map.isEmpty ? null : Product.fromMap(map);
    }
    final db = await _dbHelper.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Product.fromMap(maps.first);
  }

  Future<String> getCategoryName(int id) async {
    if (kIsWeb) {
      final map = _webStorage['categories']!.firstWhere(
        (c) => c['id'] == id,
        orElse: () => {},
      );
      return map['name'] ?? 'Uncategorized';
    }
    final db = await _dbHelper.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? 'Uncategorized' : maps.first['name'] as String;
  }

  Future<void> createZReport(
    int shiftId,
    Map<String, dynamic> reportData,
  ) async {
    final db = await _dbHelper.database;
    final zCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM z_reports',
    );
    final zCount = (zCountResult.first['count'] as int) + 1;

    final report = ZReportModel(
      shiftId: shiftId,
      zCount: zCount,
      reportData: reportData,
      createdAt: DateTime.now(),
    );

    if (kIsWeb) {
      final id =
          (_webStorage['z_reports']!.isEmpty
              ? 0
              : _webStorage['z_reports']!
                    .map((r) => r['id'] as int)
                    .reduce((a, b) => a > b ? a : b)) +
          1;
      final map = report.toMap();
      map['id'] = id;
      _webStorage['z_reports']!.add(map);
      await _saveWebData();
      return;
    }
    await db.insert('z_reports', report.toMap());
  }

  Future<List<ZReportModel>> getZReports() async {
    if (kIsWeb)
      return _webStorage['z_reports']!
          .map((r) => ZReportModel.fromMap(r))
          .toList()
          .reversed
          .toList();
    final db = await _dbHelper.database;
    final maps = await db.query('z_reports', orderBy: 'created_at DESC');
    return maps.map((m) => ZReportModel.fromMap(m)).toList();
  }

  // ── Mock Data Seeding ─────────────────────────────────────────────────────

  Future<void> seedMockData() async {
    if (kIsWeb) return; // Seeding is designed for SQLite local files
    
    final db = await _dbHelper.database;
    final random = Random();
    
    // 1. Get existing entities
    final products = await getProducts();
    final waiters = await getWaiters();
    final users = await getUsers();
    
    if (products.isEmpty || waiters.isEmpty || users.isEmpty) {
      print('Seeding skipped: Products, Waiters, or Users missing.');
      return;
    }
    
    final cashier = users.firstWhere((u) => u.role == UserRole.cashier, orElse: () => users.first);
    final waiter = waiters.first;

    for (int i = 7; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final startTime = DateTime(date.year, date.month, date.day, 8 + random.nextInt(2), random.nextInt(60));
      final endTime = startTime.add(const Duration(hours: 10)); 
      
      final isCurrentDay = i == 0;

      // 2. Insert Shift
      final shiftId = await db.insert('shifts', {
        'cashier_id': cashier.id,
        'start_time': startTime.toIso8601String(),
        'starting_cash': 1000.0,
        'status': isCurrentDay ? 'open' : 'closed',
        'end_time': isCurrentDay ? null : endTime.toIso8601String(),
        'actual_cash_declared': isCurrentDay ? null : 0.0, 
      });

      double shiftTotal = 0;
      
      // 3. Create 15-25 orders per shift
      int orderCount = 15 + random.nextInt(10);
      for (int j = 0; j < orderCount; j++) {
        final orderTime = startTime.add(Duration(minutes: random.nextInt(600)));
        
        final orderId = await db.insert('orders', {
          'table_id': 1 + random.nextInt(10),
          'waiter_id': waiter.id,
          'cashier_id': cashier.id,
          'status': 'completed',
          'created_at': orderTime.toIso8601String(),
          'updated_at': orderTime.toIso8601String(),
          'total_amount': 0.0, 
          'service_charge': 5.0,
          'discount_amount': random.nextDouble() > 0.8 ? 20.0 : 0.0,
          'payment_method': random.nextDouble() > 0.3 ? 'cash' : 'telebirr',
          'shift_id': shiftId,
        });

        double orderSubtotal = 0;
        int itemCount = 1 + random.nextInt(5);
        for (int k = 0; k < itemCount; k++) {
          final product = products[random.nextInt(products.length)];
          final qty = 1 + random.nextInt(3);
          final subtotal = product.price * qty;
          
          await db.insert('order_items', {
            'order_id': orderId,
            'product_id': product.id,
            'quantity': qty,
            'unit_price': product.price,
            'subtotal': subtotal,
            'is_printed_to_kitchen': 1,
            'kitchen_round': 1,
            'created_at': orderTime.toIso8601String(),
          });
          orderSubtotal += subtotal;
        }
        
        await db.update(
          'orders', 
          {'total_amount': orderSubtotal}, 
          where: 'id = ?', 
          whereArgs: [orderId]
        );
        shiftTotal += (orderSubtotal + 5.0 - (random.nextDouble() > 0.8 ? 20.0 : 0.0));
      }
      
      // 4. Finalize Shift and Create Z-Report
      if (!isCurrentDay) {
        final actualCash = 1000.0 + shiftTotal;
        await db.update(
          'shifts', 
          {'actual_cash_declared': actualCash}, 
          where: 'id = ?', 
          whereArgs: [shiftId]
        );
        
        final reportData = await getShiftReportData(shiftId);
        await createZReport(shiftId, reportData);
      }
    }
  }

  Future<void> clearOrderHistory() async {
    if (kIsWeb) {
      _webStorage['orders'] = [];
      _webStorage['order_items'] = [];
      _webStorage['shifts'] = [];
      _webStorage['z_reports'] = [];
      _webStorage['audit_logs'] = [];
      for (var t in _webStorage['tables']!) {
        t['status'] = 'available';
      }
      await _saveWebData();
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('orders');
      await txn.delete('order_items');
      await txn.delete('shifts');
      await txn.delete('z_reports');
      await txn.delete('audit_logs');
      await txn.update('tables', {'status': 'available'});
    });
  }
}
