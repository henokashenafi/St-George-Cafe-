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
        version: 1,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onCreate(Database db, int version) async {
    // Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT
      )
    ''');

    // Products
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

    // Waiters
    await db.execute('''
      CREATE TABLE waiters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT UNIQUE
      )
    ''');

    // Tables
    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        status TEXT DEFAULT 'available' -- available, occupied, reserved
      )
    ''');

    // Orders
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER,
        waiter_id INTEGER,
        status TEXT DEFAULT 'pending', -- pending, completed, cancelled
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        total_amount REAL DEFAULT 0.0,
        FOREIGN KEY (table_id) REFERENCES tables (id),
        FOREIGN KEY (waiter_id) REFERENCES waiters (id)
      )
    ''');

    // Order Items
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        product_id INTEGER,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        is_printed_to_kitchen INTEGER DEFAULT 0, -- 0 for false, 1 for true
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Seed initial data
    await _seedData(db);
  }

  Future _seedData(Database db) async {
    // Seed Tables
    for (var i = 1; i <= 20; i++) {
      await db.insert('tables', {'name': 'Table $i'});
    }

    // Seed Categories
    await db.insert('categories', {'name': 'Food'});
    await db.insert('categories', {'name': 'Drinks'});
    await db.insert('categories', {'name': 'Desserts'});

    // Seed some products
    await db.insert('products', {'category_id': 1, 'name': 'Burger', 'price': 250.0});
    await db.insert('products', {'category_id': 1, 'name': 'Pizza', 'price': 450.0});
    await db.insert('products', {'category_id': 2, 'name': 'Coffee', 'price': 50.0});
    await db.insert('products', {'category_id': 2, 'name': 'Juice', 'price': 120.0});
    
    // Seed a waiter
    await db.insert('waiters', {'name': 'Default Waiter', 'code': '0000'});
  }
}
