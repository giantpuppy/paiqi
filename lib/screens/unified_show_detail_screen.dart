import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/show.dart';
import '../models/performance.dart';
import '../models/cast_member.dart';
import '../models/ticket.dart';

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
  List<CastMember> _castMembers = [];
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  // 编辑控制器
  late TextEditingController _seatController;
  late TextEditingController _priceController;
  late TextEditingController _actualPriceController;
  String _selectedDate = '';
  String _selectedTime = '';

  // 状态星星颜色
  static const _starColors = {
    'unmarked': Color(0xFF555555),
    'want_to_see': Color(0xFF811FE2),
    'bought': Color(0xFF34D399),
    'watched': Color(0xFFFDCB6E),
  };

  @override
  void initState() {
    super.initState();
    _seatController = TextEditingController();
    _priceController = TextEditingController();
    _actualPriceController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _seatController.dispose();
    _priceController.dispose();
    _actualPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final detail = await db.getPerformanceDetail(widget.performanceId);
    if (detail == null) {
      setState(() => _isLoading = false);
      return;
    }

    final showId = detail['show_id'] as int;
    final show = await db.getShowById(showId);
    final perfs = await db.getPerformancesByShowId(showId);
    final cast = await db.getCastMembersByPerformanceId(widget.performanceId);
    final tickets = await db.getTicketsByPerformanceId(widget.performanceId);

    final currentPerf =
        perfs.firstWhere((p) => p.id == widget.performanceId);

    // 自动检测：bought + 日期已过 → watched
    String status = currentPerf.status ?? 'unmarked';
    if (status == 'bought' && _isPastDate(currentPerf.date)) {
      status = 'watched';
    }

    setState(() {
      _show = show;
      _currentPerf = currentPerf.copyWith(status: status);
      _castMembers = cast;
      _tickets = tickets;
      _selectedDate = currentPerf.date;
      _selectedTime = currentPerf.time ?? '19:30';
      _seatController.text = currentPerf.seat ?? '';
      _priceController.text =
          currentPerf.price != null ? currentPerf.price!.toStringAsFixed(0) : '';
      _actualPriceController.text = currentPerf.actualPrice != null
          ? currentPerf.actualPrice!.toStringAsFixed(0)
          : '';
      _isLoading = false;
    });
  }

  bool _isPastDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  String get _status => _currentPerf?.status ?? 'unmarked';

  /// 切换想看状态（仅未买票时有效）
  void _toggleWantToSee() {
    if (_status == 'bought' || _status == 'watched') return;
    setState(() {
      final newStatus = _status == 'want_to_see' ? 'unmarked' : 'want_to_see';
      _currentPerf = _currentPerf!.copyWith(status: newStatus);
      _hasChanges = true;
    });
  }

  /// 根据票根数量自动更新状态
  void _autoUpdateStatus() {
    if (_tickets.isNotEmpty) {
      _currentPerf = _currentPerf!.copyWith(
        status: _isPastDate(_selectedDate) ? 'watched' : 'bought',
      );
    } else {
      // 没票了，回退到 unmarked
      _currentPerf = _currentPerf!.copyWith(status: 'unmarked');
    }
  }

  Future<void> _save() async {
    if (_currentPerf == null) return;
    final db = DatabaseHelper.instance;

    final updated = Performance(
      id: _currentPerf!.id,
      showId: _currentPerf!.showId,
      date: _selectedDate,
      time: _selectedTime,
      seat: _seatController.text.isNotEmpty ? _seatController.text : null,
      price: double.tryParse(_priceController.text),
      actualPrice: double.tryParse(_actualPriceController.text),
      status: _currentPerf!.status,
      createdAt: _currentPerf!.createdAt,
    );

    await db.updatePerformance(updated);

    // 更新卡司
    await db.deleteCastMembersByPerformanceId(_currentPerf!.id!);
    for (final cast in _castMembers) {
      await db.createCastMember(CastMember(
        performanceId: _currentPerf!.id!,
        role: cast.role,
        actorName: cast.actorName,
        isFeatured: cast.isFeatured,
      ));
    }

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
        title: const Text('确认删除'),
        content: const Text('确定要删除这场演出记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
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
      await db.deleteCastMembersByPerformanceId(_currentPerf!.id!);
      await db.deletePerformance(_currentPerf!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickTime() async {
    final parts = _selectedTime.split(':');
    final current = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 19,
      minute: int.tryParse(parts[1]) ?? 30,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6B5BCD),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _hasChanges = true;
      });
    }
  }

  void _addTicket() {
    setState(() {
      _tickets.add(Ticket(
        performanceId: _currentPerf!.id!,
        seat: null,
        price: null,
        actualPrice: null,
      ));
      _autoUpdateStatus();
      _hasChanges = true;
    });
  }

  void _removeTicket(int index) {
    setState(() {
      _tickets.removeAt(index);
      _autoUpdateStatus();
      _hasChanges = true;
    });
  }

  // ==================== 海报色 ====================

  Color _getCoverColor() {
    const colors = [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
      Color(0xFF0F3460),
      Color(0xFF533483),
      Color(0xFF2C3333),
      Color(0xFF2D4040),
      Color(0xFF3A3A3A),
      Color(0xFF2D1B69),
    ];
    return colors[(_show!.id ?? 0).abs() % colors.length];
  }

  Color _getCoverColor2() {
    const colors = [
      Color(0xFF0F3460),
      Color(0xFF533483),
      Color(0xFF1A1A2E),
      Color(0xFF2D1B69),
      Color(0xFF16213E),
      Color(0xFF3A3A3A),
      Color(0xFF2C3333),
      Color(0xFF2D4040),
    ];
    return colors[(_show!.id ?? 0).abs() % colors.length];
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

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // 海报蒙层 AppBar
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 卡司区
                  _buildCastSection(),
                  const SizedBox(height: 16),

                  // 票根区（仅已买/已看）
                  if (_status == 'bought' || _status == 'watched') ...[
                    _buildTicketSection(),
                    const SizedBox(height: 16),
                  ],

                  // 底部留白
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 海报蒙层 AppBar ====================

  Widget _buildSliverAppBar() {
    final dateTime = DateTime.tryParse(_selectedDate);
    final weekday =
        dateTime != null ? DateFormat('EEEE', 'zh_CN').format(dateTime) : '';
    final starColor = _starColors[_status] ?? _starColors['unmarked']!;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (_hasChanges) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('未保存的修改'),
                content: const Text('是否保存？'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('不保存'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _save();
                      if (mounted) Navigator.pop(context, true);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          } else {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white70),
          onPressed: _deletePerformance,
        ),
        if (_hasChanges)
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF6B5BCD)),
            onPressed: _save,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 海报背景
            _buildPosterBackground(),
            // 渐变蒙层
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD121212)],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
            // 底部信息
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期时间 + 状态星星
                  Row(
                    children: [
                      // 日期时间（可点击编辑）
                      GestureDetector(
                        onTap: _pickDate,
                        child: Text(
                          '$weekday $_selectedDate',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Text(
                          _selectedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 状态星星
                      GestureDetector(
                        onTap: _toggleWantToSee,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: starColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star_rounded,
                            color: starColor,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 剧名
                  Text(
                    _show!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 剧场
                  if (_show!.theater != null && _show!.theater!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _show!.theater!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_getCoverColor(), _getCoverColor2()],
        ),
      ),
      child: Center(
        child: Text(
          _show!.name.length >= 2 ? _show!.name.substring(0, 2) : _show!.name,
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==================== 卡司区（只读） ====================

  Widget _buildCastSection() {
    if (_castMembers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('本场卡司',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // 表头
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text('角色',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Color(0xFF8A8F98)))),
                    Expanded(
                        flex: 3,
                        child: Text('演员',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Color(0xFF8A8F98)))),
                  ],
                ),
              ),
              // 数据行
              ..._castMembers.asMap().entries.map((entry) {
                final i = entry.key;
                final cast = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 14),
                  decoration: BoxDecoration(
                    border: i > 0
                        ? const Border(
                            top: BorderSide(
                                color: Color(0xFF222222), width: 0.5))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          cast.role.isEmpty ? '-' : cast.role,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          cast.actorName.isEmpty ? '-' : cast.actorName,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 票根区 ====================

  Widget _buildTicketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('票根',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _addTicket,
              tooltip: '添加票根',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tickets.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('暂无票根',
                  style: TextStyle(color: Color(0xFF8A8F98))),
            ),
          )
        else
          ..._tickets.asMap().entries.map((entry) {
            final i = entry.key;
            final ticket = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < _tickets.length - 1 ? 10 : 0),
              child: _buildTicketCard(i, ticket),
            );
          }),
      ],
    );
  }

  Widget _buildTicketCard(int index, Ticket ticket) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 左侧紫色窄条
          Container(
            width: 3,
            decoration: const BoxDecoration(
              color: Color(0xFF6B5BCD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          // 虚线分隔
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: CustomPaint(
              size: const Size(1, double.infinity),
              painter: _DashedLinePainter(),
            ),
          ),
          // 票根内容
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      const Icon(Icons.confirmation_num_outlined,
                          size: 14, color: Color(0xFF6B5BCD)),
                      const SizedBox(width: 4),
                      Text('票根 ${index + 1}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Color(0xFFB3B3B3))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _removeTicket(index),
                        child: const Icon(Icons.close,
                            size: 14, color: Color(0xFF444444)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 座位
                  _buildTicketField(
                    icon: Icons.event_seat,
                    value: ticket.seat ?? '',
                    placeholder: '点击输入座位',
                    onTap: () {
                      final ctrl =
                          TextEditingController(text: ticket.seat ?? '');
                      _showEditDialog('座位', ctrl, (v) {
                        setState(() {
                          _tickets[index] = ticket.copyWith(seat: v.isEmpty ? null : v);
                          _hasChanges = true;
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  // 票价行
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTicketField(
                          icon: Icons.payments_outlined,
                          value: ticket.actualPrice != null
                              ? '¥${ticket.actualPrice!.toStringAsFixed(0)}'
                              : '',
                          placeholder: '¥实付',
                          onTap: () {
                            final ctrl = TextEditingController(
                                text: ticket.actualPrice?.toStringAsFixed(0) ??
                                    '');
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
          ),
        ],
      ),
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
          Icon(icon, size: 13, color: const Color(0xFF6B5BCD)),
          const SizedBox(width: 4),
          Text(
            value.isNotEmpty ? value : placeholder,
            style: TextStyle(
              fontSize: 12,
              color: value.isNotEmpty
                  ? Colors.white
                  : const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      String label, TextEditingController controller, ValueChanged<String> onChanged) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogController = TextEditingController(text: controller.text);
        return AlertDialog(
          title: Text('输入$label'),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            keyboardType: label.contains('价格') || label.contains('票面') || label.contains('实付')
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                controller.text = dialogController.text;
                onChanged(dialogController.text);
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}

// 虚线绘制器
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1;
    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 4;
    while (startY < size.height - 4) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
