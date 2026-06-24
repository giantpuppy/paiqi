import 'cover_import_helper_io.dart'
    if (dart.library.html) 'cover_import_helper_web.dart';

/// 匹配 covers 目录中的图片到数据库剧目（仅原生平台支持）
Future<void> importCovers() => importCoversImpl();
