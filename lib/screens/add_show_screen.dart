import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/actor.dart';
import '../models/ticket.dart';
import '../utils/ocr_service.dart';
import '../utils/knowledge_base.dart';
import '../utils/cover_helper.dart';
import '../utils/status_colors.dart';
import 'show_management_screen.dart';

class AddShowScreen extends StatefulWidget {
  final Show? initialShow;
  final List<Performance>? initialPerformances;
  final bool isEditMode;

  const AddShowScreen({
    super.key,
    this.initialShow,
    this.initialPerformances,
    this.isEditMode = false,
  });

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _PerformanceEntry {
  TextEditingController dateController;
  TextEditingController priceController;
  TextEditingController actualPriceController;
  String time;

  _PerformanceEntry()
      : dateController = TextEditingController(),
        priceController = TextEditingController(),
        actualPriceController = TextEditingController(),
        time = '19:30';

  void dispose() {
    dateController.dispose();
    priceController.dispose();
    actualPriceController.dispose();
  }
}

class _RoleColumn {
  TextEditingController roleController;
  List<TextEditingController> actorControllers;

  _RoleColumn()
      : roleController = TextEditingController(),
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
  String? _coverPath;

  static const List<String> _timePresets = ['14:00', '14:30', '19:00', '19:30'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.initialShow != null) {
      _nameController.text = widget.initialShow!.name;
      _theaterController.text = widget.initialShow!.theater ?? '';
      _coverPath = widget.initialShow!.coverPath;
      _loadEditModeData();
    } else {
      _addPerformance();
      _addRole();
    }
    _loadActorNames();
  }

  Future<void> _loadEditModeData() async {
    final db = DatabaseHelper.instance;
    final performances = widget.initialPerformances ?? [];

    for (final perf in performances) {
      final entry = _PerformanceEntry();
      entry.dateController.text = perf.date;
      entry.time = perf.time ?? '19:30';
      entry.priceController.text = perf.price?.toString() ?? '';
      entry.actualPriceController.text = perf.actualPrice?.toString() ?? '';
      _performances.add(entry);

      // 加载该场次的卡司
      final casts = await db.getCastMembersByPerformanceId(perf.id!);
      for (final cast in casts) {
        // 查找是否已有该角色
        final existingRoleIdx = _roles.indexWhere((r) => r.roleController.text == cast.role);
        if (existingRoleIdx >= 0) {
          // 已有角色，补充演员
          _roles[existingRoleIdx].sync(_performances.length);
          _roles[existingRoleIdx].actorControllers[_performances.length - 1].text = cast.actorName;
        } else {
          // 新角色
          final role = _RoleColumn();
          role.roleController.text = cast.role;
          role.sync(_performances.length);
          role.actorControllers[_performances.length - 1].text = cast.actorName;
          _roles.add(role);
        }
      }
    }

    // 确保所有角色的 controller 数量与场次数量一致
    for (final role in _roles) {
      role.sync(_performances.length);
    }

    if (_performances.isEmpty) {
      _addPerformance();
    }
    if (_roles.isEmpty) {
      _addRole();
    }

    if (mounted) setState(() {});
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
      final removed = _performances.removeAt(index);
      removed.dispose();
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

  // ==================== 海报选择 ====================

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final showName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : '未命名剧目';

    final savedPath = await CoverHelper.saveCoverImage(showName, bytes);
    setState(() => _coverPath = savedPath);
  }

  // ==================== 暗黑风格日期选择 ====================

