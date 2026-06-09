class Ticket {
  int? id;
  int performanceId;
  String? seat;
  double? price;       // 票面价格
  double? actualPrice; // 实付价格

  Ticket({
    this.id,
    required this.performanceId,
    this.seat,
    this.price,
    this.actualPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'performance_id': performanceId,
      'seat': seat,
      'price': price,
      'actual_price': actualPrice,
    };
  }

  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      id: map['id'] as int?,
      performanceId: map['performance_id'] as int,
      seat: map['seat'] as String?,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      actualPrice: map['actual_price'] != null ? (map['actual_price'] as num).toDouble() : null,
    );
  }

  Ticket copyWith({
    int? id,
    int? performanceId,
    String? seat,
    double? price,
    double? actualPrice,
  }) {
    return Ticket(
      id: id ?? this.id,
      performanceId: performanceId ?? this.performanceId,
      seat: seat ?? this.seat,
      price: price ?? this.price,
      actualPrice: actualPrice ?? this.actualPrice,
    );
  }
}
