import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Database> _initDatabase() async {
    DatabaseFactory databaseFactory;
    String dbPath;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      dbPath = 'st_george_pos_web.db';
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      dbPath = join(appDocumentsDir.path, 'st_george_pos.db');
    }

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'cashier',
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_by INTEGER,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS table_zones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          waiter_id INTEGER,
          FOREIGN KEY (waiter_id) REFERENCES waiters (id)
        )
      ''');
      await db.execute('ALTER TABLE tables ADD COLUMN zone_id INTEGER REFERENCES table_zones(id)');
      await _seedUsers(db);
      await _seedSettings(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE orders ADD COLUMN cashier_id INTEGER REFERENCES users(id)');
      await db.execute('ALTER TABLE orders ADD COLUMN service_charge REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE orders ADD COLUMN discount_amount REAL DEFAULT 0.0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE order_items ADD COLUMN kitchen_round INTEGER DEFAULT 0');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE waiters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE table_zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        waiter_id INTEGER,
        FOREIGN KEY (waiter_id) REFERENCES waiters (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        status TEXT DEFAULT 'available',
        zone_id INTEGER,
        FOREIGN KEY (zone_id) REFERENCES table_zones (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER,
        waiter_id INTEGER,
        cashier_id INTEGER,
        status TEXT DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        total_amount REAL DEFAULT 0.0,
        service_charge REAL DEFAULT 0.0,
        discount_amount REAL DEFAULT 0.0,
        FOREIGN KEY (table_id) REFERENCES tables (id),
        FOREIGN KEY (waiter_id) REFERENCES waiters (id),
        FOREIGN KEY (cashier_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        product_id INTEGER,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        is_printed_to_kitchen INTEGER DEFAULT 0,
        kitchen_round INTEGER DEFAULT 0,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_by INTEGER,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _seedData(db);
  }

  Future _seedUsers(Database db) async {
    final directorHash = hashPassword('director123');
    final cashierHash = hashPassword('cashier123');
    await db.insert('users', {
      'username': 'Director',
      'password_hash': directorHash,
      'role': 'director',
      'is_active': 1,
    });
    await db.insert('users', {
      'username': 'Cashier 1',
      'password_hash': cashierHash,
      'role': 'cashier',
      'is_active': 1,
    });
  }

  Future _seedSettings(Database db) async {
    await db.insert('app_settings', {'key': 'service_charge_percent', 'value': '5.0'});
    await db.insert('app_settings', {'key': 'discount_enabled', 'value': 'true'});
  }

  Future _seedData(Database db) async {
    await _seedUsers(db);
    await _seedSettings(db);
    
    // Seed Categories
    final catIds = <String, int>{};
    for (var cat in ['Coffee', 'Tea', 'Pastries', 'Soft Drinks']) {
      final id = await db.insert('categories', {'name': cat});
      catIds[cat] = id;
    }

    // Seed Products
    final products = [
      {'category': 'Coffee', 'name': 'Macchiato', 'price': 35.0},
      {'category': 'Coffee', 'name': 'Black Coffee', 'price': 25.0},
      {'category': 'Coffee', 'name': 'Caffe Latte', 'price': 45.0},
      {'category': 'Tea', 'name': 'Black Tea', 'price': 15.0},
      {'category': 'Tea', 'name': 'Spiced Tea', 'price': 20.0},
      {'category': 'Pastries', 'name': 'Croissant', 'price': 55.0},
      {'category': 'Pastries', 'name': 'Chocolate Cake', 'price': 75.0},
      {'category': 'Soft Drinks', 'name': 'Coca Cola', 'price': 30.0},
      {'category': 'Soft Drinks', 'name': 'Water 0.5L', 'price': 20.0},
    ];

    for (var p in products) {
      await db.insert('products', {
        'category_id': catIds[p['category']],
        'name': p['name'],
        'price': p['price'],
      });
    }

    // Seed Waiters
    await db.insert('waiters', {'name': 'Default Waiter', 'code': 'W001'});
    
    // Seed Tables
    for (var i = 1; i <= 10; i++) {
      await db.insert('tables', {'name': 'Table $i', 'status': 'available'});
    }
  }
}
