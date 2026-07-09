class Member {
  final String id;
  final String name;
  final String groupId;            // belongs to which group
  final String? upiId;             // UPI ID for payments (optional)
  final String? userId;            // unique device user ID (optional, links user to placeholder)

  Member({
    required this.id,
    required this.name,
    required this.groupId,
    this.upiId,
    this.userId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'groupId': groupId,
        'upiId': upiId,
        'userId': userId,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'group_id': groupId,
        'upi_id': upiId,
        'user_id': userId,
      };

  factory Member.fromMap(Map<dynamic, dynamic> map) => Member(
        id: map['id'] as String,
        name: map['name'] as String,
        groupId: (map['groupId'] ?? map['group_id']) as String,
        upiId: (map['upiId'] ?? map['upi_id']) as String?,
        userId: (map['userId'] ?? map['user_id']) as String?,
      );
}
