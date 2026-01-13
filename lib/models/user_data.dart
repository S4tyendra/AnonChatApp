import 'package:hive_flutter/hive_flutter.dart';

class UserData {
  final String id;
  final String name;
  final String token;

  UserData({
    required this.id,
    required this.name,
    required this.token,
  });

  Map<String, String> toMap() => {
        'id': id,
        'token': token,
        'name': name,
      };
}

class UserDataAdapter extends TypeAdapter<UserData> {
  @override
  final int typeId = 0;

  @override
  UserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserData(
      id: fields[0] as String,
      name: fields[1] as String,
      token: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.token);
  }
}
