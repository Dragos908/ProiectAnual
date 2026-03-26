import 'package:shared_preferences/shared_preferences.dart';

class User {
  String _name;
  final String id;

  static const _keyId   = 'guest_uid';
  static const _keyName = 'guest_name';

  String get uid  => id;
  String get name => _name;

  User({String name = '', required this.id}) : _name = name;

  static Future<User> loadGuest() async {
    final prefs = await SharedPreferences.getInstance();
    String uid = prefs.getString(_keyId) ?? _generateGuestId();
    await prefs.setString(_keyId, uid);
    return User(id: uid, name: prefs.getString(_keyName) ?? '');
  }

  static String _generateGuestId() =>
      'guest_${DateTime.now().millisecondsSinceEpoch}';

  factory User.guest() => User(name: '', id: 'guest_placeholder');

  Future<void> updateNamePersistent(String newName) async {
    _name = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, newName);
  }
}