import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';
import 'calendar_poster_cell.dart';

/// 月历单个日期单元格。
///
/// 根据是否有事件，分别渲染传统数字单元格（无事件）或海报单元格（有事件）。
class CalendarCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final List<Map<String, dynamic>> events;
  final int rotationIndex;

  const CalendarCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
    this.events = const [],
    this.rotationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutside) {
      return const SizedBox.shrink();
    }

    final hasEvents = events.isNotEmpty;

    if (hasEvents) {
      return CalendarPosterCell(
        day: day,
        events: events,
        isToday: isToday,
        isSelected: isSelected,
        isOutside: isOutside,
        rotationIndex: rotationIndex,
      );
    }

    return _buildNoEventCell(context);
  }

  Widget _buildNoEventCell(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lunar = Lunar.fromDate(day);
    final lunarDay = lunar.getDayInChinese();
    final lunarText =
        lunarDay == '初一' ? '${lunar.getMonthInChinese()}月' : lunarDay;
    final textColor = day.weekday >= 6
        ? const Color(0xFFB3B3B3)
        : Colors.white;

    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.5),
                width: 1,
              ),
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            )
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isToday ? primaryColor : textColor),
              ),
            ),
            Text(
              lunarText,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : (isToday
                        ? primaryColor.withValues(alpha: 0.7)
                        : const Color(0xFF8A8F98)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
