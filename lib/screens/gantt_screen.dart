import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../utils/page_transitions.dart';
import '../utils/ocr_service.dart';
import '../utils/knowledge_base.dart';
import '../models/actor.dart';
import 'add_show_screen.dart';
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

/// 8色卡用于海报默认背景
const List<Color> _kCoverColors = [
  Color(0xFF1A1A2E),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFF533483),
  Color(0xFF2C3333),
  Color(0xFF2D4040),
  Color(0xFF3A3A3A),
  Color(0xFF2D1B69),
];

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends State<GanttScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  bool _isLoading = true;

  TimelineMode _mode = TimelineMode.focus3Day;

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

  double get _focusRowHeight => _availableHeight / 3;
  double get _microRowHeight => _availableHeight / 7;
  double get _currentRowHeight => _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

  static const double _labelWidth = 64.0;
  static const double _microLabelWidth = 48.0;

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _initDays();
    _loadData();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateMonthTitle);
  }

  void _updateMonthTitle() {
    if (!_scrollController.hasClients || _days.isEmpty) return;
    final idx = (_scrollController.offset / _currentRowHeight).floor().clamp(0, _days.length - 1);
    final d = _days[idx];
    _monthTitle.value = '${d.year}年${d.month}月';
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
      _isLoadingMore = false;
    });
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final performances = await db.getAllPerformancesWithShow();
    final castMap = <int, List<CastMember>>{};
    for (final perf in performances) {
      final perfId = perf['id'] as int;
      final casts = await db.getCastMembersByPerformanceId(perfId);
      castMap[perfId] = casts;
    }
    if (mounted) {
      setState(() {
        _performances = performances;
        _castMap = castMap;
        _isLoading = false;
      });
      // 数据加载完成后，滚动到今天为第一个可见行
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(30 * _currentRowHeight);
          _updateMonthTitle();
        }
      });
    }
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _monthTitle.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 回到今天：重置列表，今天为第一个可见行
  void _goToToday() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    setState(() {
      _days = List.generate(91, (i) => DateTime(start.year, start.month, start.day + i));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(30 * _currentRowHeight);
        _updateMonthTitle();
      }
    });
  }

  /// 弹出年月选择器，选择后跳转到对应月份
  void _pickYearMonth() async {
    // 解析当前显示的年月
    final parts = _monthTitle.value.split('年');
    final currentYear = int.tryParse(parts[0]) ?? DateTime.now().year;
    final currentMonth = int.tryParse(parts[1].replaceFirst('月', '')) ?? DateTime.now().month;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(currentYear, currentMonth, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null && mounted) {
      // 只取年月，跳转到该月第一天
      _jumpToMonth(picked.year, picked.month);
    }
  }

  /// 跳转到指定月份
  void _jumpToMonth(int year, int month) {
    // 查找该月份在 _days 中的第一天
    final targetIndex = _days.indexWhere((d) => d.year == year && d.month == month);
    if (targetIndex >= 0) {
      // 已在列表中，直接滚动
      _scrollController.animateTo(
        targetIndex * _currentRowHeight,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      // 不在当前范围，重新生成日期列表并加载
      _loadDataForMonth(year, month);
    }
  }

  /// 重新生成日期列表，以目标月份为中心
  Future<void> _loadDataForMonth(int year, int month) async {
    final center = DateTime(year, month, 1);
    final start = center.subtract(const Duration(days: 30));
    final end = center.add(const Duration(days: 60));

    setState(() {
      _isLoading = true;
      _days = [];
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        _days.add(d);
      }
    });

    final db = DatabaseHelper.instance;
    final performances = await db.getAllPerformancesWithShow();
    final castMap = <int, List<CastMember>>{};
    for (final perf in performances) {
      final perfId = perf['id'] as int;
      final casts = await db.getCastMembersByPerformanceId(perfId);
      castMap[perfId] = casts;
    }

    if (mounted) {
      setState(() {
        _performances = performances;
        _castMap = castMap;
        _isLoading = false;
      });
      // 滚动到目标月份第一天
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = _days.indexWhere((d) => d.year == year && d.month == month);
        if (idx >= 0 && _scrollController.hasClients) {
          _scrollController.jumpTo(idx * _currentRowHeight);
          _updateMonthTitle();
        }
      });
    }
  }

  /// 获取某天的所有演出（含 show 信息）
  List<Map<String, dynamic>> _getPerformancesForDay(DateTime day) {
    final dateStr = _fullDateFormat.format(day);
    return _performances.where((p) => p['date'] == dateStr).toList()
      ..sort((a, b) => ((a['time'] as String?) ?? '').compareTo((b['time'] as String?) ?? ''));
  }

  Color _getShowColor(int showId) {
    return _kCoverColors[showId.abs() % _kCoverColors.length];
  }

  // ==================== 状态操作 ====================

  Future<void> _updateStatus(int perfId, String status) async {
    final db = DatabaseHelper.instance;
    final perf = await db.getPerformanceById(perfId);
    if (perf == null) return;
    await db.updatePerformance(perf.copyWith(status: status));
    _loadData();
  }

  Future<void> _showBoughtForm(int perfId) async {
    final seatController = TextEditingController();
    final priceController = TextEditingController();
    final actualPriceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('补充购票信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: seatController,
              decoration: const InputDecoration(
                labelText: '座位',
                hintText: '如: 1楼-3排-5号',
                prefixIcon: Icon(Icons.event_seat_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '票面价格',
                hintText: '如: 580',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: actualPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '实付价格',
                hintText: '如: 480',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = DatabaseHelper.instance;
      final perf = await db.getPerformanceById(perfId);
      if (perf != null) {
        await db.updatePerformance(perf.copyWith(
          status: 'bought',
          seat: seatController.text.isNotEmpty ? seatController.text : null,
          price: priceController.text.isNotEmpty
              ? double.tryParse(priceController.text)
              : null,
          actualPrice: actualPriceController.text.isNotEmpty
              ? double.tryParse(actualPriceController.text)
              : null,
        ));
        _loadData();
      }
    } else if (result == false) {
      await _updateStatus(perfId, 'bought');
    }

    seatController.dispose();
    priceController.dispose();
    actualPriceController.dispose();
  }

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

  // ==================== + 号按钮分流弹窗 ====================

  void _showAddMenu() {
    showModalBottomSheet(
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
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Color(0xFF6B5BCD)),
                title: const Text('手动录入新排期'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    SlideFadeRoute(page: const AddShowScreen()),
                  );
                  if (result == true) _loadData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF6B5BCD)),
                title: const Text('拍照/相册识别卡司'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndRecognize();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageAndRecognize() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      String text;
      try {
        text = await recognizeTextAuto(bytes);
      } on BaiduOcrException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('百度 OCR 失败: $e，请检查配置')));
        }
        return;
      }

      if (text.trim().isEmpty) {
        if (mounted) {
          _showOcrErrorDialog('未识别到文字，请上传更清晰的排期表');
        }
        return;
      }

      List<CastEntry>? castList;
      String? showName;
      String? scheduleDate;
      String? scheduleTime;

      if (isScheduleFormat(text)) {
        final schedule = parseSchedule(text);
        if (schedule.isEmpty) {
          if (mounted) _showOcrErrorDialog('未解析到排期信息，请上传更清晰的排期表');
          return;
        }
        castList = schedule.first.castList;
        scheduleDate = schedule.first.date;
        scheduleTime = schedule.first.time;
      } else {
        castList = parseCastText(text);
        if (castList.isEmpty) {
          if (mounted) _showOcrErrorDialog('未识别到卡司信息，请上传更清晰的排期表');
          return;
        }
      }

      // 知识库修正
      final corrected = await correctOcrResult(showName: showName, theater: null, castList: castList);
      final correctedCasts = corrected.castList.map((c) => CastEntry(c.role, c.actor)).toList();

      if (!mounted) return;

      // 跳转到 AddShowScreen 预填数据
      final result = await Navigator.push(
        context,
        SlideFadeRoute(page: AddShowScreen(
          initialShow: null,
          initialPerformances: null,
          isEditMode: false,
        )),
      );
      if (result == true) _loadData();
    } catch (e) {
      if (mounted) {
        _showOcrErrorDialog('识别失败: $e');
      }
    }
  }

  void _showOcrErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('识别失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
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
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: _buildMonthTitle(),
        actions: [
          // 视图密度切换
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: IconButton(
              key: ValueKey<TimelineMode>(_mode),
              onPressed: () => _switchMode(
                _mode == TimelineMode.focus3Day
                    ? TimelineMode.micro7Day
                    : TimelineMode.focus3Day,
              ),
              icon: Icon(
                _mode == TimelineMode.focus3Day
                    ? Icons.density_medium
                    : Icons.density_small,
                color: const Color(0xFF6B5BCD),
              ),
              tooltip: _mode == TimelineMode.focus3Day
                  ? '切换到 7 天宏观模式'
                  : '切换到 3 天聚焦模式',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5BCD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  SlideFadeRoute(page: const AddShowScreen()),
                );
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.add, size: 24),
              color: Colors.white,
              tooltip: '添加剧目',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _performances.isEmpty
              ? _buildEmptyState()
              : _buildTimeline(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingIcon(icon: Icons.view_timeline_outlined),
          const SizedBox(height: 16),
          const Text('暂无排期', style: TextStyle(fontSize: 18, color: Color(0xFF8A8F98))),
          const SizedBox(height: 8),
          const Text('点击右上角 + 添加剧目', style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C))),
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

  Widget _buildMonthTitle() {
    return ValueListenableBuilder<String>(
      valueListenable: _monthTitle,
      builder: (context, title, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 年月文字 → 点击弹出年月选择器进行跳转
            GestureDetector(
              onTap: _pickYearMonth,
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            // 管理台 icon
            GestureDetector(
              onTap: () {
                final parts = title.split('年');
                if (parts.length == 2) {
                  final year = int.tryParse(parts[0]);
                  final month = int.tryParse(parts[1].replaceFirst('月', ''));
                  if (year != null && month != null) {
                    _openMonthlyWorkbench(year, month);
                  }
                }
              },
              child: const Icon(Icons.calendar_month, size: 20, color: Color(0xFF9CA3AF)),
            ),
          ],
        );
      },
    );
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
              return _buildDayRow(index, today);
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

    // 所有计算和滚动调整在布局完成后执行，确保使用最新的行高和 maxScrollExtent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 在 post frame 中重新计算行高，确保 _availableHeight 已更新
        final oldRowHeight = previousMode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;
        final newRowHeight = _mode == TimelineMode.focus3Day ? _focusRowHeight : _microRowHeight;

        // 用 floor 更保守：确保视口顶部始终是同一个 item
        final firstVisibleIndex = (previousOffset / oldRowHeight).floor().clamp(0, _days.length - 1);
        final targetOffset = firstVisibleIndex * newRowHeight;

        _scrollController.jumpTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
      // jumpTo 后强制 rebuild，让 _buildMonthTitle 使用新的 offset 计算正确月份
      if (mounted) setState(() {});
      _isTransitioning = false;
      // 短暂标记刚刚切换完，阻止磁吸干扰 jumpTo 后的位置
      _justSwitched = true;
      Future.delayed(const Duration(milliseconds: 300), () => _justSwitched = false);
    });
  }

  // ==================== 统一日期行（行高瞬间切换，避免 ListView 滚动冲突） ====================

  Widget _buildDayRow(int index, DateTime today) {
    final day = _days[index];
    final isToday = _isSameDay(day, today);
    final dayPerfs = _getPerformancesForDay(day);
    final isFocus = _mode == TimelineMode.focus3Day;
    final targetHeight = isFocus ? _focusRowHeight : _microRowHeight;

    return Container(
      height: targetHeight,
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFF54A45).withValues(alpha: 0.04) : const Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 左侧日期标签
          Container(
            width: isFocus ? _labelWidth : _microLabelWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 大日期：聚焦模式显示 MM-DD，微观模式显示几号
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? 14 : 16,
                    fontWeight: isFocus ? FontWeight.w700 : FontWeight.w800,
                    color: isToday ? const Color(0xFFF54A45) : Colors.white.withOpacity(0.9),
                  ),
                  child: Text(isFocus
                      ? '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'
                      : '${day.day}'),
                ),
                const SizedBox(height: 2),
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: isFocus ? 10 : 9,
                    fontWeight: FontWeight.w500,
                    color: isToday ? const Color(0xFFF54A45).withOpacity(0.7) : const Color(0xFF6B7280),
                  ),
                  child: Text(isFocus
                      ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1]
                      : '周${['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}'),
                ),
                // 今天/明天标签（聚焦模式才显示）
                Opacity(
                  opacity: isFocus ? 1.0 : 0.0,
                  child: _buildTodayBadge(day, isToday),
                ),
              ],
            ),
          ),
          // 右侧内容区
          Expanded(
            child: dayPerfs.isEmpty
                ? (isFocus
                    ? Center(
                        child: Text('无排期',
                          style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12)),
                      )
                    : const SizedBox())
                : isFocus
                    ? _buildFocusContent(dayPerfs, targetHeight)
                    : _buildMicroContent(dayPerfs, targetHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayBadge(DateTime day, bool isToday) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final isTomorrow = _isSameDay(day, tomorrow);
    if (!isToday && !isTomorrow) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFF54A45).withOpacity(0.15)
              : const Color(0xFF6B5BCD).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isToday ? '今天' : '明天',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isToday ? const Color(0xFFF54A45) : const Color(0xFF6B5BCD),
          ),
        ),
      ),
    );
  }

  // ==================== 聚焦模式内容（大海报卡片） ====================

  Widget _buildFocusContent(List<Map<String, dynamic>> dayPerfs, double rowHeight, {Key? key}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - _labelWidth) * 0.45;
    final cardHeight = rowHeight - 24;

    return ListView.builder(
      key: key,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildFocusCard(dayPerfs[index], cardWidth, cardHeight),
    );
  }

  Widget _buildFocusCard(Map<String, dynamic> perf, double cardWidth, double cardHeight) {
    final showId = perf['show_id'] as int;
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = _getShowColor(showId);
    final perfId = perf['id'] as int;
    final status = perf['status'] as String? ?? 'unmarked';

    // 卡司：全部显示
    final allCasts = _castMap[perfId] ?? [];

    final hasCover = coverPath != null && coverPath.isNotEmpty;

    return GestureDetector(
      onTap: () => _showPerformanceDetail(perf),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.only(right: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: 海报底图（无海报时用深色渐变）
              if (hasCover)
                Image.file(File(coverPath!), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, _kCoverColors[(showId + 3) % _kCoverColors.length]],
                      ),
                    ),
                  ))
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, _kCoverColors[(showId + 3) % _kCoverColors.length]],
                    ),
                  ),
                ),
              // Layer 2: 全屏蒙版
              Container(color: Colors.black.withOpacity(0.5)),
              // Layer 3: 信息
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 时间 + 状态
                      Row(
                        children: [
                          if (time.isNotEmpty)
                            Text('🕒 $time',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (status == 'want_to_see' || status == 'bought')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: status == 'bought'
                                    ? const Color(0xFF34D399).withOpacity(0.85)
                                    : const Color(0xFF811FE2).withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status == 'bought' ? '已买' : '想看',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      // 剧名
                      const SizedBox(height: 4),
                      Text(showName,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      // 剧场
                      if (theater.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(theater,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      // 卡司列表（可滚动）
                      if (allCasts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: allCasts.length,
                            itemBuilder: (context, i) {
                              final c = allCasts[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(c.role,
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('|', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(c.actorName,
                                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 微观模式内容（邮票墙） ====================

  Widget _buildMicroContent(List<Map<String, dynamic>> dayPerfs, double rowHeight, {Key? key}) {
    return ListView.builder(
      key: key,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemCount: dayPerfs.length,
      itemBuilder: (context, index) => _buildMicroCard(dayPerfs[index], rowHeight - 8),
    );
  }

  Widget _buildMicroCard(Map<String, dynamic> perf, double cardHeight) {
    final showId = perf['show_id'] as int;
    final time = (perf['time'] as String?)?.substring(0, 5) ?? '';
    final coverPath = perf['cover_path'] as String?;
    final color = _getShowColor(showId);
    final cardWidth = cardHeight * 0.75; // 3:4 比例

    return GestureDetector(
      onTap: () => _showPerformanceDetail(perf),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.only(right: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              coverPath != null && coverPath.isNotEmpty
                  ? Image.file(File(coverPath), fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, color.withOpacity(0.6)],
                        ),
                      ),
                    ),
              Container(
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.35),
                child: Text(time,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                  )),
              ),
            ],
          ),
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
    final next = perf.status == 'bought'
        ? 'unmarked'
        : perf.status == 'want_to_see'
            ? 'bought'
            : 'want_to_see';
    await DatabaseHelper.instance.updatePerformance(perf.copyWith(status: next));
    setState(() {
      _performances = _performances.map((p) {
        if (p.id == perf.id) return p.copyWith(status: next);
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF4D4D4D), borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isEditing ? _buildEditForm() : _buildShowInfo(),
          ),
          const SizedBox(height: 12),
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: _filteredPerformances.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_filter == _ShowFilter.all ? '暂无排期' : '暂无符合条件的排期', style: const TextStyle(color: Color(0xFF8A8F98))),
                  ))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredPerformances.length,
                    itemBuilder: (context, index) {
                      final perf = _filteredPerformances[index];
                      final isWatched = _isWatched(perf);
                      final status = statusFromString(perf.status);
                      final displayLabel = isWatched ? '已观演' : status.label;
                      final displayColor = isWatched ? const Color(0xFF9CA3AF) : status.color;
                      final displayIcon = isWatched
                          ? Icons.visibility
                          : (perf.status == 'bought' ? Icons.check_circle : perf.status == 'want_to_see' ? Icons.star : Icons.circle_outlined);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: displayColor.withValues(alpha: 0.15),
                          child: Icon(displayIcon, size: 18, color: displayColor),
                        ),
                        title: Text('${perf.date} ${perf.time?.substring(0, 5) ?? ''}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: perf.seat != null && perf.seat!.isNotEmpty ? Text('座位: ${perf.seat}') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusBadge(label: displayLabel, color: displayColor, onTap: () => _toggleStatus(perf)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _deletePerformance(perf.id!),
                              color: Colors.red[300],
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ],
                        ),
                        onTap: () => widget.onEditPerformance(perf.toMap()),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteShow,
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                  label: Text('删除剧目', style: TextStyle(color: Colors.red[300])),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[300], padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildShowInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_showName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_showTheater != null && _showTheater!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(_showTheater!, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8F98))),
                ),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => setState(() => _isEditing = true), tooltip: '编辑', constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 26), onPressed: () => widget.onQuickAdd(widget.showId), tooltip: '添加场次', color: const Color(0xFF6B5BCD), constraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: filters.map((f) {
          final isActive = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(f.$2),
              selected: isActive,
              onSelected: (_) => setState(() => _filter = f.$1),
              selectedColor: f.$3?.withValues(alpha: 0.2) ?? const Color(0xFF6B5BCD).withValues(alpha: 0.2),
              backgroundColor: const Color(0xFF1F1F1F),
              side: BorderSide(color: isActive ? (f.$3 ?? const Color(0xFF6B5BCD)).withValues(alpha: 0.5) : const Color(0xFF2A2A2A)),
              labelStyle: TextStyle(color: isActive ? (f.$3 ?? const Color(0xFF6B5BCD)) : const Color(0xFF8A8F98), fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, fontSize: 12),
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
