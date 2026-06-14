import '../models/performance.dart';
import '../models/show.dart';
import '../models/cast_member.dart';

enum TimeSlice { all, year, month }

/// 个人中心统计数据聚合模型
///
/// 将 UI 层的统计计算下沉到纯 Dart 模型，支持时间切片过滤。
class ProfileStats {
  final TimeSlice timeSlice;

  // Hero 指标
  final int totalSessions;
  final double totalPaid;
  final double faceValue;
  final double savedValue;
  final int showsTracked;

  // 月度数据（12个月）
  final List<int> monthlySessions;

  // 演员排名
  final List<MapEntry<String, int>> actorRanking;

  // 剧场分布
  final List<MapEntry<String, int>> theaterDistribution;

  // 时段偏好
  final Map<String, int> timeSlotDistribution;

  const ProfileStats({
    required this.timeSlice,
    required this.totalSessions,
    required this.totalPaid,
    required this.faceValue,
    required this.savedValue,
    required this.showsTracked,
    required this.monthlySessions,
    required this.actorRanking,
    required this.theaterDistribution,
    required this.timeSlotDistribution,
  });

  int get maxMonthlyValue => monthlySessions.isEmpty
      ? 0
      : monthlySessions.reduce((a, b) => a > b ? a : b);

  int get maxActorCount => actorRanking.isEmpty ? 0 : actorRanking.first.value;

  int get maxTheaterCount => theaterDistribution.isEmpty ? 0 : theaterDistribution.first.value;

  /// 从原始数据构建统计对象
  factory ProfileStats.fromData({
    required TimeSlice slice,
    required List<Performance> performances,
    required List<Show> shows,
    required List<CastMember> castMembers,
  }) {
    final filtered = _filterByTimeSlice(performances, slice);

    // 已购买场次
    final boughtPerformances = filtered
        .where((p) => p.status == 'bought' || _isWatched(p))
        .toList();

    // Hero 指标
    final totalSessions = boughtPerformances.length;
    final totalPaid = boughtPerformances.fold(
      0.0,
      (sum, p) => sum + (p.actualPrice ?? p.price ?? 0),
    );
    final faceValue = boughtPerformances.fold(
      0.0,
      (sum, p) => sum + (p.price ?? 0),
    );
    final savedValue = faceValue - totalPaid > 0 ? faceValue - totalPaid : 0.0;

    final boughtShowIds = boughtPerformances.map((p) => p.showId).toSet();
    final showsTracked = boughtShowIds.length;

    // 月度数据
    final monthlySessions = List.generate(12, (index) => 0);
    for (final p in boughtPerformances) {
      final date = DateTime.tryParse(p.date);
      if (date != null) {
        monthlySessions[date.month - 1]++;
      }
    }

    // 演员排名
    final boughtPerfIds = boughtPerformances.map((p) => p.id).whereType<int>().toSet();
    final actorCounts = <String, int>{};
    for (final cm in castMembers) {
      if (boughtPerfIds.contains(cm.performanceId)) {
        actorCounts[cm.actorName] = (actorCounts[cm.actorName] ?? 0) + 1;
      }
    }
    final actorRanking = actorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 剧场分布
    final theaterCounts = <String, int>{};
    for (final p in boughtPerformances) {
      final show = shows.firstWhere(
        (s) => s.id == p.showId,
        orElse: () => Show(name: '未知剧场'),
      );
      if (show.theater != null && show.theater!.isNotEmpty) {
        theaterCounts[show.theater!] = (theaterCounts[show.theater!] ?? 0) + 1;
      }
    }
    final theaterDistribution = theaterCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 时段偏好
    final timeSlotCounts = <String, int>{
      '下午场': 0,
      '傍晚场': 0,
      '晚场': 0,
    };
    for (final p in boughtPerformances) {
      final slot = _timeSlot(p.time);
      timeSlotCounts[slot] = (timeSlotCounts[slot] ?? 0) + 1;
    }

    return ProfileStats(
      timeSlice: slice,
      totalSessions: totalSessions,
      totalPaid: totalPaid,
      faceValue: faceValue,
      savedValue: savedValue,
      showsTracked: showsTracked,
      monthlySessions: monthlySessions,
      actorRanking: actorRanking,
      theaterDistribution: theaterDistribution,
      timeSlotDistribution: timeSlotCounts,
    );
  }

  static List<Performance> _filterByTimeSlice(
    List<Performance> performances,
    TimeSlice slice,
  ) {
    final now = DateTime.now();
    return performances.where((p) {
      final date = DateTime.tryParse(p.date);
      if (date == null) return false;

      switch (slice) {
        case TimeSlice.month:
          return date.year == now.year && date.month == now.month;
        case TimeSlice.year:
          return date.year == now.year;
        case TimeSlice.all:
          return true;
      }
    }).toList();
  }

  static bool _isWatched(Performance p) {
    if (p.status != 'bought') return false;
    final date = DateTime.tryParse(p.date);
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  static String _timeSlot(String? time) {
    if (time == null || time.isEmpty) return '晚场';
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 19;
    if (hour < 14) return '下午场';
    if (hour < 18) return '傍晚场';
    return '晚场';
  }
}
