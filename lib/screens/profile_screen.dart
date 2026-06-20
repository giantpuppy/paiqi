import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/ticket.dart';
import '../utils/page_transitions.dart';
import '../models/cast_member.dart';
import '../models/profile_stats.dart';
import '../widgets/charts/chart_theme.dart';
import '../widgets/warm_spotlight.dart';
import '../widgets/glow_card.dart';
import '../widgets/poster_fallback.dart';
import '../widgets/breathing_icon.dart';
import 'settings_page.dart';
import 'ranking_detail_page.dart';
import 'performance_list_page.dart';

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
  bool _needsRefresh = true;

  // 时间筛选
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];

  ProfileStats _stats = ProfileStats.fromData(
    slice: const TimeSlice.all(),
    performances: const [],
    shows: const [],
    castMembers: const [],
    tickets: const [],
  );

  // 金额隐藏（默认隐藏）
  bool _amountHidden = true;

  static const int _defaultShowRows = 4;

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

  TimeSlice get _currentTimeSlice {
    if (_selectedMonth != null && _selectedYear != null) {
      return TimeSlice.month(_selectedYear!, _selectedMonth!);
    } else if (_selectedYear != null) {
      return TimeSlice.year(_selectedYear!);
    }
    return const TimeSlice.all();
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
    // 提取可用年份
    final years = <int>{};
    for (final p in performances) {
      final date = DateTime.tryParse(p.date);
      if (date != null) years.add(date.year);
    }
    final sortedYears = years.toList()..sort();

    setState(() {
      _shows = shows;
      _performances = performances;
      _tickets = tickets;
      _castMembers = castMembers;
      _availableYears = sortedYears;
      _stats = ProfileStats.fromData(
        slice: _currentTimeSlice,
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
        slice: _currentTimeSlice,
        performances: _performances,
        shows: _shows,
        castMembers: _castMembers,
        tickets: _tickets,
      );
    });
  }

  Show? _showForPerformance(Performance performance) {
    try {
      return _shows.firstWhere((s) => s.id == performance.showId);
    } catch (_) {
      return null;
    }
  }

  /// 获取某场次的卡司演员名列表
  List<String> _actorsForPerformance(Performance performance) {
    return _castMembers
        .where((cm) => cm.performanceId == performance.id)
        .map((cm) => cm.actorName)
        .toList();
  }

  void _openSettings() {
    Navigator.push(
      context,
      SlideFadeRoute(page: const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildTimeFilter()),
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(child: _buildShowRankingList()),
                SliverToBoxAdapter(child: _buildActorRankingList()),
                SliverToBoxAdapter(child: _buildTheaterRankingList()),
                SliverToBoxAdapter(child: _buildWantToSeeCard()),
                SliverToBoxAdapter(child: _buildBoughtCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  // ─────────────────── Header ───────────────────

  Widget _buildHeader() {
    const displayName = 'GlueeulG';
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
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/profile_avatar.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      displayName,
                      style: TextStyle(
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

  // ─────────────────── 时间筛选胶囊 ───────────────────

  Widget _buildTimeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: _currentTimeSlice.isAll,
            onTap: () {
              setState(() {
                _selectedYear = null;
                _selectedMonth = null;
              });
              _recomputeStats();
            },
          ),
          const SizedBox(width: 8),
          _buildYearChip(),
          const SizedBox(width: 8),
          _buildMonthChip(),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : ChartTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : ChartTheme.label,
          ),
        ),
      ),
    );
  }

  Widget _buildYearChip() {
    final isSelected = _currentTimeSlice.isYear || _currentTimeSlice.isMonth;
    final label = _selectedYear != null ? '$_selectedYear年' : '年份▾';

    return GestureDetector(
      onTap: () => _showYearPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : ChartTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : ChartTheme.label,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedYear = null;
                    _selectedMonth = null;
                  });
                  _recomputeStats();
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthChip() {
    final isSelected = _currentTimeSlice.isMonth;
    final enabled = _selectedYear != null;
    final label = _selectedMonth != null ? '$_selectedMonth月' : '月份▾';

    return GestureDetector(
      onTap: enabled ? () => _showMonthPicker() : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : enabled
                  ? ChartTheme.background
                  : ChartTheme.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : enabled
                        ? ChartTheme.label
                        : ChartTheme.muted,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _selectedMonth = null);
                  _recomputeStats();
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择年份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              ..._availableYears.map((year) {
                final isSelected = _selectedYear == year;
                return ListTile(
                  title: Text(
                    '$year年',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                  ),
                  tileColor: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedYear = year;
                      _selectedMonth = null;
                    });
                    _recomputeStats();
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$_selectedYear年 · 选择月份',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: List.generate(12, (index) {
                  final month = index + 1;
                  final isSelected = _selectedMonth == month;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedMonth = month);
                      _recomputeStats();
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2)
                            : ChartTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────── 观剧场次 + 金额（并排） ───────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Expanded(child: _buildSessionsCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildAmountCardCompact()),
        ],
      ),
    );
  }

  Widget _buildSessionsCard() {
    return GlowCard(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      borderRadius: ChartTheme.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '观剧场次数',
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
    );
  }

  Widget _buildAmountCardCompact() {
    return GlowCard(
      padding: const EdgeInsets.all(ChartTheme.cardPadding),
      borderRadius: ChartTheme.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '金额统计',
                style: TextStyle(
                  fontSize: ChartTheme.titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: ChartTheme.label,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _amountHidden = !_amountHidden),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ChartTheme.grid.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _amountHidden
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 16,
                    color: _amountHidden
                        ? Theme.of(context).colorScheme.primary
                        : ChartTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 实付金额 - 主位
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
              _amountHidden
                  ? '***'
                  : '¥${_formatCurrency(_stats.totalPaid)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 票面金额 - 次位
          Text(
            '票面金额',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _amountHidden
                ? '***'
                : '¥${_formatCurrency(_stats.faceValue)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── 排序列表通用组件 ───────────────────

  Widget _buildRankingList({
    required String title,
    required List<MapEntry<String, int>> data,
    required Color accentColor,
  }) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: GlowCard(
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
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '暂无数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: ChartTheme.muted.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxValue = data.first.value.toDouble();
    final displayData = data.take(_defaultShowRows).toList();
    final hasMore = data.length > _defaultShowRows;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlowCard(
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
            const SizedBox(height: 12),
            ...displayData.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
              return _buildRankingRow(
                rank: rank,
                name: item.key,
                count: item.value,
                ratio: ratio,
                accentColor: accentColor,
                showDivider: entry.key > 0,
              );
            }),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    SlideFadeRoute(
                      page: RankingDetailPage(
                        title: title,
                        data: data,
                        accentColor: accentColor,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      '查看全部 ${data.length} ▾',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int count,
    required double ratio,
    required Color accentColor,
    required bool showDivider,
  }) {
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: rank <= 3
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 迷你进度条
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              color: ChartTheme.grid.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── 剧目排序 ───────────────────

  Widget _buildShowRankingList() {
    return _buildRankingList(
      title: '剧目场次次数',
      data: _stats.showRanking,
      accentColor: ChartTheme.primary,
    );
  }

  // ─────────────────── 演员排序 ───────────────────

  Widget _buildActorRankingList() {
    return _buildRankingList(
      title: '演员场次次数',
      data: _stats.actorRanking,
      accentColor: ChartTheme.watched,
    );
  }

  // ─────────────────── 剧场排序 ───────────────────

  Widget _buildTheaterRankingList() {
    return _buildRankingList(
      title: '剧场场次次数',
      data: _stats.theaterDistribution,
      accentColor: ChartTheme.bought,
    );
  }

  // ─────────────────── 想看卡片 ───────────────────

  Widget _buildWantToSeeCard() {
    final performances = _stats.wantToSeePerformances;
    final count = performances.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: GlowCard(
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '想看',
                  style: TextStyle(
                    fontSize: ChartTheme.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: ChartTheme.label,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count场次',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPerformanceListPreview(
              performances: performances,
              emptyIcon: Icons.star_border,
              emptyText: '暂无想看的剧目',
              onViewAll: () => Navigator.push(
                context,
                SlideFadeRoute(
                  page: PerformanceListPage(
                    title: '想看列表',
                    performances: performances,
                    shows: _shows,
                    castMembers: _castMembers,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 已买卡片 ───────────────────

  Widget _buildBoughtCard() {
    final performances = _stats.boughtPerformances;
    final count = performances.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlowCard(
        padding: const EdgeInsets.all(ChartTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '已买',
                  style: TextStyle(
                    fontSize: ChartTheme.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: ChartTheme.label,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ChartTheme.bought.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count场次',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ChartTheme.bought,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPerformanceListPreview(
              performances: performances,
              emptyIcon: Icons.confirmation_number_outlined,
              emptyText: '暂无已买的场次',
              onViewAll: () => Navigator.push(
                context,
                SlideFadeRoute(
                  page: PerformanceListPage(
                    title: '已买列表',
                    performances: performances,
                    shows: _shows,
                    castMembers: _castMembers,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 列表预览（最多4行） ───────────────────

  Widget _buildPerformanceListPreview({
    required List<Performance> performances,
    required IconData emptyIcon,
    required String emptyText,
    required VoidCallback onViewAll,
  }) {
    if (performances.isEmpty) {
      return _buildEmptyListPlaceholder(icon: emptyIcon, text: emptyText);
    }

    final displayItems = performances.take(_defaultShowRows).toList();
    final hasMore = performances.length > _defaultShowRows;

    return Column(
      children: [
        ...displayItems.asMap().entries.map((entry) {
          final index = entry.key;
          final performance = entry.value;
          final show = _showForPerformance(performance);
          final actors = _actorsForPerformance(performance);
          return _buildPerformanceRow(
            performance: performance,
            show: show,
            actors: actors,
            showDivider: index > 0,
          );
        }),
        if (hasMore)
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              alignment: Alignment.center,
              child: Text(
                '查看全部 ${performances.length} ▾',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPerformanceRow({
    required Performance performance,
    required Show? show,
    required List<String> actors,
    required bool showDivider,
  }) {
    final date = DateTime.tryParse(performance.date);
    final dateText =
        date != null ? '${date.month}/${date.day}' : performance.date;
    final actorText = actors.isNotEmpty ? actors.join('、') : '';

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
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                ? PosterFallback(
                    showId: show.id ?? 0,
                    showName: show.name,
                    fontSize: 18,
                  )
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
                const SizedBox(height: 3),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                if (actorText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    actorText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyListPlaceholder({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            BreathingIcon(
              icon: icon,
              size: 40,
              color: ChartTheme.muted.withValues(alpha: 0.4),
            ),
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
}
