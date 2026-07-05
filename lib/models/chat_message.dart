class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String messageType; // 'text', 'image', 'gif'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'groupId': groupId,
        'senderId': senderId,
        'senderName': senderName,
        'messageType': messageType,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        groupId: map['groupId'] as String,
        senderId: map['senderId'] as String,
        senderName: map['senderName'] as String,
        messageType: map['messageType'] as String,
        content: map['content'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
