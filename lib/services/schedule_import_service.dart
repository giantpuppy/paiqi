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
  static Future<String?> importBundleIfNeeded(String? username) async {
    if (username == null || username.isEmpty) return '未登录用户，跳过导入';

    final prefs = await SharedPreferences.getInstance();
    final flagKey = '$_prefKeyPrefix$username';
    if (prefs.getBool(flagKey) == true) {
      return null; // 已导入过
    }

    final result = await importBundle();
    if (result.startsWith('导入成功') || result.startsWith('新增')) {
      await prefs.setBool(flagKey, true);
    }
    return result;
  }

  /// 强制把数据包写入当前数据库。返回操作结果描述。
  static Future<String> importBundle() async {
    final db = DatabaseHelper.instance;
    final existingShows = await db.getAllShows();
    final existingKey = <String>{
      for (final s in existingShows) '${s.name}|${s.theater}',
    };

    int createdShows = 0;
    int createdPerformances = 0;
    int createdCasts = 0;
    int skippedShows = 0;

    for (final importShow in scheduleImportBundle) {
      final key = '${importShow.name}|${importShow.theater}';
      if (existingKey.contains(key)) {
        skippedShows++;
        continue;
      }

      final show = await db.createShow(Show(
        name: importShow.name,
        theater: importShow.theater,
        isInScheduleFlow: false,
        createdAt: DateTime.now().toIso8601String(),
      ));
      createdShows++;

      if (show.id == null) continue;
      existingKey.add(key);

      for (final importPerf in importShow.performances) {
        final perf = await db.createPerformance(Performance(
          showId: show.id!,
          date: importPerf.date,
          time: importPerf.time,
          status: 'unmarked',
          createdAt: DateTime.now().toIso8601String(),
        ));
        createdPerformances++;

        if (perf.id == null) continue;

        for (final importCast in importPerf.cast) {
          await db.createCastMember(CastMember(
            performanceId: perf.id!,
            role: importCast.role,
            actorName: importCast.actor,
            createdAt: DateTime.now().toIso8601String(),
          ));
          createdCasts++;
        }
      }
    }

    if (createdShows == 0 && skippedShows == scheduleImportBundle.length) {
      return '导入成功：所有剧目已存在，无需新增';
    }

    return '导入成功：新增 $createdShows 个剧目到管理台、$createdPerformances 场演出、'
        '$createdCasts 条卡司；跳过 $skippedShows 个重复剧目';
  }

  /// 重置当前用户的导入标记（调试用）。
  static Future<void> resetFlag(String? username) async {
    if (username == null || username.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefKeyPrefix$username');
  }
}
