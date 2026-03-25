import 'package:shared_preferences/shared_preferences.dart';

class User {
  String _name;
  final String id;

  static const _keyGuestId   = 'guest_uid';
  static const _keyGuestName = 'guest_name';

  /// Alias pentru compatibilitate cu Firebase (`user.uid`)
  String get uid => id;

  /// Numele curent al utilizatorului (poate fi gol)
  String get name => _name;

  User({
    String name = '',
    required this.id,
  }) : _name = name;

  /// Încarcă (sau creează) guest-ul cu ID persistent între sesiuni.
  static Future<User> loadGuest() async {
    final prefs = await SharedPreferences.getInstance();

    String? uid = prefs.getString(_keyGuestId);
    if (uid == null) {
      uid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyGuestId, uid);
    }

    final name = prefs.getString(_keyGuestName) ?? '';
    return User(id: uid, name: name);
  }

  /// Folosit la migrare: setează manual un guest ID existent (o singură dată).
  static Future<void> migrateGuestId(String existingId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyGuestId) == null) {
      await prefs.setString(_keyGuestId, existingId);
    }
  }

  /// Păstrat pentru compatibilitate — folosit în main.dart ca fallback sincronic.
  factory User.guest() {
    return User(
      name: '',
      id: 'guest_placeholder',
    );
  }

  /// Actualizează numele la runtime și îl salvează persistent.
  Future<void> updateNamePersistent(String newName) async {
    _name = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGuestName, newName);
  }
}