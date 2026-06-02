import 'dart:io';
import 'package:flutter/material.dart';
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
  DateTime _anchorDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  double _scaleAccumulator = 0;

  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');
  static const double _stickyHeaderHeight = 44.0;
  static const double _tableLineOpacity = 0.06;

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
    if (mounted) {
      setState(() {
        _performances = performances;
        _castMap = castMap;
        _isLoading = false;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int get _dayCount => _mode == TimelineMode.focus3Day ? 3 : 7;

  DateTime get _viewStart {
    // 对齐到周一起始（7天模式）或 anchorDate（3天模式）
    if (_mode == TimelineMode.micro7Day) {
      final d = _anchorDate;
      return d.subtract(Duration(days: d.weekday - 1));
    }
    return _anchorDate;
  }

  void _prevPeriod() {
    setState(() {
      _anchorDate = _anchorDate.subtract(Duration(days: _dayCount));
    });
  }

  void _nextPeriod() {
    setState(() {
      _anchorDate = _anchorDate.add(Duration(days: _dayCount));
    });
  }

  void _goToToday() {
    setState(() {
      _anchorDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    });
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
                  width: 40, height: 4,
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
                    child: Text(showName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: status.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(status.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: status.color)),
                  ),
                ],
              ),
              if (theater.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined, size: 18, color: const Color(0xFF8A8F98)),
                    const SizedBox(width: 4),
                    Text(theater, style: const TextStyle(color: Color(0xFFB3B3B3))),
                  ]),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 16, runSpacing: 12,
                  children: [
                    _buildInfoItem(Icons.calendar_today, '日期', date),
                    _buildInfoItem(Icons.access_time, '时间', time.isNotEmpty ? time : '未设置'),
                    if (seat.isNotEmpty) _buildInfoItem(Icons.event_seat, '座位', seat),
                    if (price.isNotEmpty) _buildInfoItem(Icons.confirmation_number_outlined, '票面', price),
                    if (actualPrice.isNotEmpty) _buildInfoItem(Icons.payments_outlined, '实付', actualPrice),
                  ],
                ),
              ),
              if (casts.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('卡司', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFB3B3B3))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: casts.map((c) {
                    final isFeatured = c.isFeatured == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? const Color(0xFF811FE2).withValues(alpha: 0.08)
                            : const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(8),
                        border: isFeatured
                            ? Border.all(color: const Color(0xFF811FE2).withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Text('${c.role}: ${c.actorName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isFeatured ? const Color(0xFF811FE2) : const Color(0xFFB3B3B3),
                          fontWeight: isFeatured ? FontWeight.w600 : FontWeight.normal,
                        )),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              const Text('标记状态', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFB3B3B3))),
              const SizedBox(height: 12),
              Row(children: [
                _buildStatusButton(label: '想看', icon: Icons.star_border, color: PerformanceStatus.wantToSee.color, isActive: status == PerformanceStatus.wantToSee, onTap: () async { Navigator.pop(context); await _updateStatus(perfId, 'want_to_see'); }),
                const SizedBox(width: 12),
                _buildStatusButton(label: '已买', icon: Icons.check_circle_outline, color: PerformanceStatus.bought.color, isActive: status == PerformanceStatus.bought, onTap: () async { Navigator.pop(context); await _showBoughtForm(perfId); }),
                const SizedBox(width: 12),
                _buildStatusButton(label: '取消', icon: Icons.remove_circle_outline, color: PerformanceStatus.unmarked.color, isActive: status == PerformanceStatus.unmarked, onTap: () async { Navigator.pop(context); await _updateStatus(perfId, 'unmarked'); }),
              ]),
              const Spacer(),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); _editShowFromPerf(perf); },
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('编辑'),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(perf),
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
                  label: Text('删除', style: TextStyle(color: Colors.red[400])),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[400]),
                )),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusButton({required String label, required IconData icon, required Color color, required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(500),
            border: Border.all(color: isActive ? color : const Color(0xFF4D4D4D), width: isActive ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: isActive ? color : const Color(0xFF8A8F98), size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? color : const Color(0xFF8A8F98))),
          ]),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(children: [
      Icon(icon, size: 20, color: const Color(0xFF8A8F98)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8F98))),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }

  // ==================== 编辑 / 删除 ====================

  void _editShowFromPerf(Map<String, dynamic> perf) async {
    final showId = perf['show_id'] as int;
    final db = DatabaseHelper.instance;
    final show = await db.getShowById(showId);
    if (show == null || !mounted) return;

    final perfs = await db.getPerformancesByShowId(showId);
    // ignore: use_build_context_synchronously
    final result = await Navigator.push(
      context,
      SlideFadeRoute(page: AddShowScreen(
        initialShow: show,
        initialPerformances: perfs,
        isEditMode: true,
      )),
    );
    if (result == true) {
      _loadData();
    }
  }

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
    final monthStr = '${_anchorDate.year}年${_anchorDate.month}月';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Text(monthStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5BCD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _showAddMenu,
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

  // ==================== 剧场流时间轴 ====================

  String _dayLabel(DateTime day) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    String extra = '';
    if (_isSameDay(day, today)) {
      extra = ' 今天';
    } else if (_isSameDay(day, tomorrow)) {
      extra = ' 明天';
    }
    return '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}\n${weekdays[day.weekday - 1]}$extra';
  }

  Widget _buildTimeline() {
    final today = DateTime.now();
    final days = List.generate(_dayCount, (i) => _viewStart.add(Duration(days: i)));

    return GestureDetector(
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          _scaleAccumulator += (details.scale - 1.0);
          if (_scaleAccumulator > 0.3 && _mode == TimelineMode.micro7Day) {
            setState(() {
              _mode = TimelineMode.focus3Day;
              _scaleAccumulator = 0;
            });
          } else if (_scaleAccumulator < -0.3 && _mode == TimelineMode.focus3Day) {
            setState(() {
              _mode = TimelineMode.micro7Day;
              _scaleAccumulator = 0;
            });
          }
        }
      },
      onScaleEnd: (_) {
        _scaleAccumulator = 0;
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 200) {
              _prevPeriod();
            } else if (details.primaryVelocity! < -200) {
              _nextPeriod();
            }
          }
        },
        child: _mode == TimelineMode.focus3Day
            ? _buildFocusLayout(days, today)
            : _buildMicroLayout(days, today),
      ),
    );
  }

  /// 3天聚焦模式：Column 等分，不滚动
  Widget _buildFocusLayout(List<DateTime> days, DateTime today) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rHeight = constraints.maxHeight / _dayCount;
        return Column(
          children: List.generate(_dayCount, (index) {
            final day = days[index];
            final dayPerfs = _getPerformancesForDay(day);
            return _buildFocusDayRow(day, dayPerfs, today, rHeight);
          }),
        );
      },
    );
  }

  /// 7天微模式：ListView 可滚动，日期标签锁定左侧
  Widget _buildMicroLayout(List<DateTime> days, DateTime today) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _dayCount,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayPerfs = _getPerformancesForDay(day);
        return _buildMicroDayRow(day, dayPerfs, today, 90.0);
      },
    );
  }

  // ==================== 日期行：左侧标签 + 右侧卡片 ====================

  Widget _buildDayLabel(DateTime day, double height, {required bool isToday}) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final isTomorrow = _isSameDay(day, tomorrow);
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      width: 64,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isToday ? const Color(0xFFF54A45) : Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekdays[day.weekday - 1],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isToday ? const Color(0xFFF54A45).withOpacity(0.7) : const Color(0xFF6B7280),
            ),
          ),
          if (isToday || isTomorrow) ...[
            const SizedBox(height: 3),
            Container(
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
          ],
        ],
      ),
    );
  }

  // ==================== 模式 A：放大聚焦（3天） ====================

  Widget _buildFocusDayRow(DateTime day, List<Map<String, dynamic>> dayPerfs, DateTime today, double rowHeight) {
    final isToday = _isSameDay(day, today);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 64) * 0.45; // 减去左侧日期列 64px
    final cardHeight = rowHeight - 24; // 上下留 padding

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(_tableLineOpacity)),
        ),
      ),
      child: Row(
        children: [
          // 左侧日期标签
          _buildDayLabel(day, rowHeight, isToday: isToday),
          // 右侧海报卡片
          Expanded(
            child: dayPerfs.isEmpty
                ? Center(
                    child: Text(
                      '',
                      style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    itemCount: dayPerfs.length,
                    itemBuilder: (context, index) {
                      return _buildFocusCard(dayPerfs[index], cardWidth, cardHeight);
                    },
                  ),
          ),
        ],
      ),
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
    final casts = (_castMap[perfId] ?? []).where((c) => c.isFeatured == true).toList();

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
              // 海报背景
              coverPath != null && coverPath.isNotEmpty
                  ? Image.file(File(coverPath), fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, color.withOpacity(0.7)],
                        ),
                      ),
                    ),
              // 左上角时间胶囊
              if (time.isNotEmpty)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('🕒 $time',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              // 底部渐变蒙层 + 文字
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: cardHeight * 0.4, // 底部 40% 渐变蒙层
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8, right: 8, bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(showName,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (theater.isNotEmpty) theater,
                        ...casts.map((c) => '${c.role}:${c.actorName}'),
                      ].join(' · '),
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
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

  // ==================== 模式 B：缩小微观（7天） ====================

  Widget _buildMicroDayRow(DateTime day, List<Map<String, dynamic>> dayPerfs, DateTime today, double rowHeight) {
    final isToday = _isSameDay(day, today);
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFF54A45).withValues(alpha: 0.04) : const Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 左侧锁定日期标签（深色背景，固定不滚动）
          Container(
            width: 48,
            height: rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isToday ? const Color(0xFFF54A45) : Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '周${weekdays[day.weekday - 1]}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: isToday ? const Color(0xFFF54A45).withOpacity(0.7) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // 右侧微海报邮票墙
          Expanded(
            child: dayPerfs.isEmpty
                ? Container(
                    color: const Color(0xFF121212),
                    alignment: Alignment.center,
                    child: Text(
                      '',
                      style: TextStyle(color: Colors.white.withOpacity(0.08), fontSize: 10),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    itemCount: dayPerfs.length,
                    itemBuilder: (context, index) {
                      return _buildMicroCard(dayPerfs[index], rowHeight - 8);
                    },
                  ),
          ),
        ],
      ),
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
              // 微型海报背景
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
              // 半透明遮罩 + 时间戳居中
              Container(
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.35),
                child: Text(time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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
