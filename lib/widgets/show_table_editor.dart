import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/actor.dart';
import '../models/performance.dart';
import '../models/ticket.dart';

/// 表格中一行场次的控制器集合
class PerformanceEntry {
  final TextEditingController dateController;
  final TextEditingController priceController;
  final TextEditingController actualPriceController;
  String time;

  /// 若该场次来自数据库，记录原始 Performance，用于保留 id/status/ticket 等元数据
  final Performance? existingPerformance;

  /// 当前关联的 ticket（管理页编辑用）
  Ticket? ticket;

  /// 当前状态（管理页状态循环用）
  String status;

  /// 当前场次是否已加入排期流
  bool isInScheduleFlow;

  PerformanceEntry({
    this.existingPerformance,
    this.ticket,
  })  : status = existingPerformance?.status ?? 'unmarked',
        isInScheduleFlow = existingPerformance?.isInScheduleFlow ?? false,
        dateController = TextEditingController(),
        priceController = TextEditingController(),
        actualPriceController = TextEditingController(),
        time = '19:30';

  void dispose() {
    dateController.dispose();
    priceController.dispose();
    actualPriceController.dispose();
  }
}

/// 表格中一列角色的控制器集合
class RoleColumn {
  final TextEditingController roleController;
  final List<TextEditingController> actorControllers;

  /// 与 [actorControllers] 一一对应，标记该场次该角色是否为Featured卡司
  final List<bool> isFeatured;

  RoleColumn()
      : roleController = TextEditingController(),
        actorControllers = [],
        isFeatured = [];

  void sync(int count) {
    while (actorControllers.length < count) {
      actorControllers.add(TextEditingController());
      isFeatured.add(false);
    }
    while (actorControllers.length > count) {
      final removed = actorControllers.removeLast();
      removed.dispose();
      isFeatured.removeLast();
    }
  }

  void dispose() {
    roleController.dispose();
    for (final c in actorControllers) {
      c.dispose();
    }
  }
}

/// 把数据库数据转成表格控制器结构的辅助类
class ShowTableData {
  final List<PerformanceEntry> performances;
  final List<RoleColumn> roles;

  ShowTableData({
    required this.performances,
    required this.roles,
  });

  static Future<ShowTableData> fromShowId(int showId) async {
    final db = DatabaseHelper.instance;
    final perfMaps = await db.getPerformancesWithTicketsByShowId(showId);

    final perfs = perfMaps.map((m) => Performance.fromMap(m)).toList();

    // 提取 ticket
    final ticketMap = <int, Ticket>{};
    for (final m in perfMaps) {
      final perfId = m['id'] as int?;
      if (perfId == null) continue;
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

    return fromPerformanceList(perfs, ticketMap: ticketMap);
  }

  static Future<ShowTableData> fromPerformanceList(
    List<Performance> perfs, {
    Map<int, Ticket>? ticketMap,
  }) async {
    final db = DatabaseHelper.instance;
    final entries = perfs.map((perf) {
      // 兼容旧数据：若未提供 ticketMap，从 Performance 的废弃字段构造 Ticket
      Ticket? ticket = ticketMap?[perf.id];
      ticket ??= (perf.price != null || perf.actualPrice != null || perf.seat != null)
          ? Ticket(
              performanceId: perf.id ?? 0,
              seat: perf.seat,
              price: perf.price,
              actualPrice: perf.actualPrice,
            )
          : null;
      final entry = PerformanceEntry(
        existingPerformance: perf,
        ticket: ticket,
      );
      entry.dateController.text = perf.date;
      entry.time = perf.time ?? '19:30';
      entry.status = perf.status ?? 'unmarked';
      entry.isInScheduleFlow = perf.isInScheduleFlow;
      entry.priceController.text = entry.ticket?.price?.toString() ?? '';
      entry.actualPriceController.text = entry.ticket?.actualPrice?.toString() ?? '';
      return entry;
    }).toList();

    // 加载卡司
    final roles = <RoleColumn>[];
    final roleNames = <String>[];
    final roleActorsByPerf = <String, List<String?>>{};
    final roleFeaturedByPerf = <String, List<bool>>{};

    for (var i = 0; i < perfs.length; i++) {
      final perf = perfs[i];
      if (perf.id == null) continue;
      final casts = await db.getCastMembersByPerformanceId(perf.id!);
      for (final cast in casts) {
        if (cast.role.isEmpty) continue;
        if (!roleNames.contains(cast.role)) {
          roleNames.add(cast.role);
          roleActorsByPerf[cast.role] = List.filled(perfs.length, null);
          roleFeaturedByPerf[cast.role] = List.filled(perfs.length, false);
        }
        roleActorsByPerf[cast.role]![i] = cast.actorName;
        roleFeaturedByPerf[cast.role]![i] = cast.isFeatured == true;
      }
    }

    for (final roleName in roleNames) {
      final role = RoleColumn();
      role.roleController.text = roleName;
      role.sync(perfs.length);
      final actors = roleActorsByPerf[roleName]!;
      final featured = roleFeaturedByPerf[roleName]!;
      for (var i = 0; i < actors.length; i++) {
        if (actors[i] != null) {
          role.actorControllers[i].text = actors[i]!;
          role.isFeatured[i] = featured[i];
        }
      }
      roles.add(role);
    }

    return ShowTableData(performances: entries, roles: roles);
  }
}

/// 共享的剧目场次表格编辑器
///
/// 用于 AddShowScreen（空表录入）和 ShowManagementScreen（已填表二次编辑）。
class ShowTableEditor extends StatefulWidget {
  final List<PerformanceEntry> performances;
  final List<RoleColumn> roles;
  final List<String> actorNames;

