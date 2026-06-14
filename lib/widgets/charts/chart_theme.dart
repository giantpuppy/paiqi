import 'package:flutter/material.dart';

/// 图表主题常量
///
/// 统一个人中心、年历页等场景下图表的颜色、间距、字体规范。
class ChartTheme {
  // 背景与辅助
  static const Color background = Color(0xFF181818);
  static const Color grid = Color(0xFF2A2A2A);
  static const Color barDefault = Color(0xFF4D4D4D);

  // 强调色
  static const Color primary = Color(0xFF6B5BCD);
  static const Color bought = Color(0xFF34D399);
  static const Color wantToSee = Color(0xFF811FE2);
  static const Color watched = Color(0xFFD4A853);

  // 文字
  static const Color label = Color(0xFFB3B3B3);
  static const Color value = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF7C7C7C);

  // 间距
  static const double cardPadding = 20.0;
  static const double cardRadius = 16.0;
  static const double barSpacing = 6.0;
  static const double barRadius = 4.0;

  // 字体
  static const double titleFontSize = 14.0;
  static const double labelFontSize = 12.0;
  static const double valueFontSize = 11.0;

  // 光效
  static Color glow(Color color, double intensity) =>
      color.withValues(alpha: intensity);
}
