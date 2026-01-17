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
  final isPeerTemporarilyDisconnected = false.obs;
  final canSkip = false.obs;

  final ScrollController scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();

  StreamSubscription? _sseSubscription;
  Timer? _typingTimer;
  Timer? _skipCooldownTimer;
  Timer? _myTypingDebounceTimer;
  bool _lastSentTypingStatus = false;
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
    _skipCooldownTimer?.cancel();
    _myTypingDebounceTimer?.cancel();
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
    debugPrint('[SSE] Event: "$event" | Data: "$data"');

    switch (event) {
      case 'identity':
        _myId = data;
        debugPrint('[SSE] My ID set to: $data');
        break;
      case 'status':
        status.value = data;
        debugPrint('[SSE] Status updated: $data');
        break;
      case 'peer':
      case 'connected':
        debugPrint('[SSE] PEER/CONNECTED EVENT RECEIVED: $data');
        // Only start new session if this is a new peer
        if (peerName.value != data) {
          _saveCurrentSession();
          messages.clear();
          _startNewSession(data);
          _addSystemMessage('Connected to $data');
        }
        peerName.value = data;
        status.value = 'Connected to $data';
        isConnected.value = true;
        isPeerTemporarilyDisconnected.value = false;
        _startSkipCooldown();
        debugPrint('[SSE] isConnected now: ${isConnected.value}, peerName: ${peerName.value}');
        break;
      case 'reconnected':
        // We reconnected within grace period, session restored
        debugPrint('[SSE] Reconnected to session: $data');
        status.value = 'Reconnected';
        _addSystemMessage('Connection restored');
        break;
      case 'peer_disconnected':
        // Peer temporarily lost connection
        debugPrint('[SSE] Peer temporarily disconnected');
        isPeerTemporarilyDisconnected.value = true;
        status.value = '${peerName.value} may be reconnecting...';
        _addSystemMessage('${peerName.value} lost connection, waiting for reconnect...');
        break;
      case 'peer_reconnected':
        // Peer came back
        debugPrint('[SSE] Peer reconnected: $data');
        isPeerTemporarilyDisconnected.value = false;
        status.value = 'Connected to $data';
        _addSystemMessage('${peerName.value} reconnected');
        break;
      case 'message':
        debugPrint('[SSE] MESSAGE EVENT - isConnected: ${isConnected.value}');
        try {
          final Map<String, dynamic> msgJson = jsonDecode(data);
          final senderName = msgJson['from'] as String;

          // Workaround: If we receive a message but peer event was missed, infer connection
          if (!isConnected.value && senderName.isNotEmpty) {
            debugPrint('[SSE] Inferring peer connection from message sender: $senderName');
            peerName.value = senderName;
            status.value = 'Connected to $senderName';
            isConnected.value = true;
            _startNewSession(senderName);
          }

          messages.add(
            ChatMessage(
              text: msgJson['text'],
              from: senderName,
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
        isPeerTemporarilyDisconnected.value = false;
        _addSystemMessage('Stranger disconnected. Looking for a new one...');
        _currentSessionId = null;
        break;
      default:
        debugPrint('[SSE] UNKNOWN EVENT: "$event" with data: "$data"');
    }
  }

  void _startNewSession(String peer) {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartedAt = DateTime.now().millisecondsSinceEpoch;
  }

  void _startSkipCooldown() {
    canSkip.value = false;
    _skipCooldownTimer?.cancel();
    _skipCooldownTimer = Timer(const Duration(seconds: 10), () {
      canSkip.value = true;
    });
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
    _resetTypingStatus();

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
    if (_myId == null || !isConnected.value) return;

    // Cancel any pending debounce timer
    _myTypingDebounceTimer?.cancel();

    if (typing) {
      // Only send typing=true if we haven't already sent it
      if (!_lastSentTypingStatus) {
        _lastSentTypingStatus = true;
        _apiService.sendTypingStatus(userData.id, 1);
      }
      // Set timer to send typing=false after 3 seconds of no activity
      _myTypingDebounceTimer = Timer(const Duration(seconds: 3), () {
        if (_lastSentTypingStatus) {
          _lastSentTypingStatus = false;
          _apiService.sendTypingStatus(userData.id, 0);
        }
      });
    } else {
      // Text field is empty, send typing=false immediately if we were typing
      if (_lastSentTypingStatus) {
        _lastSentTypingStatus = false;
        _apiService.sendTypingStatus(userData.id, 0);
      }
    }
  }

  void _resetTypingStatus() {
    _myTypingDebounceTimer?.cancel();
    _lastSentTypingStatus = false;
  }

  Future<void> skipPeer() async {
    if (userData.id.isEmpty) return;
    try {
      _saveCurrentSession();
      _resetTypingStatus();
      messages.clear();
      peerName.value = null;
      isConnected.value = false;
      isTyping.value = false;
      canSkip.value = false;
      status.value = 'Looking for a new stranger...';
      _currentSessionId = null;
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
