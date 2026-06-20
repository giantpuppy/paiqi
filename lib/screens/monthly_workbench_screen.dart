import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../utils/status_colors.dart';
import '../widgets/breathing_icon.dart';
import 'add_show_screen.dart';
import 'show_management_screen.dart';

/// 月度管理工作台 — 海报网格画廊
/// 2列海报网格，年月选择器，点击进入剧目管理
class MonthlyWorkbenchScreen extends StatefulWidget {
  final int year;
  final int month;
  final bool embedded;
  final void Function(int year, int month)? onMonthChanged;
  final ValueNotifier<int>? reloadSignal;

  const MonthlyWorkbenchScreen({
    super.key,
    required this.year,
    required this.month,
    this.embedded = false,
    this.onMonthChanged,
    this.reloadSignal,
  });

  @override
  State<MonthlyWorkbenchScreen> createState() => _MonthlyWorkbenchScreenState();
}

class _ShowStats {
  final int totalCount;
  final int flowCount;
  final String? startDate;
  final String? endDate;

  const _ShowStats({
    required this.totalCount,
    required this.flowCount,
    this.startDate,
    this.endDate,
  });
}

class _MonthlyWorkbenchScreenState extends State<MonthlyWorkbenchScreen> {
  bool _isLoading = true;
  late int _year;
  late int _month;
  List<Show> _shows = [];
  Map<int, _ShowStats> _showStats = {};
  double? _dragStartX;
  double? _dragCurrentX;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
    _loadData();
    widget.reloadSignal?.addListener(_onReloadSignal);
  }

  @override
  void didUpdateWidget(MonthlyWorkbenchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _year = widget.year;
      _month = widget.month;
      _loadData();
    }
    if (oldWidget.reloadSignal != widget.reloadSignal) {
      oldWidget.reloadSignal?.removeListener(_onReloadSignal);
      widget.reloadSignal?.addListener(_onReloadSignal);
    }
  }

  @override
  void dispose() {
    widget.reloadSignal?.removeListener(_onReloadSignal);
    super.dispose();
  }

  void _onReloadSignal() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final perfs = await db.getPerformancesByMonth(_year, _month);

    // 按 showId 去重，获取当月有演出的剧目列表
    final showIds = <int>{};
    for (final perf in perfs) {
      showIds.add(perf['show_id'] as int);
    }

    final shows = <Show>[];
    final stats = <int, _ShowStats>{};
    for (final showId in showIds) {
      final show = await db.getShowById(showId);
      if (show == null) continue;
      shows.add(show);

      // 查询该剧目所有场次（含跨月），计算统计与起止日期
      final allPerfs = await db.getPerformancesByShowId(showId);
      final total = allPerfs.length;
      final flow = allPerfs.where((p) => p.isInScheduleFlow).length;
      String? start;
      String? end;
      if (allPerfs.isNotEmpty) {
        final sorted = List<Performance>.from(allPerfs)
          ..sort((a, b) => a.date.compareTo(b.date));
        start = sorted.first.date;
        end = sorted.last.date;
      }
      stats[showId] = _ShowStats(
        totalCount: total,
        flowCount: flow,
        startDate: start,
        endDate: end,
      );
    }

    // 按剧目最早场次日期升序排列，开始时间相同则按最晚场次日期升序
    shows.sort((a, b) {
      final aStart = stats[a.id]?.startDate ?? '';
      final bStart = stats[b.id]?.startDate ?? '';
      final startCmp = aStart.compareTo(bStart);
      if (startCmp != 0) return startCmp;
      final aEnd = stats[a.id]?.endDate ?? '';
      final bEnd = stats[b.id]?.endDate ?? '';
      return aEnd.compareTo(bEnd);
    });

    if (mounted) {
      setState(() {
        _shows = shows;
        _showStats = stats;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    HapticFeedback.lightImpact();
    var newMonth = _month + delta;
    var newYear = _year;
    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    // 嵌入模式下由父组件驱动月份状态，避免重复加载数据
    if (widget.onMonthChanged != null) {
      widget.onMonthChanged!(newYear, newMonth);
      return;
    }

    setState(() {
      _year = newYear;
      _month = newMonth;
    });
    _loadData();
  }

  Future<void> _pickMonth() async {
    final initialDate = DateTime(_year, _month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(2030, 12),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
      });
      _loadData();
    }
  }

  Future<void> _navigateToShowManagement(Show show) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowManagementScreen(showId: show.id!),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _addNewShow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddShowScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridSpacing = screenWidth * 0.03;

    final content = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _dragStartX = details.globalPosition.dx;
        _dragCurrentX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        _dragCurrentX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (_dragStartX == null || _dragCurrentX == null) return;
        final delta = _dragStartX! - _dragCurrentX!;
        const threshold = 60.0;
        if (delta > threshold) {
          _changeMonth(1); // 左滑 → 下月
        } else if (delta < -threshold) {
          _changeMonth(-1); // 右滑 → 上月
        }
        _dragStartX = null;
        _dragCurrentX = null;
      },
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kBrandPurple),
            )
          : _shows.isEmpty
              ? _buildEmptyState()
              : _buildPosterGrid(gridSpacing),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: _buildMonthSelector(),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left, color: Colors.white70),
          onPressed: () => _changeMonth(-1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 28,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickMonth,
          child: Text(
            '$_year年$_month月',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.arrow_right, color: Colors.white70),
          onPressed: () => _changeMonth(1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 28,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BreathingIcon(
            icon: Icons.event_busy_outlined,
            size: 72,
            color: Color(0xFF4D4D4D),
          ),
          const SizedBox(height: 20),
          Text(
            '这个月还没有排期',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewShow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加剧目'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrandPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterGrid(double spacing) {
    return GridView.count(
      padding: EdgeInsets.all(spacing),
      crossAxisCount: 2,
      childAspectRatio: 3 / 4,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      children: _shows.map((show) => _buildPosterCard(show)).toList(),
    );
  }

  Widget _buildPosterCard(Show show) {
    final coverPath = show.coverPath;
    final color = coverColorForShow(show.id ?? 0);
    final stats = _showStats[show.id];
    final total = stats?.totalCount ?? 0;
    final flow = stats?.flowCount ?? 0;
    final isInFlow = flow > 0;
    final dateRange = _formatDateRange(stats?.startDate, stats?.endDate);

    return GestureDetector(
      onTap: () => _navigateToShowManagement(show),
      onLongPress: () => _confirmDeleteShow(show),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image or gradient fallback
            if (coverPath != null && coverPath.isNotEmpty)
              Image.file(
                File(coverPath),
                fit: BoxFit.cover,
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    show.name.length >= 2
                        ? show.name.substring(0, 2)
                        : show.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Status + count badge (top-right)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isInFlow
                        ? kBrandPurple.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  isInFlow ? '排期中 $flow/$total场' : '待排期 0/$total场',
                  style: TextStyle(
                    fontSize: 11,
                    color: isInFlow ? kBrandPurple : Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Bottom info overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 48, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      show.theater ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.78),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.78),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null || start.isEmpty) return '';
    final startParts = start.split('-');
    final startMonth = int.tryParse(startParts[1]) ?? 0;
    final startDay = int.tryParse(startParts[2]) ?? 0;
    final startStr = '$startMonth.$startDay';

    if (end == null || end.isEmpty || end == start) return startStr;
    final endParts = end.split('-');
    final endMonth = int.tryParse(endParts[1]) ?? 0;
    final endDay = int.tryParse(endParts[2]) ?? 0;

    if (startMonth == endMonth) {
      return '$startMonth.$startDay-$endDay';
    }
    return '$startMonth.$startDay-$endMonth.$endDay';
  }

  Future<void> _confirmDeleteShow(Show show) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确认删除',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '删除「${show.name}」将同时删除所有场次和卡司数据，此操作不可恢复。',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8A8F98))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFF54A45))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = DatabaseHelper.instance;
    await db.deleteShow(show.id!);
    _loadData();
  }
}
