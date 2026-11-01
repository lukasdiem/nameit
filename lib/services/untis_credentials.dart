import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// WebUntis login kept in the phone's secure storage (Android Keystore /
/// iOS Keychain) for automatic sign-in.
///
/// Preferably only the app key ([secret]) is stored – the same key the
/// WebUntis QR code contains. The password is kept only if the server
/// doesn't hand out an app key.
class UntisCredentials {
  UntisCredentials({required this.server, required this.school, required this.user, this.secret, this.password});

  final String server;
  final String school;
  final String user;
  final String? secret;
  final String? password;

  static const _storage = FlutterSecureStorage();
  static const _key = 'untis_credentials';

  /// Parses the QR code from WebUntis
  /// (Profil → Freigaben → Zugriff über Untis Mobile → Anzeigen), e.g.
  /// `untis://setschool?url=xyz.webuntis.com&school=myschool&user=alice&key=ABC123`.
  static UntisCredentials? fromQr(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'untis') return null;
    final q = uri.queryParameters;
    final server = q['url'], school = q['school'], user = q['user'], key = q['key'];
    if ([server, school, user, key].any((v) => v == null || v.isEmpty)) return null;
    return UntisCredentials(server: server!, school: school!, user: user!, secret: key);
  }

  UntisCredentials copyWith({String? secret, String? password}) => UntisCredentials(
        server: server,
        school: school,
        user: user,
        secret: secret ?? this.secret,
        password: secret != null ? null : (password ?? this.password),
      );

  Map<String, dynamic> toJson() => {
        'server': server,
        'school': school,
        'user': user,
        if (secret != null) 'secret': secret,
        if (password != null) 'password': password,
      };

  static Future<UntisCredentials?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return UntisCredentials(
        server: j['server'],
        school: j['school'],
        user: j['user'],
        secret: j['secret'],
        password: j['password'],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save() => _storage.write(key: _key, value: jsonEncode(toJson()));

  static Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: 'untis_password'); // from earlier versions
  }
}
