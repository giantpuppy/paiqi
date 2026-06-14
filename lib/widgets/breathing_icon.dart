import 'package:flutter/material.dart';

/// 呼吸动画图标
///
/// 用于空状态、引导页等场景，图标上下浮动，营造呼吸感。
class BreathingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Duration duration;

  const BreathingIcon({
    super.key,
    required this.icon,
    this.size = 72,
    this.color = const Color(0xFF4D4D4D),
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<BreathingIcon>
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
    _animation = Tween<double>(begin: 0, end: 4).animate(
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
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -_animation.value),
        child: child,
      ),
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}
