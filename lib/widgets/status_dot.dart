import 'package:flutter/material.dart';

/// 状态标记圆点
///
/// 用于日历、列表等场景标记演出状态。
/// 颜色由调用方传入，保持灵活。
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.size = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
