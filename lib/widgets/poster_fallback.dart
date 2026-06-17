import 'package:flutter/material.dart';
import '../utils/status_colors.dart';

/// 无海报时的剧名大字占位海报
class PosterFallback extends StatelessWidget {
  final int showId;
  final String showName;
  final double fontSize;

  const PosterFallback({
    super.key,
    required this.showId,
    required this.showName,
    this.fontSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final color1 = coverColorForShow(showId);
    final color2 = kCoverColors[(showId.abs() + 3) % kCoverColors.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            showName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
