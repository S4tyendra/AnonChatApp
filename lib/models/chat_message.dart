class ChatMessage {
  final String text;
  final String from;
  final int ts;
  final bool isMe;
  final bool isSystem;

  ChatMessage({
    required this.text,
    required this.from,
    required this.ts,
    required this.isMe,
    this.isSystem = false,
  });
}
