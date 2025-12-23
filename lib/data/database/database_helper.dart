import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cat.dart';
import '../models/reminder.dart';
import '../models/weight_record.dart';
import '../models/vaccination.dart';
import '../models/health_note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dotcat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cats(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        birthDate TEXT NOT NULL,
        breed TEXT,
        weight REAL,
        photoPath TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders(
        id TEXT PRIMARY KEY,
        catId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        time TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'daily',
        isActive INTEGER NOT NULL DEFAULT 1,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL,
        nextDate TEXT,
        FOREIGN KEY (catId) REFERENCES cats (id) ON DELETE CASCADE
      )
    ''');

    // Tekrarlayan hatırlatıcıların tamamlama kayıtları
    await db.execute('''
      CREATE TABLE reminder_completions(
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        completedDate TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        FOREIGN KEY (reminderId) REFERENCES reminders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_records(
        id TEXT PRIMARY KEY,
        catId TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT,
        recordedAt TEXT NOT NULL,
        FOREIGN KEY (catId) REFERENCES cats (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vaccinations(
        id TEXT PRIMARY KEY,
        catId TEXT NOT NULL,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        nextDate TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        veterinarian TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (catId) REFERENCES cats (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE health_notes(
        id TEXT PRIMARY KEY,
        catId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        veterinarian TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (catId) REFERENCES cats (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE vaccinations ADD COLUMN isCompleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE reminders ADD COLUMN frequency TEXT NOT NULL DEFAULT "daily"');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE cats ADD COLUMN photoPath TEXT');
      } catch (e) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE reminders ADD COLUMN isCompleted INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE reminders ADD COLUMN nextDate TEXT');
      } catch (e) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reminder_completions(
            id TEXT PRIMARY KEY,
            reminderId TEXT NOT NULL,
            completedDate TEXT NOT NULL,
            completedAt TEXT NOT NULL,
            FOREIGN KEY (reminderId) REFERENCES reminders (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {}
    }
  }

  // ============ CAT OPERATIONS ============
  Future<int> insertCat(Cat cat) async {
    final db = await database;
    return await db.insert('cats', cat.toMap());
  }

  Future<List<Cat>> getAllCats() async {
    final db = await database;
    final maps = await db.query('cats', orderBy: 'createdAt DESC');
    return maps.map((map) => Cat.fromMap(map)).toList();
  }

  Future<Cat?> getCatById(String id) async {
    final db = await database;
    final maps = await db.query('cats', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Cat.fromMap(maps.first);
  }

  Future<int> updateCat(Cat cat) async {
    final db = await database;
    return await db.update('cats', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<int> deleteCat(String id) async {
    final db = await database;
    return await db.delete('cats', where: 'id = ?', whereArgs: [id]);
  }

  // ============ REMINDER OPERATIONS ============
  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<Reminder>> getRemindersForCat(String catId) async {
    final db = await database;
    final maps = await db.query('reminders', where: 'catId = ?', whereArgs: [catId], orderBy: 'time ASC');
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getAllActiveReminders() async {
    final db = await database;
    final maps = await db.query('reminders', where: 'isActive = 1', orderBy: 'time ASC');
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query('reminders', orderBy: 'createdAt DESC');
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<Reminder?> getReminderById(String id) async {
    final db = await database;
    final maps = await db.query('reminders', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update('reminders', reminder.toMap(), where: 'id = ?', whereArgs: [reminder.id]);
  }

  Future<int> deleteReminder(String id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ============ WEIGHT OPERATIONS ============
  Future<int> insertWeightRecord(WeightRecord record) async {
    final db = await database;
    return await db.insert('weight_records', record.toMap());
  }

  Future<List<WeightRecord>> getWeightRecordsForCat(String catId) async {
    final db = await database;
    final maps = await db.query('weight_records', where: 'catId = ?', whereArgs: [catId], orderBy: 'recordedAt DESC');
    return maps.map((map) => WeightRecord.fromMap(map)).toList();
  }

  Future<WeightRecord?> getLatestWeightForCat(String catId) async {
    final db = await database;
    final maps = await db.query('weight_records', where: 'catId = ?', whereArgs: [catId], orderBy: 'recordedAt DESC', limit: 1);
    if (maps.isEmpty) return null;
    return WeightRecord.fromMap(maps.first);
  }

  Future<int> deleteWeightRecord(String id) async {
    final db = await database;
    return await db.delete('weight_records', where: 'id = ?', whereArgs: [id]);
  }

  // ============ VACCINATION OPERATIONS ============
  Future<int> insertVaccination(Vaccination vaccination) async {
    final db = await database;
    return await db.insert('vaccinations', vaccination.toMap());
  }

  Future<List<Vaccination>> getVaccinationsForCat(String catId) async {
    final db = await database;
    final maps = await db.query('vaccinations', where: 'catId = ?', whereArgs: [catId], orderBy: 'date DESC');
    return maps.map((map) => Vaccination.fromMap(map)).toList();
  }

  Future<List<Vaccination>> getUpcomingVaccinations() async {
    final db = await database;
    final now = DateTime.now();
    final future = now.add(const Duration(days: 30));
    final maps = await db.query(
      'vaccinations',
      where: 'nextDate IS NOT NULL AND nextDate >= ? AND nextDate <= ? AND isCompleted = 0',
      whereArgs: [now.toIso8601String(), future.toIso8601String()],
      orderBy: 'nextDate ASC',
    );
    return maps.map((map) => Vaccination.fromMap(map)).toList();
  }

  Future<int> updateVaccination(Vaccination vaccination) async {
    final db = await database;
    return await db.update('vaccinations', vaccination.toMap(), where: 'id = ?', whereArgs: [vaccination.id]);
  }

  Future<int> deleteVaccination(String id) async {
    final db = await database;
    return await db.delete('vaccinations', where: 'id = ?', whereArgs: [id]);
  }

  // ============ HEALTH NOTE OPERATIONS ============
  Future<int> insertHealthNote(HealthNote note) async {
    final db = await database;
    return await db.insert('health_notes', note.toMap());
  }

  Future<List<HealthNote>> getHealthNotesForCat(String catId) async {
    final db = await database;
    final maps = await db.query('health_notes', where: 'catId = ?', whereArgs: [catId], orderBy: 'date DESC');
    return maps.map((map) => HealthNote.fromMap(map)).toList();
  }

  Future<int> deleteHealthNote(String id) async {
    final db = await database;
    return await db.delete('health_notes', where: 'id = ?', whereArgs: [id]);
  }

  // ============ REMINDER COMPLETION OPERATIONS ============
  Future<int> insertCompletion(String reminderId, DateTime completedDate) async {
    final db = await database;
    final id = '${reminderId}_${completedDate.toIso8601String().split('T')[0]}';
    final dateStr = completedDate.toIso8601String().split('T')[0];
    final completedAtStr = DateTime.now().toIso8601String();
    
    return await db.insert('reminder_completions', {
      'id': id,
      'reminderId': reminderId,
      'completedDate': dateStr,
      'completedAt': completedAtStr,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<String>> getAllCompletedDates() async {
    final db = await database;
    final maps = await db.query('reminder_completions');
    return maps.map((map) => map['id'] as String).toSet();
  }

  // Completion tarih ve zamanını al (id -> completedAt mapping)
  Future<Map<String, DateTime>> getCompletionTimes() async {
    final db = await database;
    final maps = await db.query('reminder_completions');
    final result = <String, DateTime>{};
    for (final map in maps) {
      final id = map['id'] as String;
      final completedAtStr = map['completedAt'] as String?;
      if (completedAtStr != null) {
        try {
          result[id] = DateTime.parse(completedAtStr);
        } catch (e) {
          // Parse hatası durumunda şimdiki zamanı kullan
          result[id] = DateTime.now();
        }
      }
    }
    return result;
  }

  Future<int> deleteCompletion(String reminderId, DateTime completedDate) async {
    final db = await database;
    final dateStr = completedDate.toIso8601String().split('T')[0];
    return await db.delete('reminder_completions', 
      where: 'reminderId = ? AND completedDate = ?', 
      whereArgs: [reminderId, dateStr]);
  }

  Future<List<String>> getCompletionsForReminder(String reminderId) async {
    final db = await database;
    final maps = await db.query('reminder_completions', 
      where: 'reminderId = ?', 
      whereArgs: [reminderId]);
    return maps.map((m) => m['completedDate'] as String).toList();
  }
}
