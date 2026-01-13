import 'package:get/get.dart';
import 'package:anonchatapp/models/user_data.dart';
import 'package:anonchatapp/services/storage_service.dart';
import 'package:anonchatapp/services/api_service.dart';
import 'package:anonchatapp/pages/chat_page.dart';
import 'package:anonchatapp/pages/auth_webview_page.dart';

class AuthController extends GetxController {
  final ApiService _apiService = Get.find<ApiService>();

  final isLoading = false.obs;
  final isAuthenticated = false.obs;
  UserData? currentUser;

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
      _apiService.startAuthServer().then((accountData) async {
        _apiService.stopAuthServer();

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

          Get.off(() => ChatPage());
        }
      });

      Get.to(() => const AuthWebViewPage());
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', 'Authentication failed: $e');
    }
  }

  void onWebViewAuthComplete() {
    isLoading.value = true;
  }

  void onWebViewAuthError(String error) {
    isLoading.value = false;
    _apiService.stopAuthServer();
    Get.back();
    Get.snackbar('Error', error);
  }

  Future<void> logout() async {
    await StorageService.clearUser();
    currentUser = null;
    isAuthenticated.value = false;
  }
}
