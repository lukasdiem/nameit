import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A WebUntis login kept in the phone's secure storage (Android Keystore /
/// iOS Keychain) for automatic sign-in. Several can be stored – one per
/// school or account – and one of them is active.
///
/// Preferably only the app key ([secret]) is stored – the same key the
/// WebUntis QR code contains. The password is kept only if the server
/// doesn't hand out an app key.
class UntisCredentials {
  UntisCredentials({
    required this.server,
    required this.school,
    required this.user,
    this.secret,
    this.password,
    this.schoolName,
  });

  final String server;
  final String school;
  final String user;
  final String? secret;
  final String? password;

  /// Display name of the school, e.g. "HTL Rankweil" (null until looked up).
  final String? schoolName;

  static const _storage = FlutterSecureStorage();
  static const _listKey = 'untis_accounts';
  static const _activeKey = 'untis_active';
  static const _legacyKey = 'untis_credentials'; // one account, before multi-account

  /// Identifies the account.
  String get id => '${server.toLowerCase()}/${school.toLowerCase()}/${user.toLowerCase()}';

  /// "HTL Rankweil" or the login name when no display name is known.
  String get label => schoolName ?? school;

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

  UntisCredentials copyWith({String? server, String? secret, String? password, String? schoolName}) =>
      UntisCredentials(
        server: server ?? this.server,
        school: school,
        user: user,
        secret: secret ?? this.secret,
        password: secret != null ? null : (password ?? this.password),
        schoolName: schoolName ?? this.schoolName,
      );

  Map<String, dynamic> toJson() => {
        'server': server,
        'school': school,
        'user': user,
        if (secret != null) 'secret': secret,
        if (password != null) 'password': password,
        if (schoolName != null) 'schoolName': schoolName,
      };

  factory UntisCredentials.fromJson(Map<String, dynamic> j) => UntisCredentials(
        server: j['server'],
        school: j['school'],
        user: j['user'],
        secret: j['secret'],
        password: j['password'],
        schoolName: j['schoolName'],
      );

  // ------------------------------------------------------------ storage

  /// All stored accounts, the active one first.
  static Future<List<UntisCredentials>> loadAll() async {
    try {
      var raw = await _storage.read(key: _listKey);
      if (raw == null) {
        // Move a login stored by an earlier version into the list.
        final legacy = await _storage.read(key: _legacyKey);
        if (legacy == null) return [];
        final c = UntisCredentials.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
        await _write([c], c.id);
        await _storage.delete(key: _legacyKey);
        raw = await _storage.read(key: _listKey);
      }
      final list = [
        for (final e in jsonDecode(raw!) as List) UntisCredentials.fromJson(e as Map<String, dynamic>),
      ];
      final active = await _storage.read(key: _activeKey);
      list.sort((a, b) => a.id == active ? -1 : b.id == active ? 1 : a.label.compareTo(b.label));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Adds or updates this account and makes it the active one.
  Future<void> saveAndActivate() async {
    final list = (await loadAll()).where((c) => c.id != id).toList()..add(this);
    await _write(list, id);
  }

  /// Removes this account. Returns the remaining ones, the new active first.
  Future<List<UntisCredentials>> remove() async {
    final list = (await loadAll()).where((c) => c.id != id).toList();
    await _write(list, list.isEmpty ? null : list.first.id);
    return list;
  }

  static Future<void> _write(List<UntisCredentials> list, String? activeId) async {
    await _storage.write(key: _listKey, value: jsonEncode([for (final c in list) c.toJson()]));
    if (activeId == null) {
      await _storage.delete(key: _activeKey);
    } else {
      await _storage.write(key: _activeKey, value: activeId);
    }
  }

  static Future<void> clearAll() async {
    await _storage.delete(key: _listKey);
    await _storage.delete(key: _activeKey);
    await _storage.delete(key: _legacyKey);
    await _storage.delete(key: 'untis_password'); // from early versions
  }
}
