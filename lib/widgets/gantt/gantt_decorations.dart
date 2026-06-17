import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';

/// 剧场节目单风格标题：居中文字 + 两侧渐变装饰线。
class TheaterProgramHeader extends StatelessWidget {
  final String title;
  final double screenWidth;
  final VoidCallback? onTap;

  const TheaterProgramHeader({
    super.key,
    required this.title,
    required this.screenWidth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lineWidth = screenWidth * 0.07;
    final lineHeight = screenWidth * 0.0025;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLine(lineWidth, lineHeight, true),
        SizedBox(width: screenWidth * 0.03),
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.052,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        SizedBox(width: screenWidth * 0.03),
        _buildLine(lineWidth, lineHeight, false),
      ],
    );

    if (onTap != null) {
      child = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return child;
  }

  Widget _buildLine(double width, double height, bool fadeFromCenter) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fadeFromCenter ? Alignment.centerRight : Alignment.centerLeft,
          end: fadeFromCenter ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// 极淡垂直渐变纹理，用于空行营造天鹅绒幕布质感。
class VelvetTexture extends StatelessWidget {
  final Widget child;

  const VelvetTexture({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.012),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.018),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 邮票风格时间显示：大号、加粗、无 emoji。
class StampTime extends StatelessWidget {
  final String time;
  final double width;
  final bool isToday;

  const StampTime({
    super.key,
    required this.time,
    required this.width,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      time,
      style: TextStyle(
        color: isToday ? kWarmGold : Colors.white,
        fontSize: width * 0.085,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
