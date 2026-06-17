import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
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

  const MonthlyWorkbenchScreen({
    super.key,
    required this.year,
    required this.month,
    this.embedded = false,
    this.onMonthChanged,
  });

  @override
  State<MonthlyWorkbenchScreen> createState() => _MonthlyWorkbenchScreenState();
}

class _MonthlyWorkbenchScreenState extends State<MonthlyWorkbenchScreen> {
  bool _isLoading = true;
  late int _year;
  late int _month;
  List<Show> _shows = [];
  Map<int, int> _showPerformanceCounts = {};
  double? _dragStartX;
  double? _dragCurrentX;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
    _loadData();
  }

  @override
  void didUpdateWidget(MonthlyWorkbenchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _year = widget.year;
      _month = widget.month;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final perfs = await db.getPerformancesByMonth(_year, _month);

    // 按 showId 去重，获取剧目列表
    final showIds = <int>{};
    final counts = <int, int>{};
    for (final perf in perfs) {
      final showId = perf['show_id'] as int;
      showIds.add(showId);
      counts[showId] = (counts[showId] ?? 0) + 1;
    }

    final shows = <Show>[];
    for (final showId in showIds) {
      final show = await db.getShowById(showId);
      if (show != null) shows.add(show);
    }

    if (mounted) {
      setState(() {
        _shows = shows;
        _showPerformanceCounts = counts;
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
    final count = _showPerformanceCounts[show.id] ?? 0;

    return GestureDetector(
      onTap: () => _navigateToShowManagement(show),
      onLongPress: () => _showShowActionSheet(show),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            // Bottom shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            // Colored glow
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

            // Performance count badge (top-right)
            if (count > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$count场',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Schedule flow indicator (top-left)
            if (show.isInScheduleFlow)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: kBrandPurple.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: kBrandPurple,
                  ),
                ),
              ),

            // Show name at bottom with gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  show.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShowActionSheet(Show show) async {
    final isInFlow = show.isInScheduleFlow;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4D4D4D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  isInFlow ? Icons.remove_circle_outline : Icons.playlist_add_check,
                  color: isInFlow ? Colors.orange : kBrandPurple,
                ),
                title: Text(isInFlow ? '移出排期流' : '导入排期流'),
                subtitle: Text(
                  isInFlow
                      ? '该剧目将不再出现在排期流和月历中'
                      : '将该剧目加入排期流，可在排期页查看',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleShowInScheduleFlow(show);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text('编辑剧目'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToShowManagement(show);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFF54A45)),
                title: const Text(
                  '删除剧目',
                  style: TextStyle(color: Color(0xFFF54A45)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteShow(show);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleShowInScheduleFlow(Show show) async {
    final db = DatabaseHelper.instance;
    final updated = show.copyWith(isInScheduleFlow: !show.isInScheduleFlow);
    await db.updateShow(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isInScheduleFlow
                ? '「${show.name}」已导入排期流'
                : '「${show.name}」已移出排期流',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadData();
    }
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
