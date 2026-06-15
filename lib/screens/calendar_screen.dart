import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database_helper.dart';
import '../utils/page_transitions.dart';
import '../utils/status_colors.dart' as status_colors;
import '../widgets/animated_list_item.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/calendar/calendar_cell.dart';
import '../widgets/status_dot.dart';
import '../widgets/ticket_clipper.dart';
import 'unified_show_detail_screen.dart';
import 'year_calendar_screen.dart';

enum CalendarFilter { all, wantToSee, bought, watched }

extension CalendarFilterExt on CalendarFilter {
  String get label {
    switch (this) {
      case CalendarFilter.all:
        return '全部';
      case CalendarFilter.wantToSee:
        return '想看';
      case CalendarFilter.bought:
        return '已买';
      case CalendarFilter.watched:
        return '已看';
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.onSelectedDayHasEvent,
  });

  /// 当选中日期是否包含剧目发生变化时回调（用于底部导航条上方光感分隔符）
  final ValueChanged<bool>? onSelectedDayHasEvent;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _lastTappedDay;
  int _posterRotationIndex = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFilter _filter = CalendarFilter.bought;
  List<Map<String, dynamic>> _performances = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = false;
  bool _isCalendarExpanded = true;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('yyyy年M月');
  final DateFormat _weekdayFormat = DateFormat('EEEE', 'zh_CN');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
    _loadPerformancesForDate(_focusedDay);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool _shouldInclude(Map<String, dynamic> perf) {
    final status = perf['status'] as String? ?? 'unmarked';
    if (status == 'unmarked') return false;
    switch (_filter) {
      case CalendarFilter.all:
        return status == 'want_to_see' ||
            status == 'bought' ||
            status == 'watched';
      case CalendarFilter.wantToSee:
        return status == 'want_to_see';
      case CalendarFilter.bought:
        return status == 'bought';
      case CalendarFilter.watched:
        return status == 'watched';
    }
  }

