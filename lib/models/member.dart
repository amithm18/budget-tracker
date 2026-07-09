class Member {
  final String id;
  final String name;
  final String groupId;            // belongs to which group
  final String? upiId;             // UPI ID for payments (optional)

  Member({
    required this.id,
    required this.name,
    required this.groupId,
    this.upiId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'groupId': groupId,
        'upiId': upiId,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'group_id': groupId,
        'upi_id': upiId,
      };

  factory Member.fromMap(Map<dynamic, dynamic> map) => Member(
        id: map['id'] as String,
        name: map['name'] as String,
        groupId: (map['groupId'] ?? map['group_id']) as String,
        upiId: (map['upiId'] ?? map['upi_id']) as String?,
      );
}
