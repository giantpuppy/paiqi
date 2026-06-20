import '../models/performance.dart';
import '../models/show.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';

/// 时间切片：全部 / 指定年 / 指定年月
class TimeSlice {
  final int? year;
  final int? month;

  const TimeSlice.all()
      : year = null,
        month = null;
  const TimeSlice.year(this.year) : month = null;
  const TimeSlice.month(this.year, this.month);

  bool get isAll => year == null;
  bool get isYear => year != null && month == null;
  bool get isMonth => year != null && month != null;

  String get label {
    if (isAll) return '全部';
    if (isMonth) return '$year年$month月';
    return '$year年';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlice && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

/// 个人中心统计数据聚合模型
///
/// 将 UI 层的统计计算下沉到纯 Dart 模型，支持时间切片过滤。
class ProfileStats {
  final TimeSlice timeSlice;

  // Hero 指标
  final int totalSessions;
  final int watchedSessions;
  final int upcomingSessions;
  final double totalPaid;
  final double faceValue;
  final double savedValue;
  final double totalDurationHours;
  final int showsTracked;

  // 月度数据（12个月）
  final List<int> monthlySessions;

  // 演员排名
  final List<MapEntry<String, int>> actorRanking;

  // 剧场分布
  final List<MapEntry<String, int>> theaterDistribution;

  // 剧目排名
  final List<MapEntry<String, int>> showRanking;

  // 时段偏好
  final Map<String, int> timeSlotDistribution;

  // 想看清单
  final List<Performance> wantToSeePerformances;

  // 已买清单（bought + watched）
  final List<Performance> boughtPerformances;

  const ProfileStats({
    required this.timeSlice,
    required this.totalSessions,
    required this.watchedSessions,
    required this.upcomingSessions,
    required this.totalPaid,
    required this.faceValue,
    required this.savedValue,
    required this.totalDurationHours,
    required this.showsTracked,
    required this.monthlySessions,
    required this.actorRanking,
    required this.theaterDistribution,
    required this.showRanking,
    required this.timeSlotDistribution,
    required this.wantToSeePerformances,
    required this.boughtPerformances,
  });

  int get maxMonthlyValue => monthlySessions.isEmpty
      ? 0
      : monthlySessions.reduce((a, b) => a > b ? a : b);

  int get maxActorCount => actorRanking.isEmpty ? 0 : actorRanking.first.value;

  int get maxTheaterCount =>
      theaterDistribution.isEmpty ? 0 : theaterDistribution.first.value;

  int get wantToSeeCount => wantToSeePerformances.length;
  int get boughtCount => boughtPerformances.length;

  /// 从原始数据构建统计对象
  factory ProfileStats.fromData({
    required TimeSlice slice,
    required List<Performance> performances,
    required List<Show> shows,
    required List<CastMember> castMembers,
    required List<Ticket> tickets,
  }) {
    final filtered = _filterByTimeSlice(performances, slice);

    // 想看清单（不受 bought/watched 过滤影响，但受时间切片影响）
    final wantToSeePerformances =
        filtered.where((p) => p.status == 'want_to_see').toList();

    // 按 performanceId 聚合 ticket（取首条）
    final ticketMap = <int, Ticket>{};
    for (final t in tickets) {
      ticketMap.putIfAbsent(t.performanceId, () => t);
    }

    // 已购买 / 已观演场次（优先使用持久化状态；旧数据回退到日期规则）
    final boughtPerformances = filtered
        .where((p) => p.status == 'bought' || p.status == 'watched')
        .toList();

    // Hero 指标
    final totalSessions = boughtPerformances.length;
    final now = DateTime.now();
    final watchedSessions = boughtPerformances.where((p) {
      if (p.status == 'watched') return true;
      final date = DateTime.tryParse(p.date);
      return date != null && date.isBefore(now);
    }).length;
    final upcomingSessions = totalSessions - watchedSessions;
    final totalPaid = boughtPerformances.fold(
      0.0,
      (sum, p) {
        final t = ticketMap[p.id];
        return sum + (t?.actualPrice ?? t?.price ?? 0);
      },
    );
    final faceValue = boughtPerformances.fold(
      0.0,
      (sum, p) => sum + (ticketMap[p.id]?.price ?? 0),
    );
    final savedValue = faceValue - totalPaid > 0 ? faceValue - totalPaid : 0.0;
    final totalDurationHours = totalSessions * 2.5;

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
    final boughtPerfIds =
        boughtPerformances.map((p) => p.id).whereType<int>().toSet();
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

    // 剧目排名
    final showCounts = <String, int>{};
    for (final p in boughtPerformances) {
      final show = shows.firstWhere(
        (s) => s.id == p.showId,
        orElse: () => Show(name: '未知剧目'),
      );
      showCounts[show.name] = (showCounts[show.name] ?? 0) + 1;
    }
    final showRanking = showCounts.entries.toList()
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
      watchedSessions: watchedSessions,
      upcomingSessions: upcomingSessions,
      totalPaid: totalPaid,
      faceValue: faceValue,
      savedValue: savedValue,
      totalDurationHours: totalDurationHours,
      showsTracked: showsTracked,
      monthlySessions: monthlySessions,
      actorRanking: actorRanking,
      theaterDistribution: theaterDistribution,
      showRanking: showRanking,
      timeSlotDistribution: timeSlotCounts,
      wantToSeePerformances: wantToSeePerformances,
      boughtPerformances: boughtPerformances,
    );
  }

  static List<Performance> _filterByTimeSlice(
    List<Performance> performances,
    TimeSlice slice,
  ) {
    if (slice.isAll) return performances;

    return performances.where((p) {
      final date = DateTime.tryParse(p.date);
      if (date == null) return false;

      if (slice.isMonth) {
        return date.year == slice.year && date.month == slice.month;
      }
      // isYear
      return date.year == slice.year;
    }).toList();
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
