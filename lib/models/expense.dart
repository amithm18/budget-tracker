enum SplitType {
  equal,
  amount,
  share,
  percent,
}

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

  List<String> get cleanParticipantIds {
    return participantIds.map((p) => p.split(':').first).toList();
  }

  SplitType get splitType {
    if (participantIds.isEmpty) return SplitType.equal;
    final first = participantIds.first;
    final parts = first.split(':');
    if (parts.length >= 3) {
      final typeStr = parts[1];
      if (typeStr == 'amount') return SplitType.amount;
      if (typeStr == 'share') return SplitType.share;
      if (typeStr == 'percent') return SplitType.percent;
    }
    return SplitType.equal;
  }

  Map<String, double> get splitValues {
    final Map<String, double> values = {};
    for (var p in participantIds) {
      final parts = p.split(':');
      if (parts.length >= 3) {
        final memberId = parts[0];
        final val = double.tryParse(parts[2]) ?? 0.0;
        values[memberId] = val;
      } else {
        values[p] = 0.0;
      }
    }
    return values;
  }

  Map<String, double> getCalculatedSpent() {
    final cleanIds = cleanParticipantIds;
    if (cleanIds.isEmpty) return {};

    final type = splitType;
    final values = splitValues;

    if (type == SplitType.equal) {
      final share = amount / cleanIds.length;
      return {for (var id in cleanIds) id: share};
    } else if (type == SplitType.amount) {
      return {for (var id in cleanIds) id: values[id] ?? 0.0};
    } else if (type == SplitType.share) {
      final totalShares = values.values.fold<double>(0.0, (sum, val) => sum + val);
      if (totalShares <= 0) {
        final share = amount / cleanIds.length;
        return {for (var id in cleanIds) id: share};
      }
      return {for (var id in cleanIds) id: (values[id] ?? 0.0) / totalShares * amount};
    } else if (type == SplitType.percent) {
      return {for (var id in cleanIds) id: ((values[id] ?? 0.0) / 100.0) * amount};
    }
    return {};
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paidByMemberId': paidByMemberId,
        'participantIds': participantIds,
        'groupId': groupId,
        'date': date.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paid_by_member_id': paidByMemberId,
        'participant_ids': participantIds,
        'group_id': groupId,
        'date': date.toIso8601String(),
      };

  factory Expense.fromMap(Map<dynamic, dynamic> map) => Expense(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        paidByMemberId: (map['paidByMemberId'] ?? map['paid_by_member_id']) as String,
        participantIds: List<String>.from((map['participantIds'] ?? map['participant_ids'] ?? []) as List),
        groupId: (map['groupId'] ?? map['group_id']) as String,
        date: DateTime.parse((map['date'] ?? map['created_at']) as String),
      );
}
