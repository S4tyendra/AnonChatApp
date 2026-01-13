import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/controllers/settings_controller.dart';
import 'package:anonchatapp/controllers/auth_controller.dart';
import 'package:anonchatapp/pages/chat_history_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.find<SettingsController>();
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Obx(
              () => SwitchListTile(
                title: const Text(
                  'Save Chats',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Automatically save chat history',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: controller.saveChatsEnabled.value,
                onChanged: controller.toggleSaveChats,
                activeTrackColor: const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (!controller.saveChatsEnabled.value) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.white70),
                    title: const Text(
                      'Saved Chats',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${controller.savedChats.length}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                    onTap: () => Get.to(() => const ChatHistoryPage()),
                  ),
                ),
                const SizedBox(height: 12),
                if (controller.savedChats.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.file_upload_outlined, color: Colors.white70),
                      title: const Text(
                        'Export All Chats',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: controller.exportAllChats,
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              onTap: () async {
                final confirm = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Logout', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to logout?',
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
                          'Logout',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await authController.logout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
