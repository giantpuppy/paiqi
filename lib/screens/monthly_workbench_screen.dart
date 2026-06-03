import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import 'add_show_screen.dart';

/// 月度管理工作台
/// 按剧目聚合显示某个月份的所有演出，支持全量编辑
class MonthlyWorkbenchScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyWorkbenchScreen({
    super.key,
    required this.year,
    required this.month,
  });

  @override
  State<MonthlyWorkbenchScreen> createState() => _MonthlyWorkbenchScreenState();
}

class _MonthlyWorkbenchScreenState extends State<MonthlyWorkbenchScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _performances = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final perfs = await db.getPerformancesByMonth(widget.year, widget.month);
    setState(() {
      _performances = perfs;
      _isLoading = false;
    });
  }

  /// 按剧目名称分组
  Map<String, List<Map<String, dynamic>>> get _groupedByShow {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final perf in _performances) {
      final showName = perf['show_name'] as String? ?? '未知剧目';
      groups.putIfAbsent(showName, () => []).add(perf);
    }
    return groups;
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'bought':
        return const Color(0xFF34D399);
      case 'want_to_see':
        return const Color(0xFF6B5BCD);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'bought':
        return '已购';
      case 'want_to_see':
        return '想看';
      default:
        return '未标';
    }
  }

  Future<void> _editPerformance(Map<String, dynamic> perf) async {
    final showId = perf['show_id'] as int;
    final db = DatabaseHelper.instance;

    final show = await db.getShowById(showId);
    final perfs = await db.getPerformancesByShowId(showId);

    if (show == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddShowScreen(
          initialShow: show,
          initialPerformances: perfs,
          isEditMode: true,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = widget.month.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.year}年${widget.month}月',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Text(
              '管理台',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8F98), fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B5BCD)))
          : _performances.isEmpty
              ? _buildEmptyState()
              : _buildGroupedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            '${widget.year}年${widget.month}月暂无演出',
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupedByShow;
    final showNames = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: showNames.length,
      itemBuilder: (context, index) {
        final showName = showNames[index];
        final perfs = groups[showName]!;
        return _buildShowCard(showName, perfs);
      },
    );
  }

  Widget _buildShowCard(String showName, List<Map<String, dynamic>> perfs) {
    final coverPath = perfs.first['cover_path'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 剧目标题行
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 海报缩略图
                _buildMiniCover(coverPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${perfs.length} 场演出',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 分隔线
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          // 演出列表
          ...perfs.map((perf) => _buildPerformanceItem(perf)),
        ],
      ),
    );
  }

  Widget _buildMiniCover(String? coverPath) {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverPath != null && coverPath.isNotEmpty
          ? Image.file(File(coverPath), fit: BoxFit.cover)
          : Container(
              color: const Color(0xFF2A2A2A),
              child: Icon(Icons.image, size: 20, color: Colors.white.withOpacity(0.2)),
            ),
    );
  }

  Widget _buildPerformanceItem(Map<String, dynamic> perf) {
    final date = perf['date'] as String? ?? '';
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final theater = perf['theater'] as String? ?? '';
    final status = perf['status'] as String?;
    final seat = perf['seat'] as String?;
    final price = perf['price'] != null ? (perf['price'] as num).toDouble() : null;

    return InkWell(
      onTap: () => _editPerformance(perf),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
          ),
        ),
        child: Row(
          children: [
            // 日期列
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.substring(5), // MM-DD
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 剧院 + 座位 + 价格
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theater,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (seat != null && seat.isNotEmpty)
                    Text(
                      '座位: $seat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  if (price != null)
                    Text(
                      '¥${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                ],
              ),
            ),
            // 状态标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.3), width: 0.5),
              ),
              child: Text(
                _getStatusLabel(status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 编辑箭头
            Icon(Icons.chevron_right, size: 18, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
