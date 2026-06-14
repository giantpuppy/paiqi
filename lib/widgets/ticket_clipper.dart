import 'package:flutter/material.dart';

/// 票根齿孔裁剪器
///
/// 在卡片左右两侧剪出内凹半圆，模拟电影票/火车票的齿孔效果。
/// 可用于月历首页、详情页等票根风格卡片。
class TicketClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double cornerRadius;

  const TicketClipper({
    this.notchRadius = 12.0,
    this.cornerRadius = 12.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final notchCenterY = size.height / 2;

    // 左上角圆角
    path.moveTo(cornerRadius, 0);
    // 上边
    path.lineTo(size.width - cornerRadius, 0);
    // 右上角圆角
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    // 右边到上齿孔
    path.lineTo(size.width, notchCenterY - notchRadius);
    // 上齿孔（向内凹）
    path.arcToPoint(
      Offset(size.width, notchCenterY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    // 右边到下齿孔
    path.lineTo(size.width, size.height - cornerRadius);
    // 右下角圆角
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );
    // 下边
    path.lineTo(cornerRadius, size.height);
    // 左下角圆角
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    // 左边到下齿孔
    path.lineTo(0, notchCenterY + notchRadius);
    // 下齿孔（向内凹）
    path.arcToPoint(
      Offset(0, notchCenterY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    // 左边到上
    path.lineTo(0, cornerRadius);
    // 左上角圆角
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
