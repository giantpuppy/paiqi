import 'package:flutter/material.dart';

/// 光岛卡片容器
///
/// 用于详情页等「黑暗中的光」场景：比页面背景稍亮的底色 + 柔和光晕 + 圆角，
/// 营造独立浮岛感。支持点击反馈。
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? glowColor;
  final double borderRadius;
  final double glowBlur;
  final double spreadRadius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const GlowCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.glowColor,
    this.borderRadius = 12,
    this.glowBlur = 16,
    this.spreadRadius = 0,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final baseBackground = backgroundColor ?? Colors.white.withValues(alpha: 0.03);
    final baseGlow = (glowColor ?? Colors.white).withValues(alpha: 0.04);

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: baseGlow,
            blurRadius: glowBlur,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: card,
        ),
      );
    }

    return card;
  }
}
