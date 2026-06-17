import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';
import '../utils/status_colors.dart';
import '../widgets/status_badge.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/bought_form_sheet.dart';

/// 剧目管理页
/// 展示单个剧目的详细信息、所有场次列表，支持编辑和删除
class ShowManagementScreen extends StatefulWidget {
  final int showId;

  const ShowManagementScreen({
    super.key,
    required this.showId,
  });

  @override
  State<ShowManagementScreen> createState() => _ShowManagementScreenState();
}

class _ShowManagementScreenState extends State<ShowManagementScreen> {
  bool _isLoading = true;
  Show? _show;
  List<Performance> _performances = [];
  Map<int, List<CastMember>> _castMap = {};
  Map<int, Ticket> _ticketMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;

    final show = await db.getShowById(widget.showId);
    final perfMaps = await db.getPerformancesWithTicketsByShowId(widget.showId);
    final perfs = perfMaps.map((m) => Performance.fromMap(m)).toList();

    // 从 JOIN 结果中提取每个演出的首条 ticket
    final ticketMap = <int, Ticket>{};
    for (final m in perfMaps) {
      final perfId = m['id'] as int;
      final ticketId = m['ticket_id'] as int?;
      if (ticketId != null) {
        ticketMap[perfId] = Ticket(
          id: ticketId,
          performanceId: perfId,
          seat: m['ticket_seat'] as String?,
          price: m['ticket_price'] != null
              ? (m['ticket_price'] as num).toDouble()
              : null,
          actualPrice: m['ticket_actual_price'] != null
              ? (m['ticket_actual_price'] as num).toDouble()
              : null,
        );
      }
    }

    // Batch load casts for all performances
    final perfIds = perfs.map((p) => p.id!).toList();
    final castMap = await db.getCastMembersByPerformanceIds(perfIds);

