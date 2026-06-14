import 'dart:math';
import 'package:flutter/material.dart';
import 'chart_theme.dart';

/// 环形图
///
/// 用于时段偏好等占比类数据。
class DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  final String? title;

  const DonutChart({
    super.key,
    required this.data,
    required this.colors,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      decoration: BoxDecoration(
        color: ChartTheme.background,
        borderRadius: BorderRadius.circular(ChartTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: ChartTheme.titleFontSize,
                fontWeight: FontWeight.w600,
                color: ChartTheme.label,
              ),
            ),
          if (title != null) const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    data: data,
                    colors: colors,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: entries.map((entry) {
                    final index = entries.indexOf(entry);
                    final percent = (entry.value / total * 100)
                        .toStringAsFixed(0);
                    final color = colors[index % colors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ChartTheme.value,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$percent% (${entry.value}场)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ChartTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  _DonutChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.6;
    final strokeWidth = radius - innerRadius;

    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    var startAngle = -pi / 2;
    final entries = data.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