  final VoidCallback onAddPerformance;
  final ValueChanged<int>? onRemovePerformance;
  final VoidCallback onAddRole;
  final ValueChanged<int>? onRemoveRole;
  final Future<void> Function()? onLoadActorNames;

  /// 每行尾部的操作区，用于管理页放置状态、票、删除等按钮
  final Widget? Function(int perfIndex)? rowActionBuilder;

  const ShowTableEditor({
    super.key,
    required this.performances,
    required this.roles,
    required this.actorNames,
    required this.onAddPerformance,
    required this.onAddRole,
    this.onRemovePerformance,
    this.onRemoveRole,
    this.onLoadActorNames,
    this.rowActionBuilder,
  });

  @override
  State<ShowTableEditor> createState() => _ShowTableEditorState();
}

class _ShowTableEditorState extends State<ShowTableEditor> {
  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _pickDate(int perfIndex) async {
    final entry = widget.performances[perfIndex];
    DateTime initialDate = DateTime.now();
    if (entry.dateController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(entry.dateController.text);
      } catch (_) {}
    }

    DateTime? pickedDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                      const Text('选择日期', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (pickedDate != null) {
                            setState(() {
                              entry.dateController.text = _fullDateFormat.format(pickedDate!);
                            });
                          }
                        },
                        child: const Text('确定', style: TextStyle(color: Color(0xFF6B5BCD))),
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
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initialDate,
                      minimumDate: DateTime(2020),
                      maximumDate: DateTime(2030),
                      onDateTimeChanged: (date) {
                        pickedDate = date;
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
  }

