class Show {
  int? id;
  String name;
  String? theater;
  String? coverPath;
  String? createdAt;
  bool isInScheduleFlow;

  Show({
    this.id,
    required this.name,
    this.theater,
    this.coverPath,
    this.createdAt,
    this.isInScheduleFlow = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'theater': theater,
      'cover_path': coverPath,
      'created_at': createdAt,
      'is_in_schedule_flow': isInScheduleFlow ? 1 : 0,
    };
  }

  factory Show.fromMap(Map<String, dynamic> map) {
    return Show(
      id: map['id'] as int?,
      name: map['name'] as String,
      theater: map['theater'] as String?,
      coverPath: map['cover_path'] as String?,
      createdAt: map['created_at'] as String?,
      isInScheduleFlow: (map['is_in_schedule_flow'] as int?) == 1,
    );
  }

  Show copyWith({
    int? id,
    String? name,
    String? theater,
    String? coverPath,
    String? createdAt,
    bool? isInScheduleFlow,
  }) {
    return Show(
      id: id ?? this.id,
      name: name ?? this.name,
      theater: theater ?? this.theater,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      isInScheduleFlow: isInScheduleFlow ?? this.isInScheduleFlow,
    );
  }
}
