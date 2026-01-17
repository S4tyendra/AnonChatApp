import 'package:hive_flutter/hive_flutter.dart';
import 'package:anonchatapp/models/chat_message.dart';

class SavedMessage {
  final String text;
  final String from;
  final int ts;
  final bool isMe;
  final bool isSystem;

  SavedMessage({
    required this.text,
    required this.from,
    required this.ts,
    required this.isMe,
    this.isSystem = false,
  });

  factory SavedMessage.fromChatMessage(ChatMessage msg) {
    return SavedMessage(
      text: msg.text,
      from: msg.from,
      ts: msg.ts,
      isMe: msg.isMe,
      isSystem: msg.isSystem,
    );
  }

  ChatMessage toChatMessage() {
    return ChatMessage(
      text: text,
      from: from,
      ts: ts,
      isMe: isMe,
      isSystem: isSystem,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'from': from,
        'ts': ts,
        'isMe': isMe,
        'isSystem': isSystem,
      };

  factory SavedMessage.fromJson(Map<String, dynamic> json) {
    return SavedMessage(
      text: json['text'],
      from: json['from'],
      ts: json['ts'],
      isMe: json['isMe'],
      isSystem: json['isSystem'] ?? false,
    );
  }
}

class ChatSession {
  final String id;
  final String peerName;
  final int startedAt;
  final int? endedAt;
  final List<SavedMessage> messages;

  ChatSession({
    required this.id,
    required this.peerName,
    required this.startedAt,
    this.endedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerName': peerName,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List;
    final messages = rawMessages.map((m) {
      if (m is SavedMessage) return m;
      if (m is Map) return SavedMessage.fromJson(Map<String, dynamic>.from(m));
      throw ArgumentError('Invalid message type: ${m.runtimeType}');
    }).toList();

    return ChatSession(
      id: json['id'],
      peerName: json['peerName'],
      startedAt: json['startedAt'],
      endedAt: json['endedAt'],
      messages: messages,
    );
  }
}

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 1;

  @override
  ChatSession read(BinaryReader reader) {
    final map = reader.readMap().cast<String, dynamic>();
    return ChatSession.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer.writeMap(obj.toJson());
  }
}
