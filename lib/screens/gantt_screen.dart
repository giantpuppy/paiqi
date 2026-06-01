import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../utils/page_transitions.dart';
import '../models/actor.dart';
import 'add_show_screen.dart';

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

class GanttScreen extends StatefulWidget {
  const GanttScreen({super.key});

  @override
  State<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends State<GanttScreen> {
  List<Map<String, dynamic>> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  bool _isLoading = true;

  DateTime _weekStart = _getWeekStart(DateTime.now());

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  static const double _layerGap = 8;
  static const double _rowPadding = 20;
  static const double _headerHeight = 48;
  static const double _leftPanelWidth = 120;
  static const double _minBlockHeight = 64;

  static DateTime _getWeekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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
    setState(() {
      _performances = performances;
      _castMap = castMap;
      _isLoading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _weekStart = _getWeekStart(DateTime.now());
    });
  }

  int _getLayers(int showId, List<Map<String, dynamic>> perfs) {
    final dayCounts = <String, int>{};
    for (final p in perfs) {
      if (p['show_id'] != showId) continue;
      final date = p['date'] as String;
      dayCounts[date] = (dayCounts[date] ?? 0) + 1;
    }
    if (dayCounts.isEmpty) return 1;
    return dayCounts.values.reduce((a, b) => a > b ? a : b);
  }

  /// 计算单个演出区块的高度（根据卡司数量自适应）
  double _calculateBlockHeight(List<CastMember> casts) {
    const timeRowHeight = 18.0;
    const castLineHeight = 14.0;
    const verticalPadding = 8.0;
    final featuredCasts = casts.where((c) => c.isFeatured == true).toList();
    final castHeight = featuredCasts.length * castLineHeight;
    final h = verticalPadding + timeRowHeight + castHeight + verticalPadding;
    return h < _minBlockHeight ? _minBlockHeight : h;
  }

  /// 计算行高（基于各层的最大区块高度）
  double _getRowHeight(List<double> layerHeights) {
    var total = _rowPadding + _rowPadding;
    for (var i = 0; i < layerHeights.length; i++) {
      total += layerHeights[i];
      if (i < layerHeights.length - 1) total += _layerGap;
    }
    return total;
  }

  Color _getShowColor(int showId) {
    final colors = [
      const Color(0xFF3370FF),
      const Color(0xFF34D399),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFFF97316),
    ];
    return colors[showId.abs() % colors.length];
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

