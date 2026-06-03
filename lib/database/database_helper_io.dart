import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../models/ocr_correction.dart';
import '../models/show_template.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static String _dbName = 'paiqi_app.db';
  static Database? _database;

  DatabaseHelper._init();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._init();
    return _instance!;
  }

  /// 切换用户：关闭当前数据库，下次访问时自动打开新用户的数据库
  static Future<void> switchUser(String username) async {
    final newName = '${username}_paiqi.db';
    if (_dbName == newName) return;

    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _dbName = newName;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // 不管当前版本，始终尝试补缺失的列（已存在会报错，忽略即可）
    try {
      await db.execute('ALTER TABLE performances ADD COLUMN status TEXT DEFAULT \'unmarked\'');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE cast_members ADD COLUMN is_featured INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE performances ADD COLUMN actual_price REAL');
    } catch (_) {}

    // v7: shows 表新增 cover_path 字段
    try {
      await db.execute('ALTER TABLE shows ADD COLUMN cover_path TEXT');
    } catch (_) {}

    // v6: 添加知识库表
    try {
      await db.execute('''
        CREATE TABLE ocr_corrections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ocr_text TEXT NOT NULL,
          corrected_text TEXT NOT NULL,
          category TEXT,
          use_count INTEGER DEFAULT 1,
          created_at TEXT,
          UNIQUE(ocr_text, category)
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE show_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          theater TEXT,
          roles TEXT NOT NULL,
          performance_count INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    } catch (_) {}
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        theater TEXT,
        cover_path TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE performances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        show_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        seat TEXT,
        price REAL,
        actual_price REAL,
        status TEXT DEFAULT 'unmarked',
        created_at TEXT,
        FOREIGN KEY (show_id) REFERENCES shows (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cast_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        performance_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        is_featured INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (performance_id) REFERENCES performances (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE actors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        note TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ocr_corrections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ocr_text TEXT NOT NULL,
        corrected_text TEXT NOT NULL,
        category TEXT,
        use_count INTEGER DEFAULT 1,
        created_at TEXT,
        UNIQUE(ocr_text, category)
      )
    ''');

    await db.execute('''
      CREATE TABLE show_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        theater TEXT,
        roles TEXT NOT NULL,
        performance_count INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ========== Shows ==========
  Future<Show> createShow(Show show) async {
    final db = await instance.database;
    final id = await db.insert('shows', show.toMap());
    return show.copyWith(id: id);
  }

  Future<List<Show>> getAllShows() async {
    final db = await instance.database;
    final result = await db.query('shows', orderBy: 'created_at DESC');
    return result.map((json) => Show.fromMap(json)).toList();
  }

  Future<Show?> getShowById(int id) async {
    final db = await instance.database;
    final maps = await db.query('shows', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Show.fromMap(maps.first);
    return null;
  }

  Future<int> updateShow(Show show) async {
    final db = await instance.database;
    return db.update('shows', show.toMap(), where: 'id = ?', whereArgs: [show.id]);
  }

  Future<int> deleteShow(int id) async {
    final db = await instance.database;
    return db.delete('shows', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Performances ==========
  Future<Performance> createPerformance(Performance perf) async {
    final db = await instance.database;
    final id = await db.insert('performances', perf.toMap());
    return perf.copyWith(id: id);
  }

  Future<List<Performance>> getAllPerformances() async {
    final db = await instance.database;
    final result = await db.query('performances', orderBy: 'date ASC, time ASC');
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByShowId(int showId) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'show_id = ?',
      whereArgs: [showId],
      orderBy: 'date ASC, time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<List<Performance>> getPerformancesByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, time ASC',
    );
    return result.map((json) => Performance.fromMap(json)).toList();
  }

  Future<Performance?> getPerformanceById(int id) async {
    final db = await instance.database;
    final maps = await db.query('performances', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Performance.fromMap(maps.first);
    return null;
  }

  Future<int> updatePerformance(Performance perf) async {
    final db = await instance.database;
    return db.update('performances', perf.toMap(), where: 'id = ?', whereArgs: [perf.id]);
  }

  Future<int> deletePerformance(int id) async {
    final db = await instance.database;
    return db.delete('performances', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Cast Members ==========
  Future<CastMember> createCastMember(CastMember cast) async {
    final db = await instance.database;
    final id = await db.insert('cast_members', cast.toMap());
    return cast.copyWith(id: id);
  }

  Future<List<CastMember>> getCastMembersByPerformanceId(int performanceId) async {
    final db = await instance.database;
    final result = await db.query(
      'cast_members',
      where: 'performance_id = ?',
      whereArgs: [performanceId],
    );
    return result.map((json) => CastMember.fromMap(json)).toList();
  }

  Future<List<CastMember>> getAllCastMembers() async {
    final db = await instance.database;
    final result = await db.query('cast_members');
    return result.map((json) => CastMember.fromMap(json)).toList();
  }

  Future<int> deleteCastMembersByPerformanceId(int performanceId) async {
    final db = await instance.database;
    return db.delete('cast_members', where: 'performance_id = ?', whereArgs: [performanceId]);
  }

  // ========== Actors ==========
  Future<Actor> createActor(Actor actor) async {
    final db = await instance.database;
    try {
      final id = await db.insert('actors', actor.toMap());
      return actor.copyWith(id: id);
    } catch (e) {
      final existing = await getActorByName(actor.name);
      return existing ?? actor;
    }
  }

  Future<List<Actor>> getAllActors() async {
    final db = await instance.database;
    final result = await db.query('actors', orderBy: 'name ASC');
    return result.map((json) => Actor.fromMap(json)).toList();
  }

  Future<Actor?> getActorByName(String name) async {
    final db = await instance.database;
    final maps = await db.query('actors', where: 'name = ?', whereArgs: [name]);
    if (maps.isNotEmpty) return Actor.fromMap(maps.first);
    return null;
  }

  Future<int> deleteActor(int id) async {
    final db = await instance.database;
    return db.delete('actors', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Transaction: replace all performances for a show ==========
  Future<void> replaceAllPerformances(int showId, List<Map<String, dynamic>> perfDataList) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. 删除该剧目所有旧场次（CASCADE 会自动删除关联的 cast_members）
      await txn.delete('performances', where: 'show_id = ?', whereArgs: [showId]);
      // 2. 批量插入新场次 + 卡司
      for (final data in perfDataList) {
        final perf = data['performance'] as Performance;
        final casts = data['casts'] as List<CastMember>;
        final perfId = await txn.insert('performances', perf.toMap());
        for (final cast in casts) {
          await txn.insert('cast_members', cast.copyWith(performanceId: perfId).toMap());
        }
      }
    });
  }

  // ========== Complex Queries ==========
  Future<List<Map<String, dynamic>>> getPerformancesWithShowByDate(String date) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater, s.cover_path
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.date = ?
      ORDER BY p.time ASC
    ''', [date]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllPerformancesWithShow() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater, s.cover_path
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      ORDER BY p.date ASC, p.time ASC
    ''');
    return result;
  }

  /// 查询某个月份的所有演出（含剧目信息），用于月度管理工作台
  Future<List<Map<String, dynamic>>> getPerformancesByMonth(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater, s.cover_path
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.date LIKE ?
      ORDER BY s.name ASC, p.date ASC, p.time ASC
    ''', ['$year-$monthStr%']);
    return result;
  }

  Future<Map<String, dynamic>?> getPerformanceDetail(int performanceId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater, s.cover_path
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.id = ?
    ''', [performanceId]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // ========== OCR Corrections ==========
  Future<OcrCorrection> createOcrCorrection(OcrCorrection correction) async {
    final db = await instance.database;
    try {
      final id = await db.insert('ocr_corrections', correction.toMap());
      return correction.copyWith(id: id);
    } catch (e) {
      // 已存在则更新
      await db.update(
        'ocr_corrections',
        {
          'corrected_text': correction.correctedText,
          'use_count': correction.useCount + 1,
        },
        where: 'ocr_text = ? AND category = ?',
        whereArgs: [correction.ocrText, correction.category],
      );
      final maps = await db.query(
        'ocr_corrections',
        where: 'ocr_text = ? AND category = ?',
        whereArgs: [correction.ocrText, correction.category],
      );
      if (maps.isNotEmpty) return OcrCorrection.fromMap(maps.first);
      return correction;
    }
  }

  Future<List<OcrCorrection>> getOcrCorrectionsByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'ocr_corrections',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'use_count DESC',
    );
    return result.map((json) => OcrCorrection.fromMap(json)).toList();
  }

  Future<OcrCorrection?> getOcrCorrectionByText(String ocrText, String category) async {
    final db = await instance.database;
    final maps = await db.query(
      'ocr_corrections',
      where: 'ocr_text = ? AND category = ?',
      whereArgs: [ocrText, category],
    );
    if (maps.isNotEmpty) return OcrCorrection.fromMap(maps.first);
    return null;
  }

  Future<List<OcrCorrection>> getAllOcrCorrections() async {
    final db = await instance.database;
    final result = await db.query('ocr_corrections', orderBy: 'use_count DESC');
    return result.map((json) => OcrCorrection.fromMap(json)).toList();
  }

  // ========== Show Templates ==========
  Future<ShowTemplate> createShowTemplate(ShowTemplate template) async {
    final db = await instance.database;
    try {
      final id = await db.insert('show_templates', template.toMap());
      return template.copyWith(id: id);
    } catch (e) {
      // 已存在则合并角色列表
      final existing = await getShowTemplateByName(template.name);
      if (existing != null) {
        final merged = existing.mergeRoles(template.roles);
        await db.update(
          'show_templates',
          merged.toMap(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return merged.copyWith(id: existing.id);
      }
      return template;
    }
  }

  Future<ShowTemplate?> getShowTemplateByName(String name) async {
    final db = await instance.database;
    final maps = await db.query(
      'show_templates',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) return ShowTemplate.fromMap(maps.first);
    return null;
  }

  Future<List<ShowTemplate>> getAllShowTemplates() async {
    final db = await instance.database;
    final result = await db.query('show_templates', orderBy: 'performance_count DESC');
    return result.map((json) => ShowTemplate.fromMap(json)).toList();
  }

  Future<int> updateShowTemplate(ShowTemplate template) async {
    final db = await instance.database;
    return db.update(
      'show_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }
}
