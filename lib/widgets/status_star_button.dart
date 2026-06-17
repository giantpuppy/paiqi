import 'package:flutter/material.dart';
import '../utils/status_colors.dart';

/// 状态星星按钮
///
/// 详情页右上角的状态入口，循环切换：未标记 → 想看 → 已买 → 未标记。
/// watched 不进入循环，由 bought + 日期已过 自动推导显示。
class StatusStarButton extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  final double size;

  const StatusStarButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final isUnmarked = status == 'unmarked';
    final isWantToSee = status == 'want_to_see';
    final isBought = status == 'bought';
    final isWatched = status == 'watched';

    final color = isWantToSee
        ? const Color(0xFF811FE2)
        : isBought
            ? statusColor('bought')
            : isWatched
                ? statusColor('watched')
                : const Color(0xFF555555);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isUnmarked
              ? Colors.white.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          boxShadow: isUnmarked
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Icon(
          isUnmarked ? Icons.star_border : Icons.star_rounded,
          color: color,
          size: size,
        ),
      ),
    );
  }
}
