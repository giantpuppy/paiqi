import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';
import '../warm_spotlight.dart';
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
  final bool showStatusBadge;
  final int rotationIndex;

  const CalendarCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
    this.events = const [],
    this.showStatusBadge = false,
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
        showStatusBadge: showStatusBadge,
        rotationIndex: rotationIndex,
      );
    }

    return _buildNoEventCell(context);
  }

  Widget _buildNoEventCell(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = day.weekday >= 6
        ? const Color(0xFFB3B3B3)
        : Colors.white;

    Widget content = Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.5),
                width: 1,
              ),
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            )
          : (isToday
              ? BoxDecoration(
                  color: kBrandPurple.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                )
              : null),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: isToday || isSelected
                ? FontWeight.bold
                : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isToday ? kBrandPurple : textColor),
          ),
        ),
      ),
    );

    if (isToday) {
      content = WarmSpotlight(
        color: kBrandPurple,
        borderRadius: 10,
        minAlpha: 0.04,
        maxAlpha: 0.08,
        minBlur: 4,
        maxBlur: 8,
        child: content,
      );
    }

    return content;
  }
}
