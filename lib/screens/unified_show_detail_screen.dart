import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';
import '../utils/status_colors.dart';
import '../widgets/poster_fallback.dart';
import '../widgets/status_star_button.dart';
import '../widgets/warm_spotlight.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/todo_list_section.dart';
import '../widgets/bought_form_sheet.dart';
import 'add_show_screen.dart';

class UnifiedShowDetailScreen extends StatefulWidget {
  final int performanceId;

  const UnifiedShowDetailScreen({super.key, required this.performanceId});

  @override
  State<UnifiedShowDetailScreen> createState() =>
      _UnifiedShowDetailScreenState();
}

class _UnifiedShowDetailScreenState extends State<UnifiedShowDetailScreen> {
  // 数据
  Show? _show;
  Performance? _currentPerf;
  List<Performance> _allPerformances = [];
  List<CastMember> _castMembers = [];
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final detail = await db.getPerformanceDetail(widget.performanceId);
    if (detail == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final showId = detail['show_id'] as int;
    final show = await db.getShowById(showId);
    final perfs = await db.getPerformancesByShowId(showId);
    final cast = await db.getCastMembersByPerformanceId(widget.performanceId);
    final tickets = await db.getTicketsByPerformanceId(widget.performanceId);

    final currentPerf = perfs.firstWhere((p) => p.id == widget.performanceId);

    if (mounted) {
      setState(() {
        _show = show;
        _currentPerf = currentPerf;
        _allPerformances = perfs;
        _castMembers = cast;
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchPerformance(int perfId) async {
    if (perfId == _currentPerf?.id) return;
    setState(() => _isLoading = true);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedShowDetailScreen(performanceId: perfId),
      ),
    );
  }

  /// 循环切换状态：未标记 → 想看 → 已买 → 已观演 → 未标记
  Future<void> _cycleStatus() async {
    if (_currentPerf == null) return;
    final current = _currentPerf!.status ?? 'unmarked';
    final next = switch (current) {
      'unmarked' => 'want_to_see',
      'want_to_see' => 'bought',
      'bought' => 'watched',
      'watched' => 'unmarked',
      _ => 'unmarked',
    };

    setState(() {
      _currentPerf = _currentPerf!.copyWith(status: next);
    });

    await _saveStatus(next);

    // 切到 bought 时弹出购票信息表单
    if (next == 'bought') {
      final ticket = await showBoughtFormSheet(
        context,
        performanceId: _currentPerf!.id!,
      );
      if (ticket != null) {
        setState(() {
          _tickets.add(ticket);
          _hasChanges = true;
        });
        await _save();
      }
    }
  }

  Future<void> _saveStatus(String status) async {
    if (_currentPerf == null) return;
    final db = DatabaseHelper.instance;
    final updated = _currentPerf!.copyWith(status: status);
    await db.updatePerformance(updated);
  }

  void _addTicket() {
    setState(() {
      _tickets.add(Ticket(
        performanceId: _currentPerf!.id!,
        seat: null,
        price: null,
        actualPrice: null,
      ));
      _hasChanges = true;
    });
  }

  void _removeTicket(int index) {
    setState(() {
      _tickets.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    if (_currentPerf == null) return;
    final db = DatabaseHelper.instance;

    final updated = _currentPerf!.copyWith(status: _currentPerf!.status);
    await db.updatePerformance(updated);

    // 更新票根
    await db.deleteTicketsByPerformanceId(_currentPerf!.id!);
    for (final ticket in _tickets) {
      await db.createTicket(Ticket(
        performanceId: _currentPerf!.id!,
        seat: ticket.seat,
        price: ticket.price,
        actualPrice: ticket.actualPrice,
      ));
    }

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _deletePerformance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('确认删除', style: TextStyle(color: Colors.white)),
        content: const Text('确定要删除这场演出记录吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      await db.deleteTicketsByPerformanceId(_currentPerf!.id!);
      await db.deleteTodoItemsByPerformanceId(_currentPerf!.id!);
      await db.deleteCastMembersByPerformanceId(_currentPerf!.id!);
      await db.deletePerformance(_currentPerf!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _editShow() {
    if (_show == null || _currentPerf == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddShowScreen(
          isEditMode: true,
          initialShow: _show,
          initialPerformances: [_currentPerf!],
        ),
      ),
    ).then((_) => _loadData());
  }

  void _onBackPressed() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('未保存的修改', style: TextStyle(color: Colors.white)),
          content: const Text('是否保存？', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('不保存', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _save();
                if (mounted) Navigator.pop(context, true);
              },
              child: const Text('保存', style: TextStyle(color: kBrandPurple)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_show == null || _currentPerf == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('场次详情')),
        body: const Center(child: Text('未找到场次信息')),
      );
    }

    final showColor = coverColorForShow(_show!.id ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: _hasChanges
          ? FloatingActionButton(
              onPressed: _save,
              backgroundColor: kBrandPurple,
              shape: const StadiumBorder(),
              child: const Icon(Icons.check, color: Colors.white),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (_allPerformances.length > 1)
                    _buildPerformanceSwitcher(showColor),
                  if (_allPerformances.length > 1)
                    const SizedBox(height: 20),
                  _buildInfoCard(showColor),
                  const SizedBox(height: 24),
                  _buildCastSection(showColor),
                  const SizedBox(height: 24),
                  if (_currentPerf!.status == 'bought' ||
                      _currentPerf!.status == 'watched') ...[
                    _buildTicketSection(showColor),
                    const SizedBox(height: 24),
                  ],
                  TodoListSection(
                    performanceId: _currentPerf!.id!,
                    glowColor: showColor,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SliverAppBar ====================

  Widget _buildSliverAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final expandedHeight = (screenWidth * 0.55).clamp(260.0, 360.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _onBackPressed,
      ),
      actions: [
        StatusStarButton(status: _currentPerf?.status ?? 'unmarked', onTap: _cycleStatus),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF1E1E1E),
          onSelected: (value) {
            if (value == 'edit') {
              _editShow();
            } else if (value == 'delete') {
              _deletePerformance();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('编辑剧目', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('删除场次',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final t = (constraints.maxHeight - kToolbarHeight) /
              (expandedHeight - kToolbarHeight);
          final collapseOpacity = 1.0 - t.clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildPosterBackground(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      Colors.black87,
                      Color(0xFF121212),
                    ],
                    stops: [0.0, 0.35, 0.72, 1.0],
                  ),
                ),
              ),
              // 折叠时：剧名在 AppBar 左侧与返回键同行
              Positioned(
                left: 56,
                right: 120,
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: collapseOpacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _show!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== 场次切换条 ====================

  Widget _buildPerformanceSwitcher(Color accentColor) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allPerformances.length,
        itemBuilder: (context, index) {
          final perf = _allPerformances[index];
          final isCurrent = perf.id == _currentPerf!.id;
          final dateTime = DateTime.tryParse(perf.date);
          final label = dateTime != null
              ? '${dateTime.month}/${dateTime.day} ${perf.time ?? ''}'
              : (perf.time ?? '');

          return GestureDetector(
            onTap: isCurrent ? null : () => _switchPerformance(perf.id!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCurrent
                      ? accentColor.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isCurrent
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 场次信息区（只读） ====================

  Widget _buildInfoCard(Color showColor) {
    final dateTime = DateTime.tryParse(_currentPerf!.date);
    final weekday = dateTime != null
        ? DateFormat('EEEE', 'zh_CN').format(dateTime)
        : '';
    final seatText = _tickets.isNotEmpty ? (_tickets.first.seat ?? '') : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 90,
          decoration: BoxDecoration(
            color: statusColor(_currentPerf?.status ?? 'unmarked'),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${dateTime?.month ?? '--'}月${dateTime?.day ?? '--'}日',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _currentPerf!.time ?? '19:30',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kBrandPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _show!.theater ?? '未知剧场',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              if (seatText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _formatSeatDisplay(seatText),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatSeatDisplay(String seat) {
    final parts = seat.split('-');
    if (parts.length >= 3) {
      return '${parts[0]}区/层 · ${parts[1]}排 · ${parts[2]}号';
    }
    return seat;
  }

  // ==================== 卡司区（只读） ====================

  Widget _buildCastSection(Color showColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('本场卡司', '${_castMembers.length}人', showColor),
        const SizedBox(height: 12),
        if (_castMembers.isEmpty)
          _buildEmptyState(
            icon: Icons.people_outline,
            text: '暂无卡司信息',
          )
        else
          Column(
            children: _castMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final cast = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: index > 0
                      ? Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cast.role.isEmpty ? '-' : cast.role,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            cast.actorName.isEmpty ? '-' : cast.actorName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          if (cast.isFeatured == true) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: kWarmGold,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ==================== 票根区 ====================

  Widget _buildTicketSection(Color showColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionHeaderInline('票根', '${_tickets.length}张', showColor),
            const Spacer(),
            WarmSpotlight(
              color: kWarmGold,
              minAlpha: 0.1,
              maxAlpha: 0.25,
              minBlur: 6,
              maxBlur: 12,
              borderRadius: 10,
              child: GestureDetector(
                onTap: _addTicket,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kWarmGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: kWarmGold.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: kWarmGold),
                      SizedBox(width: 4),
                      Text(
                        '添加',
                        style: TextStyle(
                          fontSize: 12,
                          color: kWarmGold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tickets.isEmpty)
          _buildEmptyState(
            icon: Icons.confirmation_num_outlined,
            text: '暂无票根，点击上方按钮添加',
          )
        else
          ..._tickets.asMap().entries.map((entry) {
            final i = entry.key;
            final ticket = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _tickets.length - 1 ? 12 : 0),
              child: _buildTicketCard(i, ticket),
            );
          }),
      ],
    );
  }

  Widget _buildTicketCard(int index, Ticket ticket) {
    final accentColor = index == 0 ? kBrandPurple : kWarmGold;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 80,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '票根 ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _removeTicket(index),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTicketField(
                icon: Icons.event_seat,
                value: ticket.seat != null && ticket.seat!.isNotEmpty
                    ? _formatSeatDisplay(ticket.seat!)
                    : '',
                placeholder: '点击输入座位',
                onTap: () => _showSeatEditDialog(index, ticket),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                Expanded(
                  child: _buildTicketField(
                    icon: Icons.confirmation_number_outlined,
                    value: ticket.price != null
                        ? '¥${ticket.price!.toStringAsFixed(0)}'
                        : '',
                    placeholder: '¥票面',
                    onTap: () {
                      final ctrl = TextEditingController(
                          text: ticket.price?.toStringAsFixed(0) ?? '');
                      _showEditDialog('票面价格', ctrl, (v) {
                        setState(() {
                          _tickets[index] = ticket.copyWith(
                              price: double.tryParse(v));
                          _hasChanges = true;
                        });
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTicketField(
                    icon: Icons.payments_outlined,
                    value: ticket.actualPrice != null
                        ? '¥${ticket.actualPrice!.toStringAsFixed(0)}'
                        : '',
                    placeholder: '¥实付',
                    onTap: () {
                      final ctrl = TextEditingController(
                          text: ticket.actualPrice?.toStringAsFixed(0) ?? '');
                      _showEditDialog('实付价格', ctrl, (v) {
                        setState(() {
                          _tickets[index] = ticket.copyWith(
                              actualPrice: double.tryParse(v));
                          _hasChanges = true;
                        });
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
    );
  }

  Widget _buildTicketField({
    required IconData icon,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B5BCD)),
          const SizedBox(width: 6),
          Text(
            value.isNotEmpty ? value : placeholder,
            style: TextStyle(
              fontSize: 14,
              color: value.isNotEmpty
                  ? Colors.white.withValues(alpha: 0.85)
                  : const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 座位三段式编辑 ====================

  void _showSeatEditDialog(int index, Ticket ticket) {
    final parts = (ticket.seat ?? '').split('-');
    final floorCtrl = TextEditingController(
        text: parts.isNotEmpty ? parts[0] : '');
    final rowCtrl = TextEditingController(
        text: parts.length > 1 ? parts[1] : '');
    final seatCtrl = TextEditingController(
        text: parts.length > 2 ? parts[2] : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('输入座位',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: floorCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  decoration: _seatInputDecoration('区/层'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('-',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ),
              Expanded(
                child: TextField(
                  controller: rowCtrl,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  decoration: _seatInputDecoration('排'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('-',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ),
              Expanded(
                child: TextField(
                  controller: seatCtrl,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                  decoration: _seatInputDecoration('号'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () {
                final floor = floorCtrl.text.trim();
                final row = rowCtrl.text.trim();
                final seat = seatCtrl.text.trim();
                final combined = '$floor-$row-$seat';
                setState(() {
                  _tickets[index] = ticket.copyWith(
                    seat: combined == '--' ? null : combined,
                  );
                  _hasChanges = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('确定',
                  style: TextStyle(
                      color: kBrandPurple, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _seatInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: const Color(0xFF181818),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBrandPurple, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  // ==================== 通用区块头部 ====================

  Widget _buildSectionHeader(String title, String count, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderInline(String title, String count, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          BreathingIcon(
            icon: icon,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 海报背景 ====================

  Widget _buildPosterBackground() {
    final hasCover =
        _show!.coverPath != null && _show!.coverPath!.isNotEmpty;

    if (hasCover) {
      return Image.file(
        File(_show!.coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientFallback(),
      );
    }
    return _buildGradientFallback();
  }

  Widget _buildGradientFallback() {
    return PosterFallback(
      showId: _show!.id ?? 0,
      showName: _show!.name,
      fontSize: 96,
    );
  }

  // ==================== 编辑对话框 ====================

  void _showEditDialog(
      String label, TextEditingController controller, ValueChanged<String> onChanged) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogController = TextEditingController(text: controller.text);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('输入$label',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            keyboardType: label.contains('价格') ||
                    label.contains('票面') ||
                    label.contains('实付')
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF181818),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBrandPurple, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () {
                controller.text = dialogController.text;
                onChanged(dialogController.text);
                Navigator.pop(ctx);
              },
              child: const Text('确定',
                  style: TextStyle(
                      color: kBrandPurple, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
