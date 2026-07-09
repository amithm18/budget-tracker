class Group {
  final String id;
  final String name;
  final List<String> memberIds;    // references to members
  final List<String> expenseIds;   // references to expenses
  final DateTime createdAt;
  final DateTime? dueDate;         // deadline for settlement

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.expenseIds,
    required this.createdAt,
    this.dueDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
        'expenseIds': expenseIds,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
      };

  factory Group.fromMap(Map<dynamic, dynamic> map) => Group(
        id: map['id'] as String,
        name: map['name'] as String,
        memberIds: List<String>.from((map['memberIds'] ?? map['member_ids']) as List? ?? []),
        expenseIds: List<String>.from((map['expenseIds'] ?? map['expense_ids']) as List? ?? []),
        createdAt: DateTime.parse((map['createdAt'] ?? map['created_at']) as String),
        dueDate: map['dueDate'] != null || map['due_date'] != null
            ? DateTime.parse((map['dueDate'] ?? map['due_date']) as String)
            : null,
      );
}
