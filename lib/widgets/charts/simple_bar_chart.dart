import 'package:flutter/material.dart';
import 'chart_theme.dart';

class ChartData {
  final String label;
  final int value;

  const ChartData({required this.label, required this.value});
}

/// 简单柱状图
///
/// 用于展示月度观演节奏等时间序列数据。
class SimpleBarChart extends StatelessWidget {
  final List<ChartData> data;
  final Color? activeColor;
  final String? title;
  final bool showValueLabels;
  final int? highlightIndex;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.activeColor,
    this.title,
    this.showValueLabels = true,
    this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.isEmpty
        ? 1
        : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (index) {
              final item = data[index];
              final height = maxValue > 0
                  ? (item.value / maxValue * 80).clamp(4.0, 80.0)
                  : 4.0;
              final isHighlight = index == highlightIndex;
              final color = isHighlight
                  ? (activeColor ?? ChartTheme.primary)
                  : ChartTheme.barDefault;

              return Column(
                children: [
                  if (showValueLabels && item.value > 0)
                    Text(
                      '${item.value}',
                      style: const TextStyle(
                        fontSize: ChartTheme.valueFontSize,
                        color: ChartTheme.muted,
                      ),
                    ),
                  if (showValueLabels && item.value > 0)
                    const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 18,
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(ChartTheme.barRadius),
                      boxShadow: isHighlight
                          ? [
                              BoxShadow(
                                color: ChartTheme.glow(
                                    activeColor ?? ChartTheme.primary, 0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: ChartTheme.valueFontSize,
                      color: isHighlight
                          ? ChartTheme.label
                          : ChartTheme.muted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
