import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnonChatApp());
}

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
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  HttpServer? _server;
  bool _isLoading = false;
  bool _showWebView = false;
  bool _webViewLoading = true;
  bool _webViewError = false;
  String? _webViewErrorMessage;
  Map<String, dynamic>? _userData;
  String? _errorMessage;
  late AnimationController _pulseController;
  WebViewController? _webViewController;
  Completer<Map<String, dynamic>>? _authCompleter;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopServer();
    super.dispose();
  }

  Future<void> _stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _startAuthFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _webViewLoading = true;
      _webViewError = false;
      _webViewErrorMessage = null;
    });

    try {
      _authCompleter = Completer<Map<String, dynamic>>();

      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler((shelf.Request request) async {
            if (request.method == 'POST' && request.url.path == 'auth') {
              try {
                final body = await request.readAsString();
                final json = jsonDecode(body) as Map<String, dynamic>;

                if (_authCompleter != null && !_authCompleter!.isCompleted) {
                  _authCompleter!.complete(json);
                }

                return shelf.Response.ok(
                  'OK',
                  headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'text/plain',
                  },
                );
              } catch (e) {
                debugPrint('Auth parse error: $e');
                return shelf.Response.internalServerError(
                  body: 'Failed to parse: $e',
                  headers: {'Access-Control-Allow-Origin': '*'},
                );
              }
            }

            if (request.method == 'OPTIONS') {
              return shelf.Response.ok(
                '',
                headers: {
                  'Access-Control-Allow-Origin': '*',
                  'Access-Control-Allow-Methods': 'POST, OPTIONS',
                  'Access-Control-Allow-Headers': 'Content-Type',
                },
              );
            }

            return shelf.Response.notFound('Not found');
          });

      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        6364,
      );
      debugPrint('Auth server running on http://localhost:6364/auth');

      // Initialize WebView controller
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0F172A))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              debugPrint('Loading: $url');
              if (mounted) {
                setState(() {
                  _webViewLoading = true;
                  _webViewError = false;
                });
              }
            },
            onPageFinished: (url) {
              debugPrint('Loaded: $url');
              if (mounted) {
                setState(() {
                  _webViewLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              debugPrint('WebView error: ${error.description}');
              // Only show error for main frame failures
              if (error.isForMainFrame == true) {
                if (mounted) {
                  setState(() {
                    _webViewLoading = false;
                    _webViewError = true;
                    _webViewErrorMessage = error.description;
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://create-anon-account.devh.in/'));

      setState(() {
        _showWebView = true;
        _isLoading = false;
      });

      // Wait for auth callback
      final result = await _authCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Authentication timed out'),
      );

      await _stopServer();

      setState(() {
        _userData = result;
        _showWebView = false;
      });
    } catch (e) {
      await _stopServer();
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _showWebView = false;
      });
    }
  }

  void _logout() {
    setState(() {
      _userData = null;
      _errorMessage = null;
    });
  }

  void _cancelAuth() {
    _stopServer();
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.completeError('Cancelled by user');
    }
    setState(() {
      _showWebView = false;
      _isLoading = false;
    });
  }

  void _retryWebView() {
    setState(() {
      _webViewLoading = true;
      _webViewError = false;
      _webViewErrorMessage = null;
    });
    _webViewController?.loadRequest(
      Uri.parse('https://create-anon-account.devh.in/'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showWebView && _webViewController != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelAuth,
          ),
          title: const Text(
            'Sign In',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // WebView (hidden during loading/error)
            Opacity(
              opacity: (_webViewLoading || _webViewError) ? 0.0 : 1.0,
              child: WebViewWidget(controller: _webViewController!),
            ),

            // Loading overlay
            if (_webViewLoading)
              Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading authentication...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error overlay
            if (_webViewError)
              Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            size: 64,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Connection Failed',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _webViewErrorMessage ?? 'Unable to load the page',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _retryWebView,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _userData != null ? _buildUserProfile() : _buildLoginScreen(),
        ),
      ),
    );
  }

  Widget _buildLoginScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF6366F1).withOpacity(0.1),
                      const Color(0xFF6366F1).withOpacity(0.2),
                      _pulseController.value,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF6366F1,
                        ).withOpacity(0.2 * _pulseController.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 72,
                    color: Color(0xFF6366F1),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'AnonChat',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect anonymously. Chat freely.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 64),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startAuthFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF6366F1,
                  ).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Sign In to Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your identity stays anonymous',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Authenticated!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your session data',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _userData!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            color: const Color(0xFF6366F1).withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          color: Colors.white.withOpacity(0.1),
                          height: 1,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
