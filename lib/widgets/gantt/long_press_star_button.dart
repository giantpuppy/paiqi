import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';

/// 可长按的动画星星
///
/// - unmarked：灰色空心星，长按逐渐填满为紫色（want_to_see）
/// - want_to_see：紫色实心星，长按逐渐清空为灰色（unmarked）
/// - bought / watched：仅展示对应颜色实心星，不响应长按
class LongPressStarButton extends StatefulWidget {
  final String status;
  final VoidCallback onStatusChanged;
  final double size;

  const LongPressStarButton({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.size = 24,
  });

  @override
  State<LongPressStarButton> createState() => _LongPressStarButtonState();
}

class _LongPressStarButtonState extends State<LongPressStarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isLongPressing) {
      widget.onStatusChanged();
    }
  }

  bool get _canToggle {
    return widget.status == 'unmarked' || widget.status == 'want_to_see';
  }

  bool get _isReverse {
    // want_to_see 时，动画是从紫色退回到灰色
    return widget.status == 'want_to_see';
  }

  Color get _baseColor {
    return switch (widget.status) {
      'want_to_see' => const Color(0xFF811FE2),
      'bought' => statusColor('bought'),
      'watched' => statusColor('watched'),
      _ => const Color(0xFF555555),
    };
  }

  Color get _targetColor {
    return switch (widget.status) {
      'want_to_see' => const Color(0xFF555555),
      _ => const Color(0xFF811FE2),
    };
  }

  IconData get _icon {
    return widget.status == 'unmarked' ? Icons.star_border : Icons.star_rounded;
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (!_canToggle || !mounted) return;
    setState(() => _isLongPressing = true);
    if (_isReverse) {
      _controller.forward();
    } else {
      _controller.forward();
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _cancelOrComplete();
  }

  void _onLongPressCancel() {
    _cancelOrComplete();
  }

  void _cancelOrComplete() {
    if (!mounted) return;
    setState(() => _isLongPressing = false);
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant LongPressStarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _baseColor.withValues(alpha: 0.15);
    final glowColor = _baseColor.withValues(alpha: 0.35);

    Widget star = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 填充进度：unmarked 时 0→1 填满；want_to_see 时视觉上是从紫退到灰
        final fillRatio = _isReverse ? 1.0 - t : t;

        return Container(
          padding: EdgeInsets.all(widget.size * 0.22),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: widget.status == 'unmarked'
                ? null
                : [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 10 + t * 6,
                      spreadRadius: t * 2,
                    ),
                  ],
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 底色星星（起始状态）
                Icon(
                  _icon,
                  color: _baseColor,
                  size: widget.size,
                ),
                // 目标颜色遮罩层，随动画展开
                ClipRect(
                  clipper: _StarClipper(fillRatio),
                  child: Icon(
                    Icons.star_rounded,
                    color: _targetColor,
                    size: widget.size,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!_canToggle) {
      return star;
    }

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: star,
    );
  }
}

/// 从左到右展开的 Clipper，模拟星星逐渐填满
class _StarClipper extends CustomClipper<Rect> {
  final double fillRatio;

  _StarClipper(this.fillRatio);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      0,
      size.width * fillRatio.clamp(0.0, 1.0),
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => true;
}