  Future<void> _pickDate(int perfIndex) async {
    final entry = _performances[perfIndex];
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
                // 顶部栏
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
                // Cupertino 日期滚轮
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

  // ==================== 暗黑风格时间选择 ====================

  Future<void> _pickTime(int perfIndex) async {
    final entry = _performances[perfIndex];
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

  // ==================== 事务级保存 ====================

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
    int? newShowId;
    try {
      final db = DatabaseHelper.instance;
      final showName = _nameController.text.trim();
      final theater = _theaterController.text.trim().isNotEmpty
          ? _theaterController.text.trim() : null;

      // 编辑模式下：海报改名联动
      String? finalCoverPath = _coverPath;
      if (widget.isEditMode && widget.initialShow != null) {
        final oldName = widget.initialShow!.name;
        if (oldName != showName && _coverPath != null && _coverPath!.isNotEmpty) {
          finalCoverPath = await CoverHelper.renameCoverImage(_coverPath, showName);
        }
      }

      if (widget.isEditMode && widget.initialShow != null) {
        // 编辑模式：更新 show + 事务替换 performances
        final updatedShow = widget.initialShow!.copyWith(
          name: showName,
          theater: theater,
          coverPath: finalCoverPath,
        );
        await db.updateShow(updatedShow);
        newShowId = updatedShow.id;

        // 构建 performances + casts 数据
        final perfDataList = <Map<String, dynamic>>[];
        for (int pi = 0; pi < _performances.length; pi++) {
          final perfEntry = _performances[pi];
          final casts = <CastMember>[];
          for (final role in _roles) {
            final roleName = role.roleController.text.trim();
            final actorName = role.actorControllers[pi].text.trim();
            if (roleName.isNotEmpty && actorName.isNotEmpty) {
              casts.add(CastMember(
                performanceId: 0, // 会在 replaceAllPerformances 中被替换
                role: roleName,
                actorName: actorName,
                isFeatured: false,
                createdAt: DateTime.now().toIso8601String(),
              ));
            }
          }
          perfDataList.add({
            'performance': Performance(
              showId: widget.initialShow!.id!,
              date: perfEntry.dateController.text,
              time: perfEntry.time,
              status: 'unmarked',
              createdAt: DateTime.now().toIso8601String(),
            ),
            'casts': casts,
            'ticket': _buildTicketFromPerfEntry(perfEntry),
          });
        }
        await db.replaceAllPerformances(widget.initialShow!.id!, perfDataList);
      } else {
        // 新增模式：事务级保存
        final show = await db.createShow(Show(
          name: showName,
          theater: theater,
          coverPath: finalCoverPath,
          isInScheduleFlow: false,
          createdAt: DateTime.now().toIso8601String(),
        ));

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
              showId: show.id!,
              date: perfEntry.dateController.text,
              time: perfEntry.time,
              status: 'unmarked',
              createdAt: DateTime.now().toIso8601String(),
            ),
            'casts': casts,
            'ticket': _buildTicketFromPerfEntry(perfEntry),
          });
        }
        await db.replaceAllPerformances(show.id!, perfDataList);
        newShowId = show.id;
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
          SnackBar(content: Text(widget.isEditMode ? '剧目更新成功！' : '剧目添加成功！')));
        if (widget.isEditMode || newShowId == null) {
          Navigator.pop(context, true);
        } else {
          // 新建剧目后直接进入剧目管理页，使用统一界面继续管理
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ShowManagementScreen(showId: newShowId!),
            ),
          );
        }
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
    for (final p in _performances) { p.dispose(); }
    for (final r in _roles) { r.dispose(); }
    super.dispose();
  }

  // 根据 perfEntry 中的价格控件生成 Ticket；没有价格数据时返回 null。
  Ticket? _buildTicketFromPerfEntry(_PerformanceEntry perfEntry) {
    final price = double.tryParse(perfEntry.priceController.text.trim());
    final actualPrice = double.tryParse(perfEntry.actualPriceController.text.trim());
    if (price == null && actualPrice == null) return null;
    return Ticket(
      performanceId: 0, // 会在 replaceAllPerformances 中被替换
      price: price,
      actualPrice: actualPrice,
    );
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
        title: Text(widget.isEditMode ? '编辑剧目' : '添加剧目'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveShow,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B5BCD),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('保存'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 海报 + 剧目信息
            _buildHeaderSection(),
            const SizedBox(height: 24),

            // 排期场次标题
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5BCD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('排期场次',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addPerformance,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF6B5BCD)),
                  label: const Text('添加场次', style: TextStyle(color: Color(0xFF6B5BCD))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 表格
            _buildTable(),

            const SizedBox(height: 20),

            // OCR识别按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRecognizing ? null : _pickImageAndRecognize,
                icon: _isRecognizing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(_isRecognizing ? '识别中...' : '图片识别卡司'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5BCD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==================== 头部：海报 + 剧目信息 ====================

  Widget _buildHeaderSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = screenWidth * 0.22;
    final posterHeight = posterWidth * 4 / 3;
    final color = _getCoverColor();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：3:4 海报位
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            width: posterWidth,
            height: posterHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color,
              gradient: _coverPath == null || _coverPath!.isEmpty
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
              image: _coverPath != null && _coverPath!.isNotEmpty
                  ? DecorationImage(
                      image: FileImage(File(_coverPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _coverPath == null || _coverPath!.isEmpty
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // 剧名首字
                      if (_nameController.text.trim().isNotEmpty)
                        Text(
                          _nameController.text.trim().substring(0,
                              _nameController.text.trim().length > 2
                                  ? 2
                                  : _nameController.text.trim().length),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.18),
                            fontSize: posterWidth * 0.35,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      // 相机图标
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.camera_alt,
                            size: posterWidth * 0.14, color: Colors.white70),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        // 右侧：剧目名称 + 演出地点
        Expanded(
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('剧目名称'),
                style: const TextStyle(fontSize: 15),
                validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _theaterController,
                decoration: _inputDecoration('演出剧场'),
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getCoverColor() {
    if (_coverPath != null && _coverPath!.isNotEmpty) return Colors.transparent;
    final id = widget.initialShow?.id ?? 0;
    return kCoverColors[id.abs() % kCoverColors.length];
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
        borderSide: const BorderSide(color: Color(0xFF6B5BCD), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  // ==================== 表格（弱边框高密度风格） ====================

  Widget _buildTable() {
    const dateW = 62.0;
    const timeW = 52.0;
    const roleW = 76.0;
    const headerH = 32.0;
    const cellH = 38.0;
    const fixedW = dateW + timeW + 0.5;
    const dividerColor = Color(0xFF2A2A2A);
    const headerBg = Color(0xFF1A1A1A);

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
        // 左侧固定：日期 + 时间
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(
                      width: timeW,
                      child: Center(
                        child: Text('时间',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              // 固定数据行
              ..._performances.asMap().entries.map((perfEntry) {
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
                              ? Text('选择',
                                  style: TextStyle(fontSize: 11, color: const Color(0xFF6B5BCD).withValues(alpha: 0.85)))
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
                      ..._roles.map((role) {
                        return SizedBox(
                          width: roleW,
                          child: Center(
                            child: TextField(
                              controller: role.roleController,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '角色',
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
                            onTap: _addRole,
                            child: Icon(Icons.add_circle_outline,
                              size: 16, color: const Color(0xFF6B5BCD).withValues(alpha: 0.85)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 滚动数据行
                ..._performances.asMap().entries.map((perfEntry) {
                  final pi = perfEntry.key;
                  return Container(
                    height: cellH,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: dividerColor, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: _roles.asMap().entries.map((roleEntry) {
                        final ri = roleEntry.key;
                        final roleCol = roleEntry.value;
                        return SizedBox(
                          width: roleW,
                          child: TextField(
                            controller: roleCol.actorControllers[pi],
                            textAlign: TextAlign.center,
                            readOnly: true,
                            onTap: () => _showActorPicker(pi, ri),
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
        ],
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
