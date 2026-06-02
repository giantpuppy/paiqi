import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 海报封面图片持久化工具
class CoverHelper {
  /// 过滤非法文件名字符
  static String sanitizeFileName(String name) {
    // 移除或替换操作系统非法字符: \ / : * ? " < > |
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  /// 保存海报图片到永久目录，返回绝对路径
  ///
  /// 命名规则: {剧目名称}_{时间戳}_封面.jpg
  static Future<String> saveCoverImage(String showName, Uint8List imageBytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final safeName = sanitizeFileName(showName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${safeName}_${timestamp}_封面.jpg';
    final filePath = p.join(coversDir.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    return filePath;
  }

  /// 编辑模式下改名联动：重命名海报文件以匹配新剧名
  ///
  /// 返回新的文件路径，如果旧路径为空或文件不存在则返回 null
  static Future<String?> renameCoverImage(String? oldPath, String newShowName) async {
    if (oldPath == null || oldPath.isEmpty) return null;

    final oldFile = File(oldPath);
    if (!await oldFile.exists()) return null;

    // 从旧文件名中提取时间戳
    // 格式: {name}_{timestamp}_封面.jpg
    final oldFileName = p.basename(oldPath);
    final timestampMatch = RegExp(r'_(\d+)_封面\.jpg$').firstMatch(oldFileName);
    final timestamp = timestampMatch?.group(1) ?? DateTime.now().millisecondsSinceEpoch.toString();

    final safeName = sanitizeFileName(newShowName);
    final newFileName = '${safeName}_${timestamp}_封面.jpg';
    final newFilePath = p.join(p.dirname(oldPath), newFileName);

    // 如果新旧路径相同（剧名没变），不需要重命名
    if (oldPath == newFilePath) return oldPath;

    // 重命名文件
    await oldFile.rename(newFilePath);
    return newFilePath;
  }

  /// 删除海报文件
  static Future<void> deleteCoverImage(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }
}
