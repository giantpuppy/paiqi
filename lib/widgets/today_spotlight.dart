import 'package:flutter/material.dart';

/// 今日追光呼吸效果
///
/// 用于日历单元格，给"今天"一个柔和的舞台追光外发光。
/// 动画在 opacity / blurRadius / spreadRadius 之间缓慢呼吸。
class TodaySpotlight extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration duration;

  const TodaySpotlight({
    super.key,
    required this.child,
    this.color = const Color(0xFF6B5BCD),
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<TodaySpotlight> createState() => _TodaySpotlightState();
}

class _TodaySpotlightState extends State<TodaySpotlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final alpha = 0.15 + (0.15 * t); // 0.15 ~ 0.3
        final blurRadius = 8.0 + (8.0 * t); // 8 ~ 16
        final spreadRadius = 1.0 + (2.0 * t); // 1 ~ 3

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha((255 * alpha).round()),
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
