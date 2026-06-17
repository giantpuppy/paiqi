class TodoItem {
  int? id;
  int performanceId;
  String content;
  bool isDone;
  int sortOrder;
  String? createdAt;

  TodoItem({
    this.id,
    required this.performanceId,
    required this.content,
    this.isDone = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'performance_id': performanceId,
      'content': content,
      'is_done': isDone ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as int?,
      performanceId: map['performance_id'] as int,
      content: map['content'] as String,
      isDone: map['is_done'] == 1 || map['is_done'] == true,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }

  TodoItem copyWith({
    int? id,
    int? performanceId,
    String? content,
    bool? isDone,
    int? sortOrder,
    String? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      performanceId: performanceId ?? this.performanceId,
      content: content ?? this.content,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
