import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../utils/ocr_service.dart';
import '../utils/knowledge_base.dart';

class AddShowScreen extends StatefulWidget {
  const AddShowScreen({super.key});

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _PerformanceEntry {
  TextEditingController dateController;
  String time;

  _PerformanceEntry()
      : dateController = TextEditingController(),
        time = '19:30';
}

class _RoleColumn {
  TextEditingController roleController;
  bool isFeatured;
  List<TextEditingController> actorControllers;

  _RoleColumn()
      : roleController = TextEditingController(),
        isFeatured = false,
        actorControllers = [];

  void sync(int count) {
    while (actorControllers.length < count) {
      actorControllers.add(TextEditingController());
    }
    while (actorControllers.length > count) {
      final removed = actorControllers.removeLast();
      removed.dispose();
    }
  }

  void dispose() {
    roleController.dispose();
    for (final c in actorControllers) {
      c.dispose();
    }
  }
}

class _AddShowScreenState extends State<AddShowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _theaterController = TextEditingController();
  final List<_PerformanceEntry> _performances = [];
  final List<_RoleColumn> _roles = [];
  final DateFormat _fullDateFormat = DateFormat('yyyy-MM-dd');

  bool _isSaving = false;
  bool _isRecognizing = false;
  List<CastEntry>? _lastOcrRawResult;
  List<String> _actorNames = [];

  static const List<String> _timePresets = ['14:00', '14:30', '19:00', '19:30'];

  @override
  void initState() {
    super.initState();
    _addPerformance();
    _addRole();
    _loadActorNames();
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
      _performances.add(_PerformanceEntry());
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _removePerformance(int index) {
    setState(() {
      _performances.removeAt(index);
      for (final role in _roles) {
        role.sync(_performances.length);
      }
    });
  }

  void _addRole() {
    setState(() {
      final role = _RoleColumn();
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

  Future<void> _pickDate(int perfIndex) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _performances[perfIndex].dateController.text = _fullDateFormat.format(picked);
      });
    }
  }

