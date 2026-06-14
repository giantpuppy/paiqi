import 'dart:convert';
import 'dart:html';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../models/ocr_correction.dart';
import '../models/show_template.dart';
import '../models/ticket.dart';

class _WebDB {
  final String username;
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  final Map<String, int> _autoIncrement = {};

  _WebDB(this.username);

  String get _storageKey => 'paiqi_app_${username}_v1';

  Future<void> _save() async {
    try {
      final data = {
        'tables': _tables,
        'autoIncrement': _autoIncrement,
      };
      final json = jsonEncode(data);
      window.localStorage[_storageKey] = json;
      print('[WebDB] Saved ${json.length} bytes to localStorage ($_storageKey)');
    } catch (e, st) {
      print('[WebDB] Failed to save: $e');
      print(st);
    }
  }

  Future<void> _load() async {
    final stored = window.localStorage[_storageKey];
    if (stored == null || stored.isEmpty) {
      print('[WebDB] No stored data found for $_storageKey');
      return;
    }
    try {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      final tables = data['tables'] as Map<String, dynamic>?;
      final ai = data['autoIncrement'] as Map<String, dynamic>?;
      if (tables != null) {
        _tables.clear();
        for (final entry in tables.entries) {
          final rows = (entry.value as List<dynamic>).map((r) {
            final row = Map<String, dynamic>.from(r as Map<dynamic, dynamic>);
            if (entry.key == 'performances') {
              if (!row.containsKey('status')) row['status'] = 'unmarked';
              if (!row.containsKey('actual_price')) row['actual_price'] = null;
            }
            if (entry.key == 'cast_members' && !row.containsKey('is_featured')) {
              row['is_featured'] = 0;
            }
            if (entry.key == 'shows' && !row.containsKey('cover_path')) {
              row['cover_path'] = null;
            }
            return row;
          }).toList();
          _tables[entry.key] = rows;
          print('[WebDB] Loaded ${rows.length} rows into ${entry.key}');
        }
      }
      if (ai != null) {
        _autoIncrement.clear();
        for (final entry in ai.entries) {
          _autoIncrement[entry.key] = (entry.value as num).toInt();
        }
      }
      // 确保新表存在
      _tables.putIfAbsent('ocr_corrections', () => []);
      _tables.putIfAbsent('show_templates', () => []);
      _tables.putIfAbsent('tickets', () => []);
      _autoIncrement.putIfAbsent('ocr_corrections', () => 0);
      _autoIncrement.putIfAbsent('show_templates', () => 0);
      _autoIncrement.putIfAbsent('tickets', () => 0);

      // v9 迁移：将 performances 上的 seat/price 复制到 tickets
      if (!_tables.containsKey('_tickets_migrated')) {
        final perfs = _tables['performances'] ?? [];
        final tickets = _tables['tickets'] ?? [];
        for (final p in perfs) {
          final hasSeat = p['seat'] != null && p['seat'].toString().isNotEmpty;
          final hasPrice = p['price'] != null;
          final hasActual = p['actual_price'] != null;
          if (hasSeat || hasPrice || hasActual) {
            final alreadyMigrated = tickets.any((t) => t['performance_id'] == p['id']);
            if (!alreadyMigrated) {
              _autoIncrement['tickets'] = (_autoIncrement['tickets'] ?? 0) + 1;
              tickets.add({
                'id': _autoIncrement['tickets'],
                'performance_id': p['id'],
                'seat': p['seat'],
                'price': p['price'],
                'actual_price': p['actual_price'],
              });
            }
          }
        }
        _tables['tickets'] = tickets;
        _tables['_tickets_migrated'] = [{'done': true}];
      }
      print('[WebDB] Data loaded successfully for $_storageKey');
    } catch (e, st) {
      print('[WebDB] Failed to load data: $e');
      print(st);
    }
  }

