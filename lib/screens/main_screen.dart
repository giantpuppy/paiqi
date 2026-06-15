import 'dart:ui';
import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'gantt_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _calendarHasSelectedEvent = false;

  List<Widget> get _pages => [
        CalendarScreen(
          onSelectedDayHasEvent: (hasEvent) {
            setState(() => _calendarHasSelectedEvent = hasEvent);
          },
        ),
        const GanttScreen(),
        const ProfileScreen(),
      ];

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
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: '日历',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.view_timeline_outlined),
                      selectedIcon: Icon(Icons.view_timeline),
                      label: '排期',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: '我的',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