  void _showPerformanceDetail(Map<String, dynamic> perf) {
    final status = statusFromString(perf['status'] as String?);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildDetailSheet(perf, status),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> perf, PerformanceStatus status) {
    final showName = perf['show_name'] as String? ?? '未知';
    final theater = perf['theater'] as String? ?? '';
    final date = perf['date'] as String? ?? '';
    final time = perf['time'] as String? ?? '';
    final seat = perf['seat'] as String? ?? '';
    final price = perf['price'] != null ? '¥${perf['price']}' : '';
    final actualPrice = perf['actual_price'] != null ? '¥${perf['actual_price']}' : '';
    final perfId = perf['id'] as int;
    final casts = _castMap[perfId] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4D4D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: status.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (theater.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 18, color: const Color(0xFF8A8F98)),
                      const SizedBox(width: 4),
                      Text(theater,
                          style: TextStyle(color: const Color(0xFFB3B3B3))),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildInfoItem(Icons.calendar_today, '日期', date),
                    _buildInfoItem(Icons.access_time, '时间',
                        time.isNotEmpty ? time : '未设置'),
                    if (seat.isNotEmpty)
                      _buildInfoItem(Icons.event_seat, '座位', seat),
                    if (price.isNotEmpty)
                      _buildInfoItem(Icons.confirmation_number_outlined, '票面', price),
                    if (actualPrice.isNotEmpty)
                      _buildInfoItem(Icons.payments_outlined, '实付', actualPrice),
                  ],
                ),
              ),
              if (casts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('卡司',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB3B3B3))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: casts.map((c) {
                    final isFeatured = c.isFeatured == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? const Color(0xFF811FE2).withValues(alpha: 0.08)
                            : const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(8),
                        border: isFeatured
                            ? Border.all(
                                color: const Color(0xFF811FE2)
                                    .withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Text(
                        '${c.role}: ${c.actorName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isFeatured
                              ? const Color(0xFF811FE2)
                              : const Color(0xFFB3B3B3),
                          fontWeight:
                              isFeatured ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Text('标记状态',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3))),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusButton(
                    label: '想看',
                    icon: Icons.star_border,
                    color: PerformanceStatus.wantToSee.color,
                    isActive: status == PerformanceStatus.wantToSee,
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateStatus(perfId, 'want_to_see');
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildStatusButton(
                    label: '已买',
                    icon: Icons.check_circle_outline,
                    color: PerformanceStatus.bought.color,
                    isActive: status == PerformanceStatus.bought,
                    onTap: () async {
                      Navigator.pop(context);
                      await _showBoughtForm(perfId);
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildStatusButton(
                    label: '取消',
                    icon: Icons.remove_circle_outline,
                    color: PerformanceStatus.unmarked.color,
                    isActive: status == PerformanceStatus.unmarked,
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateStatus(perfId, 'unmarked');
                    },
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPerformance(perf);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(perf),
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red[400]),
                      label: Text('删除',
                          style: TextStyle(color: Colors.red[400])),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(500),
            border: Border.all(
              color: isActive ? color : const Color(0xFF4D4D4D),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isActive ? color : const Color(0xFF8A8F98), size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? color : const Color(0xFF8A8F98),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8A8F98)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: const Color(0xFF8A8F98))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ==================== 编辑 / 删除 / 添加 ====================

  void _editPerformance(Map<String, dynamic> perf) async {
    final db = DatabaseHelper.instance;
    final perfId = perf['id'] as int;
    final existingCasts = await db.getCastMembersByPerformanceId(perfId);

    // ignore: use_build_context_synchronously
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return _EditPerformanceSheet(
          perf: perf,
          existingCasts: existingCasts,
          onSaved: () {
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更新成功')),
              );
            }
          },
        );
      },
    );
  }

  void _confirmDelete(Map<String, dynamic> perf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              final db = DatabaseHelper.instance;
              await db.deletePerformance(perf['id'] as int);
              await db.deleteCastMembersByPerformanceId(perf['id'] as int);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickTimeQuick(BuildContext context,
      {String? initial}) async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const Text('选择开场时间',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(
                        label: Text(t),
                        onPressed: () => Navigator.pop(context, t),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = (initial ?? '19:30').split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        Navigator.pop(
                          context,
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
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
  }

  void _quickAddPerformance(int showId) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (date == null) return;

    final time = await _pickTimeQuick(context);
    if (time == null) return;

    final db = DatabaseHelper.instance;
    await db.createPerformance(Performance(
      showId: showId,
      date: _fullDateFormat.format(date),
      time: time,
      status: 'unmarked',
      createdAt: DateTime.now().toIso8601String(),
    ));

    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('场次添加成功')),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _performances.isEmpty
              ? _buildEmptyState()
              : _buildGanttChart(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingIcon(icon: Icons.view_timeline_outlined),
          const SizedBox(height: 16),
          const Text('暂无排期',
              style: TextStyle(fontSize: 18, color: Color(0xFF8A8F98))),
          const SizedBox(height: 8),
          const Text('点击右下角添加剧目',
              style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                SlideFadeRoute(
                    page: const AddShowScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.add),
            label: const Text('添加剧目'),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttChart() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - _leftPanelWidth) / 7;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final today = DateTime.now();
    final isCurrentWeek = _isSameDay(_getWeekStart(today), _weekStart);

    // 按剧目分组（只包含当前周内的演出）
    final showGroups = <int, List<Map<String, dynamic>>>{};
    for (final perf in _performances) {
      final showId = perf['show_id'] as int;
      final date = DateTime.parse(perf['date'] as String);
      final dayIdx = DateTime(date.year, date.month, date.day)
          .difference(DateTime(_weekStart.year, _weekStart.month, _weekStart.day))
          .inDays;
      // 只保留当前周范围内的演出
      if (dayIdx < 0 || dayIdx >= 7) continue;
      showGroups.putIfAbsent(showId, () => []);
      showGroups[showId]!.add(perf);
    }

    // 计算每行各层的最大区块高度
    final layerHeightsMap = <int, List<double>>{};
    final rowHeights = <int, double>{};
    double totalHeight = 0;
    for (final entry in showGroups.entries) {
      final showId = entry.key;
      final perfs = entry.value;
      final layers = _getLayers(showId, perfs);
      // 计算每层最大高度
      final layerHeights = List<double>.filled(layers, _minBlockHeight);
      // 按天分组，计算每天的各层高度
      for (final p in perfs) {
        final d = DateTime.parse(p['date'] as String);
        final idx = DateTime(d.year, d.month, d.day)
            .difference(DateTime(_weekStart.year, _weekStart.month, _weekStart.day))
            .inDays;
        if (idx < 0 || idx >= 7) continue;
        // 按时间排序后确定层索引
        final dayPerfs = perfs.where((pp) => pp['date'] == p['date']).toList()
          ..sort((a, b) => ((a['time'] as String?) ?? '').compareTo((b['time'] as String?) ?? ''));
        final layerIdx = dayPerfs.indexWhere((pp) => pp['id'] == p['id']);
        if (layerIdx >= 0 && layerIdx < layers) {
          final perfId = p['id'] as int;
          final casts = (_castMap[perfId] ?? []).where((c) => c.isFeatured == true).toList();
          final h = _calculateBlockHeight(casts);
          if (h > layerHeights[layerIdx]) layerHeights[layerIdx] = h;
        }
      }
      layerHeightsMap[showId] = layerHeights;
      final h = _getRowHeight(layerHeights);
      rowHeights[showId] = h;
      totalHeight += h;
    }

    return Column(
      children: [
        _buildToolbar(cellWidth, weekEnd),
        // 表头
        Container(
          height: _headerHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            color: Color(0xFF181818),
          ),
          child: Row(
            children: [
              Container(
                width: _leftPanelWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  '剧目',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white),
                ),
              ),
              Expanded(
                child: Row(
                  children: List.generate(7, (index) {
                    final date = _weekStart.add(Duration(days: index));
                    final isToday = _isSameDay(date, today);
                    final isWeekend = date.weekday >= 6;

                    return Container(
                      width: cellWidth,
                      height: _headerHeight,
                      decoration: BoxDecoration(
                        border: const Border(
                          right: BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                        color: isToday
                            ? const Color(0xFFF54A45).withValues(alpha: 0.08)
                            : (isWeekend
                                ? const Color(0xFF1A1A1A)
                                : null),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? const Color(0xFFF54A45)
                                  : (isWeekend
                                      ? const Color(0xFF8A8F98)
                                      : Colors.white),
                            ),
                          ),
                          Text(
                            ['一', '二', '三', '四', '五', '六', '日']
                                [date.weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              color: isToday
                                  ? const Color(0xFFF54A45)
                                      .withValues(alpha: 0.7)
                                  : const Color(0xFF8A8F98),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        // 数据区域
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 200) {
                  _prevWeek();
                } else if (details.primaryVelocity! < -200) {
                  _nextWeek();
                }
              }
            },
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧列表
                  Container(
                    width: _leftPanelWidth,
                    decoration: const BoxDecoration(
                      border:
                          Border(right: BorderSide(color: Color(0xFF2A2A2A))),
                    ),
                    child: Column(
                      children: showGroups.entries.map((entry) {
                        final showId = entry.key;
                        final perfs = entry.value;
                        final showName =
                            perfs.first['show_name'] as String? ?? '未知';
                        final showTheater =
                            perfs.first['theater'] as String? ?? '';
                        final color = _getShowColor(showId);
                        final h = rowHeights[showId] ?? _getRowHeight([_minBlockHeight]);

                        return GestureDetector(
                          onTap: () => _showShowDetail(showId, showName),
                          behavior: HitTestBehavior.translucent,
                          child: Container(
                            height: h,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: const Color(0xFF1F1F1F))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                            MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        showName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (showTheater.isNotEmpty)
                                        Text(
                                          showTheater,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF8A8F98),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // 右侧时间轴
                  Expanded(
                    child: SizedBox(
                      height: totalHeight,
                      child: Stack(
                        children: [
                          // 背景格子和甘特条
                          Column(
                            children: showGroups.entries.map((entry) {
                              final showId = entry.key;
                              final perfs = entry.value;
                              final rowH = rowHeights[showId] ?? _getRowHeight([_minBlockHeight]);

                              // 按 dayIndex 分组
                              final dayGroups = <int, List<Map<String, dynamic>>>{};
                              for (final p in perfs) {
                                final d = DateTime.parse(p['date'] as String);
                                final idx = DateTime(d.year, d.month, d.day)
                                    .difference(DateTime(
                                        _weekStart.year,
                                        _weekStart.month,
                                        _weekStart.day))
                                    .inDays;
                                if (idx < 0 || idx >= 7) continue;
                                dayGroups.putIfAbsent(idx, () => []);
                                dayGroups[idx]!.add(p);
                              }

                              // 排序每个日期的场次
                              for (final list in dayGroups.values) {
                                list.sort((a, b) {
                                  final ta = (a['time'] as String?) ?? '';
                                  final tb = (b['time'] as String?) ?? '';
                                  return ta.compareTo(tb);
                                });
                              }

                              return Container(
                                height: rowH,
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: const Color(0xFF1F1F1F))),
                                ),
                                child: Stack(
                                  children: [
                                    // 背景格子
                                    Row(
                                      children: List.generate(7, (index) {
                                        final date = _weekStart
                                            .add(Duration(days: index));
                                        final isToday = _isSameDay(
                                            date, DateTime.now());
                                        final isWeekend =
                                            date.weekday >= 6;

                                        return Container(
                                          width: cellWidth,
                                          height: rowH,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(
                                                  color: const Color(
                                                      0xFF1F1F1F)),
                                            ),
                                            color: isToday
                                                ? const Color(
                                                        0xFFF54A45)
                                                    .withValues(
                                                        alpha: 0.08)
                                                : (isWeekend
                                                    ? const Color(
                                                            0xFF1A1A1A)
                                                    : null),
                                          ),
                                        );
                                      }),
                                    ),
                                    // 甘特条（按层渲染）
                                    ...dayGroups.entries.expand((dayEntry) {
                                      final dayIndex = dayEntry.key;
                                      final dayPerfs = dayEntry.value;

                                      return dayPerfs
                                          .asMap()
                                          .entries
                                          .map((perfEntry) {
                                        final layer = perfEntry.key;
                                        final perf = perfEntry.value;
                                        final status = statusFromString(
                                            perf['status'] as String?);
                                        final isUnmarked = status ==
                                            PerformanceStatus.unmarked;
                                        final statusColor = isUnmarked
                                            ? const Color(0xFF9CA3AF)
                                            : (status ==
                                                    PerformanceStatus
                                                        .wantToSee
                                                ? const Color(
                                                    0xFF811FE2)
                                                : const Color(
                                                    0xFF34D399));

                                        // 计算该区块的 top 位置
                                        final showLayerHeights = layerHeightsMap[showId] ?? [_minBlockHeight];
                                        var top = _rowPadding.toDouble();
                                        for (var i = 0; i < layer && i < showLayerHeights.length; i++) {
                                          top += showLayerHeights[i] + _layerGap;
                                        }
                                        final blockHeight = (layer < showLayerHeights.length)
                                            ? showLayerHeights[layer]
                                            : _minBlockHeight;

                                        final perfId = perf['id'] as int;
                                        final featuredCasts =
                                            (_castMap[perfId] ?? [])
                                                .where((c) =>
                                                    c.isFeatured == true)
                                                .toList();

                                        return Positioned(
                                          left: dayIndex * cellWidth +
                                              2,
                                          top: top,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _showPerformanceDetail(
                                                    perf),
                                            child: Container(
                                              width: cellWidth - 4,
                                              height: blockHeight,
                                              decoration: BoxDecoration(
                                                color: isUnmarked
                                                    ? statusColor
                                                        .withValues(
                                                            alpha: 0.25)
                                                    : statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        4),
                                                border: Border.all(
                                                  color: isUnmarked
                                                      ? statusColor
                                                          .withValues(
                                                              alpha: 0.4)
                                                      : statusColor
                                                          .withValues(
                                                              alpha: 0.8),
                                                  width: 0.5,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(3),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                children: [
                                                  // 时间行
                                                  Row(
                                                    children: [
                                                      if (!isUnmarked &&
                                                          (cellWidth - 10) >= 40)
                                                        Icon(
                                                          status == PerformanceStatus.wantToSee
                                                              ? Icons.star
                                                              : Icons.check,
                                                          size: 12,
                                                          color: Colors
                                                              .white
                                                              .withValues(
                                                                  alpha:
                                                                      0.9),
                                                        ),
                                                      if (!isUnmarked &&
                                                          (cellWidth - 10) >= 40)
                                                        const SizedBox(
                                                            width: 2),
                                                      Flexible(
                                                        child: Text(
                                                          (perf['time'] as String?)
                                                                  ?.substring(
                                                                      0,
                                                                      5) ??
                                                              '',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: isUnmarked
                                                                ? const Color(
                                                                    0xFF4B5563)
                                                                : Colors
                                                                    .white,
                                                            height: 1.1,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // 卡司行
                                                  if (featuredCasts
                                                      .isNotEmpty)
                                                    ...featuredCasts
                                                        .map((c) {
                                                      return Text(
                                                        '${c.role}:${c.actorName}',
                                                        style:
                                                            TextStyle(
                                                          fontSize: 10,
                                                          color: isUnmarked
                                                              ? const Color(
                                                                  0xFF6B7280)
                                                              : Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.9),
                                                          height: 1.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      );
                                                    }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          // 今天线
                          if (isCurrentWeek)
                            Positioned(
                              left: (today.weekday - 1) * cellWidth +
                                  cellWidth / 2 -
                                  1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: const Color(0xFFF54A45)
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(double cellWidth, DateTime weekEnd) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
        color: Color(0xFF181818),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevWeek,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一周',
          ),
          OutlinedButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18),
            label: const Text('今天'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一周',
          ),
          const SizedBox(width: 12),
          Text(
            '${_weekStart.month}/${_weekStart.day} - ${weekEnd.month}/${weekEnd.day}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6B5BCD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  SlideFadeRoute(
                      page: const AddShowScreen()),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add, size: 32),
              color: Colors.white,
              tooltip: '添加剧目',
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // 显示剧目管理面板（点击左侧剧目名称触发）
  void _showShowDetail(int showId, String showName) async {
    final db = DatabaseHelper.instance;
    final perfs = await db.getPerformancesByShowId(showId);
    final show = await db.getShowById(showId);

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ShowManagementSheet(
        showId: showId,
        showName: showName,
        showTheater: show?.theater,
        performances: perfs,
        onDataChanged: _loadData,
        onQuickAdd: (id) {
          Navigator.pop(sheetContext);
          _quickAddPerformance(id);
        },
        onEditPerformance: (perfMap) {
          Navigator.pop(sheetContext);
          _editPerformance(perfMap);
        },
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
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
          // 拖拽手柄
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF4D4D4D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 剧目信息 / 编辑表单
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isEditing ? _buildEditForm() : _buildShowInfo(),
          ),
          const SizedBox(height: 12),
          // 筛选栏
          _buildFilterBar(),
          const Divider(height: 1),
          // 场次列表
          Expanded(
            child: _filteredPerformances.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _filter == _ShowFilter.all
                            ? '暂无排期'
                            : '暂无符合条件的排期',
                        style: const TextStyle(color: Color(0xFF8A8F98)),
                      ),
                    ),
                  )
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
                          : (perf.status == 'bought'
                              ? Icons.check_circle
                              : perf.status == 'want_to_see'
                                  ? Icons.star
                                  : Icons.circle_outlined);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: displayColor.withValues(alpha: 0.15),
                          child: Icon(
                            displayIcon,
                            size: 18,
                            color: displayColor,
                          ),
                        ),
                        title: Text(
                          '${perf.date} ${perf.time?.substring(0, 5) ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: perf.seat != null && perf.seat!.isNotEmpty
                            ? Text('座位: ${perf.seat}')
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusBadge(
                              label: displayLabel,
                              color: displayColor,
                              onTap: () => _toggleStatus(perf),
                            ),
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
          // 底部操作
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteShow,
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                    label: Text('删除剧目', style: TextStyle(color: Colors.red[300])),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[300],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
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
              Text(
                _showName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_showTheater != null && _showTheater!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _showTheater!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8F98),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => setState(() => _isEditing = true),
          tooltip: '编辑',
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 26),
          onPressed: () => widget.onQuickAdd(widget.showId),
          tooltip: '添加场次',
          color: const Color(0xFF6B5BCD),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '剧目名称',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _theaterController,
          decoration: const InputDecoration(
            labelText: '演出地点',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _saveShowInfo,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
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
              side: BorderSide(
                color: isActive
                    ? (f.$3 ?? const Color(0xFF6B5BCD)).withValues(alpha: 0.5)
                    : const Color(0xFF2A2A2A),
              ),
              labelStyle: TextStyle(
                color: isActive ? (f.$3 ?? const Color(0xFF6B5BCD)) : const Color(0xFF8A8F98),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
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

  const _StatusBadge({
    required this.label,
    required this.color,
    this.onTap,
  });

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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ==================== 编辑场次 Sheet ====================

class _EditPerformanceSheet extends StatefulWidget {
  final Map<String, dynamic> perf;
  final List<CastMember> existingCasts;
  final VoidCallback onSaved;

  const _EditPerformanceSheet({
    required this.perf,
    required this.existingCasts,
    required this.onSaved,
  });

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
      _castRows.add(_EditCastRow(
        role: c.role,
        actor: c.actorName,
        featured: c.isFeatured,
      ));
    }
    if (_castRows.isEmpty) {
      _castRows.add(_EditCastRow());
    }
  }

  @override
  void dispose() {
    for (final r in _castRows) {
      r.dispose();
    }
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
    if (picked != null) {
      setState(() => _date = _fullDateFormat.format(picked));
    }
  }

  Future<void> _pickTime() async {
    const presets = ['14:00', '14:30', '19:00', '19:30'];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const Text('选择开场时间',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...presets.map((t) => ActionChip(
                        label: Text(t),
                        onPressed: () => Navigator.pop(context, t),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = _time.split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        Navigator.pop(context,
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
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
    if (result != null) {
      setState(() => _time = result);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper.instance;
      final perfId = widget.perf['id'] as int;

      // 更新场次
      final performance = await db.getPerformanceById(perfId);
      if (performance != null) {
        await db.updatePerformance(performance.copyWith(
          date: _date,
          time: _time,
        ));
      }

      // 删除旧卡司
      await db.deleteCastMembersByPerformanceId(perfId);

      // 创建新卡司
      for (final row in _castRows) {
        final role = row.roleController.text.trim();
        final actor = row.actorController.text.trim();
        if (role.isNotEmpty && actor.isNotEmpty) {
          await db.createCastMember(CastMember(
            performanceId: perfId,
            role: role,
            actorName: actor,
            isFeatured: row.isFeatured,
            createdAt: DateTime.now().toIso8601String(),
          ));
          try {
            await db.createActor(Actor(
              name: actor,
              createdAt: DateTime.now().toIso8601String(),
            ));
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4D4D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('编辑场次',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // 日期 + 时间
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '日期',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_date, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '时间',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_time, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 卡司表格
              Row(
                children: [
                  Text('卡司',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _castRows.add(_EditCastRow())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加角色'),
                  ),
                ],
              ),
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
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.roleController,
                                decoration: const InputDecoration(
                                  labelText: '角色',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.actorController,
                                decoration: const InputDecoration(
                                  labelText: '演员',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: row.isFeatured,
                                  onChanged: (v) => setState(
                                      () => row.isFeatured = v ?? false),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => row.isFeatured = !row.isFeatured),
                                  child: const Text('★',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF811FE2))),
                                ),
                              ],
                            ),
                            if (_castRows.length > 1)
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red[300]),
                                onPressed: () => setState(() {
                                  row.dispose();
                                  _castRows.removeAt(index);
                                }),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
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

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -_animation.value),
        child: child,
      ),
      child: Icon(widget.icon, size: 72, color: const Color(0xFF4D4D4D)),
    );
  }
}
