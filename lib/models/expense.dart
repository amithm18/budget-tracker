class Expense {
  final String id;
  final String title;
  final double amount;
  final String paidByMemberId;        // who paid
  final List<String> participantIds;  // who's involved
  final String groupId;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidByMemberId,
    required this.participantIds,
    required this.groupId,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paidByMemberId': paidByMemberId,
        'participantIds': participantIds,
        'groupId': groupId,
        'date': date.toIso8601String(),
      };

  factory Expense.fromMap(Map<dynamic, dynamic> map) => Expense(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        paidByMemberId: map['paidByMemberId'] as String,
        participantIds: List<String>.from(map['participantIds'] as List? ?? []),
        groupId: map['groupId'] as String,
        date: DateTime.parse(map['date'] as String),
      );
}
