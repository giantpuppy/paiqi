import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/ticket.dart';
import '../utils/page_transitions.dart';
import '../models/cast_member.dart';
import '../models/profile_stats.dart';
import '../services/user_service.dart';
import '../widgets/charts/chart_theme.dart';
import '../widgets/charts/simple_bar_chart.dart';
import '../widgets/charts/horizontal_bar_chart.dart';
import '../widgets/charts/donut_chart.dart';
import '../widgets/warm_spotlight.dart';
import '../widgets/glow_card.dart';
import '../widgets/poster_fallback.dart';
import '../widgets/breathing_icon.dart';
import 'calendar_screen.dart';
import 'settings_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Show> _shows = [];
  List<Performance> _performances = [];
  List<Ticket> _tickets = [];
  List<CastMember> _castMembers = [];
  bool _isLoading = true;
  String? _currentUser;
  bool _needsRefresh = true;

  TimeSlice _currentSlice = TimeSlice.all;
  ProfileStats _stats = _emptyStats(TimeSlice.all);
  bool _isActorDonut = false;
  int _showListTabIndex = 0;

  static ProfileStats _emptyStats(TimeSlice slice) {
    return ProfileStats(
      timeSlice: slice,
      totalSessions: 0,
      watchedSessions: 0,
      upcomingSessions: 0,
      totalPaid: 0,
      faceValue: 0,
      savedValue: 0,
      totalDurationHours: 0,
      showsTracked: 0,
      monthlySessions: List.generate(12, (_) => 0),
      actorRanking: const [],
      theaterDistribution: const [],
      showRanking: const [],
      timeSlotDistribution: const {'下午场': 0, '傍晚场': 0, '晚场': 0},
      wantToSeePerformances: const [],
    );
  }

  String _formatCurrency(double value) {
    if (value == 0) return '0';
    final s = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needsRefresh) {
      _needsRefresh = false;
      _loadData();
    }
  }

  @override
  void deactivate() {
    _needsRefresh = true;
    super.deactivate();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final shows = await db.getAllShows();
    final performances = await db.getAllPerformances();
    final tickets = await db.getAllTickets();
    final castMembers = await db.getAllCastMembers();
    final currentUser = await UserService.getCurrentUsername();

    setState(() {
      _shows = shows;
      _performances = performances;
      _tickets = tickets;
      _castMembers = castMembers;
      _currentUser = currentUser;
      _stats = ProfileStats.fromData(
        slice: _currentSlice,
        performances: performances,
        shows: shows,
        castMembers: castMembers,
        tickets: tickets,
      );
      _isLoading = false;
    });
  }

  void _recomputeStats() {
    setState(() {
      _stats = ProfileStats.fromData(
        slice: _currentSlice,
        performances: _performances,
        shows: _shows,
        castMembers: _castMembers,
        tickets: _tickets,
      );
    });
  }

  void _navigateToCalendar(CalendarFilter filter, {DateTime? focusedDay}) {
    Navigator.push(
      context,
      SlideFadeRoute(
        page: CalendarScreen(
          initialFilter: filter,
          initialFocusedDay: focusedDay,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      SlideFadeRoute(page: const SettingsPage()),
    );
  }

  Future<void> _removeFromWantToSee(Performance performance) async {
    final updated = performance.copyWith(status: 'unmarked');
    await DatabaseHelper.instance.updatePerformance(updated);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从想看清单移除')),
      );
    }
  }

  Show? _showForPerformance(Performance performance) {
    try {
      return _shows.firstWhere((s) => s.id == performance.showId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildTotalSessionsHero()),
                SliverToBoxAdapter(child: _buildTimeSliceController()),
                SliverToBoxAdapter(child: _buildShowRankingChart()),
                SliverToBoxAdapter(child: _buildChartGrid()),
                SliverToBoxAdapter(child: _buildAmountCard()),
                SliverToBoxAdapter(child: _buildStatusCards()),
                SliverToBoxAdapter(child: _buildMonthlyChart()),
                SliverToBoxAdapter(child: _buildShowLists()),
                SliverToBoxAdapter(child: _buildFavoritePlaceholder()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final displayName = _currentUser ?? '未登录';
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, statusBarHeight + 16, 24, 0),
      child: WarmSpotlight(
        color: Theme.of(context).colorScheme.primary,
        minAlpha: 0.04,
        maxAlpha: 0.10,
        minBlur: 12,
        maxBlur: 24,
        borderRadius: 20,
        shouldAnimate: true,
        child: GlowCard(
          onTap: kIsWeb ? null : _openSettings,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          borderRadius: 20,
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '我的剧场档案',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (!kIsWeb)
                Icon(
                  Icons.settings_outlined,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalSessionsHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: GlowCard(
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        borderRadius: ChartTheme.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '观看总场次',
              style: TextStyle(
                fontSize: ChartTheme.titleFontSize,
                fontWeight: FontWeight.w600,
                color: ChartTheme.label,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_stats.totalSessions}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '覆盖 ${_stats.showsTracked} 部剧目',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSliceController() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ChartTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: TimeSlice.values.map((slice) {
                  final isSelected = _currentSlice == slice;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _currentSlice = slice);
                        _recomputeStats();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slice.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : ChartTheme.label,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowRankingChart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: _stats.showRanking.isEmpty
          ? _buildEmptyChartPlaceholder(title: '观看剧目排序')
          : GlowCard(
              padding: const EdgeInsets.all(ChartTheme.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '观看剧目排序',
                    style: TextStyle(
                      fontSize: ChartTheme.titleFontSize,
                      fontWeight: FontWeight.w600,
                      color: ChartTheme.label,
                    ),
                  ),
                  const SizedBox(height: 16),
                  HorizontalBarChart(
                    data: _stats.showRanking
                        .map((e) => ChartData(label: e.key, value: e.value))
                        .toList(),
                    accentColor: ChartTheme.primary,
                    displayCount: 5,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthlyChart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: _stats.totalSessions == 0
          ? _buildEmptyChartPlaceholder(title: '月度观演节奏')
          : SimpleBarChart(
              data: List.generate(
                12,
                (index) => ChartData(
                  label: '${index + 1}月',
                  value: _stats.monthlySessions[index],
                ),
              ),
              title: '月度观演节奏',
              activeColor: ChartTheme.primary,
              highlightIndex: DateTime.now().month - 1,
              onBarTap: (index) => _navigateToCalendar(
                CalendarFilter.bought,
                focusedDay: DateTime(DateTime.now().year, index + 1, 1),
              ),
            ),
    );
  }

  Widget _buildChartGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildActorChart()),
              const SizedBox(width: 12),
              Expanded(child: _buildTheaterChart()),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimeSlotChart(),
        ],
      ),
    );
  }

  Widget _buildActorChart() {
    if (_stats.actorRanking.isEmpty) {
      return _buildEmptyChartPlaceholder(title: '演员排名', compact: true);
    }

    final actorData = _stats.actorRanking
        .map((e) => ChartData(label: e.key, value: e.value))
        .toList();

    return GlowCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '演员排名',
                style: TextStyle(
                  fontSize: ChartTheme.titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: ChartTheme.label,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isActorDonut = !_isActorDonut),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartTheme.grid.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isActorDonut ? Icons.bar_chart : Icons.donut_large,
                    size: 16,
                    color: ChartTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isActorDonut)
            _buildActorDonutChart(actorData)
          else
            HorizontalBarChart(
              data: actorData,
              accentColor: ChartTheme.watched,
              displayCount: 5,
            ),
        ],
      ),
    );
  }

  Widget _buildActorDonutChart(List<ChartData> data) {
    const topCount = 5;
    final topItems = data.take(topCount).toList();
    final othersCount = data.skip(topCount).fold(0, (sum, item) => sum + item.value);

    final Map<String, int> chartData = {
      for (final item in topItems) item.label: item.value,
    };
    if (othersCount > 0) {
      chartData['其他'] = othersCount;
    }

    return DonutChart(
      data: chartData,
      colors: const [
        ChartTheme.watched,
        ChartTheme.primary,
        ChartTheme.bought,
        Color(0xFF8A8F98),
        Color(0xFF6B5BCD),
        Color(0xFFD4A853),
      ],
    );
  }

  Widget _buildTheaterChart() {
    return GlowCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '剧场分布',
            style: TextStyle(
              fontSize: ChartTheme.titleFontSize,
              fontWeight: FontWeight.w600,
              color: ChartTheme.label,
            ),
          ),
          const SizedBox(height: 12),
          _stats.theaterDistribution.isEmpty
              ? _buildCompactEmptyPlaceholder()
              : HorizontalBarChart(
                  data: _stats.theaterDistribution
                      .map((e) => ChartData(label: e.key, value: e.value))
                  .toList(),
                  accentColor: ChartTheme.bought,
                  displayCount: 5,
                ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotChart() {
    return GlowCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '时段偏好',
            style: TextStyle(
              fontSize: ChartTheme.titleFontSize,
              fontWeight: FontWeight.w600,
              color: ChartTheme.label,
            ),
          ),
          const SizedBox(height: 12),
          _stats.totalSessions == 0
              ? _buildCompactEmptyPlaceholder()
              : DonutChart(
                  data: _stats.timeSlotDistribution,
                  colors: const [
                    ChartTheme.watched,
                    ChartTheme.primary,
                    ChartTheme.bought,
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlowCard(
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '金额统计',
              style: TextStyle(
                fontSize: ChartTheme.titleFontSize,
                fontWeight: FontWeight.w600,
                color: ChartTheme.label,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '实付金额',
                        style: TextStyle(
                          fontSize: 12,
                          color: ChartTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¥${_formatCurrency(_stats.totalPaid)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '票面金额',
                        style: TextStyle(
                          fontSize: 12,
                          color: ChartTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¥${_formatCurrency(_stats.faceValue)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: ChartTheme.watched,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '省钱 ¥${_formatCurrency(_stats.savedValue)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: '已购买',
              value: '${_stats.upcomingSessions}',
              accentColor: ChartTheme.bought,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: '已观演',
              value: '${_stats.watchedSessions}',
              accentColor: ChartTheme.watched,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowLists() {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    final upcomingPerformances = _performances.where((p) {
      if (p.status != 'bought') return false;
      final date = DateTime.tryParse(p.date);
      return date != null &&
          date.isAfter(now) &&
          date.isBefore(sevenDaysLater);
    }).toList();

    final wantToSee = _stats.wantToSeePerformances;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: GlowCard(
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShowListTab('即将观演', 0, upcomingPerformances.length),
                const SizedBox(width: 16),
                _buildShowListTab('想看清单', 1, wantToSee.length),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _showListTabIndex == 0
                  ? _buildPerformanceList(
                      key: const ValueKey('upcoming'),
                      performances: upcomingPerformances,
                      emptyIcon: Icons.confirmation_number_outlined,
                      emptyText: '未来 7 天内没有即将观演的场次',
                    )
                  : _buildWantToSeeList(
                      key: const ValueKey('want_to_see'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowListTab(String label, int index, int count) {
    final isSelected = _showListTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _showListTabIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : ChartTheme.label,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                      : ChartTheme.grid.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : ChartTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceList({
    required Key key,
    required List<Performance> performances,
    required IconData emptyIcon,
    required String emptyText,
  }) {
    if (performances.isEmpty) {
      return _buildEmptyListPlaceholder(icon: emptyIcon, text: emptyText);
    }

    return Column(
      key: key,
      children: performances.asMap().entries.map((entry) {
        final index = entry.key;
        final performance = entry.value;
        final show = _showForPerformance(performance);
        return _buildPerformanceRow(
          performance: performance,
          show: show,
          showDivider: index > 0,
        );
      }).toList(),
    );
  }

  Widget _buildWantToSeeList({required Key key}) {
    final performances = _stats.wantToSeePerformances;
    if (performances.isEmpty) {
      return _buildEmptyListPlaceholder(
        icon: Icons.star_border,
        text: '暂无想看的剧目',
      );
    }

    return Column(
      key: key,
      children: performances.asMap().entries.map((entry) {
        final index = entry.key;
        final performance = entry.value;
        final show = _showForPerformance(performance);
        return Dismissible(
          key: ValueKey('want_${performance.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF54A45).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Color(0xFFF54A45)),
          ),
          onDismissed: (_) => _removeFromWantToSee(performance),
          child: _buildPerformanceRow(
            performance: performance,
            show: show,
            showDivider: index > 0,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceRow({
    required Performance performance,
    required Show? show,
    required bool showDivider,
  }) {
    final date = DateTime.tryParse(performance.date);
    final dateText = date != null ? '${date.month}/${date.day}' : performance.date;
    final timeText = performance.time?.isNotEmpty == true ? performance.time! : '';

    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: ChartTheme.grid,
            ),
            clipBehavior: Clip.antiAlias,
            child: show != null
                ? PosterFallback(showId: show.id ?? 0, showName: show.name, fontSize: 18)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show?.name ?? '未知剧目',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${show?.theater ?? ''}  $dateText $timeText'.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyListPlaceholder({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            BreathingIcon(icon: icon, size: 40, color: ChartTheme.muted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: ChartTheme.muted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritePlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlowCard(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('收藏功能即将上线')),
          );
        },
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: ChartTheme.grid,
              ),
              child: Center(
                child: Icon(
                  Icons.favorite_border,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的收藏',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '收藏的剧目、演员和剧场将集中在这里',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartPlaceholder({required String title, bool compact = false}) {
    return GlowCard(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: ChartTheme.titleFontSize,
              fontWeight: FontWeight.w600,
              color: ChartTheme.label,
            ),
          ),
          SizedBox(height: compact ? 16 : 28),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: ChartTheme.muted.withValues(alpha: 0.4),
                  size: compact ? 24 : 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: ChartTheme.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEmptyPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              color: ChartTheme.muted.withValues(alpha: 0.4),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 12,
                color: ChartTheme.muted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;

  const _MetricCard({
    required this.label,
    required this.value,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(14),
      borderRadius: ChartTheme.cardRadius,
      glowColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: ChartTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                height: 1.1,
                color: ChartTheme.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
