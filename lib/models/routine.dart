class Routine {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final int orderIndex; // position in the user's routine list

  Routine({
    required this.id,
    required this.name,
    this.notes,
    required this.createdAt,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'order_index': orderIndex,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'] as String,
      name: map['name'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      orderIndex: map['order_index'] as int,
    );
  }
}
