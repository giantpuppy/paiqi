import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // 颜色常量
  final bg = img.ColorUint8.rgb(0x1A, 0x0F, 0x2E);
  final calendarColor = img.ColorUint8.rgb(0x2D, 0x1B, 0x4E);
  final headerColor = img.ColorUint8.rgb(0x7B, 0x61, 0xFF);
  final ticketColor = img.ColorUint8.rgb(0x9B, 0x7B, 0xFF);
  final white = img.ColorUint8.rgb(0xFF, 0xFF, 0xFF);

  // 背景：深紫黑
  img.fill(image, color: bg);

  // 中心柔光晕（径向渐变模拟）
  _drawRadialGlow(image, cx: size ~/ 2, cy: size ~/ 2, radius: 520,
      inner: 0xFF2D1B4E, outer: 0xFF1A0F2E);

  // 月历主体：深紫圆角矩形
  const calendarSize = 600;
  const calendarRadius = 80;
  const calendarX = (size - calendarSize) ~/ 2;
  const calendarY = (size - calendarSize) ~/ 2;
  _drawRoundRect(
    image,
    x: calendarX,
    y: calendarY,
    w: calendarSize,
    h: calendarSize,
    r: calendarRadius,
    color: calendarColor,
    cornerColor: bg,
  );

  // 月历顶部月份条：品牌紫（位于月历主体内部，用月历色切下角）
  const headerHeight = 150;
  _drawRoundRect(
    image,
    x: calendarX,
    y: calendarY,
    w: calendarSize,
    h: headerHeight,
    r: calendarRadius,
    color: headerColor,
    cornerColor: bg,
    bottomCornerColor: calendarColor,
  );

  // 日历挂环：两个白色小圆
  const ringRadius = 18;
  const ringY = calendarY - 8;
  img.fillCircle(
    image,
    x: (calendarX + calendarSize * 0.35).toInt(),
    y: ringY,
    radius: ringRadius,
    color: white,
  );
  img.fillCircle(
    image,
    x: (calendarX + calendarSize * 0.65).toInt(),
    y: ringY,
    radius: ringRadius,
    color: white,
  );

  // 日期网格：2 行 3 列白色小圆点
  const dotRadius = 16;
  const dotStartY = calendarY + headerHeight + 110;
  const dotSpacingX = 140;
  const dotSpacingY = 110;
  const dotsCenterX = size ~/ 2;
  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 3; col++) {
      final x = dotsCenterX + (col - 1) * dotSpacingX;
      final y = dotStartY + row * dotSpacingY;
      img.fillCircle(image, x: x, y: y, radius: dotRadius, color: white);
    }
  }

  // 票根：贴在月历右下角内部，淡紫色，带齿孔
  const ticketW = 300;
  const ticketH = 160;
  const ticketX = calendarX + calendarSize - ticketW - 40;
  const ticketY = calendarY + calendarSize - ticketH - 40;
  const ticketRadius = 24;
  _drawRoundRect(
    image,
    x: ticketX,
    y: ticketY,
    w: ticketW,
    h: ticketH,
    r: ticketRadius,
    color: ticketColor,
    cornerColor: calendarColor,
  );

  // 票根左侧两个齿孔（用月历色切出）
  const notchRadius = 16;
  img.fillCircle(
    image,
    x: ticketX,
    y: (ticketY + ticketH * 0.3).toInt(),
    radius: notchRadius,
    color: calendarColor,
  );
  img.fillCircle(
    image,
    x: ticketX,
    y: (ticketY + ticketH * 0.7).toInt(),
    radius: notchRadius,
    color: calendarColor,
  );

  // 票根中间虚线
  const dashY = ticketY + ticketH ~/ 2;
  for (var i = 0; i < 5; i++) {
    final dx = ticketX + 60 + i * 42;
    img.fillRect(
      image,
      x1: dx,
      y1: dashY - 4,
      x2: dx + 24,
      y2: dashY + 4,
      color: white,
    );
  }

  // 保存
  final png = img.encodePng(image);
  File('assets/icon_source.png').writeAsBytesSync(png);
  print('Generated assets/icon_source.png');
}

/// 画一个带圆角的填充矩形
/// - cornerColor：四个角外侧用来切圆角的颜色
/// - bottomCornerColor：如果不为空，用于下角；否则用 cornerColor
void _drawRoundRect(
  img.Image image, {
  required int x,
  required int y,
  required int w,
  required int h,
  required int r,
  required img.Color color,
  required img.Color cornerColor,
  img.Color? bottomCornerColor,
}) {
  final bc = bottomCornerColor ?? cornerColor;
  // 填充整个矩形区域
  img.fillRect(image, x1: x, y1: y, x2: x + w, y2: y + h, color: color);
  // 用对应颜色切掉四个角外侧
  img.fillCircle(image, x: x, y: y, radius: r, color: cornerColor);
  img.fillCircle(image, x: x + w, y: y, radius: r, color: cornerColor);
  img.fillCircle(image, x: x, y: y + h, radius: r, color: bc);
  img.fillCircle(image, x: x + w, y: y + h, radius: r, color: bc);
}

/// 简单径向渐变：从中心 inner 到 outer 的纯色过渡
void _drawRadialGlow(img.Image image,
    {required int cx,
    required int cy,
    required int radius,
    required int inner,
    required int outer}) {
  final ir = (inner >> 16) & 0xFF;
  final ig = (inner >> 8) & 0xFF;
  final ib = inner & 0xFF;
  final or = (outer >> 16) & 0xFF;
  final og = (outer >> 8) & 0xFF;
  final ob = outer & 0xFF;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > radius) continue;
      final t = dist / radius;
      final r = (ir + (or - ir) * t).round();
      final g = (ig + (og - ig) * t).round();
      final b = (ib + (ob - ib) * t).round();
      image.setPixel(x, y, img.ColorUint8.rgb(r, g, b));
    }
  }
}
