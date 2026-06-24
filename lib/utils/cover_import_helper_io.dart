import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import 'cover_helper.dart';

/// 匹配 covers 目录中的图片到数据库剧目
Future<void> importCoversImpl() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) return;

    final files = coversDir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'),
    ).toList();
    if (files.isEmpty) return;

    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();

    int imported = 0;
    for (final show in shows) {
      if (show.coverPath != null && show.coverPath!.isNotEmpty) {
        final existing = File(show.coverPath!);
        if (await existing.exists()) continue;
      }

      final safeName = CoverHelper.sanitizeFileName(show.name);
      File? bestMatch;

      for (final file in files) {
        final baseName = p.basename(file.path).toLowerCase();
        final nameWithoutExt = p.basenameWithoutExtension(file.path).toLowerCase();
        final showNameLower = show.name.toLowerCase();
        final safeNameLower = safeName.toLowerCase();

        // 精确前缀匹配
        if (baseName.startsWith(safeNameLower) ||
            nameWithoutExt.startsWith(showNameLower) ||
            nameWithoutExt.startsWith(safeNameLower)) {
          bestMatch = file;
          break;
        }
        // 模糊包含匹配：文件名包含剧名，或剧名包含文件名（≥2字符）
        if ((nameWithoutExt.contains(showNameLower) && showNameLower.length >= 2) ||
            (showNameLower.contains(nameWithoutExt) && nameWithoutExt.length >= 2)) {
          bestMatch = file;
          break;
        }
      }

      if (bestMatch == null) continue;

      final newPath = p.join(coversDir.path, '${safeName}_封面.jpg');
      if (bestMatch.path != newPath) {
        if (await File(newPath).exists()) {
          await File(newPath).delete();
        }
        await bestMatch.rename(newPath);
      }

      await db.updateShow(show.copyWith(coverPath: newPath));
      imported++;
      debugPrint('[CoverImport] 已导入: ${show.name}');
    }

    if (imported > 0) {
      debugPrint('[CoverImport] 完成，共导入 $imported 张海报');
    }
  } catch (e) {
    debugPrint('[CoverImport] 错误: $e');
  }
}
