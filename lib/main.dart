import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anonchatapp/services/storage_service.dart';
import 'package:anonchatapp/services/api_service.dart';
import 'package:anonchatapp/controllers/auth_controller.dart';
import 'package:anonchatapp/controllers/settings_controller.dart';
import 'package:anonchatapp/pages/auth_page.dart';
import 'package:anonchatapp/pages/chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  Get.put(ApiService());
  Get.put(AuthController());
  Get.put(SettingsController());

  runApp(const AnonChatApp());
}

class AnonChatApp extends StatelessWidget {
  const AnonChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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

class MainGate extends StatelessWidget {
  const MainGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Obx(() {
      if (authController.isAuthenticated.value) {
        return ChatPage();
      }
      return const AuthPage();
    });
  }
}
