import 'package:hive_flutter/hive_flutter.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/models/chat_session.dart';

class StorageService {
  static const String _userBox = 'user_box';
  static const String _userKey = 'current_user';
  static const String _settingsBox = 'settings_box';
  static const String _saveChatsKey = 'save_chats_enabled';
  static const String _chatsBox = 'chats_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserDataAdapter());
    Hive.registerAdapter(ChatSessionAdapter());
    await Hive.openBox<UserData>(_userBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox<ChatSession>(_chatsBox);
  }

  static Box<UserData> get _userBoxInstance => Hive.box<UserData>(_userBox);
  static Box get _settingsBoxInstance => Hive.box(_settingsBox);
  static Box<ChatSession> get _chatsBoxInstance => Hive.box<ChatSession>(_chatsBox);

  // User methods
  static Future<void> saveUser(UserData user) async {
    await _userBoxInstance.put(_userKey, user);
  }

  static UserData? getUser() {
    return _userBoxInstance.get(_userKey);
  }

  static Future<void> clearUser() async {
    await _userBoxInstance.delete(_userKey);
  }

  static bool hasUser() {
    return _userBoxInstance.containsKey(_userKey);
  }

  // Settings methods
  static bool getSaveChatsEnabled() {
    return _settingsBoxInstance.get(_saveChatsKey, defaultValue: false);
  }

  static Future<void> setSaveChatsEnabled(bool enabled) async {
    await _settingsBoxInstance.put(_saveChatsKey, enabled);
  }

  // Chat session methods
  static Future<void> saveChatSession(ChatSession session) async {
    await _chatsBoxInstance.put(session.id, session);
  }

  static List<ChatSession> getAllChatSessions() {
    return _chatsBoxInstance.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  static ChatSession? getChatSession(String id) {
    return _chatsBoxInstance.get(id);
  }

  static Future<void> deleteChatSession(String id) async {
    await _chatsBoxInstance.delete(id);
  }

  static Future<void> clearAllChatSessions() async {
    await _chatsBoxInstance.clear();
  }
}
