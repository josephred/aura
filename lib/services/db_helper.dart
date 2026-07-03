import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../models/service_request.dart';
import '../models/chat_message.dart';
import '../models/past_service.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aura.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createOutboxTable(db);
    }
  }

  Future<void> _createOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE offline_outbox (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dependents (
        id TEXT PRIMARY KEY,
        name TEXT,
        relationship TEXT,
        age INTEGER,
        health_insurance TEXT,
        medical_conditions TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_addresses (
        id TEXT PRIMARY KEY,
        label TEXT,
        text TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_payment_methods (
        id TEXT PRIMARY KEY,
        type TEXT,
        last4 TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE service_requests (
        id TEXT PRIMARY KEY,
        service_id TEXT,
        status TEXT,
        patient_type TEXT,
        dependent_id TEXT,
        address_text TEXT,
        origin_address TEXT,
        destination_address TEXT,
        ambulance_type TEXT,
        symptoms_description TEXT,
        prescription_name TEXT,
        prescription_preview TEXT,
        prescription_file TEXT,
        exam_required TEXT,
        payment_method TEXT,
        final_price INTEGER,
        start_time TEXT,
        eta_minutes INTEGER,
        current_step INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        service_request_id TEXT,
        sender TEXT,
        text TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE past_services (
        id TEXT PRIMARY KEY,
        service_title TEXT,
        service_id TEXT,
        date TEXT,
        patient TEXT,
        price INTEGER,
        status TEXT,
        details TEXT,
        professional TEXT
      )
    ''');

    await _createOutboxTable(db);
  }

  // --- Offline Outbox (queued CRUD requests awaiting connectivity) ---
  Future<void> enqueueOutbox(String method, String path, String? body) async {
    final db = await database;
    await db.insert('offline_outbox', {
      'method': method,
      'path': path,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getOutbox() async {
    final db = await database;
    return db.query('offline_outbox', orderBy: 'seq ASC');
  }

  Future<void> deleteOutboxEntry(int seq) async {
    final db = await database;
    await db.delete('offline_outbox', where: 'seq = ?', whereArgs: [seq]);
  }

  // --- Dependents ---
  Future<List<Dependent>> getDependents() async {
    final db = await database;
    final res = await db.query('dependents');
    return res.map((json) => Dependent.fromJson(json)).toList();
  }

  Future<void> saveDependents(List<Dependent> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('dependents');
      for (final item in list) {
        await txn.insert('dependents', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Saved Addresses ---
  Future<List<SavedAddress>> getAddresses() async {
    final db = await database;
    final res = await db.query('saved_addresses');
    return res.map((json) => SavedAddress.fromJson(json)).toList();
  }

  Future<void> saveAddresses(List<SavedAddress> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('saved_addresses');
      for (final item in list) {
        await txn.insert('saved_addresses', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Payment Methods ---
  Future<List<SavedPaymentMethod>> getPaymentMethods() async {
    final db = await database;
    final res = await db.query('saved_payment_methods');
    return res.map((json) => SavedPaymentMethod.fromJson(json)).toList();
  }

  Future<void> savePaymentMethods(List<SavedPaymentMethod> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('saved_payment_methods');
      for (final item in list) {
        await txn.insert('saved_payment_methods', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Service Requests (Bookings) ---
  Future<List<ServiceRequest>> getBookings() async {
    final db = await database;
    final res = await db.query('service_requests');
    return res.map((json) => ServiceRequest.fromJson(json)).toList();
  }

  Future<void> saveBookings(List<ServiceRequest> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('service_requests');
      for (final item in list) {
        await txn.insert('service_requests', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Chat Messages ---
  Future<List<ChatMessage>> getChatMessages(String bookingId) async {
    final db = await database;
    final res = await db.query(
      'chat_messages',
      where: 'service_request_id = ?',
      whereArgs: [bookingId],
    );
    return res.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> saveChatMessages(String bookingId, List<ChatMessage> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'chat_messages',
        where: 'service_request_id = ?',
        whereArgs: [bookingId],
      );
      for (final item in list) {
        final map = item.toJson();
        map['service_request_id'] = bookingId;
        await txn.insert('chat_messages', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Past Services ---
  Future<List<PastService>> getPastServices() async {
    final db = await database;
    final res = await db.query('past_services');
    return res.map((json) => PastService.fromJson(json)).toList();
  }

  Future<void> savePastServices(List<PastService> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('past_services');
      for (final item in list) {
        await txn.insert('past_services', item.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- Clear Cache ---
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('dependents');
      await txn.delete('saved_addresses');
      await txn.delete('saved_payment_methods');
      await txn.delete('service_requests');
      await txn.delete('chat_messages');
      await txn.delete('past_services');
      await txn.delete('offline_outbox');
    });
  }
}
