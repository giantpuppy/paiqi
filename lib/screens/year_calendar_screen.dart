import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class YearCalendarScreen extends StatefulWidget {
  final int initialYear;
  final DateTime? selectedDay;

  const YearCalendarScreen({
    super.key,
    required this.initialYear,
    this.selectedDay,
  });

  @override
  State<YearCalendarScreen> createState() => _YearCalendarScreenState();
}

class _YearCalendarScreenState extends State<YearCalendarScreen> {
  late int _year;
  DateTime? _selectedDate;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _selectedDate = widget.selectedDay;
    _loadYearEvents();
  }

  Future<void> _loadYearEvents() async {
    final start = DateTime(_year, 1, 1);
    final end = DateTime(_year, 12, 31);
    final db = DatabaseHelper.instance;

    final performances = await db.getPerformancesInScheduleFlowByDateRange(
      _dateFormat.format(start),
      _dateFormat.format(end),
    );

    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final map in performances) {
      final status = map['status'] as String? ?? 'unmarked';
      if (status == 'unmarked') continue;
      final dateStr = map['date'] as String;
      final date = _dateFormat.parse(dateStr);
      final normalized = DateTime(date.year, date.month, date.day);
      if (!events.containsKey(normalized)) {
        events[normalized] = [];
      }
      events[normalized]!.add(map);
    }

    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  bool _isWatched(Map<String, dynamic> perf) {
    if (perf['status'] != 'bought') return false;
    final perfDate = DateTime.parse(perf['date'] as String);
    final today = DateTime.now();
    return perfDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () {
                setState(() {
                  _year--;
                  _isLoading = true;
                });
                _loadYearEvents();
              },
            ),
            Text(
              '$_year年',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 28),
              onPressed: () {
                setState(() {
                  _year++;
                  _isLoading = true;
                });
                _loadYearEvents();
              },
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        return _MonthCard(
                          year: _year,
                          month: index + 1,
                          events: _events,
                          selectedDay: _selectedDate,
                          isWatched: _isWatched,
                          onDaySelected: (date) {
                            Navigator.pop(context, date);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, List<Map<String, dynamic>>> events;
  final DateTime? selectedDay;
  final bool Function(Map<String, dynamic>) isWatched;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCard({
    required this.year,
    required this.month,
    required this.events,
    this.selectedDay,
    required this.isWatched,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final weekdayOfFirst = firstDay.weekday % 7; // 0=周日
    final totalCells = ((weekdayOfFirst + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();
    final numWeeks = totalCells ~/ 7;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
      child: Column(
        children: [
          // 月份标题
          Text(
            '$month月',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          // 日期表格
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(1), 1: FlexColumnWidth(1),
              2: FlexColumnWidth(1), 3: FlexColumnWidth(1),
              4: FlexColumnWidth(1), 5: FlexColumnWidth(1),
              6: FlexColumnWidth(1),
            },
            children: [
              // 星期标题行
              const TableRow(
                children: [
                  _WeekLabel('日'), _WeekLabel('一'), _WeekLabel('二'),
                  _WeekLabel('三'), _WeekLabel('四'), _WeekLabel('五'), _WeekLabel('六'),
                ],
              ),
              // 日期行
              for (int week = 0; week < numWeeks; week++)
                TableRow(
                  children: List.generate(7, (day) {
                    final index = week * 7 + day;
                    final dayOffset = index - weekdayOfFirst;
                    if (dayOffset < 0 || dayOffset >= daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final dayNum = dayOffset + 1;
                    final date = DateTime(year, month, dayNum);
                    final normalized = DateTime(date.year, date.month, date.day);
                    final isToday = date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    final isSelected = selectedDay != null &&
                        date.year == selectedDay!.year &&
                        date.month == selectedDay!.month &&
                        date.day == selectedDay!.day;
                    final dayEvents = events[normalized] ?? [];
                    final hasEvents = dayEvents.isNotEmpty;

                    // 按状态统计数量
                    final watchedCount = dayEvents.where(isWatched).length;
                    final boughtCount = dayEvents
                        .where((e) =>
                            e['status'] == 'bought' && !isWatched(e))
                        .length;
                    final wantCount = dayEvents
                        .where((e) => e['status'] == 'want_to_see')
                        .length;

                    return InkWell(
                      onTap: () => onDaySelected(date),
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        decoration: isSelected
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 日期数字
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 7,
                                height: 1,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday
                                        ? const Color(0xFFF54A45)
                                        : (hasEvents
                                            ? Colors.white
                                            : const Color(0xFF4D4D4D))),
                              ),
                            ),
                            const SizedBox(height: 1),
                            // 状态色块行（无演出时透明占位，保持行高齐平）
                            if (hasEvents)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (watchedCount > 0)
                                    _StatusBadge(
                                      count: watchedCount,
                                      color: const Color(0xFFD4A853),
                                    ),
                                  if (boughtCount > 0)
                                    _StatusBadge(
                                      count: boughtCount,
                                      color: const Color(0xFF34D399),
                                    ),
                                  if (wantCount > 0)
                                    _StatusBadge(
                                      count: wantCount,
                                      color: const Color(0xFF811FE2),
                                    ),
                                ],
                              )
                            else
                              const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  final String text;
  const _WeekLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 7, color: Color(0xFF8A8F98)),
      ),
    );
  }
}

/// 状态色块：纯色小方块，>1场时叠加白色数字
class _StatusBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _StatusBadge({
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
      child: count > 1
          ? Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 5,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            )
          : null,
    );
  }
}
