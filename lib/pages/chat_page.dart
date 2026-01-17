import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/controllers/chat_controller.dart';
import 'package:anonchatapp/controllers/auth_controller.dart';
import 'package:anonchatapp/controllers/settings_controller.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/models/chat_session.dart';
import 'package:anonchatapp/pages/settings_page.dart';
import 'package:anonchatapp/widgets/chat_bubble.dart';
import 'package:anonchatapp/widgets/typing_indicator.dart';

class ChatPage extends StatelessWidget {
  final UserData? userData;

  ChatPage({super.key, this.userData}) {
    final user = userData ?? Get.find<AuthController>().currentUser!;
    Get.put(ChatController(userData: user));
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final SettingsController settingsController =
        Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Obx(
          () => Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: controller.isConnected.value
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        )
                      : null,
                  color: controller.isConnected.value
                      ? null
                      : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: controller.isConnected.value
                      ? Text(
                          controller.peerName.value?[0].toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isConnected.value
                          ? controller.peerName.value ?? 'Stranger'
                          : 'Looking for stranger...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: controller.isConnected.value
                            ? Colors.white
                            : Colors.white70,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.isPeerTemporarilyDisconnected.value
                                ? const Color(0xFFF59E0B) // Orange - peer reconnecting
                                : controller.isConnected.value
                                    ? const Color(0xFF22C55E) // Green - connected
                                    : const Color(0xFF6B7280), // Gray - searching
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            controller.status.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                color: controller.canSkip.value
                    ? const Color(0xFFF59E0B)
                    : Colors.white30,
              ),
              onPressed: controller.canSkip.value
                  ? () => controller.skipPeer()
                  : null,
              tooltip: 'Skip',
            ),
          ),
          // Obx(
          //   () => IconButton(
          //     icon: Icon(
          //       Icons.file_upload_outlined,
          //       color: controller.messages.isNotEmpty
          //           ? Colors.white70
          //           : Colors.white30,
          //     ),
          //     onPressed: controller.messages.isNotEmpty
          //         ? () => _exportCurrentChat(controller, settingsController)
          //         : null,
          //     tooltip: 'Export Chat',
          //   ),
          // ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              settingsController.loadSavedChats();
              Get.to(() => const SettingsPage());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.messages.isEmpty &&
                  !controller.isConnected.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Looking for someone to chat with...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.status.value,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.all(16),
                itemCount:
                    controller.messages.length +
                    (controller.isTyping.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == controller.messages.length &&
                      controller.isTyping.value) {
                    return const TypingIndicator();
                  }
                  final msg = controller.messages[index];
                  return ChatBubble(message: msg);
                },
              );
            }),
          ),
          Obx(
            () => Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.textController,
                      enabled: controller.isConnected.value,
                      onChanged: (v) {
                        if (controller.isConnected.value) {
                          controller.sendTypingStatus(v.isNotEmpty);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: controller.isConnected.value
                            ? 'Type a message...'
                            : 'Waiting for connection...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: controller.isConnected.value
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF0F172A).withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: controller.isConnected.value
                          ? (_) => controller.sendMessage()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: controller.isConnected.value
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            )
                          : null,
                      color: controller.isConnected.value
                          ? null
                          : const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: controller.isConnected.value
                            ? Colors.white
                            : Colors.white38,
                      ),
                      onPressed: controller.isConnected.value
                          ? controller.sendMessage
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportCurrentChat(
    ChatController controller,
    SettingsController settingsController,
  ) async {
    if (controller.messages.isEmpty) return;

    final peerName = controller.peerName.value ?? 'Unknown';
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      peerName: peerName,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      messages: controller.messages
          .map((m) => SavedMessage.fromChatMessage(m))
          .toList(),
    );

    await settingsController.exportChat(session);
  }
}
