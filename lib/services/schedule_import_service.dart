import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/schedule_import_bundle.dart';
import '../database/database_helper.dart';
import '../models/cast_member.dart';
import '../models/performance.dart';
import '../models/show.dart';

/// 一次性卡司排期汇总表导入服务。
/// 在应用启动时调用 [importBundleIfNeeded]，会为当前登录账号自动写入
/// `scheduleImportBundle` 中的剧目、场次与卡司，并按用户名记录完成标记。
class ScheduleImportService {
  static const _prefKeyPrefix = 'schedule_import_done_';

  /// 如果当前用户尚未导入，则执行导入。
  /// [autoJoinScheduleFlow] 为 true 时，导入后自动将所有数据加入排期流（用于 Demo 模式）。
  static Future<String?> importBundleIfNeeded(
    String? username, {
    bool autoJoinScheduleFlow = false,
  }) async {
    if (username == null || username.isEmpty) return '未登录用户，跳过导入';

    final prefs = await SharedPreferences.getInstance();
    final flagKey = '$_prefKeyPrefix$username';
    if (prefs.getBool(flagKey) == true) {
      return null; // 已导入过
    }

    final result = await importBundle(
      autoJoinScheduleFlow: autoJoinScheduleFlow,
    );
    if (result.startsWith('导入成功') || result.startsWith('新增')) {
      await prefs.setBool(flagKey, true);
    }
    return result;
  }

  /// 强制把数据包写入当前数据库。返回操作结果描述。
  /// [autoJoinScheduleFlow] 为 true 时，导入后自动将所有数据加入排期流。
  static Future<String> importBundle({bool autoJoinScheduleFlow = false}) async {
    final db = DatabaseHelper.instance;
    final existingShows = await db.getAllShows();
    final existingShowMap = <String, Show>{
      for (final s in existingShows) '${s.name}|${s.theater}': s,
    };

    // 已存在场次的唯一键 → performance id
    final existingPerformances = await db.getAllPerformances();
    final existingPerfMap = <String, int>{
      for (final p in existingPerformances)
        if (p.id != null) '${p.showId}|${p.date}|${p.time}': p.id!,
    };

    int createdShows = 0;
    int createdPerformances = 0;
    int createdCasts = 0;
    int skippedShows = 0;
    int skippedPerformances = 0;

    for (final importShow in scheduleImportBundle) {
      final showKey = '${importShow.name}|${importShow.theater}';
      late final Show show;

      if (existingShowMap.containsKey(showKey)) {
        show = existingShowMap[showKey]!;
        skippedShows++;
      } else {
        show = await db.createShow(Show(
          name: importShow.name,
          theater: importShow.theater,
          isInScheduleFlow: false,
          createdAt: DateTime.now().toIso8601String(),
        ));
        createdShows++;
        existingShowMap[showKey] = show;
      }

      if (show.id == null) continue;

      for (final importPerf in importShow.performances) {
        final perfKey = '${show.id}|${importPerf.date}|${importPerf.time}';
        int? perfId;

        if (existingPerfMap.containsKey(perfKey)) {
          perfId = existingPerfMap[perfKey];
          skippedPerformances++;
        } else {
          final perf = await db.createPerformance(Performance(
            showId: show.id!,
            date: importPerf.date,
            time: importPerf.time,
            status: 'unmarked',
            createdAt: DateTime.now().toIso8601String(),
          ));
          createdPerformances++;
          perfId = perf.id;
          if (perfId != null) {
            existingPerfMap[perfKey] = perfId;
          }
        }

        if (perfId == null) continue;

        // 检查该场次是否已有卡司，没有则补充
        final existingCasts = await db.getCastMembersByPerformanceId(perfId);
        if (existingCasts.isNotEmpty) continue;

        for (final importCast in importPerf.cast) {
          await db.createCastMember(CastMember(
            performanceId: perfId,
            role: importCast.role,
            actorName: importCast.actor,
            createdAt: DateTime.now().toIso8601String(),
          ));
          createdCasts++;
        }
      }
    }

    // Demo 模式：自动将所有导入数据加入排期流，确保打开月历/排期页/管理台即可见
    if (kIsWeb || autoJoinScheduleFlow) {
      final showsToFlow = await db.getAllShows();
      for (final show in showsToFlow) {
        if (!show.isInScheduleFlow) {
          await db.updateShow(show.copyWith(isInScheduleFlow: true));
        }
      }
      final perfsToFlow = await db.getAllPerformances();
      for (final perf in perfsToFlow) {
        if (!perf.isInScheduleFlow) {
          await db.updatePerformance(perf.copyWith(isInScheduleFlow: true));
        }
      }
    }

    if (createdShows == 0 && createdPerformances == 0 && createdCasts == 0) {
      return '导入成功：所有剧目和场次已存在，无需新增';
    }

    return '导入成功：新增 $createdShows 个剧目、$createdPerformances 场演出、'
        '$createdCasts 条卡司；跳过 $skippedShows 个重复剧目、'
        '$skippedPerformances 个重复场次';
  }

  /// 重置当前用户的导入标记（调试用）。
  static Future<void> resetFlag(String? username) async {
    if (username == null || username.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefKeyPrefix$username');
  }
}
