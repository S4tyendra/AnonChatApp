import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/controllers/chat_controller.dart';
import 'package:anonchatapp/controllers/auth_controller.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/pages/auth_page.dart';
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
    final AuthController authController = Get.find<AuthController>();

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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    controller.peerName.value?.isNotEmpty == true
                        ? controller.peerName.value![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.peerName.value ?? 'Searching...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.isConnected.value
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF59E0B),
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
            () => TextButton(
              onPressed: controller.isConnected.value
                  ? () => controller.skipPeer()
                  : null,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: controller.isConnected.value
                      ? const Color(0xFFF59E0B)
                      : Colors.white30,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await authController.logout();
              Get.offAll(() => const AuthPage());
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(
              () => ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: controller.messages.length +
                    (controller.isTyping.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == controller.messages.length &&
                      controller.isTyping.value) {
                    return const TypingIndicator();
                  }
                  final msg = controller.messages[index];
                  return ChatBubble(message: msg);
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.textController,
                    onChanged: (v) {
                      controller.sendTypingStatus(v.isNotEmpty);
                    },
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
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
                    onSubmitted: (_) => controller.sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: controller.sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
