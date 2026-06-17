import 'dart:convert';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/actor.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';
import '../models/todo_item.dart';
import '../services/user_service.dart';
import '../utils/cover_helper.dart';
export 'data_backup_io.dart' if (dart.library.html) 'data_backup_web.dart';

class DataBackupCore {
  static Future<Map<String, dynamic>> exportData() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final performances = await db.getAllPerformances();
    final actors = await db.getAllActors();
    final castMembers = await db.getAllCastMembers();
    final tickets = await db.getAllTickets();
    final todoItems = await db.getAllTodoItems();
    final users = await UserService.getAllUsers();
    final currentUser = await UserService.getCurrentUsername();
    final autoLoginUser = await UserService.getAutoLoginUser();

    // 导出海报图片为 base64
    final showMaps = <Map<String, dynamic>>[];
    for (final show in shows) {
      final map = show.toMap();
      final base64 = await CoverHelper.readAsBase64(show.coverPath);
      if (base64 != null && base64.isNotEmpty) {
        map['cover_image_base64'] = base64;
      }
      showMaps.add(map);
    }

    return {
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'users': users.map((u) => u.toMap()).toList(),
      'currentUser': currentUser,
      'autoLoginUser': autoLoginUser,
      'shows': showMaps,
      'performances': performances.map((p) => p.toMap()).toList(),
      'actors': actors.map((a) => a.toMap()).toList(),
      'castMembers': castMembers.map((c) => c.toMap()).toList(),
      'tickets': tickets.map((t) => t.toMap()).toList(),
      'todoItems': todoItems.map((t) => t.toMap()).toList(),
    };
  }

  static Future<String?> importData(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      await _doImport(data);
      return '导入成功';
    } catch (e) {
      return '导入失败: $e';
    }
  }

  static Future<void> _doImport(Map<String, dynamic> data) async {
    final db = DatabaseHelper.instance;

    final allPerfs = await db.getAllPerformances();
    for (final p in allPerfs) {
      if (p.id != null) {
        await db.deleteCastMembersByPerformanceId(p.id!);
        await db.deleteTicketsByPerformanceId(p.id!);
        await db.deleteTodoItemsByPerformanceId(p.id!);
        await db.deletePerformance(p.id!);
      }
    }
    final allShows = await db.getAllShows();
    for (final s in allShows) {
      if (s.id != null) await db.deleteShow(s.id!);
    }
    final allActors = await db.getAllActors();
    for (final a in allActors) {
      if (a.id != null) await db.deleteActor(a.id!);
    }

    // 恢复用户账号（追加不覆盖）
    final users = data['users'] as List<dynamic>? ?? [];
    await UserService.restoreUsers(users);

    final restoredCurrentUser = data['currentUser'] as String?;
    final restoredAutoLoginUser = data['autoLoginUser'] as String?;
    final targetUser = restoredAutoLoginUser ?? restoredCurrentUser;

    // 切换到备份对应的数据库（如果存在）
    if (targetUser != null && targetUser.isNotEmpty) {
      await UserService.setAutoLoginUser(targetUser);
      await DatabaseHelper.switchUser(targetUser);
    }

    final showIdMap = <int, int>{};
    final shows = data['shows'] as List<dynamic>? ?? [];
    for (final s in shows) {
      final oldId = s['id'] as int?;
      var coverPath = s['cover_path'] as String?;

      // 如果备份中嵌入了海报图片，优先从 base64 恢复
      final coverBase64 = s['cover_image_base64'] as String?;
      if (coverBase64 != null && coverBase64.isNotEmpty) {
        final restoredPath = await CoverHelper.saveCoverFromBase64(
          s['name'] as String,
          coverBase64,
        );
        if (restoredPath != null) {
          coverPath = restoredPath;
        }
      }

      final newShow = await db.createShow(Show(
        name: s['name'] as String,
        theater: s['theater'] as String?,
        coverPath: coverPath,
        isInScheduleFlow: (s['is_in_schedule_flow'] as int?) == 1,
        createdAt: s['created_at'] as String?,
      ));
      if (oldId != null && newShow.id != null) {
        showIdMap[oldId] = newShow.id!;
      }
    }

    final actorIdMap = <int, int>{};
    final actors = data['actors'] as List<dynamic>? ?? [];
    for (final a in actors) {
      final oldId = a['id'] as int?;
      try {
        final newActor = await db.createActor(Actor(
          name: a['name'] as String,
          note: a['note'] as String?,
          createdAt: a['created_at'] as String?,
        ));
        if (oldId != null && newActor.id != null) {
          actorIdMap[oldId] = newActor.id!;
        }
      } catch (_) {
        final existing = await db.getActorByName(a['name'] as String);
        if (oldId != null && existing?.id != null) {
          actorIdMap[oldId] = existing!.id!;
        }
      }
    }

    final perfIdMap = <int, int>{};
    final performances = data['performances'] as List<dynamic>? ?? [];
    for (final p in performances) {
      final oldId = p['id'] as int?;
      final oldShowId = p['show_id'] as int?;
      final newShowId = showIdMap[oldShowId] ?? oldShowId;

      final newPerf = await db.createPerformance(Performance(
        showId: newShowId ?? 0,
        date: p['date'] as String,
        time: p['time'] as String?,
        seat: p['seat'] as String?,
        price: p['price'] != null ? (p['price'] as num).toDouble() : null,
        actualPrice: p['actual_price'] != null
            ? (p['actual_price'] as num).toDouble()
            : null,
        status: p['status'] as String? ?? 'unmarked',
        createdAt: p['created_at'] as String?,
      ));
      if (oldId != null && newPerf.id != null) {
        perfIdMap[oldId] = newPerf.id!;
      }
    }

    final castMembers = data['castMembers'] as List<dynamic>? ??
        (data['cast_members'] as List<dynamic>? ?? []);
    for (final c in castMembers) {
      final oldPerfId = c['performance_id'] as int?;
      final newPerfId = perfIdMap[oldPerfId] ?? oldPerfId;
      if (newPerfId != null) {
        await db.createCastMember(CastMember(
          performanceId: newPerfId,
          role: c['role'] as String,
          actorName: c['actor_name'] as String,
          isFeatured: (c['is_featured'] as int?) == 1 ||
              (c['is_featured'] as bool?) == true,
          createdAt: c['created_at'] as String?,
        ));
      }
    }

    final tickets = data['tickets'] as List<dynamic>? ?? [];
    for (final t in tickets) {
      final oldPerfId = t['performance_id'] as int?;
      final newPerfId = perfIdMap[oldPerfId] ?? oldPerfId;
      if (newPerfId != null) {
        await db.createTicket(Ticket(
          performanceId: newPerfId,
          seat: t['seat'] as String?,
          price: t['price'] != null ? (t['price'] as num).toDouble() : null,
          actualPrice: t['actual_price'] != null
              ? (t['actual_price'] as num).toDouble()
              : null,
        ));
      }
    }

    final todoItems = data['todoItems'] as List<dynamic>? ??
        (data['todo_items'] as List<dynamic>? ?? []);
    for (final t in todoItems) {
      final oldPerfId = t['performance_id'] as int?;
      final newPerfId = perfIdMap[oldPerfId] ?? oldPerfId;
      if (newPerfId != null) {
        await db.createTodoItem(TodoItem(
          performanceId: newPerfId,
          content: t['content'] as String,
          isDone: (t['is_done'] as int?) == 1 || (t['is_done'] as bool?) == true,
          sortOrder: t['sort_order'] as int? ?? 0,
          createdAt: t['created_at'] as String?,
        ));
      }
    }
  }
}