  Future<void> execute(String sql) async {
    final upper = sql.trim().toUpperCase();
    if (upper.startsWith('CREATE TABLE')) {
      final match = RegExp(r'CREATE TABLE\s+(\w+)').firstMatch(sql);
      if (match != null) {
        final tableName = match.group(1)!;
        _tables[tableName] = [];
        _autoIncrement[tableName] = 0;
      }
    }
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    _tables.putIfAbsent(table, () => []);
    final row = Map<String, dynamic>.from(values);
    if (row['id'] == null) {
      _autoIncrement[table] = (_autoIncrement[table] ?? 0) + 1;
      row['id'] = _autoIncrement[table];
    }
    _tables[table]!.add(row);
    await _save();
    return row['id'];
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    _tables.putIfAbsent(table, () => []);
    var results = List<Map<String, dynamic>>.from(_tables[table]!);
    if (where != null && whereArgs != null) {
      results = results.where((row) => _matchesWhere(row, where, whereArgs)).toList();
    }
    if (orderBy != null) {
      results = _sortResults(results, orderBy);
    }
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _tables.putIfAbsent(table, () => []);
    int count = 0;
    for (var i = 0; i < _tables[table]!.length; i++) {
      if (where == null || whereArgs == null || _matchesWhere(_tables[table]![i], where, whereArgs)) {
        for (final entry in values.entries) {
          _tables[table]![i][entry.key] = entry.value;
        }
        count++;
      }
    }
    if (count > 0) await _save();
    return count;
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    _tables.putIfAbsent(table, () => []);
    if (where == null || whereArgs == null) {
      final count = _tables[table]!.length;
      _tables[table]!.clear();
      if (count > 0) await _save();
      return count;
    }
    final original = List<Map<String, dynamic>>.from(_tables[table]!);
    final filtered = original.where((row) => !_matchesWhere(row, where, whereArgs)).toList();
    final count = original.length - filtered.length;
    _tables[table] = filtered;
    if (count > 0) await _save();
    return count;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? args]) async {
    final upper = sql.trim().toUpperCase();

    if (upper.contains('JOIN SHOWS')) {
      if (upper.contains('WHERE P.DATE = ?')) {
        return _joinPerformancesWithShows(
          dateFilter: args?.isNotEmpty == true ? args![0].toString() : null,
        );
      }
      if (upper.contains('WHERE P.ID = ?')) {
        final all = _joinPerformancesWithShows();
        final id = args?.isNotEmpty == true ? int.tryParse(args![0].toString()) : null;
        return id != null ? all.where((r) => r['id'] == id).toList() : all;
      }
      return _joinPerformancesWithShows();
    }

    if (upper.contains('FROM PERFORMANCES')) {
      return _tables['performances']?.map((r) => Map<String, dynamic>.from(r)).toList() ?? [];
    }

    return [];
  }

  void close() {}

  bool _matchesWhere(Map<String, dynamic> row, String where, List<Object?> args) {
    var condition = where;
    for (var i = 0; i < args.length; i++) {
      condition = condition.replaceFirst('?', args[i].toString());
    }

    if (condition.contains(' AND ')) {
      final parts = condition.split(' AND ');
      return parts.every((p) => _evalCondition(row, p.trim()));
    }
    return _evalCondition(row, condition);
  }

  bool _evalCondition(Map<String, dynamic> row, String condition) {
    condition = condition.trim();
    if (condition.contains(' >= ') && condition.contains(' <= ')) {
      final match = RegExp(r'(\w+)\s*>=\s*(.+?)\s*AND\s*\w+\s*<=\s*(.+)').firstMatch(condition);
      if (match != null) {
        final field = match.group(1)!;
        final low = match.group(2)!.replaceAll("'", "").trim();
        final high = match.group(3)!.replaceAll("'", "").trim();
        final val = row[field]?.toString() ?? '';
        return val.compareTo(low) >= 0 && val.compareTo(high) <= 0;
      }
    }
    if (condition.contains(' = ')) {
      final parts = condition.split(' = ');
      final field = parts[0].trim();
      var value = parts[1].trim();
      value = value.replaceAll("'", "").replaceAll('"', '');
      return row[field]?.toString() == value;
    }
    return true;
  }

  List<Map<String, dynamic>> _sortResults(List<Map<String, dynamic>> results, String orderBy) {
    final copy = List<Map<String, dynamic>>.from(results);
    final fields = orderBy.split(',').map((s) => s.trim()).toList();
    copy.sort((a, b) {
      for (final field in fields) {
        final parts = field.split(' ');
        final col = parts[0];
        final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
        final va = a[col]?.toString() ?? '';
        final vb = b[col]?.toString() ?? '';
        int cmp = va.compareTo(vb);
        if (cmp != 0) return desc ? -cmp : cmp;
      }
      return 0;
    });
    return copy;
  }

  List<Map<String, dynamic>> _joinPerformancesWithShows({String? dateFilter}) {
    final perfs = _tables['performances'] ?? [];
    final shows = _tables['shows'] ?? [];
    var results = <Map<String, dynamic>>[];

    for (final p in perfs) {
      if (dateFilter != null && p['date'] != dateFilter) continue;
      final show = shows.firstWhere(
        (s) => s['id'] == p['show_id'],
        orElse: () => {'name': '', 'theater': '', 'cover_path': null},
      );
      results.add({
        ...Map<String, dynamic>.from(p),
        'show_name': show['name'],
        'theater': show['theater'],
        'cover_path': show['cover_path'],
      });
    }
    results.sort((a, b) {
      final da = a['date']?.toString() ?? '';
      final db_ = b['date']?.toString() ?? '';
      final cmp = da.compareTo(db_);
      if (cmp != 0) return cmp;
      final ta = a['time']?.toString() ?? '';
      final tb = b['time']?.toString() ?? '';
      return ta.compareTo(tb);
    });
    return results;
  }
}

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static String _username = 'default';
  static _WebDB? _db;
  bool _initialized = false;

  DatabaseHelper._init();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._init();
    return _instance!;
  }

  static Future<void> switchUser(String username) async {
    if (_username == username) return;
    _username = username;
    _db = null;
    _instance?._initialized = false;
  }

  Future<_WebDB> get database async {
    _db ??= _WebDB(_username);
    if (!_initialized) {
      await _initDB();
      _initialized = true;
    }
    return _db!;
  }

  Future<void> _initDB() async {
    print('[WebDB] Initializing database for user: $_username');
    final db = _db!;
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
    await db.execute('''
      CREATE TABLE tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        performance_id INTEGER NOT NULL,
        seat TEXT,
        price REAL,
        actual_price REAL,
        FOREIGN KEY (performance_id) REFERENCES performances (id) ON DELETE CASCADE
      )
    ''');
    await db._load();
    print('[WebDB] Init complete for user: $_username');
  }

  Future close() async {}

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

  /// 轻量查询：只返回某剧目下所有场次 id 列表
  Future<List<int>> getPerformanceIdsByShowId(int showId) async {
    final db = await instance.database;
    final result = await db.query(
      'performances',
      where: 'show_id = ?',
      whereArgs: [showId],
    );
    return result.map((row) => row['id'] as int).toList();
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

  Future<List<Map<String, dynamic>>> getPerformancesWithShowByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.name as show_name, s.theater, s.cover_path
      FROM performances p
      JOIN shows s ON p.show_id = s.id
      WHERE p.date >= ? AND p.date <= ?
      ORDER BY p.date ASC, p.time ASC
    ''', [startDate, endDate]);
    return result;
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

  /// 批量查询多个 performance 的卡司，避免 N+1 查询
  Future<Map<int, List<CastMember>>> getCastMembersByPerformanceIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final db = await instance.database;
    final all = await db.query('cast_members');
    final map = <int, List<CastMember>>{};
    for (final row in all) {
      final cm = CastMember.fromMap(row);
      if (ids.contains(cm.performanceId)) {
        map.putIfAbsent(cm.performanceId, () => []).add(cm);
      }
    }
    return map;
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

  // ========== Tickets ==========
  Future<Ticket> createTicket(Ticket ticket) async {
    final db = await instance.database;
    final id = await db.insert('tickets', ticket.toMap());
    return ticket.copyWith(id: id);
  }

  Future<List<Ticket>> getTicketsByPerformanceId(int performanceId) async {
    final db = await instance.database;
    final result = await db.query(
      'tickets',
      where: 'performance_id = ?',
      whereArgs: [performanceId],
    );
    return result.map((json) => Ticket.fromMap(json)).toList();
  }

  Future<int> updateTicket(Ticket ticket) async {
    final db = await instance.database;
    return db.update('tickets', ticket.toMap(), where: 'id = ?', whereArgs: [ticket.id]);
  }

  Future<int> deleteTicket(int id) async {
    final db = await instance.database;
    return db.delete('tickets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTicketsByPerformanceId(int performanceId) async {
    final db = await instance.database;
    return db.delete('tickets', where: 'performance_id = ?', whereArgs: [performanceId]);
  }

  Future<Actor> createActor(Actor actor) async {
    final db = await instance.database;
    final existing = await getActorByName(actor.name);
    if (existing != null) return existing;
    final id = await db.insert('actors', actor.toMap());
    return actor.copyWith(id: id);
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

  Future<int> updateActor(Actor actor) async {
    final db = await instance.database;
    return db.update('actors', actor.toMap(), where: 'id = ?', whereArgs: [actor.id]);
  }

  Future<void> replaceAllPerformances(int showId, List<Map<String, dynamic>> perfDataList) async {
    final db = await instance.database;
    await db.delete('performances', where: 'show_id = ?', whereArgs: [showId]);
    for (final data in perfDataList) {
      final perf = data['performance'] as Performance;
      final casts = data['casts'] as List<CastMember>;
      final perfMap = perf.toMap();
      perfMap.remove('id');
      final perfId = await db.insert('performances', perfMap);
      for (final cast in casts) {
        final castMap = cast.copyWith(performanceId: perfId).toMap();
        castMap.remove('id');
        await db.insert('cast_members', castMap);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPerformancesWithShowByDate(String date) async {
    final db = await instance.database;
    return db.rawQuery(
      'SELECT p.*, s.name as show_name, s.theater, s.cover_path FROM performances p JOIN shows s ON p.show_id = s.id WHERE p.date = ? ORDER BY p.time ASC',
      [date],
    );
  }

  Future<List<Map<String, dynamic>>> getAllPerformancesWithShow() async {
    final db = await instance.database;
    return db.rawQuery(
      'SELECT p.*, s.name as show_name, s.theater, s.cover_path FROM performances p JOIN shows s ON p.show_id = s.id ORDER BY p.date ASC, p.time ASC',
    );
  }

  Future<Map<String, dynamic>?> getPerformanceDetail(int performanceId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT p.*, s.name as show_name, s.theater, s.cover_path FROM performances p JOIN shows s ON p.show_id = s.id WHERE p.id = ?',
      [performanceId],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // ========== OCR Corrections ==========
  Future<OcrCorrection> createOcrCorrection(OcrCorrection correction) async {
    final db = await instance.database;
    final existing = await getOcrCorrectionByText(correction.ocrText, correction.category);
    if (existing != null) {
      final updated = existing.copyWith(
        correctedText: correction.correctedText,
        useCount: existing.useCount + 1,
      );
      await db.update(
        'ocr_corrections',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return updated;
    }
    final id = await db.insert('ocr_corrections', correction.toMap());
    return correction.copyWith(id: id);
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
    final id = await db.insert('show_templates', template.toMap());
    return template.copyWith(id: id);
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

  Future<int> deleteShowTemplate(int id) async {
    final db = await instance.database;
    return db.delete('show_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// 查询某个月份的所有演出（含剧目信息），用于月度管理工作台
  Future<List<Map<String, dynamic>>> getPerformancesByMonth(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$year-$monthStr';
    // 用已有的 rawQuery JOIN 逻辑，手动过滤月份
    final all = await db.rawQuery(
      'SELECT p.*, s.name as show_name, s.theater, s.cover_path FROM performances p JOIN shows s ON p.show_id = s.id ORDER BY p.date ASC, p.time ASC',
    );
    return all.where((r) {
      final date = r['date']?.toString() ?? '';
      return date.startsWith(prefix);
    }).toList();
  }
}
