import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/models/chat_message.dart';
import 'package:anonchatapp/models/chat_session.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/services/api_service.dart';
import 'package:anonchatapp/services/storage_service.dart';

class ChatController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();
  final UserData userData;

  ChatController({required this.userData});

  final messages = <ChatMessage>[].obs;
  final status = 'Connecting...'.obs;
  final peerName = RxnString();
  final isTyping = false.obs;
  final isConnected = false.obs;

  final ScrollController scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();

  StreamSubscription? _sseSubscription;
  Timer? _typingTimer;
  String? _myId;
  String? _currentSessionId;
  int? _sessionStartedAt;

  @override
  void onInit() {
    super.onInit();
    _connectSSE();
  }

  @override
  void onClose() {
    _saveCurrentSession();
    _sseSubscription?.cancel();
    _typingTimer?.cancel();
    scrollController.dispose();
    textController.dispose();
    super.onClose();
  }

  Future<void> _connectSSE() async {
    try {
      final response = await _apiService.connectStream(
        userData.token,
        userData.name,
      );

      String currentEvent = '';

      _sseSubscription = response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.isEmpty) return;

              if (line.startsWith('event: ')) {
                currentEvent = line.substring(7).trim();
              } else if (line.startsWith('data: ')) {
                final data = line.substring(6).trim();
                _handleSSEEvent(currentEvent, data);
                currentEvent = '';
              }
            },
            onError: (e) {
              status.value = 'Connection Lost. Retrying...';
              Future.delayed(const Duration(seconds: 5), _connectSSE);
            },
          );
    } catch (e) {
      debugPrint('Dio SSE Error: $e');
      status.value = 'Connection failed';
    }
  }

  void _handleSSEEvent(String event, String data) {
    switch (event) {
      case 'identity':
        _myId = data;
        debugPrint('My ID: $data');
        break;
      case 'status':
        status.value = data;
        break;
      case 'peer':
        _saveCurrentSession();
        peerName.value = data;
        messages.clear();
        status.value = 'Connected to $data';
        isConnected.value = true;
        _startNewSession(data);
        _addSystemMessage('Connected to $data');
        break;
      case 'message':
        try {
          final Map<String, dynamic> msgJson = jsonDecode(data);
          messages.add(
            ChatMessage(
              text: msgJson['text'],
              from: msgJson['from'],
              ts: msgJson['ts'],
              isMe: false,
            ),
          );
          _scrollToBottom();
        } catch (e) {
          debugPrint('JSON Parse Error on message: $e');
        }
        break;
      case 'typing':
        try {
          final Map<String, dynamic> typingJson = jsonDecode(data);
          isTyping.value = typingJson['s'] == 1;
          _typingTimer?.cancel();
          if (isTyping.value) {
            _typingTimer = Timer(const Duration(seconds: 3), () {
              isTyping.value = false;
            });
          }
        } catch (_) {}
        break;
      case 'disconnected':
        _saveCurrentSession();
        peerName.value = null;
        status.value = 'Stranger left. Waiting for new match...';
        isTyping.value = false;
        isConnected.value = false;
        _addSystemMessage('Stranger disconnected. Looking for a new one...');
        _currentSessionId = null;
        break;
    }
  }

  void _startNewSession(String peer) {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartedAt = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _saveCurrentSession() async {
    if (!StorageService.getSaveChatsEnabled()) return;
    if (_currentSessionId == null || peerName.value == null) return;
    if (messages.where((m) => !m.isSystem).isEmpty) return;

    final session = ChatSession(
      id: _currentSessionId!,
      peerName: peerName.value!,
      startedAt: _sessionStartedAt ?? DateTime.now().millisecondsSinceEpoch,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      messages: messages.map((m) => SavedMessage.fromChatMessage(m)).toList(),
    );

    await StorageService.saveChatSession(session);
  }

  void _addSystemMessage(String text) {
    messages.add(
      ChatMessage(
        text: text,
        from: 'System',
        ts: DateTime.now().millisecondsSinceEpoch,
        isMe: false,
        isSystem: true,
      ),
    );
    _scrollToBottom();
  }

  Future<void> sendMessage() async {
    if (textController.text.trim().isEmpty) return;
    final text = textController.text.trim();
    textController.clear();

    final ts = DateTime.now().millisecondsSinceEpoch;
    messages.add(ChatMessage(text: text, from: 'Me', ts: ts, isMe: true));
    _scrollToBottom();

    try {
      await _apiService.sendMessage(userData.id, text);
    } catch (e) {
      debugPrint('Send Error: $e');
    }
  }

  void sendTypingStatus(bool typing) {
    if (_myId == null) return;
    _apiService.sendTypingStatus(userData.id, typing ? 1 : 0);
  }

  Future<void> skipPeer() async {
    if (userData.id.isEmpty) return;
    try {
      await _apiService.disconnect(userData.id);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
