import 'dart:ui';
import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'gantt_screen.dart';
import 'profile_screen.dart';
import '../widgets/schedule_tab_icon.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _calendarHasSelectedEvent = false;
  final _ganttKey = GlobalKey<GanttScreenState>();
  final _fallbackModeNotifier = ValueNotifier<TimelineMode>(TimelineMode.focus3Day);

  ValueNotifier<TimelineMode> get _scheduleModeNotifier =>
      _ganttKey.currentState?.modeNotifier ?? _fallbackModeNotifier;

  List<Widget> get _pages => [
        CalendarScreen(
          onSelectedDayHasEvent: (hasEvent) {
            setState(() => _calendarHasSelectedEvent = hasEvent);
          },
        ),
        GanttScreen(key: _ganttKey),
        const ProfileScreen(),
      ];

  @override
  void dispose() {
    _fallbackModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final showReminderLight =
        _currentIndex == 0 && _calendarHasSelectedEvent;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 选中有剧目日期时，底部导航条上方的提醒光感分隔符
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: showReminderLight ? 2 : 0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  primaryColor.withValues(alpha: showReminderLight ? 1.0 : 0.0),
                  primaryColor.withValues(alpha: showReminderLight ? 0.6 : 0.0),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              ),
              boxShadow: showReminderLight
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFF121212).withValues(alpha: 0.65),
                child: ValueListenableBuilder<TimelineMode>(
                  valueListenable: _scheduleModeNotifier,
                  builder: (context, mode, child) {
                    final isFocus = mode == TimelineMode.focus3Day;
                    return BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) {
                        if (index == 1 && _currentIndex == 1) {
                          _ganttKey.currentState?.toggleMode();
                          // 强制重建，确保 icon 使用 GanttScreen 的真实 modeNotifier
                          setState(() {});
                          return;
                        }
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: primaryColor,
                      unselectedItemColor: const Color(0xFF8A8F98),
                      selectedFontSize: 0,
                      unselectedFontSize: 0,
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      type: BottomNavigationBarType.fixed,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.calendar_month_outlined),
                          activeIcon: Icon(Icons.calendar_month),
                          label: '日历',
                        ),
                        BottomNavigationBarItem(
                          icon: AnimatedSwitcher(
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
                            child: ScheduleTabIcon(
                              mode: isFocus
                                  ? ScheduleTabIconMode.threeDay
                                  : ScheduleTabIconMode.sevenDay,
                              key: ValueKey<bool>(isFocus),
                            ),
                          ),
                          label: '排期',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline),
                          activeIcon: Icon(Icons.person),
                          label: '我的',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
