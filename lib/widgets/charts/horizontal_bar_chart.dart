import 'package:flutter/material.dart';
import 'chart_theme.dart';
import 'simple_bar_chart.dart';

/// 横向条形图
///
/// 用于演员排名、剧场分布等排名类数据。
class HorizontalBarChart extends StatelessWidget {
  final List<ChartData> data;
  final Color accentColor;
  final String? title;
  final int displayCount;
  final bool expandable;

  const HorizontalBarChart({
    super.key,
    required this.data,
    required this.accentColor,
    this.title,
    this.displayCount = 5,
    this.expandable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final showExpand = expandable && data.length > displayCount;

    return StatefulBuilder(
      builder: (context, setState) {
        return _HorizontalBarChartContent(
          data: data,
          maxValue: maxValue,
          accentColor: accentColor,
          title: title,
          displayCount: displayCount,
          showExpand: showExpand,
        );
      },
    );
  }
}

class _HorizontalBarChartContent extends StatefulWidget {
  final List<ChartData> data;
  final int maxValue;
  final Color accentColor;
  final String? title;
  final int displayCount;
  final bool showExpand;

  const _HorizontalBarChartContent({
    required this.data,
    required this.maxValue,
    required this.accentColor,
    this.title,
    required this.displayCount,
    required this.showExpand,
  });

  @override
  State<_HorizontalBarChartContent> createState() =>
      _HorizontalBarChartContentState();
}

class _HorizontalBarChartContentState
    extends State<_HorizontalBarChartContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final displayList = _expanded
        ? widget.data
        : widget.data.take(widget.displayCount).toList();

    return Container(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      decoration: BoxDecoration(
        color: ChartTheme.background,
        borderRadius: BorderRadius.circular(ChartTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.title != null)
                Text(
                  widget.title!,
                  style: const TextStyle(
                    fontSize: ChartTheme.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: ChartTheme.label,
                  ),
                ),
              const Spacer(),
              if (widget.showExpand)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? '收起' : '查看全部 ${widget.data.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ChartTheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayList.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final progress =
                widget.maxValue > 0 ? item.value / widget.maxValue : 0.0;
            final isTop3 = index < 3;
            final barColor = isTop3 ? ChartTheme.watched : widget.accentColor;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isTop3 ? ChartTheme.watched : ChartTheme.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ChartTheme.value,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: ChartTheme.grid,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              width: constraints.maxWidth * progress,
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    barColor,
                                    barColor.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${item.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ChartTheme.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
