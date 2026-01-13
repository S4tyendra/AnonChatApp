import 'package:hive_flutter/hive_flutter.dart';
import 'package:anonchatapp/models/user_data.dart';

class StorageService {
  static const String _userBox = 'user_box';
  static const String _userKey = 'current_user';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserDataAdapter());
    await Hive.openBox<UserData>(_userBox);
  }

  static Box<UserData> get _box => Hive.box<UserData>(_userBox);

  static Future<void> saveUser(UserData user) async {
    await _box.put(_userKey, user);
  }

  static UserData? getUser() {
    return _box.get(_userKey);
  }

  static Future<void> clearUser() async {
    await _box.delete(_userKey);
  }

  static bool hasUser() {
    return _box.containsKey(_userKey);
  }
}
