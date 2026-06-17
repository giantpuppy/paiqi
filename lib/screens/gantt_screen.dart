import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../utils/page_transitions.dart';
import '../utils/status_colors.dart';
import '../models/actor.dart';
import '../widgets/gantt/long_press_star_button.dart';
import '../widgets/poster_fallback.dart';
import '../widgets/bought_form_sheet.dart';
import '../widgets/warm_spotlight.dart';
import '../widgets/gantt/cast_list.dart';
import '../widgets/gantt/gantt_decorations.dart';
import 'unified_show_detail_screen.dart';
import 'monthly_workbench_screen.dart';

enum PerformanceStatus { unmarked, wantToSee, bought }

extension PerformanceStatusExt on PerformanceStatus {
  String get value {
    switch (this) {
      case PerformanceStatus.unmarked:
        return 'unmarked';
      case PerformanceStatus.wantToSee:
        return 'want_to_see';
      case PerformanceStatus.bought:
        return 'bought';
    }
  }

  String get label {
    switch (this) {
      case PerformanceStatus.unmarked:
        return '未标记';
      case PerformanceStatus.wantToSee:
        return '想看';
      case PerformanceStatus.bought:
        return '已买';
    }
  }

  Color get color {
    switch (this) {
      case PerformanceStatus.unmarked:
        return const Color(0xFF9CA3AF);
      case PerformanceStatus.wantToSee:
        return const Color(0xFF811FE2);
      case PerformanceStatus.bought:
        return const Color(0xFF34D399);
    }
  }
}

PerformanceStatus statusFromString(String? s) {
  switch (s) {
    case 'want_to_see':
      return PerformanceStatus.wantToSee;
    case 'bought':
      return PerformanceStatus.bought;
    default:
      return PerformanceStatus.unmarked;
  }
}

/// 剧场流时间轴模式
enum TimelineMode { focus3Day, micro7Day }

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => GanttScreenState();
}