  Future<void> _loadEventsForMonth(DateTime month, {bool merge = false}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final db = DatabaseHelper.instance;
    final performances = await db.getPerformancesWithShowByDateRange(
      _dateFormat.format(startOfMonth),
      _dateFormat.format(endOfMonth),
    );

    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final p in performances) {
      if (!_shouldInclude(p)) continue;
      final dateStr = p['date'] as String;
      final date = _dateFormat.parse(dateStr);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!events.containsKey(normalizedDate)) {
        events[normalizedDate] = [];
      }
      events[normalizedDate]!.add(p);
    }

    setState(() {
      if (merge) {
        _events.addAll(events);
      } else {
        _events = events;
      }
    });
    _notifySelectedDayHasEvent();
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
    _notifySelectedDayHasEvent();
  }

  bool get _selectedDayHasEvent {
    if (_selectedDay == null) return false;
    final normalized = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    return _events[normalized]?.isNotEmpty ?? false;
  }

  void _notifySelectedDayHasEvent() {
    widget.onSelectedDayHasEvent?.call(_selectedDayHasEvent);
  }

  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < -100) {
      // 向上滑动：折叠到周视图
      _collapseCalendar();
    } else if (details.primaryVelocity! > 100) {
      // 向下滑动：展开到月视图
      _expandCalendar();
    }
  }

  void _onScroll() {
    // 折叠/展开不再由滚动位置自动触发，改由明确手势控制，避免状态抖动和弹回
  }

  void _expandCalendar() {
    if (!_isCalendarExpanded) {
      final oldHeight = _currentCalendarHeight(context);
      setState(() {
        _isCalendarExpanded = true;
        _calendarFormat = CalendarFormat.month;
      });
      _syncScrollAfterCollapse(oldHeight);
    }
  }

  void _collapseCalendar() {
    if (_isCalendarExpanded) {
      final oldHeight = _currentCalendarHeight(context);
      setState(() {
        _isCalendarExpanded = false;
        _calendarFormat = CalendarFormat.week;
      });
      _syncScrollAfterCollapse(oldHeight);
    }
  }

  void _toggleCalendarExpansion() {
    if (_isCalendarExpanded) {
      _collapseCalendar();
    } else {
      _expandCalendar();
    }
  }

  /// 月历高度变化后，同步 scroll offset 以保持列表视觉位置不变
  void _syncScrollAfterCollapse(double oldHeight) {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final newHeight = _currentCalendarHeight(context);
      final heightDelta = oldHeight - newHeight;
      if (heightDelta.abs() < 0.5) return;

      final currentOffset = _scrollController.offset;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = (currentOffset + heightDelta).clamp(0.0, maxExtent);

      if ((targetOffset - currentOffset).abs() > 0.5) {
        _scrollController.jumpTo(targetOffset);
      }
    });
  }

  double _currentCalendarHeight(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const appBarHeight = kToolbarHeight;
    final weekdayHeaderHeight = screenSize.width * 0.085;
    final expandedCalendarHeight = (screenSize.height -
            statusBarHeight -
            appBarHeight -
            weekdayHeaderHeight) *
        0.58;
    return _isCalendarExpanded
        ? expandedCalendarHeight
        : _focusedRowHeight(context);
  }

  double _focusedRowHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 周视图行高，给海报、日期圆标和 TableCalendar 内部边距留足空间
    return (screenWidth * 0.22).clamp(80.0, 120.0);
  }

  void _onDaySelected(DateTime selectedDay, {bool fromUser = true}) {
    if (fromUser) {
      HapticFeedback.lightImpact();
    }

    final normalized = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final dayEvents = _events[normalized] ?? [];
    final int newRotationIndex;
    if (_lastTappedDay != null &&
        isSameDay(_lastTappedDay!, selectedDay) &&
        dayEvents.length > 1) {
      newRotationIndex = (_posterRotationIndex + 1) % dayEvents.length;
    } else {
      newRotationIndex = 0;
    }

    setState(() {
      _selectedDay = selectedDay;
      // 周视图下点击日期不切换 focusedDay，避免页面自动左右滑动
      if (_calendarFormat == CalendarFormat.month) {
        _focusedDay = selectedDay;
      }
      _lastTappedDay = selectedDay;
      _posterRotationIndex = newRotationIndex;
    });
    _loadPerformancesForDate(selectedDay);
    _notifySelectedDayHasEvent();
  }

  void _onHeaderHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (_calendarFormat == CalendarFormat.week) {
      // 周视图：左右滑动切换周目
      if (details.primaryVelocity! > 50) {
        HapticFeedback.lightImpact();
        _changeWeek(-1);
      } else if (details.primaryVelocity! < -50) {
        HapticFeedback.lightImpact();
        _changeWeek(1);
      }
    } else {
      // 月视图：左右滑动切换月份
      if (details.primaryVelocity! > 50) {
        HapticFeedback.lightImpact();
        _changeMonth(-1);
      } else if (details.primaryVelocity! < -50) {
        HapticFeedback.lightImpact();
        _changeMonth(1);
      }
    }
  }

  void _changeWeek(int delta) {
    final newFocusedDay = _focusedDay.add(Duration(days: 7 * delta));

    // 保持选中日期的星期几不变，平移到新周
    DateTime? newSelectedDay = _selectedDay;
    if (_selectedDay != null) {
      final focusedWeekday = _selectedDay!.weekday % 7;
      final newWeekStart = newFocusedDay.subtract(
        Duration(days: newFocusedDay.weekday % 7),
      );
      newSelectedDay = newWeekStart.add(Duration(days: focusedWeekday));
    }

    setState(() {
      _focusedDay = newFocusedDay;
      if (newSelectedDay != null) {
        _selectedDay = newSelectedDay;
      }
    });

    _loadEventsForMonth(newFocusedDay, merge: true);

    // 周视图可能跨月，确保相邻月份事件也加载
    final weekStart = newFocusedDay.subtract(
      Duration(days: newFocusedDay.weekday % 7),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.month != newFocusedDay.month ||
        weekStart.year != newFocusedDay.year) {
      _loadEventsForMonth(weekStart, merge: true);
    }
    if ((weekEnd.month != newFocusedDay.month ||
            weekEnd.year != newFocusedDay.year) &&
        !isSameDay(weekEnd, weekStart)) {
      _loadEventsForMonth(weekEnd, merge: true);
    }

    if (newSelectedDay != null) {
      _loadPerformancesForDate(newSelectedDay);
    }
    _notifySelectedDayHasEvent();
  }

  void _changeMonth(int delta) {
    final newMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + delta,
      1,
    );
    setState(() {
      _focusedDay = newMonth;
      _selectedDay = newMonth;
    });
    _loadEventsForMonth(newMonth);
    _loadPerformancesForDate(newMonth);
    _notifySelectedDayHasEvent();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const appBarHeight = kToolbarHeight;
    final weekdayHeaderHeight = screenSize.width * 0.085;
    final focusedRowHeight = _focusedRowHeight(context);
    final monthRowHeight = focusedRowHeight;
    final availableHeight = screenSize.height -
        statusBarHeight -
        appBarHeight -
        weekdayHeaderHeight;
    // 展开状态：6 行月历 + 分割线/手柄区余量，让分割线紧贴第六排下方
    final dividerAreaHeight = screenSize.width * 0.075;
    final expandedCalendarHeight = max(
      monthRowHeight * 6,
      min(
        monthRowHeight * 6 + dividerAreaHeight,
        availableHeight * 0.9,
      ),
    );
    final calendarHeight =
        _isCalendarExpanded ? expandedCalendarHeight : focusedRowHeight;

    final displayFocusedDay = _focusedDay;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: _isCalendarExpanded
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        slivers: [
          // 顶部 AppBar：月份标题 + 今天 + 筛选
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            centerTitle: false,
            title: GestureDetector(
              onTap: _showYearPicker,
              onHorizontalDragEnd: _onHeaderHorizontalSwipe,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayFormat.format(_focusedDay),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
            actions: [
              _buildFilterButton(),
              const SizedBox(width: 8),
            ],
            foregroundColor: Colors.white,
          ),

          // 星期标题（固定）
          SliverPersistentHeader(
            pinned: true,
            delegate: _WeekdayHeaderDelegate(
              height: weekdayHeaderHeight,
            ),
          ),

          // 月历网格
          SliverToBoxAdapter(
            child: SizedBox(
              height: calendarHeight,
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: _onVerticalSwipe,
                    onHorizontalDragEnd: _onHeaderHorizontalSwipe,
                    onTap: _isCalendarExpanded ? null : _expandCalendar,
                    child: ClipRect(
                      child: TableCalendar(
                        firstDay: DateTime(2020),
                        lastDay: DateTime(2030),
                        focusedDay: displayFocusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        calendarFormat: _calendarFormat,
                        availableCalendarFormats: const {
                          CalendarFormat.month: '月',
                          CalendarFormat.week: '周',
                        },
                        availableGestures: AvailableGestures.none,
                        rowHeight: _isCalendarExpanded
                            ? monthRowHeight
                            : calendarHeight,
                        eventLoader: (day) {
                          final normalized =
                              DateTime(day.year, day.month, day.day);
                          return _events[normalized] ?? [];
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          _onDaySelected(selectedDay);
                        },
                        onPageChanged: (focusedDay) {
                          setState(() => _focusedDay = focusedDay);
                          _loadEventsForMonth(focusedDay);
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                            _focusedDay = _selectedDay ?? _focusedDay;
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          dowBuilder: (context, day) => const SizedBox.shrink(),
                          markerBuilder: (context, date, events) {
                            // 海报单元格通过海报边框/渐变占位表达状态，不再显示底部圆点
                            return const SizedBox.shrink();
                          },
                          // 显示农历
                          defaultBuilder: (context, day, focusedDay) {
                            final normalized =
                                DateTime(day.year, day.month, day.day);
                            return CalendarCell(
                              day: day,
                              isToday: false,
                              isSelected: false,
                              events: _events[normalized] ?? [],
                            );
                          },
                          todayBuilder: (context, day, focusedDay) {
                            final normalized =
                                DateTime(day.year, day.month, day.day);
                            return CalendarCell(
                              day: day,
                              isToday: true,
                              isSelected: false,
                              events: _events[normalized] ?? [],
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            final normalized =
                                DateTime(day.year, day.month, day.day);
                            return CalendarCell(
                              day: day,
                              isToday: isSameDay(day, DateTime.now()),
                              isSelected: true,
                              events: _events[normalized] ?? [],
                              rotationIndex: _posterRotationIndex,
                            );
                          },
                          outsideBuilder: (context, day, focusedDay) {
                            if (_calendarFormat == CalendarFormat.month) {
                              return const SizedBox.shrink();
                            }
                            final normalized =
                                DateTime(day.year, day.month, day.day);
                            return CalendarCell(
                              day: day,
                              isToday: false,
                              isSelected: false,
                              isOutside: true,
                              events: _events[normalized] ?? [],
                            );
                          },
                          disabledBuilder: (context, day, focusedDay) =>
                              const SizedBox.shrink(),
                        ),
                        calendarStyle: CalendarStyle(
                          cellMargin: const EdgeInsets.all(2),
                          markerSize: 6,
                          markersMaxCount: 3,
                          outsideDaysVisible:
                              _calendarFormat != CalendarFormat.month,
                          defaultTextStyle:
                              const TextStyle(color: Colors.white),
                          weekendTextStyle:
                              const TextStyle(color: Color(0xFFB3B3B3)),
                          outsideTextStyle:
                              const TextStyle(color: Color(0xFF444444)),
                          // today/selected 样式完全由 custom builder 控制
                        ),
                        daysOfWeekHeight: 0,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        headerVisible: false,
                        locale: 'zh_CN',
                        sixWeekMonthsEnforced: true,
                        formatAnimationDuration:
                            const Duration(milliseconds: 120),
                        formatAnimationCurve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _isCalendarExpanded ? monthRowHeight * 0.5 : 0,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context)
                                  .scaffoldBackgroundColor
                                  .withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 分割条（胶囊形拖拽手柄 + 淡淡光线）
          SliverToBoxAdapter(
            child: GestureDetector(
              onVerticalDragEnd: _onVerticalSwipe,
              onTap: _toggleCalendarExpansion,
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final selectedNormalized = _selectedDay != null
                      ? DateTime(_selectedDay!.year, _selectedDay!.month,
                          _selectedDay!.day)
                      : null;
                  final hasSelectedEvent = selectedNormalized != null &&
                      (_events[selectedNormalized]?.isNotEmpty ?? false);
                  final primaryColor = Theme.of(context).colorScheme.primary;

                  return Column(
                    children: [
                      Container(
                        height:
                            screenWidth * (hasSelectedEvent ? 0.008 : 0.004),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              primaryColor.withValues(
                                  alpha: hasSelectedEvent ? 1.0 : 0.45),
                              primaryColor.withValues(
                                  alpha: hasSelectedEvent ? 0.6 : 0.2),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 0.55, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(
                                  alpha: hasSelectedEvent ? 0.55 : 0.25),
                              blurRadius: hasSelectedEvent ? 18 : 6,
                              spreadRadius: hasSelectedEvent ? 3 : 0.5,
                            ),
                          ],
                        ),
                      ),
                      // 向下的柔和过渡，与票根列表暗色背景融合
                      Container(
                        height: screenWidth * 0.03,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor.withValues(
                                  alpha: hasSelectedEvent ? 0.12 : 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: screenWidth * 0.01),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: screenWidth * 0.10,
                          height: screenWidth * 0.01,
                          decoration: BoxDecoration(
                            color: _calendarFormat == CalendarFormat.month
                                ? const Color(0xFF6B5BCD)
                                : const Color(0xFF8A8F98),
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.005),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 选中日期标题
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                screenSize.width * 0.04,
                screenSize.width * 0.01,
                screenSize.width * 0.04,
                screenSize.width * 0.02,
              ),
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
          ),

          // 票根列表
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _performances.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final perf = _performances[index];
                          final status =
                              perf['status'] as String? ?? 'unmarked';
                          final statusColor = status_colors.statusColor(status);
                          final coverPath = perf['cover_path'] as String?;

                          return AnimatedListItem(
                            index: index,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SlideFadeRoute(
                                    page: UnifiedShowDetailScreen(
                                      performanceId: perf['id'] as int,
                                    ),
                                  ),
                                ).then((_) {
                                  _loadPerformancesForDate(
                                      _selectedDay ?? _focusedDay);
                                  _loadEventsForMonth(_focusedDay);
                                });
                              },
                              child: _buildTicketCard(
                                  perf, status, statusColor, coverPath),
                            ),
                          );
                        },
                        childCount: _isCalendarExpanded
                            ? min(_performances.length, 1)
                            : _performances.length,
                      ),
                    ),

          // 底部呼吸空间
          SliverToBoxAdapter(
            child: SizedBox(
                height: _isCalendarExpanded ? 0 : screenSize.width * 0.06),
          ),
        ],
      ),
    );
  }

  // 大麦风格票根卡片
  Widget _buildTicketCard(Map<String, dynamic> perf, String status,
      Color statusColor, String? coverPath) {
    final showName = perf['show_name'] ?? '未知剧目';
    final theater = perf['theater'] ?? '未知剧场';
    final rawDate = perf['date'] as String? ?? '';
    final rawTime = perf['time'] as String? ?? '';
    final date = rawDate.length >= 10 ? rawDate.substring(5) : rawDate;
    final time = rawTime.isNotEmpty ? rawTime.substring(0, 5) : '';
    final seat = perf['seat'] as String? ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // 卡片高度：屏幕宽度的 28%，放大票根展示
        final cardHeight = (maxW * 0.28).clamp(120.0, 180.0);
        // 海报宽度：卡片高度的 85%，左侧海报更大
        final posterWidth = cardHeight * 0.85;
        // 右侧状态区：只显示图标，宽度稍窄
        final statusAreaWidth = (maxW * 0.12).clamp(48.0, 72.0);
        // 信息区内边距比例化
        final horizontalPadding = maxW * 0.04;
        final verticalPadding = (cardHeight * 0.05).clamp(6.0, 12.0);
        // 字号比例化
        final titleFontSize = (cardHeight * 0.16).clamp(14.0, 18.0);
        final metaFontSize = (cardHeight * 0.13).clamp(11.0, 14.0);
        final dateFontSize = (cardHeight * 0.12).clamp(10.0, 13.0);
        final statusIconSize = (cardHeight * 0.24).clamp(22.0, 30.0);

        return Padding(
          padding: EdgeInsets.only(
            bottom: maxW * 0.035,
            left: maxW * 0.03,
            right: maxW * 0.03,
          ),
          child: ClipPath(
            clipper: const TicketClipper(),
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(maxW * 0.035),
              ),
              child: Row(
                children: [
                  // 左侧：海报
                  Container(
                    width: posterWidth,
                    decoration: BoxDecoration(
                      gradient: coverPath == null || coverPath.isEmpty
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                statusColor.withValues(alpha: 0.35),
                                statusColor.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      image: coverPath != null && coverPath.isNotEmpty
                          ? DecorationImage(
                              image: FileImage(File(coverPath)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: coverPath == null || coverPath.isEmpty
                        ? Center(
                            child: Text(
                              showName.length >= 2
                                  ? showName.substring(0, 2)
                                  : showName,
                              style: TextStyle(
                                fontSize: cardHeight * 0.22,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                  // 中间：信息区
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 顶部：日期 + 座位（座位在日期下一行）
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: dateFontSize * 1.1,
                                      color: statusColor),
                                  SizedBox(width: maxW * 0.01),
                                  Text(
                                    '$date ${time.isNotEmpty ? time.substring(0, 5) : ''}',
                                    style: TextStyle(
                                      fontSize: dateFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'bought' ||
                                  status == 'watched') ...[
                                SizedBox(height: cardHeight * 0.02),
                                Row(
                                  children: [
                                    Icon(Icons.event_seat,
                                        size: dateFontSize * 1.1,
                                        color: statusColor),
                                    SizedBox(width: maxW * 0.01),
                                    Flexible(
                                      child: Text(
                                        seat.isNotEmpty ? seat : '座位未录入',
                                        style: TextStyle(
                                          fontSize: dateFontSize,
                                          color: statusColor.withValues(
                                              alpha: seat.isNotEmpty
                                                  ? 1.0
                                                  : 0.5),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          // 底部：剧名 + 剧院
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                showName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: cardHeight * 0.02),
                              Text(
                                theater,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: metaFontSize,
                                  color: const Color(0xFF8A8F98),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 右侧状态
                  SizedBox(
                    width: statusAreaWidth,
                    child: Center(
                      child: Icon(status_colors.statusIcon(status),
                          size: statusIconSize, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      _notifySelectedDayHasEvent();
    }
  }

  Widget _buildFilterButton() {
    final filterColor =
        _filter == CalendarFilter.all ? null : _statusColorForFilter(_filter);

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                filterColor?.withValues(alpha: 0.3) ?? const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filterColor != null) ...[
              StatusDot(color: filterColor, size: 6),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.tune, size: 18),
          ],
        ),
      ),
      onPressed: _showFilterMenu,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  void _showFilterMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.topRight(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<CalendarFilter>(
      context: context,
      position: position,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: CalendarFilter.values
          .map((filter) => _buildFilterMenuItem(filter))
          .toList(),
    );

    if (result != null && result != _filter) {
      setState(() => _filter = result);
      _loadEventsForMonth(_focusedDay);
      _loadPerformancesForDate(_selectedDay ?? _focusedDay);
    }
  }

  PopupMenuItem<CalendarFilter> _buildFilterMenuItem(CalendarFilter filter) {
    final isSelected = _filter == filter;
    final color = _statusColorForFilter(filter);
    return PopupMenuItem(
      value: filter,
      child: Row(
        children: [
          if (filter != CalendarFilter.all) ...[
            StatusDot(color: color, size: 8),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 20),
          Text(
            filter.label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected
                  ? (filter == CalendarFilter.all ? Colors.white : color)
                  : const Color(0xFFB3B3B3),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 16,
              color: filter == CalendarFilter.all ? Colors.white : color,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColorForFilter(CalendarFilter filter) {
    return switch (filter) {
      CalendarFilter.wantToSee => const Color(0xFF811FE2),
      CalendarFilter.bought => const Color(0xFF34D399),
      CalendarFilter.watched => const Color(0xFFD4A853),
      _ => const Color(0xFFB3B3B3),
    };
  }

  // 星期标题委托（用于 SliverPersistentHeader）
  // ignore: unused_element
  Widget _buildWeekdayHeader(double height) {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      height: height,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: List.generate(7, (index) {
          final isWeekend = index >= 5;
          return Expanded(
            child: Center(
              child: Text(
                weekdays[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isWeekend
                      ? const Color(0xFFB3B3B3)
                      : const Color(0xFF8A8F98),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BreathingIcon(icon: Icons.bookmark_border),
            SizedBox(height: 16),
            Text(
              '今日无标记场次',
              style: TextStyle(color: Color(0xFF8A8F98)),
            ),
            SizedBox(height: 8),
            Text(
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
    );
  }
}

class _WeekdayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;

  _WeekdayHeaderDelegate({required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      height: height,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: List.generate(7, (index) {
          final isWeekend = index >= 5;
          return Expanded(
            child: Center(
              child: Text(
                weekdays[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isWeekend
                      ? const Color(0xFFB3B3B3)
                      : const Color(0xFF8A8F98),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _WeekdayHeaderDelegate oldDelegate) {
    return oldDelegate.height != height;
  }
}
