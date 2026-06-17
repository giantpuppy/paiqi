import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../database/database_helper.dart';
import 'animated_list_item.dart';

/// 待办清单区块
///
/// 用于演出详情页，支持添加、勾选、删除待办项。
/// 添加方式：底部常驻输入框，回车或点击 + 直接添加。
class TodoListSection extends StatefulWidget {
  final int performanceId;
  final Color glowColor;

  const TodoListSection({
    super.key,
    required this.performanceId,
    this.glowColor = const Color(0xFFD4A853),
  });

  @override
  State<TodoListSection> createState() => _TodoListSectionState();
}

class _TodoListSectionState extends State<TodoListSection> {
  List<TodoItem> _items = [];
  bool _isLoading = true;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final db = DatabaseHelper.instance;
    final items = await db.getTodoItemsByPerformanceId(widget.performanceId);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitTodo() async {
    final value = _inputController.text.trim();
    if (value.isEmpty) return;

    final db = DatabaseHelper.instance;
    try {
      final newItem = await db.createTodoItem(TodoItem(
        performanceId: widget.performanceId,
        content: value,
        sortOrder: _items.length,
        createdAt: DateTime.now().toIso8601String(),
      ));
      if (mounted) {
        setState(() {
          _items.add(newItem);
          _inputController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _toggleItem(TodoItem item) async {
    final updated = item.copyWith(isDone: !item.isDone);
    final db = DatabaseHelper.instance;
    await db.updateTodoItem(updated);
    if (mounted) {
      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) _items[index] = updated;
      });
    }
  }

  Future<void> _deleteItem(TodoItem item) async {
    final db = DatabaseHelper.instance;
    if (item.id != null) await db.deleteTodoItem(item.id!);
    if (mounted) {
      setState(() => _items.removeWhere((i) => i.id == item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final undoneCount = _items.where((i) => !i.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: widget.glowColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '待办',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$undoneCount/${_items.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Column(
            children: [
              if (_items.isNotEmpty)
                Column(
                  children: _items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return AnimatedListItem(
                      index: index,
                      child: _buildTodoRow(item, index > 0),
                    );
                  }).toList(),
                ),
              _buildInputRow(),
            ],
          ),
      ],
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: _items.isNotEmpty
              ? BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 0.5)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add,
            size: 18,
            color: widget.glowColor.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '添加待办...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _submitTodo(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_upward, size: 18, color: widget.glowColor),
            onPressed: _submitTodo,
          ),
        ],
      ),
    );
  }

  Widget _buildTodoRow(TodoItem item, bool showDivider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleItem(item),
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isDone
                        ? const Color(0xFF34D399).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  color: item.isDone
                      ? const Color(0xFF34D399).withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: item.isDone
                    ? const Icon(Icons.check, size: 12, color: Color(0xFF34D399))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: item.isDone
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.85),
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _deleteItem(item),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