class GanttScreenState extends State<GanttScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  bool _isLoading = true;
  bool _isWorkbenchMode = false;
  late int _workbenchYear;
  late int _workbenchMonth;

  TimelineMode _mode = TimelineMode.focus3Day;
  final ValueNotifier<TimelineMode> modeNotifier = ValueNotifier(TimelineMode.focus3Day);

  // 连续滚动
  late List<DateTime> _days;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isSnapping = false;
  Timer? _snapTimer;
  bool _isTransitioning = false; // 模式切换过渡中，封锁重复切换
  bool _justSwitched = false;     // 刚刚切换完，短暂封锁磁吸避免干扰

  // 动态行高：由 LayoutBuilder 实时更新
  double _availableHeight = 800.0; // 默认值，首次布局后更新

  // 左上角月份标题，随滚动实时更新
  final ValueNotifier<String> _monthTitle = ValueNotifier('');

  // 当前屏幕中心聚焦的日期索引
  final ValueNotifier<int> _focalDayIndex = ValueNotifier(30);

  double get _focusRowHeight => _availableHeight / 3;
  double get _microRowHeight => _availableHeight / 7;
  double get _currentRowHeight => _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    modeNotifier.value = _mode;
    final now = DateTime.now();
    _workbenchYear = now.year;
    _workbenchMonth = now.month;
    _initDays();
    _loadData();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateMonthTitle);
  }

  void _updateMonthTitle() {
    if (!_scrollController.hasClients || _days.isEmpty) return;
    if (_availableHeight <= 0) return;
    final idx = (_scrollController.offset / _currentRowHeight).floor().clamp(0, _days.length - 1);
    final d = _days[idx];
    _monthTitle.value = '${d.year}年${d.month}月';

    // 聚焦日期：屏幕中心点所在的日期
    final centerOffset = _scrollController.offset + _availableHeight / 2;
    final focalIdx = (centerOffset / _currentRowHeight).floor().clamp(0, _days.length - 1);
    if (focalIdx != _focalDayIndex.value) {
      _focalDayIndex.value = focalIdx;
      if (mounted) setState(() {});
    }
  }

  /// 初始化日期列表：今天前30天 + 后60天
  void _initDays() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    _days = List.generate(91, (i) => DateTime(start.year, start.month, start.day + i));
  }

  /// 滚动到顶部/底部时追加更多天
  void _onScroll() {
    if (_isLoadingMore || _isSnapping || _isTransitioning) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _appendDays();
    } else if (_scrollController.position.pixels <= 200) {
      _prependDays();
    }
  }

  void _appendDays() {
    _isLoadingMore = true;
    final lastDay = _days.last;
    final newDays = List.generate(30, (i) => DateTime(lastDay.year, lastDay.month, lastDay.day + i + 1));
    setState(() => _days.addAll(newDays));
    _isLoadingMore = false;
  }

  void _prependDays() {
    _isLoadingMore = true;
    final firstDay = _days.first;
    final newDays = List.generate(30, (i) => DateTime(firstDay.year, firstDay.month, firstDay.day - 30 + i));
    final offsetBefore = _scrollController.offset;
    setState(() => _days.insertAll(0, newDays));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(offsetBefore + 30 * _currentRowHeight);
      _updateMonthTitle();
      _isLoadingMore = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final db = DatabaseHelper.instance;
      final performances = await db.getPerformancesInScheduleFlow();
      // 原始列表可能是只读的，复制一份可修改的 map
      final mutablePerformances = performances.map((p) => Map<String, dynamic>.from(p)).toList();
      final castMap = <int, List<CastMember>>{};

      for (final perf in mutablePerformances) {
        final perfId = perf['id'] as int;
        final casts = await db.getCastMembersByPerformanceId(perfId);
        castMap[perfId] = casts;
        perf['effective_status'] = perf['status'] ?? 'unmarked';
      }

      if (mounted) {
        setState(() {
          _performances = mutablePerformances;
          _castMap = castMap;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(30 * _currentRowHeight);
            _updateMonthTitle();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _monthTitle.dispose();
    _focalDayIndex.dispose();
    modeNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 根据距离 today 的天数返回暗化透明度
  // ==================== 日期与演出数据 ====================

  /// 获取某天的所有演出（含 show 信息）
  List<Map<String, dynamic>> _getPerformancesForDay(DateTime day) {
    final dateStr = _fullDateFormat.format(day);
    return _performances.where((p) => p['date'] == dateStr).toList()
      ..sort((a, b) => ((a['time'] as String?) ?? '').compareTo((b['time'] as String?) ?? ''));
  }

  // ==================== 状态操作 ====================

  // ==================== 详情面板 ====================

  void _showPerformanceDetail(Map<String, dynamic> perf) async {
    final perfId = perf['id'] as int;
    final result = await Navigator.push(
      context,
      SlideFadeRoute(page: UnifiedShowDetailScreen(
        performanceId: perfId,
      )),
    );
    if (result == true) {
      _loadData();
    }
  }

  // ==================== 删除 ====================

  void _confirmDelete(Map<String, dynamic> perf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              final db = DatabaseHelper.instance;
              await db.deletePerformance(perf['id'] as int);
              await db.deleteCastMembersByPerformanceId(perf['id'] as int);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: _buildMonthTitle(),
        actions: [
          // 管理台入口：纯图标，点击切换工作台视图
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _isWorkbenchMode
                  ? kBrandPurple.withValues(alpha: 0.35)
                  : kBrandPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: kBrandPurple.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _toggleWorkbenchMode,
              icon: Icon(
                _isWorkbenchMode ? Icons.timeline_rounded : Icons.grid_view_rounded,
                size: 20,
              ),
              color: kBrandPurple,
              tooltip: _isWorkbenchMode ? '返回时间线' : '管理台',
            ),
          ),
        ],
      ),
      body: _isWorkbenchMode
          ? _buildWorkbenchView()
          : (_isLoading
              ? const Center(child: CircularProgressIndicator())
              : _performances.isEmpty
                  ? _buildEmptyState()
                  : _buildTimeline()),
    );
  }

  Widget _buildWorkbenchView() {
    return MonthlyWorkbenchScreen(
      year: _workbenchYear,
      month: _workbenchMonth,
      embedded: true,
      onMonthChanged: (year, month) {
        setState(() {
          _workbenchYear = year;
          _workbenchMonth = month;
        });
      },
    );
  }

  void _toggleWorkbenchMode() {
    if (!_isWorkbenchMode) {
      // 进入工作台时，同步当前时间轴可见月份作为初始月份
      final title = _monthTitle.value;
      final parts = title.split('年');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1].replaceFirst('月', ''));
        if (year != null && month != null) {
          _workbenchYear = year;
          _workbenchMonth = month;
        }
      }
    }
    setState(() => _isWorkbenchMode = !_isWorkbenchMode);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingIcon(icon: Icons.view_timeline_outlined),
          const SizedBox(height: 16),
          const Text('排期流为空', style: TextStyle(fontSize: 18, color: Color(0xFF8A8F98))),
          const SizedBox(height: 8),
          const Text(
            '在管理台长按剧目导入排期流后，\n场次将显示在这里',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _toggleWorkbenchMode,
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('去管理台导入'),
          ),
        ],
      ),
    );
  }

  // ==================== 动态月份标题 ====================

  void _openMonthlyWorkbench(int year, int month) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyWorkbenchScreen(year: year, month: month),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _openMonthlyWorkbenchFromCurrentTitle() {
    final title = _monthTitle.value;
    final parts = title.split('年');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1].replaceFirst('月', ''));
      if (year != null && month != null) {
        _openMonthlyWorkbench(year, month);
      }
    }
  }

  Widget _buildMonthTitle() {
    return ValueListenableBuilder<String>(
      valueListenable: _monthTitle,
      builder: (context, title, child) {
        final displayTitle = _isWorkbenchMode
            ? '$_workbenchYear年$_workbenchMonth月'
            : title;
        return GestureDetector(
          onTap: () => _showMonthPicker(),
          behavior: HitTestBehavior.opaque,
          child: Text(
            displayTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMonthPicker() async {
    if (_isWorkbenchMode) {
      final picked = await showModalBottomSheet<DateTime>(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _YearMonthPicker(
          initialYear: _workbenchYear,
          initialMonth: _workbenchMonth,
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _workbenchYear = picked.year;
          _workbenchMonth = picked.month;
        });
      }
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _days.isEmpty ? DateTime.now() : _days[(_scrollController.offset / _currentRowHeight).floor().clamp(0, _days.length - 1)],
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: kBrandPurple,
              surface: const Color(0xFF1E1E1E),
            ),
            dialogBackgroundColor: const Color(0xFF181818),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !_scrollController.hasClients) return;

    final target = DateTime(picked.year, picked.month, picked.day);
    // 确保目标日期在 _days 范围内
    if (target.isBefore(_days.first) || target.isAfter(_days.last)) {
      final start = target.subtract(const Duration(days: 30));
      _days = List.generate(91, (i) => DateTime(start.year, start.month, start.day + i));
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final index = _days.indexWhere((d) => _isSameDay(d, target));
      if (index >= 0) {
        _scrollController.jumpTo(
          (index * _currentRowHeight).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
        _updateMonthTitle();
      }
    });
  }

  // ==================== 剧场流时间轴 ====================

  Widget _buildTimeline() {
    final today = DateTime.now();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && !_isSnapping && !_isTransitioning && !_justSwitched) {
          _snapTimer?.cancel();
          _snapTimer = Timer(const Duration(milliseconds: 150), _snapToNearestRow);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _availableHeight = constraints.maxHeight;
          return ListView.builder(
            key: ValueKey<TimelineMode>(_mode),
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: _days.length,
            itemBuilder: (context, index) {
              return _buildDayRow(index, today, _focalDayIndex.value);
            },
          );
        },
      ),
    );
  }

  // ==================== 磁吸滚动 ====================

  void _snapToNearestRow() {
    if (!_scrollController.hasClients || _isTransitioning || _justSwitched) return;
    final offset = _scrollController.offset;
    final targetIndex = (offset / _currentRowHeight).round().clamp(0, _days.length - 1);
    final targetOffset = targetIndex * _currentRowHeight;

    if ((offset - targetOffset).abs() > 2) {
      _isSnapping = true;
      _scrollController
          .animateTo(targetOffset, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
          .then((_) => _isSnapping = false);
    }
  }

  // ==================== 丝滑模式切换 ====================

  void _switchMode(TimelineMode newMode) {
    if (_mode == newMode || _isTransitioning) return;

    _snapTimer?.cancel();

    // 保存切换前的关键状态
    final previousOffset = _scrollController.offset;
    final previousMode = _mode;

    _isTransitioning = true;
    setState(() => _mode = newMode);
    modeNotifier.value = newMode;

    // 所有计算和滚动调整在布局完成后执行，确保使用最新的行高和 maxScrollExtent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 在 post frame 中重新计算行高，确保 _availableHeight 已更新
        final oldRowHeight = previousMode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;
        final newRowHeight = _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

        // 以屏幕中心日期为锚点，切换后让它仍位于屏幕中心
        final viewportCenter = previousOffset + _availableHeight / 2;
        final focalIndex = (viewportCenter / oldRowHeight).floor().clamp(0, _days.length - 1);
        final targetOffset = (focalIndex * newRowHeight) - (_availableHeight - newRowHeight) / 2;

        _scrollController.jumpTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
        _updateMonthTitle();
      }
      // jumpTo 后强制 rebuild，让 _buildMonthTitle 使用新的 offset 计算正确月份
      if (mounted) setState(() {});
      _isTransitioning = false;
      // 短暂标记刚刚切换完，阻止磁吸干扰 jumpTo 后的位置
      _justSwitched = true;
      Future.delayed(const Duration(milliseconds: 300), () => _justSwitched = false);
    });
  }

  /// 公开给底部导航的切换入口：当前聚焦3天则切到7天宏观，反之亦然。
  void toggleMode() {
    _switchMode(
      _mode == TimelineMode.focus3Day
          ? TimelineMode.micro7Day
          : TimelineMode.focus3Day,
    );
  }

  // ==================== 统一日期行（行高瞬间切换，避免 ListView 滚动冲突） ====================

  Widget _buildDayRow(int index, DateTime today, int focalIndex) {
    final day = _days[index];
    final isToday = _isSameDay(day, today);
    final isFocal = index == focalIndex;
    final dayPerfs = _getPerformancesForDay(day);
    final isFocus = _mode == TimelineMode.focus3Day;
    final targetHeight = isFocus ? _focusRowHeight : _microRowHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final labelWidth = screenWidth * (isFocus ? 0.18 : 0.13);
    final hasPerformances = dayPerfs.isNotEmpty;
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    // 行背景：today 带极淡紫底，有演出正常，空行最暗
    final rowBackground = isToday
        ? kBrandPurple.withValues(alpha: 0.03)
        : (hasPerformances ? const Color(0xFF121212) : const Color(0xFF0E0E0E));
    final bottomBorderAlpha = hasPerformances ? 0.06 : 0.08;

    // 焦点高亮只保留最中心一行
    final focusDistance = (index - focalIndex).abs();
    final baseFocusTintAlpha = focusDistance == 0 ? 0.12 : 0.0;

    // 滚动波动：仅给最焦点行加一点轻微起伏
    final scrollProgress = _scrollController.hasClients
        ? _scrollController.offset / _currentRowHeight
        : 0.0;
    final wave = sin((scrollProgress + index * 0.12) * pi * 2) * 0.012;
    final focusTintAlpha = (baseFocusTintAlpha + wave).clamp(0.0, 0.16);

    Widget rowContent = Container(
      height: targetHeight,
      decoration: BoxDecoration(
        color: rowBackground,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: bottomBorderAlpha),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 左侧日期标签
          Container(
            width: labelWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: isToday
                  ? kBrandPurple.withValues(alpha: 0.08)
                  : const Color(0xFF1A1A1A),
              border: Border(
                right: BorderSide(
                  color: isToday
                      ? kBrandPurple.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.015,
              vertical: targetHeight * 0.035,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 大日期：M.D 格式
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? screenWidth * 0.038 : screenWidth * 0.042,
                    fontWeight: isFocus ? FontWeight.w700 : FontWeight.w800,
                    color: isFocal
                        ? kBrandPurple
                        : (isToday ? kBrandPurple.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)),
                  ),
                  child: Text('${day.month}.${day.day}'),
                ),
                SizedBox(height: targetHeight * 0.012),
                // 星期（放大）
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? screenWidth * 0.028 : screenWidth * 0.026,
                    fontWeight: FontWeight.w600,
                    color: isFocal
                        ? kBrandPurple.withValues(alpha: 0.85)
                        : (isToday ? kBrandPurple.withValues(alpha: 0.6) : const Color(0xFF6B7280)),
                  ),
                  child: Text(isFocus
                      ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1]
                      : '周${['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}'),
                ),
              ],
            ),
          ),
          // 右侧内容区：周末带淡淡灰色底，与工作日区分
          Expanded(
            child: Container(
              height: targetHeight,
              color: isWeekend ? const Color(0xFF161616) : Colors.transparent,
              child: hasPerformances
                  ? (isFocus
                      ? _buildFocusContent(dayPerfs, targetHeight, labelWidth, screenWidth, isToday)
                      : _buildMicroContent(dayPerfs, targetHeight, screenWidth, isToday))
                  : (isFocus ? const SizedBox() : const SizedBox()),
            ),
          ),
        ],
      ),
    );

    // 空行叠加天鹅绒纹理
    if (!hasPerformances && !isToday) {
      rowContent = VelvetTexture(child: rowContent);
    }

    // 焦点高亮带：仅最中心行有淡紫底，边缘轻微柔和溢出
    if (focusTintAlpha > 0.001) {
      rowContent = Stack(
        children: [
          rowContent,
          Positioned(
            top: -targetHeight * 0.15,
            bottom: -targetHeight * 0.15,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      kBrandPurple.withValues(alpha: focusTintAlpha * 0.6),
                      kBrandPurple.withValues(alpha: focusTintAlpha),
                      kBrandPurple.withValues(alpha: focusTintAlpha * 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return rowContent;
  }

  // ==================== 聚焦模式内容（大海报卡片） ====================

  Widget _buildFocusContent(
    List<Map<String, dynamic>> dayPerfs,
    double rowHeight,
    double labelWidth,
    double screenWidth,
    bool isToday,
  ) {
    final cardWidth = (screenWidth - labelWidth) * 0.45;
    final cardHeight = rowHeight - rowHeight * 0.08;
    final cardSpacing = cardWidth * 0.04;
    final cardBorderRadius = cardHeight * 0.055;
    final horizontalPadding = screenWidth * 0.02;
    final verticalPadding = rowHeight * 0.035;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildFocusCard(
        dayPerfs[index],
        cardWidth,
        cardHeight,
        cardSpacing,
        cardBorderRadius,
        isToday,
      ),
    );
  }

  Widget _buildFocusCard(
    Map<String, dynamic> perf,
    double cardWidth,
    double cardHeight,
    double cardSpacing,
    double cardBorderRadius,
    bool isToday,
  ) {
    final showId = perf['show_id'] as int;
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = coverColorForShow(showId);
    final perfId = perf['id'] as int;
    final storedStatus = perf['status'] as String? ?? 'unmarked';
    final effectiveStatus = perf['effective_status'] as String? ?? storedStatus;

    final allCasts = _castMap[perfId] ?? [];
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    // 卡片容器：彩色光晕 + 边缘溢光 + 底部投影 + 深色描边
    Widget card = Container(
      width: cardWidth,
      height: cardHeight,
      margin: EdgeInsets.only(right: cardSpacing),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          // 主彩色光晕
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
          // 边缘溢光
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 0),
          ),
          // 底部投影，让卡片浮起来
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: 海报底图（无海报时用双色渐变）
            if (hasCover)
              Image.file(
                File(coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientFallback(color, showId),
              )
            else
              _buildGradientFallback(color, showId),
            // Layer 2: 全屏蒙版（降低让海报更透）
            Container(color: Colors.black.withValues(alpha: 0.18)),
            // Layer 2.5: 顶部加重渐变，确保文字可读
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Layer 3: 信息
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: cardWidth * 0.05,
                  vertical: cardHeight * 0.04,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 时间
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (time.isNotEmpty)
                          StampTime(
                            time: time,
                            width: cardWidth,
                            isToday: isToday,
                          ),
                      ],
                    ),
                    // 卡司列表（主演优先，最多 3 条），垂直居中
                    if (allCasts.isNotEmpty) ...[
                      SizedBox(height: cardHeight * 0.02),
                      Expanded(
                        child: Center(
                          child: FeaturedCastList(
                            casts: allCasts,
                            width: cardWidth,
                            height: cardHeight,
                            maxCount: 3,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    // 底部信息：剧名常驻，剧场小字
                    if (showName != '未知') ...[
                      Text(
                        showName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: cardWidth * 0.055,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (theater.isNotEmpty) SizedBox(height: cardHeight * 0.005),
                    ],
                    if (theater.isNotEmpty)
                      Text(
                        theater,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: cardWidth * 0.045,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 4,
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
            // today 卡片脚灯条：底部渐变条
            if (isToday)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: cardHeight * 0.04,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(cardBorderRadius),
                      bottomRight: Radius.circular(cardBorderRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        kWarmGold.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // today 卡片增加暖色 BoxShadow 呼吸效果
    if (isToday) {
      card = WarmSpotlight(
        borderRadius: cardBorderRadius,
        color: kWarmGold,
        minAlpha: 0.10,
        maxAlpha: 0.20,
        minBlur: 10,
        maxBlur: 20,
        duration: const Duration(milliseconds: 3500),
        shouldAnimate: true,
        child: card,
      );
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showPerformanceDetail(perf),
          child: card,
        ),
        Positioned(
          top: cardHeight * 0.03,
          right: cardWidth * 0.04,
          child: LongPressStarButton(
            status: effectiveStatus,
            size: cardWidth * 0.09,
            onStatusChanged: () => _toggleWantToSee(perfId, storedStatus),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleWantToSee(int perfId, String currentStatus) async {
    if (currentStatus != 'unmarked' && currentStatus != 'want_to_see') return;
    final nextStatus = currentStatus == 'want_to_see' ? 'unmarked' : 'want_to_see';

    final db = DatabaseHelper.instance;
    final perf = await db.getPerformanceById(perfId);
    if (perf == null) return;

    await db.updatePerformance(perf.copyWith(status: nextStatus));

    // 更新本地数据，避免全量刷新
    setState(() {
      final perfMap = _performances.firstWhere((p) => p['id'] == perfId);
      perfMap['status'] = nextStatus;
      perfMap['effective_status'] = nextStatus;
    });
  }

  Widget _buildPosterFallback(Color color, int showId, String showName) {
    return PosterFallback(
      showId: showId,
      showName: showName,
      fontSize: 56,
    );
  }

  // ==================== 微观模式内容（邮票墙） ====================

  Widget _buildMicroContent(
    List<Map<String, dynamic>> dayPerfs,
    double rowHeight,
    double screenWidth,
    bool isToday,
  ) {
    final cardHeight = rowHeight - rowHeight * 0.08;
    final horizontalPadding = screenWidth * 0.015;
    final verticalPadding = rowHeight * 0.02;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildMicroCard(
        dayPerfs[index],
        cardHeight,
        screenWidth,
        isToday,
      ),
    );
  }

  Widget _buildMicroCard(
    Map<String, dynamic> perf,
    double cardHeight,
    double screenWidth,
    bool isToday,
  ) {
    final showId = perf['show_id'] as int;
    final showName = perf['show_name'] as String? ?? '未知';
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = coverColorForShow(showId);
    final status = perf['effective_status'] as String? ??
        (perf['status'] as String? ?? 'unmarked');
    final cardWidth = cardHeight * 0.75; // 3:4 比例
    final cardSpacing = cardWidth * 0.04;
    final cardBorderRadius = cardHeight * 0.05;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPerformanceDetail(perf),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: EdgeInsets.only(right: cardSpacing),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.30),
            width: 1,
          ),
          boxShadow: [
            // 彩色光晕
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            // 边缘溢光
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 28,
              spreadRadius: 3,
            ),
            // 底部投影
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              coverPath != null && coverPath.isNotEmpty
                  ? Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPosterFallback(color, showId, showName),
                    )
                  : _buildPosterFallback(color, showId, showName),
              // 黑色蒙版
              Container(color: Colors.black.withValues(alpha: 0.18)),
              // 时间与状态点
              Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StampTime(
                      time: time,
                      width: cardWidth,
                      isToday: isToday,
                    ),
                    SizedBox(height: cardHeight * 0.04),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: statusColor(status),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor(status).withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientFallback(Color color, int showId) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, coverColorForShow(showId + 3)],
        ),
      ),
    );
  }
}

// ==================== 剧目管理面板 ====================

enum _ShowFilter { all, wantToSee, bought, watched }

class _ShowManagementSheet extends StatefulWidget {
  final int showId;
  final String showName;
  final String? showTheater;
  final List<Performance> performances;
  final VoidCallback onDataChanged;
  final void Function(int showId) onQuickAdd;
  final void Function(Map<String, dynamic>) onEditPerformance;

  const _ShowManagementSheet({
    required this.showId,
    required this.showName,
    this.showTheater,
    required this.performances,
    required this.onDataChanged,
    required this.onQuickAdd,
    required this.onEditPerformance,
  });

  @override
  State<_ShowManagementSheet> createState() => _ShowManagementSheetState();
}

class _ShowManagementSheetState extends State<_ShowManagementSheet> {
  late String _showName;
  late String? _showTheater;
  bool _isEditing = false;
  _ShowFilter _filter = _ShowFilter.all;
  late List<Performance> _performances;

  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _showName = widget.showName;
    _showTheater = widget.showTheater;
    _performances = List.from(widget.performances);
    _nameController.text = _showName;
    _theaterController.text = _showTheater ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    super.dispose();
  }

  bool _isWatched(Performance perf) {
    // 优先使用持久化的 watched 状态；旧数据未迁移时按日期回退
    if (perf.status == 'watched') return true;
    if (perf.status != 'bought') return false;
    final perfDate = DateTime.parse(perf.date);
    final today = DateTime.now();
    return perfDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  List<Performance> get _filteredPerformances {
    switch (_filter) {
      case _ShowFilter.all:
        return _performances;
      case _ShowFilter.wantToSee:
        return _performances.where((p) => p.status == 'want_to_see').toList();
      case _ShowFilter.bought:
        return _performances.where((p) => p.status == 'bought' && !_isWatched(p)).toList();
      case _ShowFilter.watched:
        return _performances.where((p) => _isWatched(p)).toList();
    }
  }

  Future<void> _saveShowInfo() async {
    final db = DatabaseHelper.instance;
    final show = await db.getShowById(widget.showId);
    if (show != null) {
      await db.updateShow(show.copyWith(
        name: _nameController.text.trim(),
        theater: _theaterController.text.trim().isEmpty ? null : _theaterController.text.trim(),
      ));
      setState(() {
        _showName = _nameController.text.trim();
        _showTheater = _theaterController.text.trim().isEmpty ? null : _theaterController.text.trim();
        _isEditing = false;
      });
      widget.onDataChanged();
    }
  }

  Future<void> _deleteShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除剧目'),
        content: Text('删除「$_showName」将同时删除其所有场次和卡司记录，确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      for (final perf in _performances) {
        if (perf.id != null) {
          await db.deleteCastMembersByPerformanceId(perf.id!);
          await db.deletePerformance(perf.id!);
        }
      }
      await db.deleteShow(widget.showId);
      widget.onDataChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleStatus(Performance perf) async {
    final current = perf.status ?? 'unmarked';
    final next = switch (current) {
      'watched' => 'unmarked',
      'bought' => 'watched',
      'want_to_see' => 'bought',
      _ => 'want_to_see',
    };

    // 切到 bought 时弹出购票信息表单
    if (next == 'bought') {
      final ticket = await showBoughtFormSheet(context, performanceId: perf.id!);
      await _applyStatus(perf.id!, 'bought');
      if (ticket != null) {
        final db = DatabaseHelper.instance;
        await db.createTicket(ticket);
      }
      return;
    }

    await _applyStatus(perf.id!, next);
  }

  Future<void> _applyStatus(int perfId, String status) async {
    final db = DatabaseHelper.instance;
    final perf = await db.getPerformanceById(perfId);
    if (perf == null) return;
    await db.updatePerformance(perf.copyWith(status: status));
    setState(() {
      _performances = _performances.map((p) {
        if (p.id == perfId) return p.copyWith(status: status);
        return p;
      }).toList();
    });
    widget.onDataChanged();
  }

  Future<void> _deletePerformance(int perfId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后不可恢复，确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCastMembersByPerformanceId(perfId);
      await DatabaseHelper.instance.deletePerformance(perfId);
      setState(() {
        _performances.removeWhere((p) => p.id == perfId);
      });
      widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // 顶部拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2))),
          ),
          // 剧目信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isEditing ? _buildEditForm() : _buildShowInfo(),
          ),
          const SizedBox(height: 12),
          // 筛选栏
          _buildFilterBar(),
          const SizedBox(height: 8),
          // 分隔线
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06)),
          // 场次列表
          Expanded(
            child: _filteredPerformances.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 40, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        Text(_filter == _ShowFilter.all ? '暂无排期' : '暂无符合条件的排期',
                            style: const TextStyle(color: Color(0xFF8A8F98), fontSize: 14)),
                      ],
                    ),
                  ))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredPerformances.length,
                    itemBuilder: (context, index) => _buildPerfItem(_filteredPerformances[index]),
                  ),
          ),
          // 底部删除按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteShow,
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                label: Text('删除剧目', style: TextStyle(color: Colors.red[300])),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[300],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfItem(Performance perf) {
    final isWatched = _isWatched(perf);
    final status = statusFromString(perf.status);
    final displayLabel = isWatched ? '已观演' : status.label;
    final displayColor = isWatched ? const Color(0xFF9CA3AF) : status.color;
    final displayIcon = isWatched
        ? Icons.visibility
        : (perf.status == 'bought' ? Icons.check_circle : perf.status == 'want_to_see' ? Icons.star : Icons.circle_outlined);
    final timeStr = perf.time?.substring(0, 5) ?? '';

    return GestureDetector(
      onTap: () => widget.onEditPerformance(perf.toMap()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // 状态图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(displayIcon, size: 18, color: displayColor),
            ),
            const SizedBox(width: 12),
            // 日期时间 + 座位
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(perf.date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(timeStr, style: TextStyle(fontSize: 14, color: displayColor, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  if (perf.seat != null && perf.seat!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('座位: ${perf.seat}', style: const TextStyle(fontSize: 12, color: Color(0xFF8A8F98))),
                  ],
                ],
              ),
            ),
            // 状态标签
            _StatusBadge(label: displayLabel, color: displayColor, onTap: () => _toggleStatus(perf)),
            const SizedBox(width: 4),
            // 删除
            GestureDetector(
              onTap: () => _deletePerformance(perf.id!),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_showName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_showTheater != null && _showTheater!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF8A8F98)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(_showTheater!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF8A8F98)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // 编辑按钮
        GestureDetector(
          onTap: () => setState(() => _isEditing = true),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF8A8F98)),
          ),
        ),
        const SizedBox(width: 8),
        // 添加场次按钮
        GestureDetector(
          onTap: () => widget.onQuickAdd(widget.showId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5BCD).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: Color(0xFF6B5BCD)),
                SizedBox(width: 4),
                Text('添加', style: TextStyle(fontSize: 13, color: Color(0xFF6B5BCD), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: '剧目名称', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 10),
        TextField(controller: _theaterController, decoration: const InputDecoration(labelText: '演出地点', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditing = false), child: const Text('取消'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: _saveShowInfo, child: const Text('保存'))),
        ]),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      (_ShowFilter.all, '全部', null),
      (_ShowFilter.wantToSee, '想看', const Color(0xFF811FE2)),
      (_ShowFilter.bought, '已买', const Color(0xFF34D399)),
      (_ShowFilter.watched, '已观演', const Color(0xFF9CA3AF)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          final color = f.$3 ?? const Color(0xFF6B5BCD);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? color.withValues(alpha: 0.4) : const Color(0xFF2A2A2A),
                    width: 1,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: isActive ? color : const Color(0xFF8A8F98),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==================== 状态标签组件 ====================

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatusBadge({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ==================== 编辑场次 Sheet ====================

class _EditPerformanceSheet extends StatefulWidget {
  final Map<String, dynamic> perf;
  final List<CastMember> existingCasts;
  final VoidCallback onSaved;

  const _EditPerformanceSheet({required this.perf, required this.existingCasts, required this.onSaved});

  @override
  State<_EditPerformanceSheet> createState() => _EditPerformanceSheetState();
}

class _EditCastRow {
  TextEditingController roleController;
  TextEditingController actorController;
  bool isFeatured;

  _EditCastRow({String? role, String? actor, bool? featured})
      : roleController = TextEditingController(text: role ?? ''),
        actorController = TextEditingController(text: actor ?? ''),
        isFeatured = featured ?? false;

  void dispose() {
    roleController.dispose();
    actorController.dispose();
  }
}

class _EditPerformanceSheetState extends State<_EditPerformanceSheet> {
  late String _date;
  late String _time;
  final List<_EditCastRow> _castRows = [];
  bool _isSaving = false;
  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _date = widget.perf['date'] as String;
    _time = widget.perf['time'] as String? ?? '19:30';
    for (final c in widget.existingCasts) {
      _castRows.add(_EditCastRow(role: c.role, actor: c.actorName, featured: c.isFeatured));
    }
    if (_castRows.isEmpty) _castRows.add(_EditCastRow());
  }

  @override
  void dispose() {
    for (final r in _castRows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) setState(() => _date = _fullDateFormat.format(picked));
  }

  Future<void> _pickTime() async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('选择开场时间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(label: Text(t), onPressed: () => Navigator.pop(context, t))),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = _time.split(':');
                      final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                      if (picked != null && context.mounted) {
                        Navigator.pop(context, '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (result != null) setState(() => _time = result);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper.instance;
      final perfId = widget.perf['id'] as int;
      final performance = await db.getPerformanceById(perfId);
      if (performance != null) {
        await db.updatePerformance(performance.copyWith(date: _date, time: _time));
      }
      await db.deleteCastMembersByPerformanceId(perfId);
      for (final row in _castRows) {
        final role = row.roleController.text.trim();
        final actor = row.actorController.text.trim();
        if (role.isNotEmpty && actor.isNotEmpty) {
          await db.createCastMember(CastMember(performanceId: perfId, role: role, actorName: actor, isFeatured: row.isFeatured, createdAt: DateTime.now().toIso8601String()));
          try { await db.createActor(Actor(name: actor, createdAt: DateTime.now().toIso8601String())); } catch (_) {}
        }
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('编辑场次', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: '日期', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)), child: Text(_date, style: const TextStyle(fontSize: 15))))),
                const SizedBox(width: 12),
                Expanded(child: InkWell(onTap: _pickTime, child: InputDecorator(decoration: const InputDecoration(labelText: '时间', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)), child: Text(_time, style: const TextStyle(fontSize: 15))))),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Text('卡司', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(onPressed: () => setState(() => _castRows.add(_EditCastRow())), icon: const Icon(Icons.add, size: 18), label: const Text('添加角色')),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _castRows.length,
                  itemBuilder: (context, index) {
                    final row = _castRows[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(flex: 2, child: TextField(controller: row.roleController, decoration: const InputDecoration(labelText: '角色', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: TextField(controller: row.actorController, decoration: const InputDecoration(labelText: '演员', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
                          const SizedBox(width: 8),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Checkbox(value: row.isFeatured, onChanged: (v) => setState(() => row.isFeatured = v ?? false)),
                            GestureDetector(onTap: () => setState(() => row.isFeatured = !row.isFeatured), child: const Text('★', style: TextStyle(fontSize: 14, color: Color(0xFF811FE2)))),
                          ]),
                          if (_castRows.length > 1)
                            IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]), onPressed: () => setState(() { row.dispose(); _castRows.removeAt(index); })),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'))),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ==================== 年月滚动选择器（工作台模式） ====================

class _YearMonthPicker extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _YearMonthPicker({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<_YearMonthPicker> {
  static const int _minYear = 2020;
  static const int _maxYear = 2030;

  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear.clamp(_minYear, _maxYear);
    _selectedMonth = widget.initialMonth.clamp(1, 12);
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _minYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部把手
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4D4D4D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题 + 按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8A8F98),
                    ),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  const Text(
                    '选择年月',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTime(_selectedYear, _selectedMonth),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                    ),
                    child: const Text(
                      '确定',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 滚轮区域
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      backgroundColor: Colors.transparent,
                      itemExtent: 44,
                      scrollController: _yearController,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedYear = _minYear + index);
                      },
                      children: List.generate(
                        _maxYear - _minYear + 1,
                        (index) => Center(
                          child: Text(
                            '${_minYear + index}年',
                            style: TextStyle(
                              fontSize: 18,
                              color: (_minYear + index) == _selectedYear
                                  ? Colors.white
                                  : const Color(0xFF8A8F98),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      backgroundColor: Colors.transparent,
                      itemExtent: 44,
                      scrollController: _monthController,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMonth = index + 1);
                      },
                      children: List.generate(
                        12,
                        (index) => Center(
                          child: Text(
                            '${index + 1}月',
                            style: TextStyle(
                              fontSize: 18,
                              color: (index + 1) == _selectedMonth
                                  ? Colors.white
                                  : const Color(0xFF8A8F98),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  final IconData icon;
  const _BreathingIcon({required this.icon});

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 4).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(offset: Offset(0, -_animation.value), child: child),
      child: Icon(widget.icon, size: 72, color: const Color(0xFF4D4D4D)),
    );
  }
}
