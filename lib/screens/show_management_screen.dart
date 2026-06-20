import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../models/ticket.dart';
import '../utils/status_colors.dart';
import '../utils/cover_helper.dart';
import '../widgets/breathing_icon.dart';
import '../widgets/bought_form_sheet.dart';
import '../widgets/show_header_editor.dart';
import '../widgets/show_table_editor.dart';

/// 剧目管理页
/// 展示单个剧目的详细信息、所有场次列表，支持与添加页同一张表格进行二次编辑。
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
  bool _isSaving = false;
  Show? _show;

  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();
  final List<PerformanceEntry> _performances = [];
  final List<RoleColumn> _roles = [];
  List<String> _actorNames = [];
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActorNames();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    for (final p in _performances) { p.dispose(); }
    for (final r in _roles) { r.dispose(); }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;

    final show = await db.getShowById(widget.showId);
    final data = await ShowTableData.fromShowId(widget.showId);

    _nameController.text = show?.name ?? '';
    _theaterController.text = show?.theater ?? '';
    _coverPath = show?.coverPath;

    _performances.clear();
    _roles.clear();
    _performances.addAll(data.performances);
    _roles.addAll(data.roles);

    if (_performances.isEmpty) {
      _performances.add(PerformanceEntry());
    }
    if (_roles.isEmpty) {
      _roles.add(RoleColumn()..sync(_performances.length));
    }

    if (mounted) {
      setState(() {
        _show = show;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActorNames() async {
    final actors = await DatabaseHelper.instance.getAllActors();
    if (mounted) {
      setState(() {
        _actorNames = actors.map((a) => a.name).toList();
      });
    }
  }

  void _addPerformance() {
    setState(() {
      _performances.add(PerformanceEntry());
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _removePerformance(int index) {
    setState(() {
      final removed = _performances.removeAt(index);
      removed.dispose();
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _addRole() {
    setState(() {
      final role = RoleColumn();
      role.sync(_performances.length);
      _roles.add(role);
    });
  }

  void _removeRole(int index) {
    setState(() {
      _roles[index].dispose();
      _roles.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_show == null) return;
    if (_performances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少保留一场演出')));
      return;
    }
    for (int i = 0; i < _performances.length; i++) {
      if (_performances[i].dateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请填写第${i + 1}场的日期')));
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final db = DatabaseHelper.instance;
      final showName = _nameController.text.trim();
      final theater = _theaterController.text.trim().isNotEmpty
          ? _theaterController.text.trim() : null;

      // 海报改名联动
      String? finalCoverPath = _coverPath;
      final oldName = _show!.name;
      if (oldName != showName && _coverPath != null && _coverPath!.isNotEmpty) {
        finalCoverPath = await CoverHelper.renameCoverImage(_coverPath, showName);
      }

      // 更新剧目信息
      final updatedShow = _show!.copyWith(
        name: showName,
        theater: theater,
        coverPath: finalCoverPath,
      );
      await db.updateShow(updatedShow);

      // 事务替换所有 performances
      final perfDataList = <Map<String, dynamic>>[];
      for (int pi = 0; pi < _performances.length; pi++) {
        final perfEntry = _performances[pi];
        final casts = <CastMember>[];
        for (final role in _roles) {
          final roleName = role.roleController.text.trim();
          final actorName = role.actorControllers[pi].text.trim();
          if (roleName.isNotEmpty && actorName.isNotEmpty) {
            casts.add(CastMember(
              performanceId: 0,
              role: roleName,
              actorName: actorName,
              isFeatured: false,
              createdAt: DateTime.now().toIso8601String(),
            ));
          }
        }
        perfDataList.add({
          'performance': Performance(
            showId: widget.showId,
            date: perfEntry.dateController.text,
            time: perfEntry.time,
            status: perfEntry.status,
            isInScheduleFlow: perfEntry.isInScheduleFlow,
            createdAt: DateTime.now().toIso8601String(),
          ),
          'casts': casts,
          'ticket': _buildTicketFromPerfEntry(perfEntry),
        });
      }
      await db.replaceAllPerformances(widget.showId, perfDataList);

      // 创建演员记录
      for (final role in _roles) {
        for (int pi = 0; pi < _performances.length; pi++) {
          final actorName = role.actorControllers[pi].text.trim();
          if (actorName.isNotEmpty) {
            try {
              await db.createActor(Actor(
                name: actorName,
                createdAt: DateTime.now().toIso8601String(),
              ));
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剧目更新成功！')));
        setState(() => _isSaving = false);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  Ticket? _buildTicketFromPerfEntry(PerformanceEntry perfEntry) {
    final price = double.tryParse(perfEntry.priceController.text.trim());
    final actualPrice = double.tryParse(perfEntry.actualPriceController.text.trim());
    if (price == null && actualPrice == null && perfEntry.ticket?.seat == null) {
      return null;
    }
    return Ticket(
      performanceId: 0,
      seat: perfEntry.ticket?.seat,
      price: price,
      actualPrice: actualPrice,
    );
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

  Future<void> _cycleStatus(int perfIndex) async {
    final entry = _performances[perfIndex];
    final currentStatus = entry.status;
    final next = switch (currentStatus) {
      'watched' => 'unmarked',
      'bought' => 'watched',
      'want_to_see' => 'bought',
      _ => 'want_to_see',
    };

    if (next == 'bought') {
      final perfId = entry.existingPerformance?.id;
      final ticket = perfId != null
          ? await showBoughtFormSheet(context, performanceId: perfId)
          : null;
      _applyStatus(perfIndex, 'bought', ticket: ticket);
      return;
    }

    _applyStatus(perfIndex, next);
  }

  /// 统一设置状态并同步排期流：非未标记自动加入，未标记自动移出
  void _applyStatus(int perfIndex, String status, {Ticket? ticket}) {
    final entry = _performances[perfIndex];
    setState(() {
      entry.status = status;
      entry.isInScheduleFlow = status != 'unmarked';
      if (ticket != null) {
        entry.ticket = ticket;
      }
    });
  }

  Future<void> _editTicket(int perfIndex) async {
    final entry = _performances[perfIndex];
    final seatController = TextEditingController(text: entry.ticket?.seat ?? '');
    final priceController = TextEditingController(
        text: entry.ticket?.price?.toString() ?? '');
    final actualPriceController = TextEditingController(
        text: entry.ticket?.actualPrice?.toString() ?? '');

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
                  '${entry.dateController.text} ${entry.time}',
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
                    decoration: _inputDecoration('票面价'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: actualPriceController,
                    decoration: _inputDecoration('实付价'),
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
      setState(() {
        entry.ticket = Ticket(
          performanceId: entry.existingPerformance?.id ?? 0,
          seat: seatController.text.trim().isNotEmpty ? seatController.text.trim() : null,
          price: double.tryParse(priceController.text.trim()),
          actualPrice: double.tryParse(actualPriceController.text.trim()),
        );
      });
    }

    seatController.dispose();
    priceController.dispose();
    actualPriceController.dispose();
  }

  Future<void> _confirmDeletePerformance(int perfIndex) async {
    final entry = _performances[perfIndex];
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
          '删除 ${entry.dateController.text} ${entry.time} 的场次？',
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
      _removePerformance(perfIndex);
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
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          _show?.name ?? '剧目管理',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              style: TextButton.styleFrom(
                foregroundColor: kBrandPurple,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('保存'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            onSelected: (value) {
              if (value == 'delete') _deleteShow();
            },
            itemBuilder: (context) => [
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
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // 头部：海报 + 剧名 + 剧场（直接可编辑）
        ShowHeaderEditor(
          nameController: _nameController,
          theaterController: _theaterController,
          coverPath: _coverPath,
          show: _show,
          onCoverChanged: (path) => setState(() => _coverPath = path),
        ),
        const SizedBox(height: 20),

        // 排期流操作卡片
        _buildScheduleFlowCard(),
        const SizedBox(height: 28),

        // 排期场次标题
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
            TextButton.icon(
              onPressed: _addPerformance,
              icon: const Icon(Icons.add, size: 16, color: kBrandPurple),
              label: const Text('添加场次', style: TextStyle(color: kBrandPurple)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 表格
        ShowTableEditor(
          performances: _performances,
          roles: _roles,
          actorNames: _actorNames,
          onAddPerformance: _addPerformance,
          onRemovePerformance: _removePerformance,
          onAddRole: _addRole,
          onRemoveRole: _removeRole,
          onLoadActorNames: _loadActorNames,
          rowActionBuilder: _buildRowActions,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showRowActionMenu(int perfIndex, Offset globalPosition) async {
    final entry = _performances[perfIndex];
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      color: const Color(0xFF1E1E1E),
      items: [
        PopupMenuItem(
          value: 'toggle_schedule_flow',
          child: Row(
            children: [
              Icon(
                entry.isInScheduleFlow ? Icons.remove_circle_outline : Icons.add_circle_outline,
                size: 18,
                color: entry.isInScheduleFlow ? Colors.orange : kBrandPurple,
              ),
              const SizedBox(width: 10),
              Text(
                entry.isInScheduleFlow ? '移出排期流' : '加入排期流',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'want_to_see',
          child: Row(
            children: [
              Icon(Icons.star, size: 18, color: Color(0xFF811FE2)),
              SizedBox(width: 10),
              Text('标记为想看', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'bought',
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Color(0xFF34D399)),
              SizedBox(width: 10),
              Text('标记为已买', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'watched',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: Color(0xFFD4A853)),
              SizedBox(width: 10),
              Text('标记为已观演', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'unmarked',
          child: Row(
            children: [
              Icon(Icons.circle_outlined, size: 18, color: Color(0xFF9CA3AF)),
              SizedBox(width: 10),
              Text('标记为未标记', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'ticket',
          child: Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: entry.ticket != null ? kBrandPurple : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                entry.ticket != null ? '编辑票务' : '添加票务',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Color(0xFFF54A45)),
              SizedBox(width: 10),
              Text('删除场次', style: TextStyle(color: Color(0xFFF54A45))),
            ],
          ),
        ),
      ],
    );

    switch (value) {
      case 'toggle_schedule_flow':
        setState(() => entry.isInScheduleFlow = !entry.isInScheduleFlow);
        break;
      case 'want_to_see':
        if (entry.status != 'want_to_see') {
          _applyStatus(perfIndex, 'want_to_see');
        }
        break;
      case 'bought':
        if (entry.status != 'bought') {
          _cycleStatus(perfIndex);
        }
        break;
      case 'watched':
        if (entry.status != 'watched') {
          if (entry.status == 'bought') {
            _cycleStatus(perfIndex);
          } else {
            _applyStatus(perfIndex, 'watched');
          }
        }
        break;
      case 'unmarked':
        _applyStatus(perfIndex, 'unmarked');
        break;
      case 'ticket':
        _editTicket(perfIndex);
        break;
      case 'delete':
        _confirmDeletePerformance(perfIndex);
        break;
    }
  }

  Widget _buildRowActions(int perfIndex) {
    final entry = _performances[perfIndex];
    final statusColor = statusColorForLabel(entry.status);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _showRowActionMenu(perfIndex, details.globalPosition),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(entry.status),
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: statusColor,
            ),
          ],
        ),
      ),
    );
  }

  Color statusColorForLabel(String? status) {
    return switch (status) {
      'bought' => const Color(0xFF34D399),
      'want_to_see' => const Color(0xFF811FE2),
      'watched' => const Color(0xFFD4A853),
      _ => const Color(0xFF9CA3AF),
    };
  }

  Widget _buildScheduleFlowCard() {
    final total = _performances.length;
    final flowCount = _performances.where((p) => p.isInScheduleFlow).length;
    final isAllInFlow = total > 0 && flowCount == total;
    final isAllOutFlow = flowCount == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandPurple.withValues(alpha: flowCount > 0 ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kBrandPurple.withValues(alpha: flowCount > 0 ? 0.45 : 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kBrandPurple.withValues(alpha: 0.1),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kBrandPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  flowCount > 0 ? Icons.check_circle : Icons.schedule_outlined,
                  color: kBrandPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flowCount > 0 ? '排期中 $flowCount/$total场' : '待排期 0/$total场',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: flowCount > 0 ? kBrandPurple : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '加入排期流的场次会显示在排期页和月历中',
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isAllInFlow ? null : () {
                    setState(() {
                      for (final p in _performances) {
                        p.isInScheduleFlow = true;
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text(
                    '全部加入',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isAllOutFlow ? null : () {
                    setState(() {
                      for (final p in _performances) {
                        p.isInScheduleFlow = false;
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: kBrandPurple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: kBrandPurple.withValues(alpha: 0.4)),
                    ),
                  ),
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text(
                    '全部移出',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