  Future<void> _pickTime(int perfIndex) async {
    final entry = _performances[perfIndex];
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('选择开场时间', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  ..._timePresets.map((t) => ActionChip(
                    label: Text(t),
                    onPressed: () => Navigator.pop(context, t),
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: const Text('自定义'),
                    onPressed: () async {
                      final parts = entry.time.split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null && context.mounted) {
                        Navigator.pop(context,
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => entry.time = result);
    }
  }

  // ==================== OCR ====================

  Future<void> _pickImageAndRecognize() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isRecognizing = true);
    try {
      final bytes = await picked.readAsBytes();
      String text;
      try {
        text = await recognizeTextAuto(bytes);
      } on BaiduOcrException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('百度 OCR 失败: $e，请检查配置')),
          );
        }
        return;
      }

      if (text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未识别到文字，请尝试更清晰的图片')),
          );
        }
        return;
      }

      if (mounted) {

        if (isScheduleFormat(text)) {
          final schedule = parseSchedule(text);
          if (schedule.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未解析到排期信息')),
              );
            }
            return;
          }
          if (schedule.isNotEmpty) {
            _lastOcrRawResult = schedule.first.castList;
          }
          final correctedSchedule = await _correctSchedule(schedule);
          _fillScheduleToForm(correctedSchedule);
        } else {
          final castList = parseCastText(text);
          if (castList.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未识别到卡司信息，请尝试手动输入')),
              );
            }
            return;
          }
          _lastOcrRawResult = castList;
          final corrected = await correctOcrResult(
            showName: null,
            theater: null,
            castList: castList,
          );
          final castEntries = corrected.castList
              .map((c) => CastEntry(c.role, c.actor))
              .toList();
          _fillCastListToForm(castEntries);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<List<ScheduleEntry>> _correctSchedule(List<ScheduleEntry> schedule) async {
    final corrected = <ScheduleEntry>[];
    for (final entry in schedule) {
      final result = await correctOcrResult(
        showName: null,
        theater: null,
        castList: entry.castList,
      );
      corrected.add(ScheduleEntry(
        date: entry.date,
        time: entry.time,
        castList: result.castList.map((c) => CastEntry(c.role, c.actor)).toList(),
      ));
    }
    return corrected;
  }

  void _fillCastListToForm(List<CastEntry> castList) {
    final oldRoles = List<_RoleColumn>.from(_roles);
    setState(() {
      _roles.clear();
      for (final entry in castList) {
        final role = _RoleColumn();
        role.roleController.text = entry.role;
        role.sync(_performances.length);
        if (_performances.isNotEmpty) {
          role.actorControllers[0].text = entry.actor;
        }
        _roles.add(role);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final r in oldRoles) { r.dispose(); }
    });
  }

  void _fillScheduleToForm(List<ScheduleEntry> schedule) {
    final oldPerformances = List<_PerformanceEntry>.from(_performances);
    final oldRoles = List<_RoleColumn>.from(_roles);
    setState(() {
      _performances.clear();
      _roles.clear();

      if (schedule.isNotEmpty) {
        final firstEntry = schedule.first;
        for (final cast in firstEntry.castList) {
          final role = _RoleColumn();
          role.roleController.text = cast.role;
          role.sync(schedule.length);
          _roles.add(role);
        }

        for (var i = 0; i < schedule.length; i++) {
          final entry = schedule[i];
          final perf = _PerformanceEntry();
          perf.dateController.text = entry.date;
          perf.time = entry.time;
          _performances.add(perf);

          for (var j = 0; j < entry.castList.length && j < _roles.length; j++) {
            _roles[j].actorControllers[i].text = entry.castList[j].actor;
          }
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in oldPerformances) { p.dateController.dispose(); }
      for (final r in oldRoles) { r.dispose(); }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已填充 ${schedule.length} 场演出，${schedule.first.castList.length} 个角色')),
    );
  }

  Future<void> _saveShow() async {
    if (!_formKey.currentState!.validate()) return;
    if (_performances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一场演出')));
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
      final show = await db.createShow(Show(
        name: _nameController.text.trim(),
        theater: _theaterController.text.trim().isNotEmpty
            ? _theaterController.text.trim() : null,
        createdAt: DateTime.now().toIso8601String(),
      ));

      for (int pi = 0; pi < _performances.length; pi++) {
        final perfEntry = _performances[pi];
        final performance = await db.createPerformance(Performance(
          showId: show.id!,
          date: perfEntry.dateController.text,
          time: perfEntry.time,
          status: 'unmarked',
          createdAt: DateTime.now().toIso8601String(),
        ));
        for (final role in _roles) {
          final roleName = role.roleController.text.trim();
          final actorName = role.actorControllers[pi].text.trim();
          if (roleName.isNotEmpty && actorName.isNotEmpty) {
            await db.createCastMember(CastMember(
              performanceId: performance.id!,
              role: roleName,
              actorName: actorName,
              isFeatured: role.isFeatured,
              createdAt: DateTime.now().toIso8601String(),
            ));
          }
        }
      }
      // 保存到知识库（如果数据来自OCR识别）
      if (_lastOcrRawResult != null && _roles.isNotEmpty && _performances.isNotEmpty) {
        final finalCastList = <CastEntry>[];
        for (final role in _roles) {
          final roleName = role.roleController.text.trim();
          final actorName = role.actorControllers[0].text.trim();
          if (roleName.isNotEmpty && actorName.isNotEmpty) {
            finalCastList.add(CastEntry(roleName, actorName));
          }
        }
        await saveToKnowledgeBase(
          showName: _nameController.text.trim(),
          theater: _theaterController.text.trim().isNotEmpty
              ? _theaterController.text.trim() : null,
          castList: finalCastList,
          originalCastList: _lastOcrRawResult,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剧目添加成功！')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theaterController.dispose();
    for (final p in _performances) { p.dateController.dispose(); }
    for (final r in _roles) { r.dispose(); }
    super.dispose();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('添加剧目'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _saveShow, child: const Text('保存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 剧目 + 剧场
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '剧目名称',
                      hintText: '如：春逝',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _theaterController,
                    decoration: const InputDecoration(
                      labelText: '演出地点',
                      hintText: '如：国家话剧院',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 表格
            _buildTable(),

            const SizedBox(height: 16),
            // 添加场次按钮
            OutlinedButton.icon(
              onPressed: _addPerformance,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加场次'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            // OCR识别按钮
            ElevatedButton.icon(
              onPressed: _isRecognizing ? null : _pickImageAndRecognize,
              icon: _isRecognizing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt, size: 18),
              label: Text(_isRecognizing ? '识别中...' : '图片识别卡司'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5BCD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _showActorPicker(int perfIndex, int roleIndex) async {
    final controller = _roles[roleIndex].actorControllers[perfIndex];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ActorPickerSheet(
        actorNames: _actorNames,
        initialValue: controller.text,
        onSelected: (value) => Navigator.pop(context, value),
        onActorAdded: (name) async {
          await DatabaseHelper.instance.createActor(Actor(name: name));
          await _loadActorNames();
        },
      ),
    );
    if (selected != null && mounted) {
      controller.text = selected;
    }
  }

  Widget _buildTable() {
    const actionW = 36.0;
    const dateW = 80.0;
    const timeW = 56.0;
    const roleW = 90.0;
    const cellH = 44.0;
    const headerH = 84.0;

    final borderSide = BorderSide(color: Colors.grey[300]!);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // 表头
            Container(
              height: headerH,
              decoration: BoxDecoration(color: Colors.grey[50]),
              child: Row(
                children: [
                  // 删除列
                  Container(width: actionW, height: headerH,
                    decoration: BoxDecoration(border: Border(right: borderSide)),
                  ),
                  // 日期列
                  Container(width: dateW, height: headerH,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(right: borderSide)),
                    child: const Text('日期', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  // 时间列
                  Container(width: timeW, height: headerH,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(right: borderSide)),
                    child: const Text('时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  // 角色列（可滚动）
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._roles.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final role = entry.value;
                            return Container(
                              width: roleW,
                              height: headerH,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(border: Border(right: borderSide)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextField(
                                    controller: role.roleController,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      hintText: '角色',
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                                    ),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Checkbox(
                                          value: role.isFeatured,
                                          onChanged: (v) => setState(() => role.isFeatured = v ?? false),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => role.isFeatured = !role.isFeatured),
                                        child: const Text('★', style: TextStyle(fontSize: 12, color: Color(0xFF811FE2))),
                                      ),
                                      if (_roles.length > 1)
                                        IconButton(
                                          icon: Icon(Icons.close, size: 14, color: Colors.grey[400]),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                          onPressed: () => _removeRole(idx),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          // 添加角色
                          SizedBox(
                            width: 44, height: headerH,
                            child: IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              onPressed: _addRole,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 数据行
            ..._performances.asMap().entries.map((perfEntry) {
              final pi = perfEntry.key;
              final perf = perfEntry.value;
              final dateText = perf.dateController.text.isNotEmpty
                  ? '${int.parse(perf.dateController.text.split('-')[1])}.${int.parse(perf.dateController.text.split('-')[2])}'
                  : '';

              return Container(
                height: cellH,
                decoration: BoxDecoration(border: Border(top: borderSide)),
                child: Row(
                  children: [
                    // 删除
                    Container(
                      width: actionW, height: cellH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(right: borderSide)),
                      child: _performances.length > 1
                        ? IconButton(
                            icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _removePerformance(pi),
                          )
                        : null,
                    ),
                    // 日期
                    Container(
                      width: dateW, height: cellH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(right: borderSide)),
                      child: InkWell(
                        onTap: () => _pickDate(pi),
                        child: perf.dateController.text.isEmpty
                          ? Text('选择', style: TextStyle(fontSize: 12, color: Colors.grey[400]))
                          : Text(dateText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    // 时间
                    Container(
                      width: timeW, height: cellH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(right: borderSide)),
                      child: InkWell(
                        onTap: () => _pickTime(pi),
                        child: Text(perf.time, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    // 角色演员
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _roles.asMap().entries.map((roleEntry) {
                            final role = roleEntry.value;
                            return Container(
                              width: roleW, height: cellH,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(border: Border(right: borderSide)),
                              child: TextField(
                                controller: role.actorControllers[pi],
                                textAlign: TextAlign.center,
                                readOnly: true,
                                onTap: () => _showActorPicker(pi, roleEntry.key),
                                decoration: const InputDecoration(
                                  hintText: '演员',
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
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
    );
  }
}

class _ActorPickerSheet extends StatefulWidget {
  final List<String> actorNames;
  final String initialValue;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onActorAdded;

  const _ActorPickerSheet({
    required this.actorNames,
    required this.initialValue,
    required this.onSelected,
    this.onActorAdded,
  });

  @override
  State<_ActorPickerSheet> createState() => _ActorPickerSheetState();
}

class _ActorPickerSheetState extends State<_ActorPickerSheet> {
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
