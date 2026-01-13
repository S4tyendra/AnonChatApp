import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

class ApiService {
  static const String baseUrl = 'https://anon-chatapi.devh.in';
  static const String authWebUrl = 'https://create-anon-account.devh.in/';

  final Dio _dio;
  HttpServer? _authServer;
  Completer<Map<String, dynamic>>? _authCompleter;

  ApiService() : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<Map<String, dynamic>> startAuthServer() async {
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

    _authServer = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      6364,
    );

    return _authCompleter!.future;
  }

  void stopAuthServer() {
    _authServer?.close();
    _authServer = null;
  }

  Future<Response<dynamic>> createSession(String id, String auth) async {
    return _dio.post('/paid', data: {'id': id, 'auth': auth});
  }

  Future<Response<ResponseBody>> connectStream(String token, String name) {
    final url = '$baseUrl/stream?name=$name&token=$token';
    return _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
  }

  Future<Response<dynamic>> sendMessage(String from, String message) {
    return _dio.post('/message', data: {'from': from, 'message': message});
  }

  Future<void> sendTypingStatus(String from, int state) {
    return _dio.post('/status', data: {'from': from, 's': state});
  }

  Future<void> disconnect(String userId) {
    return _dio.post('/disconnect', data: {'userId': userId});
  }
}
