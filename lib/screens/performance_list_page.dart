import 'package:flutter/material.dart';
import '../models/performance.dart';
import '../models/show.dart';
import '../models/cast_member.dart';
import '../widgets/charts/chart_theme.dart';
import '../widgets/poster_fallback.dart';
import '../widgets/breathing_icon.dart';

/// 场次列表详情页 —— 展示完整的想看/已买列表（从个人中心"查看全部"跳转）
class PerformanceListPage extends StatelessWidget {
  final String title;
  final List<Performance> performances;
  final List<Show> shows;
  final List<CastMember> castMembers;

  const PerformanceListPage({
    super.key,
    required this.title,
    required this.performances,
    required this.shows,
    required this.castMembers,
  });

  Show? _showForPerformance(Performance performance) {
    try {
      return shows.firstWhere((s) => s.id == performance.showId);
    } catch (_) {
      return null;
    }
  }

  List<String> _actorsForPerformance(Performance performance) {
    return castMembers
        .where((cm) => cm.performanceId == performance.id)
        .map((cm) => cm.actorName)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
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
      body: performances.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BreathingIcon(
                    icon: Icons.inbox_outlined,
                    size: 48,
                    color: ChartTheme.muted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: ChartTheme.muted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              itemCount: performances.length,
              itemBuilder: (context, index) {
                final performance = performances[index];
                final show = _showForPerformance(performance);
                final actors = _actorsForPerformance(performance);
                return _buildRow(
                  context: context,
                  performance: performance,
                  show: show,
                  actors: actors,
                  showDivider: index > 0,
                );
              },
            ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required Performance performance,
    required Show? show,
    required List<String> actors,
    required bool showDivider,
  }) {
    final date = DateTime.tryParse(performance.date);
    final dateText =
        date != null ? '${date.month}/${date.day}' : performance.date;
    final actorText = actors.isNotEmpty ? actors.join('、') : '';

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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: ChartTheme.grid,
            ),
            clipBehavior: Clip.antiAlias,
            child: show != null
                ? PosterFallback(
                    showId: show.id ?? 0,
                    showName: show.name,
                    fontSize: 18,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show?.name ?? '未知剧目',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                if (actorText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    actorText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
