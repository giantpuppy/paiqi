import 'package:flutter/material.dart';
import '../widgets/charts/chart_theme.dart';

/// 排名详情页 —— 展示完整的排名列表（从个人中心"查看全部"跳转）
class RankingDetailPage extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> data;
  final Color accentColor;

  const RankingDetailPage({
    super.key,
    required this.title,
    required this.data,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue =
        data.isNotEmpty ? data.first.value.toDouble() : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E14),
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: Colors.white.withValues(alpha: 0.7),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: data.isEmpty
          ? Center(
              child: Text(
                '暂无数据',
                style: TextStyle(
                  fontSize: 14,
                  color: ChartTheme.muted.withValues(alpha: 0.7),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final rank = index + 1;
                final ratio =
                    maxValue > 0 ? item.value / maxValue : 0.0;
                return _buildRow(
                  context: context,
                  rank: rank,
                  name: item.key,
                  count: item.value,
                  ratio: ratio,
                  showDivider: index > 0,
                );
              },
            ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required int rank,
    required String name,
    required int count,
    required double ratio,
    required bool showDivider,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: rank <= 3
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                // 进度条
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: ChartTheme.grid.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
