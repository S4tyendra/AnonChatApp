import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/controllers/settings_controller.dart';
import 'package:anonchatapp/models/chat_session.dart';
import 'package:anonchatapp/widgets/chat_bubble.dart';

class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Saved Chats'),
        actions: [
          if (controller.savedChats.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirm = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Clear All', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Delete all saved chats?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await controller.clearAllChats();
                }
              },
            ),
        ],
      ),
      body: Obx(() {
        if (controller.savedChats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'No saved chats',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.savedChats.length,
          itemBuilder: (context, index) {
            final session = controller.savedChats[index];
            return _ChatSessionTile(session: session);
          },
        );
      }),
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  final ChatSession session;

  const _ChatSessionTile({required this.session});

  String _formatDate(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    final messageCount = session.messages.where((m) => !m.isSystem).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              session.peerName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          session.peerName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$messageCount messages - ${_formatDate(session.startedAt)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.file_upload_outlined, color: Colors.white54, size: 20),
              onPressed: () => controller.exportChat(session),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
              onPressed: () async {
                final confirm = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Delete chat with ${session.peerName}?',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await controller.deleteChat(session.id);
                }
              },
            ),
          ],
        ),
        onTap: () => Get.to(() => _ChatViewPage(session: session)),
      ),
    );
  }
}

class _ChatViewPage extends StatelessWidget {
  final ChatSession session;

  const _ChatViewPage({required this.session});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(session.peerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => controller.exportChat(session),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: session.messages.length,
        itemBuilder: (context, index) {
          final msg = session.messages[index];
          return ChatBubble(message: msg.toChatMessage());
        },
      ),
    );
  }
}
