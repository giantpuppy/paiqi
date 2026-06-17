import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/status_colors.dart';
import '../warm_spotlight.dart';

/// 月历中有演出场次的日期单元格。
///
/// 包含：按比例布局的海报堆叠区、底部深灰蒙版时间区。
class CalendarPosterCell extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> events;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;
  final bool showStatusBadge;
  final int rotationIndex;

  const CalendarPosterCell({
    super.key,
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    this.isOutside = false,
    this.showStatusBadge = false,
    this.rotationIndex = 0,
  });

  static const double _outerRadius = 10.0;
  static const double _innerRadius = 6.0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final topEvent = events[rotationIndex % events.length];

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(_outerRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.biggest;
          final cellPadding = cellSize.shortestSide * 0.04;
          final contentHeight = cellSize.height - cellPadding * 2;
          final posterAreaHeight = contentHeight * 0.82;
          final timeBarHeight = contentHeight * 0.18;
          final timeFontSize = (cellSize.height * 0.07).clamp(9.0, 12.0);

          final topTime = topEvent['time'] as String? ?? '';
          final timeText = topTime.length >= 5
              ? topTime.substring(0, 5)
              : topTime;
          final statusColor = statusColorForEvent(topEvent);

          return Container(
            padding: EdgeInsets.all(cellPadding),
            color: Colors.transparent,
            child: Column(
              children: [
                // 海报堆叠区
                SizedBox(
                  height: posterAreaHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPosterStack(
                        events,
                        isOutside,
                        posterAreaHeight,
                        cellSize.shortestSide,
                      ),

                      // 顶部渐变蒙层（保证角标/文字可读）
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_innerRadius),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 选中蒙层（仅覆盖海报区）
                      AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(_innerRadius),
                          ),
                        ),
                      ),

                      // 今天角标
                      if (isToday)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _buildTodayBadge(),
                        ),
                    ],
                  ),
                ),

                // 底部时间区
                Container(
                  height: timeBarHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(_innerRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    timeText,
                    style: TextStyle(
                      fontSize: timeFontSize,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                      shadows: [
                        Shadow(
                          color: statusColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (isToday) {
      content = WarmSpotlight(
        color: kBrandPurple,
        borderRadius: _outerRadius,
        minAlpha: 0.06,
        maxAlpha: 0.12,
        minBlur: 6,
        maxBlur: 12,
        child: content,
      );
    }

    return Opacity(
      opacity: isOutside ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? primaryColor.withValues(alpha: 0.04) : null,
          borderRadius: BorderRadius.circular(_outerRadius),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: content,
      ),
    );
  }

  Widget _buildTodayBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: kBrandPurple.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: kBrandPurple.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const Text(
        '今天',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPosterStack(
    List<Map<String, dynamic>> events,
    bool isOutside,
    double posterAreaHeight,
    double shortestSide,
  ) {
    final count = events.length;

    if (count == 1) {
      return _buildPosterThumbnail(
        events.first,
        isOutside: isOutside,
        borderRadius: _innerRadius,
        topmost: true,
      );
    }

    final topEvent = events[rotationIndex % count];
    final middleEvent = events[(rotationIndex + 1) % count];
    final bottomEvent = events[(rotationIndex + (count > 2 ? 2 : 1)) % count];

    // 阶梯步进：下层依次向下偏移，露出上层底部
    final stepOffset = posterAreaHeight * 0.06;
    final visibleLayers = count > 3 ? 3 : count;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层
        Positioned(
          top: stepOffset * (visibleLayers - 1),
          left: 0,
          right: 0,
          height: posterAreaHeight,
          child: Opacity(
            opacity: 0.35,
            child: _buildPosterThumbnail(
              bottomEvent,
              isOutside: isOutside,
              borderRadius: _innerRadius,
            ),
          ),
        ),

        // 中间层（>2 张时）
        if (count > 2)
          Positioned(
            top: stepOffset,
            left: 0,
            right: 0,
            height: posterAreaHeight,
            child: Opacity(
              opacity: 0.55,
              child: _buildPosterThumbnail(
                middleEvent,
                isOutside: isOutside,
                borderRadius: _innerRadius,
              ),
            ),
          ),

        // 顶层
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: posterAreaHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _buildPosterThumbnail(
              topEvent,
              isOutside: isOutside,
              borderRadius: _innerRadius,
              topmost: true,
              key: ValueKey<int>(rotationIndex),
            ),
          ),
        ),

        // 数量角标（多张时）
        if (count > 1)
          Positioned(
            top: 0,
            right: 0,
            child: _buildCountBadge(count, shortestSide),
          ),
      ],
    );
  }

  Widget _buildPosterThumbnail(
    Map<String, dynamic> event, {
    required bool isOutside,
    double borderRadius = 4.0,
    bool topmost = false,
    Key? key,
  }) {
    final status = event['status'] as String? ?? 'unmarked';
    final color = statusColor(status);
    final coverPath = event['cover_path'] as String?;
    final showName = event['show_name'] as String? ?? '未知';
    final showId = event['show_id'] as int? ?? 0;

    Widget content = coverPath != null && coverPath.isNotEmpty
        ? Image.file(
            File(coverPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) =>
                _buildPosterFallback(showName: showName, showId: showId),
          )
        : _buildPosterFallback(showName: showName, showId: showId);

    if (isOutside) {
      content = Opacity(opacity: 0.5, child: content);
    }

    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        color: color.withValues(alpha: isOutside ? 0.08 : 0.15),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildPosterFallback({required String showName, required int showId}) {
    final color = coverColorForShow(showId);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            coverColorForShow(showId + 3),
          ],
        ),
      ),
      child: Center(
        child: Text(
          showName.length >= 2 ? showName.substring(0, 2) : showName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count, double shortestSide) {
    final badgeSize = shortestSide * 0.24;
    final fontSize = (badgeSize * 0.45).clamp(8.0, 11.0);

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(badgeSize * 0.45),
          bottomLeft: Radius.circular(badgeSize * 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Color statusColorForEvent(Map<String, dynamic> event) {
    final status = event['status'] as String? ?? 'unmarked';
    return statusColor(status);
  }
}
