import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:anonchatapp/models/chat_session.dart';
import 'package:anonchatapp/services/storage_service.dart';

class SettingsController extends GetxController {
  final saveChatsEnabled = false.obs;
  final savedChats = <ChatSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  void loadSettings() {
    saveChatsEnabled.value = StorageService.getSaveChatsEnabled();
    loadSavedChats();
  }

  void loadSavedChats() {
    savedChats.value = StorageService.getAllChatSessions();
  }

  Future<void> toggleSaveChats(bool enabled) async {
    saveChatsEnabled.value = enabled;
    await StorageService.setSaveChatsEnabled(enabled);
  }

  Future<void> deleteChat(String id) async {
    await StorageService.deleteChatSession(id);
    loadSavedChats();
  }

  Future<void> clearAllChats() async {
    await StorageService.clearAllChatSessions();
    loadSavedChats();
  }

  Future<void> exportChat(ChatSession session) async {
    final json = jsonEncode(session.toJson());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/chat_${session.id}.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Chat with ${session.peerName}'),
    );
  }

  Future<void> exportAllChats() async {
    final chats = StorageService.getAllChatSessions();
    final json = jsonEncode(chats.map((c) => c.toJson()).toList());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/all_chats.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'All Saved Chats'),
    );
  }
}