    if (mounted) {
      setState(() {
        _show = show;
        _performances = perfs;
        _castMap = castMap;
        _ticketMap = ticketMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确认删除',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '删除「${_show?.name ?? '该剧目'}」将同时删除所有场次和卡司数据，此操作不可恢复。',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8A8F98))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFF54A45))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = DatabaseHelper.instance;
    await db.deleteShow(widget.showId);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _toggleScheduleFlow() async {
    if (_show == null) return;
    final db = DatabaseHelper.instance;
    final updated = _show!.copyWith(isInScheduleFlow: !_show!.isInScheduleFlow);
    await db.updateShow(updated);
    setState(() => _show = updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isInScheduleFlow
                ? '已加入排期流，场次将显示在排期页和月历中'
                : '已移出排期流，场次不再显示在排期页和月历中',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editShowInfo() async {
    if (_show == null) return;
    final nameController = TextEditingController(text: _show!.name);
    final theaterController = TextEditingController(text: _show!.theater ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4D4D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '编辑剧目信息',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: nameController,
                    decoration: _inputDecoration('剧目名称'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: theaterController,
                    decoration: _inputDecoration('演出剧场'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      final db = DatabaseHelper.instance;
      final updated = _show!.copyWith(
        name: nameController.text.trim(),
        theater: theaterController.text.trim().isNotEmpty
            ? theaterController.text.trim()
            : null,
      );
      await db.updateShow(updated);
      nameController.dispose();
      theaterController.dispose();
      if (mounted) {
        _loadData();
        Navigator.pop(context, true);
      }
    } else {
      nameController.dispose();
      theaterController.dispose();
    }
  }

  Future<void> _addPerformance() async {
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4D4D4D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      '添加场次',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    // Date picker
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF8A8F98)),
                      title: Text(
                        pickedDate != null
                            ? '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}'
                            : '选择日期',
                        style: TextStyle(
                          color: pickedDate != null ? Colors.white : const Color(0xFF8A8F98),
                        ),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: kBrandPurple,
                                surface: Color(0xFF1E1E1E),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date != null) {
                          setModalState(() => pickedDate = date);
                        }
                      },
                    ),
                    // Time picker
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF8A8F98)),
                      title: Text(
                        pickedTime != null
                            ? '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}'
                            : '选择时间',
                        style: TextStyle(
                          color: pickedTime != null ? Colors.white : const Color(0xFF8A8F98),
                        ),
                      ),
                      onTap: () async {
                        final time = await showModalBottomSheet<TimeOfDay>(
                          context: context,
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) {
                            TimeOfDay selected = TimeOfDay.now();
                            return SafeArea(
                              child: SizedBox(
                                height: 320,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('取消', style: TextStyle(color: Color(0xFF8A8F98))),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, selected),
                                            child: const Text('确定', style: TextStyle(color: kBrandPurple)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                                    Expanded(
                                      child: CupertinoTheme(
                                        data: const CupertinoThemeData(
                                          brightness: Brightness.dark,
                                          textTheme: CupertinoTextThemeData(
                                            dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 18),
                                          ),
                                        ),
                                        child: CupertinoDatePicker(
                                          mode: CupertinoDatePickerMode.time,
                                          initialDateTime: DateTime(2026, 1, 1, 19, 30),
                                          use24hFormat: true,
                                          onDateTimeChanged: (date) {
                                            selected = TimeOfDay.fromDateTime(date);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                        if (time != null) {
                          setModalState(() => pickedTime = time);
                        }
                      },
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: pickedDate != null && pickedTime != null
                              ? () => Navigator.pop(context, true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrandPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: kBrandPurple.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('添加'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && pickedDate != null && pickedTime != null && mounted) {
      final db = DatabaseHelper.instance;
      final dateStr = '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
      final timeStr = '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}';

      await db.createPerformance(Performance(
        showId: widget.showId,
        date: dateStr,
        time: timeStr,
        status: 'unmarked',
        createdAt: DateTime.now().toIso8601String(),
      ));

      if (mounted) {
        _loadData();
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _editPerformance(Performance perf) async {
    final ticket = _ticketMap[perf.id];
    final seatController = TextEditingController(text: ticket?.seat ?? '');
    final priceController = TextEditingController(
        text: ticket?.price?.toString() ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4D4D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '${perf.date} ${perf.time ?? ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: seatController,
                    decoration: _inputDecoration('座位'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: priceController,
                    decoration: _inputDecoration('票价'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      final db = DatabaseHelper.instance;
      final seat = seatController.text.trim().isNotEmpty ? seatController.text.trim() : null;
      final price = double.tryParse(priceController.text.trim());

      if (ticket != null) {
        await db.updateTicket(ticket.copyWith(seat: seat, price: price));
      } else {
        await db.createTicket(Ticket(
          performanceId: perf.id!,
          seat: seat,
          price: price,
        ));
      }

      seatController.dispose();
      priceController.dispose();
      if (mounted) {
        _loadData();
        Navigator.pop(context, true);
      }
    } else {
      seatController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _deletePerformance(Performance perf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确认删除场次',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '删除 ${perf.date} ${perf.time ?? ''} 的场次？',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8A8F98))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFF54A45))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = DatabaseHelper.instance;
      await db.deletePerformance(perf.id!);
      if (mounted) {
        _loadData();
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _cycleStatus(Performance perf) async {
    final next = switch (perf.status) {
      'watched' => 'unmarked',
      'bought' => 'watched',
      'want_to_see' => 'bought',
      _ => 'want_to_see',
    };

    if (next == 'bought') {
      final ticket = await showBoughtFormSheet(context, performanceId: perf.id!);
      final db = DatabaseHelper.instance;
      await db.updatePerformance(perf.copyWith(status: 'bought'));
      if (ticket != null) {
        await db.createTicket(ticket);
      }
      if (mounted) {
        _loadData();
        Navigator.pop(context, true);
      }
      return;
    }

    final db = DatabaseHelper.instance;
    await db.updatePerformance(perf.copyWith(status: next));
    if (mounted) {
      _loadData();
      Navigator.pop(context, true);
    }
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'bought' => '已买',
      'want_to_see' => '想看',
      'watched' => '已观演',
      _ => '未标记',
    };
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBrandPurple, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _show?.name ?? '剧目管理',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            onSelected: (value) {
              if (value == 'edit') _editShowInfo();
              if (value == 'delete') _deleteShow();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('编辑信息', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Color(0xFFF54A45), size: 18),
                    SizedBox(width: 8),
                    Text('删除剧目', style: TextStyle(color: Color(0xFFF54A45))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B5BCD)))
          : _show == null
              ? const Center(
                  child: BreathingIcon(
                    icon: Icons.error_outline,
                    size: 64,
                    color: Color(0xFF4D4D4D),
                  ),
                )
              : _buildBody(),
      floatingActionButton: !_isLoading && _show != null
          ? FloatingActionButton.extended(
              onPressed: _addPerformance,
              backgroundColor: kBrandPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('添加场次', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top section: poster + show info
        _buildHeaderSection(),
        const SizedBox(height: 20),

        // Schedule flow action card (core action)
        _buildScheduleFlowCard(),
        const SizedBox(height: 28),

        // Performance list section
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: kBrandPurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '场次列表',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const Spacer(),
            Text(
              '${_performances.length} 场',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._performances.asMap().entries.map((entry) {
          return _buildPerformanceItem(entry.value, entry.key);
        }),
      ],
    );
  }

  Widget _buildHeaderSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = screenWidth * 0.28;
    final posterHeight = posterWidth * 4 / 3;
    final color = coverColorForShow(_show!.id ?? 0);
    final coverPath = _show!.coverPath;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large poster
        Container(
          width: posterWidth,
          height: posterHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color,
            gradient: coverPath == null || coverPath.isEmpty
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.6)],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: coverPath != null && coverPath.isNotEmpty
              ? Image.file(File(coverPath), fit: BoxFit.cover)
              : Center(
                  child: Text(
                    _show!.name.length >= 2
                        ? _show!.name.substring(0, 2)
                        : _show!.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: posterWidth * 0.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        // Show info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _show!.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (_show!.theater != null && _show!.theater!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF8A8F98)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _show!.theater!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A8F98),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              // Edit icon
              GestureDetector(
                onTap: _editShowInfo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Color(0xFF8A8F98)),
                      SizedBox(width: 4),
                      Text(
                        '编辑',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8A8F98)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleFlowCard() {
    final isInFlow = _show!.isInScheduleFlow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInFlow
            ? const Color(0xFF34D399).withValues(alpha: 0.08)
            : kBrandPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInFlow
              ? const Color(0xFF34D399).withValues(alpha: 0.35)
              : kBrandPurple.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isInFlow ? const Color(0xFF34D399) : kBrandPurple)
                .withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInFlow ? Icons.check_circle : Icons.schedule,
                color: isInFlow ? const Color(0xFF34D399) : kBrandPurple,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInFlow ? '已在排期流' : '未加入排期流',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isInFlow
                            ? const Color(0xFF34D399)
                            : kBrandPurple,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInFlow
                          ? '该剧目及 ${_performances.length} 个场次会显示在排期页和月历中'
                          : '加入排期流后，该剧目及所有场次将显示在排期页和月历中',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleScheduleFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: isInFlow
                    ? const Color(0xFF34D399).withValues(alpha: 0.15)
                    : kBrandPurple,
                foregroundColor: isInFlow
                    ? const Color(0xFF34D399)
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isInFlow
                        ? const Color(0xFF34D399).withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
              ),
              icon: Icon(
                isInFlow ? Icons.remove_circle_outline : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(
                isInFlow ? '移出排期流' : '加入排期流',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(Performance perf, int index) {
    final date = perf.date;
    final time = perf.time?.substring(0, 5) ?? '';
    final status = perf.status ?? 'unmarked';
    final color = statusColor(status);
    final casts = _castMap[perf.id] ?? [];
    final ticket = _ticketMap[perf.id];
    final seat = ticket?.seat;
    final price = ticket?.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: () => _editPerformance(perf),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Date + time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Status badge (tappable to cycle)
                  StatusBadge(
                    label: _statusLabel(status),
                    color: color,
                    onTap: () => _cycleStatus(perf),
                  ),
                  const SizedBox(width: 8),
                  // Delete action
                  GestureDetector(
                    onTap: () => _deletePerformance(perf),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              // Seat + price info
              if ((seat != null && seat.isNotEmpty) || price != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (seat != null && seat.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_seat, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              seat,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      if (seat != null && seat.isNotEmpty && price != null)
                        Container(
                          width: 1,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      if (price != null)
                        Text(
                          '¥${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              // Cast preview (first 3 roles)
              if (casts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: casts.take(3).map((cast) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${cast.role}: ${cast.actorName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