  Future<void> _pickTime(int perfIndex) async {
    final entry = widget.performances[perfIndex];
    final parts = entry.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                      const Text('选择时间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确定', style: TextStyle(color: Color(0xFF6B5BCD))),
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
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: DateTime(2026, 1, 1, initialTime.hour, initialTime.minute),
                      use24hFormat: true,
                      onDateTimeChanged: (date) {
                        entry.time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

    if (mounted) setState(() {});
  }

  Future<void> _showActorPicker(int perfIndex, int roleIndex) async {
    final controller = widget.roles[roleIndex].actorControllers[perfIndex];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ActorPickerSheet(
        actorNames: widget.actorNames,
        initialValue: controller.text,
        onSelected: (value) => Navigator.pop(context, value),
        onActorAdded: (name) async {
          await DatabaseHelper.instance.createActor(Actor(name: name));
          await widget.onLoadActorNames?.call();
        },
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        controller.text = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const dateW = 64.0;
    const timeW = 54.0;
    const roleW = 100.0;
    const headerH = 36.0;
    const cellH = 44.0;
    const fixedW = dateW + timeW + 0.5;
    const dividerColor = Color(0xFF2A2A2A);
    const headerBg = Color(0xFF232323);

    if (widget.performances.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dividerColor, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 32,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 10),
              Text(
                '暂无排期场次',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '点击上方「添加场次」或「AI 识别」开始录入',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧固定：日期 + 时间 + 可选行操作
          Container(
            width: fixedW,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: dividerColor, width: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 固定表头
                Container(
                  height: headerH,
                  color: headerBg,
                  child: const Row(
                    children: [
                      SizedBox(
                        width: dateW,
                        child: Center(
                          child: Text('日期',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B80E0))),
                        ),
                      ),
                      SizedBox(
                        width: timeW,
                        child: Center(
                          child: Text('时间',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B80E0))),
                        ),
                      ),
                    ],
                  ),
                ),
                // 固定数据行
                ...widget.performances.asMap().entries.map((perfEntry) {
                  final pi = perfEntry.key;
                  final perf = perfEntry.value;
                  final dateText = perf.dateController.text.isNotEmpty
                      ? '${int.parse(perf.dateController.text.split('-')[1])}.${int.parse(perf.dateController.text.split('-')[2])}'
                      : '';

                  return Container(
                    height: cellH,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: dividerColor, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: dateW,
                          child: InkWell(
                            onTap: () => _pickDate(pi),
                            child: Center(
                              child: perf.dateController.text.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6B5BCD).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('选择',
                                      style: TextStyle(fontSize: 11, color: const Color(0xFF6B5BCD).withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                                  )
                                : Text(dateText,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: timeW,
                          child: InkWell(
                            onTap: () => _pickTime(pi),
                            child: Center(
                              child: Text(perf.time,
                                style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // 右侧滚动：角色列
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 滚动表头
                  Container(
                    height: headerH,
                    color: headerBg,
                    child: Row(
                      children: [
                        ...widget.roles.map((role) {
                          return SizedBox(
                            width: roleW,
                            child: Center(
                              child: TextField(
                                controller: role.roleController,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: '角色',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8B80E0),
                                  ),
                                  isDense: true,
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }),
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: GestureDetector(
                              onTap: widget.onAddRole,
                              child: Icon(Icons.add_circle_outline,
                                size: 16, color: const Color(0xFF6B5BCD).withValues(alpha: 0.85)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 滚动数据行
                  ...widget.performances.asMap().entries.map((perfEntry) {
                    final pi = perfEntry.key;
                    return Container(
                      height: cellH,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: dividerColor, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: widget.roles.asMap().entries.map((roleEntry) {
                          final roleCol = roleEntry.value;
                          return SizedBox(
                            width: roleW,
                            child: TextField(
                              controller: roleCol.actorControllers[pi],
                              textAlign: TextAlign.center,
                              readOnly: true,
                              onTap: () => _showActorPicker(pi, roleEntry.key),
                              decoration: InputDecoration(
                                hintText: '-',
                                isDense: true,
                                isCollapsed: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: roleCol.actorControllers[pi].text.isEmpty
                                    ? Colors.grey[600]
                                    : Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // 行操作区（管理页用）
          if (widget.rowActionBuilder != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: dividerColor, width: 0.5),
                ),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: headerH,
                      color: headerBg,
                      child: const SizedBox.shrink(),
                    ),
                    ...widget.performances.asMap().entries.map((entry) {
                      return Container(
                        height: cellH,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: dividerColor, width: 0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: widget.rowActionBuilder!(entry.key),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 演员选择底部弹窗
class ActorPickerSheet extends StatefulWidget {
  final List<String> actorNames;
  final String initialValue;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onActorAdded;

  const ActorPickerSheet({
    super.key,
    required this.actorNames,
    required this.initialValue,
    required this.onSelected,
    this.onActorAdded,
  });

  @override
  State<ActorPickerSheet> createState() => _ActorPickerSheetState();
}

class _ActorPickerSheetState extends State<ActorPickerSheet> {
  late final TextEditingController _searchController;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialValue);
    _filtered = widget.actorNames;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchText = _searchController.text.trim();
    final isNotInList = searchText.isNotEmpty &&
        !widget.actorNames.any((n) => n == searchText);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4D4D4D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('选择演员',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() {
                  _filtered = widget.actorNames
                      .where((n) => n.toLowerCase().contains(v.toLowerCase()))
                      .toList();
                }),
                decoration: const InputDecoration(
                  hintText: '搜索演员...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    dense: true,
                    title: Text(_filtered[i]),
                    onTap: () => widget.onSelected(_filtered[i]),
                  );
                },
              ),
            ),
            if (_filtered.isEmpty && !isNotInList)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('无匹配演员',
                    style: TextStyle(color: Color(0xFF8A8F98))),
              ),
            if (isNotInList && widget.onActorAdded != null) ...[
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, color: Color(0xFF6B5BCD)),
                title: Text('添加 "$searchText" 为新演员'),
                onTap: () {
                  widget.onActorAdded!(searchText);
                  widget.onSelected(searchText);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
