import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import '../utils/page_transitions.dart';
import '../widgets/animated_list_item.dart';
import 'show_detail_screen.dart';
import 'year_calendar_screen.dart';

enum CalendarFilter { all, wantToSee, bought }

extension CalendarFilterExt on CalendarFilter {
  String get label {
    switch (this) {
      case CalendarFilter.all:
        return '全部';
      case CalendarFilter.wantToSee:
        return '想看';
      case CalendarFilter.bought:
        return '已买';
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFilter _filter = CalendarFilter.all;
  List<Map<String, dynamic>> _performances = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('yyyy年M月');
  final DateFormat _weekdayFormat = DateFormat('EEEE', 'zh_CN');

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
    _loadPerformancesForDate(_focusedDay);
  }

  bool _shouldInclude(Map<String, dynamic> perf) {
    final status = perf['status'] as String? ?? 'unmarked';
    if (status == 'unmarked') return false;
    switch (_filter) {
      case CalendarFilter.all:
        return status == 'want_to_see' || status == 'bought';
      case CalendarFilter.wantToSee:
        return status == 'want_to_see';
      case CalendarFilter.bought:
        return status == 'bought';
    }
  }

  Future<void> _loadEventsForMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final db = DatabaseHelper.instance;
    final performances = await db.getPerformancesByDateRange(
      _dateFormat.format(startOfMonth),
      _dateFormat.format(endOfMonth),
    );

    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final p in performances) {
      if (!_shouldInclude(p.toMap())) continue;
      final dateStr = p.date;
      final date = _dateFormat.parse(dateStr);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!events.containsKey(normalizedDate)) {
        events[normalizedDate] = [];
      }
      events[normalizedDate]!.add(p.toMap());
    }

    setState(() {
      _events = events;
    });
  }

  Future<void> _loadPerformancesForDate(DateTime date) async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    final dateStr = _dateFormat.format(date);
    final performances = await db.getPerformancesWithShowByDate(dateStr);

    setState(() {
      _performances = performances.where(_shouldInclude).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: GestureDetector(
          onTap: _showYearPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayFormat.format(_focusedDay),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 筛选栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<CalendarFilter>(
              segments: [
                ButtonSegment(
                  value: CalendarFilter.all,
                  label: Text(CalendarFilter.all.label),
                ),
                ButtonSegment(
                  value: CalendarFilter.wantToSee,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF811FE2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(CalendarFilter.wantToSee.label),
                    ],
                  ),
                ),
                ButtonSegment(
                  value: CalendarFilter.bought,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(CalendarFilter.bought.label),
                    ],
                  ),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (set) {
                setState(() => _filter = set.first);
                _loadEventsForMonth(_focusedDay);
                _loadPerformancesForDate(_selectedDay ?? _focusedDay);
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),

          // Calendar
          Card(
            margin: const EdgeInsets.all(12),
            color: const Color(0xFF181818),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: '月',
                  CalendarFormat.twoWeeks: '双周',
                  CalendarFormat.week: '周',
                },
                eventLoader: (day) {
                  final normalized = DateTime(day.year, day.month, day.day);
                  return _events[normalized] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _loadPerformancesForDate(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                  _loadEventsForMonth(focusedDay);
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: events.take(3).map((e) {
                          final status = (e as Map<String, dynamic>)['status'] as String? ?? 'unmarked';
                          final color = status == 'want_to_see'
                              ? const Color(0xFF811FE2)
                              : const Color(0xFF34D399);
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  // 显示农历
                  defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, false, false),
                  todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, true, false),
                  selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, false, true),
                  outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, false, false, isOutside: true),
                  disabledBuilder: (context, day, focusedDay) => _buildCalendarCell(day, false, false, isOutside: true),
                ),
                calendarStyle: CalendarStyle(
                  markerSize: 6,
                  markersMaxCount: 3,
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: const TextStyle(color: Color(0xFFB3B3B3)),
                  outsideTextStyle: const TextStyle(color: Color(0xFF8A8F98)),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
                locale: 'zh_CN',
              ),
            ),
          ),

          // 分割条（支持上下滑动切换视图）
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -150) {
                // 向上滑动：月 -> 双周 -> 周
                setState(() {
                  if (_calendarFormat == CalendarFormat.month) {
                    _calendarFormat = CalendarFormat.twoWeeks;
                  } else if (_calendarFormat == CalendarFormat.twoWeeks) {
                    _calendarFormat = CalendarFormat.week;
                  }
                });
              } else if (details.primaryVelocity! > 150) {
                // 向下滑动：周 -> 双周 -> 月
                setState(() {
                  if (_calendarFormat == CalendarFormat.week) {
                    _calendarFormat = CalendarFormat.twoWeeks;
                  } else if (_calendarFormat == CalendarFormat.twoWeeks) {
                    _calendarFormat = CalendarFormat.month;
                  }
                });
              }
            },
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: const Color(0xFF4D4D4D),
                  ),
                ),
              ],
            ),
          ),

          // Selected date performances
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDay?.day ?? _focusedDay.day}日 ${_weekdayFormat.format(_selectedDay ?? _focusedDay)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_performances.length} 场',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A8F98),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _performances.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _performances.length,
                        itemBuilder: (context, index) {
                          final perf = _performances[index];
                          final status = perf['status'] as String? ?? 'unmarked';
                          final isWantToSee = status == 'want_to_see';
                          final statusColor = isWantToSee
                              ? const Color(0xFF811FE2)
                              : const Color(0xFF34D399);

                          return AnimatedListItem(
                            index: index,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        perf['time']?.substring(0, 5) ?? '--:--',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Icon(
                                        isWantToSee
                                            ? Icons.star_border
                                            : Icons.check_circle,
                                        size: 12,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              title: Text(
                                perf['show_name'] ?? '未知剧目',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                perf['theater'] ?? '未知剧场',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3B3B3),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isWantToSee ? '想看' : '已买',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SlideFadeRoute(
                                    page: ShowDetailScreen(
                                      performanceId: perf['id'] as int,
                                    ),
                                  ),
                                ).then((_) {
                                  _loadPerformancesForDate(
                                      _selectedDay ?? _focusedDay);
                                  _loadEventsForMonth(_focusedDay);
                                });
                              },
                            ),
                          ),
                        );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // 日历单元格（带农历）
  Widget _buildCalendarCell(DateTime day, bool isToday, bool isSelected,
      {bool isOutside = false}) {
    final lunar = Lunar.fromDate(day);
    final lunarDay = lunar.getDayInChinese();
    // 初一显示月份
    final lunarText = lunarDay == '初一'
        ? lunar.getMonthInChinese() + '月'
        : lunarDay;

    final textColor = isOutside
        ? const Color(0xFF8A8F98)
        : (day.weekday >= 6
            ? const Color(0xFFB3B3B3)
            : Colors.white);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: isSelected
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            )
          : isToday
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                )
              : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected || isToday
                  ? Colors.white
                  : textColor,
            ),
          ),
          Text(
            lunarText,
            style: TextStyle(
              fontSize: 9,
              color: isSelected || isToday
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFF8A8F98),
            ),
          ),
        ],
      ),
    );
  }

  // 年历页面
  void _showYearPicker() async {
    final selectedDate = await Navigator.push(
      context,
      SlideFadeRoute(
        page: YearCalendarScreen(
          initialYear: _focusedDay.year,
          selectedDay: _selectedDay,
        ),
      ),
    ) as DateTime?;

    if (selectedDate != null) {
      setState(() {
        _focusedDay = selectedDate;
        _selectedDay = selectedDate;
      });
      _loadEventsForMonth(selectedDate);
      _loadPerformancesForDate(selectedDate);
    }
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BreathingIcon(icon: Icons.bookmark_border),
              const SizedBox(height: 16),
              const Text(
                '今日无标记场次',
                style: TextStyle(color: Color(0xFF8A8F98)),
              ),
              const SizedBox(height: 8),
              const Text(
                '在甘特图标记「想看」或「已买」后，\n场次会显示在这里',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7C7C7C),
                ),
              ),
            ],
          ),
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
