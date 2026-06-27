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

  factory Member.fromMap(Map<dynamic, dynamic> map) => Member(
        id: map['id'] as String,
        name: map['name'] as String,
        groupId: map['groupId'] as String,
        upiId: map['upiId'] as String?,
      );
}
