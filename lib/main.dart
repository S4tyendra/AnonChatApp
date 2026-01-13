import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnonChatApp());
}

// --- Models ---

class ChatMessage {
  final String text;
  final String from;
  final int ts;
  final bool isMe;

  ChatMessage({
    required this.text,
    required this.from,
    required this.ts,
    required this.isMe,
  });
}

// --- Main App ---

class AnonChatApp extends StatelessWidget {
  const AnonChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnonChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainGate(),
    );
  }
}

class MainGate extends StatefulWidget {
  const MainGate({super.key});

  @override
  State<MainGate> createState() => _MainGateState();
}

class _MainGateState extends State<MainGate> {
  bool _isChecking = true;
  Map<String, String>? _savedData;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('userId');
    final token = prefs.getString('sessionToken');

    if (id != null && token != null) {
      setState(() {
        _savedData = {
          'id': id,
          'token': token,
          'name': prefs.getString('userName') ?? 'Anonymous',
        };
      });
    }
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_savedData != null) return ChatPage(userData: _savedData!);
    return const AuthPage();
  }
}

// --- Auth Page ---

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final String apiBase = "https://anon-chatapi.devh.in";
  final Dio _dio = Dio();
  HttpServer? _server;
  bool _isLoading = false;
  bool _showWebView = false;
  WebViewController? _webViewController;
  Completer<Map<String, dynamic>>? _authCompleter;

  Future<void> _startAuthFlow() async {
    setState(() => _isLoading = true);
    try {
      _authCompleter = Completer<Map<String, dynamic>>();
      final handler = const shelf.Pipeline().addHandler((req) async {
        if (req.method == 'POST' && req.url.path == 'auth') {
          final body = await req.readAsString();
          _authCompleter!.complete(jsonDecode(body));
          return shelf.Response.ok(
            'OK',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }
        return shelf.Response.notFound('Not found');
      });

      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        6364,
      );

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse('https://create-anon-account.devh.in/'));

      setState(() {
        _showWebView = true;
        _isLoading = false;
      });

      final accountData = await _authCompleter!.future;
      _server?.close();

      setState(() => _isLoading = true);
      final sessionResponse = await _dio.post(
        '$apiBase/paid',
        data: {'id': accountData['id'], 'auth': accountData['auth']},
      );

      if (sessionResponse.statusCode == 200) {
        final sessionData = sessionResponse.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', accountData['id']);
        await prefs.setString('userName', accountData['name'] ?? 'Anonymous');
        await prefs.setString('sessionToken', sessionData['token']);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                userData: {
                  'id': accountData['id'],
                  'token': sessionData['token'],
                  'name': accountData['name'] ?? 'Anonymous',
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Auth Error: $e")));
      setState(() {
        _isLoading = false;
        _showWebView = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return Scaffold(
        appBar: AppBar(title: const Text("Create Account")),
        body: WebViewWidget(controller: _webViewController!),
      );
    }
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _startAuthFlow,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text("Start Chatting"),
        ),
      ),
    );
  }
}

// --- Chat Page ---

class ChatPage extends StatefulWidget {
  final Map<String, String> userData;
  const ChatPage({super.key, required this.userData});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final String apiBase = "https://anon-chatapi.devh.in";
  final Dio _dio = Dio();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _sseSubscription;
  String _status = "Connecting...";
  String? _peerName;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _connectSSE();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _connectSSE() async {
    final url =
        "$apiBase/stream?name=${widget.userData['name']}&token=${widget.userData['token']}";

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {"Accept": "text/event-stream"},
        ),
      );

      String currentEvent = "";

      _sseSubscription = response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.isEmpty) return;

              if (line.startsWith("event: ")) {
                currentEvent = line.substring(7).trim();
              } else if (line.startsWith("data: ")) {
                final data = line.substring(6).trim();
                _handleSSEEvent(currentEvent, data);
                currentEvent = ""; // Reset after processing data
              }
            },
            onError: (e) {
              setState(() => _status = "Connection Lost. Retrying...");
              Future.delayed(const Duration(seconds: 5), _connectSSE);
            },
          );
    } catch (e) {
      debugPrint("Dio SSE Error: $e");
    }
  }

  void _handleSSEEvent(String event, String data) {
    if (!mounted) return;

    // FIX: Only jsonDecode events that are actually JSON
    switch (event) {
      case 'identity':
        debugPrint("My ID: $data");
        break;
      case 'status':
        setState(() => _status = data);
        break;
      case 'peer':
        setState(() {
          _peerName = data;
          _messages.clear();
          _status = "Connected to $data";
        });
        break;
      case 'message':
        try {
          final Map<String, dynamic> msgJson = jsonDecode(data);
          setState(() {
            _messages.add(
              ChatMessage(
                text: msgJson['text'],
                from: msgJson['from'],
                ts: msgJson['ts'],
                isMe: false,
              ),
            );
          });
          _scrollToBottom();
        } catch (e) {
          debugPrint("JSON Parse Error on message: $e");
        }
        break;
      case 'typing':
        try {
          final Map<String, dynamic> typingJson = jsonDecode(data);
          setState(() {
            _isTyping = typingJson['s'] == 1;
          });
          _typingTimer?.cancel();
          if (_isTyping) {
            _typingTimer = Timer(const Duration(seconds: 3), () {
              setState(() => _isTyping = false);
            });
          }
        } catch (e) {}
        break;
      case 'disconnected':
        setState(() {
          _peerName = null;
          _status = "Stranger left. Waiting for new match...";
          _isTyping = false;
        });
        break;
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();

    final ts = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _messages.add(ChatMessage(text: text, from: "Me", ts: ts, isMe: true));
    });
    _scrollToBottom();

    try {
      await _dio.post(
        '$apiBase/message',
        data: {'from': widget.userData['id'], 'message': text},
      );
    } catch (e) {
      debugPrint("Send Error: $e");
    }
  }

  void _sendTypingStatus(int state) {
    _dio.post(
      '$apiBase/status',
      data: {'from': widget.userData['id'], 's': state},
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _peerName ?? "Searching...",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _status,
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Session Info',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Session Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session ID:',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        widget.userData['token'] ?? 'N/A',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isMe
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(msg.text),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Stranger is typing...",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => _sendTypingStatus(v.isEmpty ? 0 : 1),
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
