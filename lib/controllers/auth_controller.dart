import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/services/storage_service.dart';
import 'package:anonchatapp/services/api_service.dart';
import 'package:anonchatapp/pages/chat_page.dart';
import 'package:anonchatapp/pages/auth_page.dart';

class AuthController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final isLoading = false.obs;
  final isAuthenticated = false.obs;
  UserData? currentUser;

  HttpServer? _server;
  Completer<Map<String, dynamic>>? _authCompleter;

  @override
  void onInit() {
    super.onInit();
    checkAuth();
  }

  void checkAuth() {
    final user = StorageService.getUser();
    if (user != null) {
      currentUser = user;
      isAuthenticated.value = true;
    }
  }

  Future<void> startAuthFlow() async {
    isLoading.value = true;

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

      Get.to(() => const AuthWebViewPage());

      final accountData = await _authCompleter!.future;
      _server?.close();

      final sessionResponse = await _apiService.createSession(
        accountData['id'],
        accountData['auth'],
      );

      if (sessionResponse.statusCode == 200) {
        final sessionData = sessionResponse.data;
        final user = UserData(
          id: accountData['id'],
          name: accountData['name'] ?? 'Anonymous',
          token: sessionData['token'],
        );

        await StorageService.saveUser(user);
        currentUser = user;
        isAuthenticated.value = true;
        isLoading.value = false;

        Get.offAll(() => ChatPage());
      }
    } catch (e) {
      _server?.close();
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Authentication failed: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void cancelAuth() {
    _server?.close();
    isLoading.value = false;
  }

  Future<void> logout() async {
    await StorageService.clearUser();
    currentUser = null;
    isAuthenticated.value = false;
    Get.offAll(() => const AuthPage());
  }
}

class AuthWebViewPage extends StatefulWidget {
  const AuthWebViewPage({super.key});

  @override
  State<AuthWebViewPage> createState() => _AuthWebViewPageState();
}

class _AuthWebViewPageState extends State<AuthWebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiService.authWebUrl));
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(ApiService.authWebUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Get.find<AuthController>().cancelAuth();
            Get.back();
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your internet connection',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
