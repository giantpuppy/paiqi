class Performance {
  int? id;
  int showId;
  String date;
  String? time;
  @Deprecated('座位已迁移到 tickets 表，新代码请通过 ticket.seat 读取')
  String? seat;
  @Deprecated('票面价格已迁移到 tickets 表，新代码请通过 ticket.price 读取')
  double? price;     // 票面价格
  @Deprecated('实付价格已迁移到 tickets 表，新代码请通过 ticket.actualPrice 读取')
  double? actualPrice; // 实付价格
  String? status; // unmarked | want_to_see | bought | watched
  String? createdAt;

  Performance({
    this.id,
    required this.showId,
    required this.date,
    this.time,
    @Deprecated('使用 Ticket 模型') this.seat,
    @Deprecated('使用 Ticket 模型') this.price,
    @Deprecated('使用 Ticket 模型') this.actualPrice,
    this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'show_id': showId,
      'date': date,
      'time': time,
      'seat': seat,
      'price': price,
      'actual_price': actualPrice,
      'status': status ?? 'unmarked',
      'created_at': createdAt,
    };
  }

  factory Performance.fromMap(Map<String, dynamic> map) {
    return Performance(
      id: map['id'] as int?,
      showId: map['show_id'] as int,
      date: map['date'] as String,
      time: map['time'] as String?,
      seat: map['seat'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      actualPrice: map['actual_price'] != null ? (map['actual_price'] as num).toDouble() : null,
      status: map['status'] as String? ?? 'unmarked',
      createdAt: map['created_at'] as String?,
    );
  }

  Performance copyWith({
    int? id,
    int? showId,
    String? date,
    String? time,
    @Deprecated('使用 Ticket 模型') String? seat,
    @Deprecated('使用 Ticket 模型') double? price,
    @Deprecated('使用 Ticket 模型') double? actualPrice,
    String? status,
    String? createdAt,
  }) {
    return Performance(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      date: date ?? this.date,
      time: time ?? this.time,
      seat: seat ?? this.seat,
      price: price ?? this.price,
      actualPrice: actualPrice ?? this.actualPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
