import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:st_george_pos/services/system_log_service.dart';

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
      SystemLogService.log('Initializing SQLite database at: $dbPath');
    }

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 15,
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
    SystemLogService.log('UPGRADING database from version $oldVersion to $newVersion');
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
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          action TEXT NOT NULL,
          details TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pos_charges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          value REAL NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');
      // Seed with defaults (VAT set to 0.0 per new requirement)
      await db.insert('pos_charges', {'name': 'VAT', 'type': 'addition', 'value': 0.0, 'is_active': 1});
      await db.insert('pos_charges', {'name': 'Service Charge', 'type': 'addition', 'value': 5.0, 'is_active': 1});
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE products ADD COLUMN category_ids TEXT');
      // Migrate existing category_id to category_ids
      await db.execute('UPDATE products SET category_ids = category_id');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE orders ADD COLUMN payment_method TEXT DEFAULT \'cash\'');
      await db.execute('ALTER TABLE orders ADD COLUMN shift_id INTEGER');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cashier_id INTEGER,
          start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
          end_time DATETIME,
          starting_cash REAL DEFAULT 0.0,
          actual_cash_declared REAL,
          status TEXT DEFAULT 'open',
          FOREIGN KEY (cashier_id) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS z_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shift_id INTEGER,
          z_count INTEGER,
          report_data TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (shift_id) REFERENCES shifts (id)
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE categories ADD COLUMN name_amharic TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN name_amharic TEXT');
      await db.execute('ALTER TABLE waiters ADD COLUMN name_amharic TEXT');
      await db.execute('ALTER TABLE tables ADD COLUMN name_amharic TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE pos_charges ADD COLUMN name_amharic TEXT');
      await db.execute('ALTER TABLE table_zones ADD COLUMN name_amharic TEXT');
      // Update default charges with Amharic names
      await db.execute("UPDATE pos_charges SET name_amharic = 'ቫት' WHERE name = 'VAT'");
      await db.execute("UPDATE pos_charges SET name_amharic = 'የአገልግሎት ክፍያ' WHERE name = 'Service Charge'");
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE orders ADD COLUMN table_name TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN table_name_amharic TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN waiter_name TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN waiter_name_amharic TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN cashier_name TEXT');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE order_items ADD COLUMN product_name TEXT');
      await db.execute('ALTER TABLE order_items ADD COLUMN product_name_amharic TEXT');
      await db.execute('ALTER TABLE order_items ADD COLUMN category_name TEXT');
    }
    if (oldVersion < 13) {
      try { await db.execute('ALTER TABLE order_items ADD COLUMN station_name_amharic TEXT'); } catch (_) {}
    }
    if (oldVersion < 14) {
      try { await db.execute('ALTER TABLE orders ADD COLUMN customer_tin TEXT'); } catch (_) {}
    }
    if (oldVersion < 15) {
      try { await db.execute('ALTER TABLE products ADD COLUMN category_ids TEXT'); } catch (_) {}
      try { await db.execute('UPDATE products SET category_ids = category_id'); } catch (_) {}
    }
  }

  Future _onCreate(Database db, int version) async {
    SystemLogService.log('CREATING fresh database version $version');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_amharic TEXT,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        name_amharic TEXT,
        price REAL NOT NULL,
        image_path TEXT,
        station_id INTEGER,
        category_ids TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (station_id) REFERENCES serving_stations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE waiters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_amharic TEXT,
        code TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE table_zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        name_amharic TEXT,
        waiter_id INTEGER,
        FOREIGN KEY (waiter_id) REFERENCES waiters (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        name_amharic TEXT,
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
        payment_method TEXT DEFAULT 'cash',
        shift_id INTEGER,
        table_name TEXT,
        table_name_amharic TEXT,
        waiter_name TEXT,
        waiter_name_amharic TEXT,
        cashier_name TEXT,
        customer_tin TEXT,
        FOREIGN KEY (table_id) REFERENCES tables (id),
        FOREIGN KEY (waiter_id) REFERENCES waiters (id),
        FOREIGN KEY (cashier_id) REFERENCES users (id),
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_id INTEGER,
        start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        end_time DATETIME,
        starting_cash REAL DEFAULT 0.0,
        actual_cash_declared REAL,
        status TEXT DEFAULT 'open',
        FOREIGN KEY (cashier_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE z_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER,
        z_count INTEGER,
        report_data TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (shift_id) REFERENCES shifts (id)
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
        station_id INTEGER,
        station_name TEXT,
        station_name_amharic TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        product_name TEXT,
        product_name_amharic TEXT,
        category_name TEXT,
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

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        details TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pos_charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_amharic TEXT,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE serving_stations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_amharic TEXT,
        printer_name TEXT
      )
    ''');

    await _seedData(db);
    await db.insert('pos_charges', {'name': 'VAT', 'name_amharic': 'ቫት', 'type': 'addition', 'value': 0.0, 'is_active': 1});
    await db.insert('pos_charges', {'name': 'Service Charge', 'name_amharic': 'የአገልግሎት ክፍያ', 'type': 'addition', 'value': 5.0, 'is_active': 1});
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
    
    // Seed Stations
    final kitchenId = await db.insert('serving_stations', {
      'name': 'Kitchen',
      'name_amharic': 'ወጥ ቤት',
    });

    // Seed Categories
    final localCatIdsMap = <String, int>{};
    final categories = [
      {'name': 'Coffee', 'name_amharic': 'ቡና'},
      {'name': 'Tea', 'name_amharic': 'ሻይ'},
      {'name': 'Pastries', 'name_amharic': 'መክሰስ'},
      {'name': 'Soft Drinks', 'name_amharic': 'ለስላሳ'},
    ];
    for (var cat in categories) {
      final id = await db.insert('categories', cat);
      localCatIdsMap[cat['name']!] = id;
    }

    // Seed Products
    final products = [
      {'category': 'Coffee', 'name': 'Macchiato', 'name_amharic': 'ማኪያቶ', 'price': 35.0},
      {'category': 'Coffee', 'name': 'Black Coffee', 'name_amharic': 'ጥቁር ቡና', 'price': 25.0},
      {'category': 'Coffee', 'name': 'Caffe Latte', 'name_amharic': 'ላቴ', 'price': 45.0},
      {'category': 'Tea', 'name': 'Black Tea', 'name_amharic': 'ጥቁር ሻይ', 'price': 15.0},
      {'category': 'Tea', 'name': 'Spiced Tea', 'name_amharic': 'የቅመም ሻይ', 'price': 20.0},
      {'category': 'Pastries', 'name': 'Croissant', 'name_amharic': 'ክሮይሰንት', 'price': 55.0},
      {'category': 'Pastries', 'name': 'Chocolate Cake', 'name_amharic': 'ቸኮሌት ኬክ', 'price': 75.0},
      {'category': 'Soft Drinks', 'name': 'Coca Cola', 'name_amharic': 'ኮካ ኮላ', 'price': 30.0},
      {'category': 'Soft Drinks', 'name': 'Water 0.5L', 'name_amharic': 'ውሃ 0.5 ሊ', 'price': 20.0},
    ];

    for (var p in products) {
      await db.insert('products', {
        'category_id': localCatIdsMap[p['category']],
        'name': p['name'],
        'name_amharic': p['name_amharic'],
        'price': p['price'],
        'station_id': kitchenId,
      });
    }

    // Seed Waiters
    await db.insert('waiters', {'name': 'Default Waiter', 'name_amharic': 'መደበኛ አስተናጋጅ', 'code': 'W001'});
    await db.insert('waiters', {'name': 'Abebe', 'name_amharic': 'አበበ', 'code': 'W002'});
    await db.insert('waiters', {'name': 'Kebe', 'name_amharic': 'ከበደ', 'code': 'W003'});
    
    // Seed Tables
    for (var i = 1; i <= 10; i++) {
      await db.insert('tables', {'name': 'Table $i', 'status': 'available'});
    }
  }
}
