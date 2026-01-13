import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'https://anon-chatapi.devh.in';
  static const String authWebUrl = 'https://create-anon-account.devh.in/';

  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(baseUrl: baseUrl));

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
