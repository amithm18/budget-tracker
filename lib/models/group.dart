class Group {
  final String id;
  final String name;
  final List<String> memberIds;    // references to members
  final List<String> expenseIds;   // references to expenses
  final DateTime createdAt;
  final DateTime? dueDate;         // deadline for settlement
  final String? imageUrl;          // Group photo / preset avatar index

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.expenseIds,
    required this.createdAt,
    this.dueDate,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
        'expenseIds': expenseIds,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory Group.fromMap(Map<dynamic, dynamic> map) => Group(
        id: map['id'] as String,
        name: map['name'] as String,
        memberIds: List<String>.from(map['memberIds'] as List? ?? []),
        expenseIds: List<String>.from(map['expenseIds'] as List? ?? []),
        createdAt: DateTime.parse(map['createdAt'] as String),
        dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
        imageUrl: map['imageUrl'] as String?,
      );
}
