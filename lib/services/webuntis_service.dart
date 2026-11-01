import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'untis_mobile_api.dart';

/// Thin client for WebUntis.
///
/// What is well documented and used here:
///   JSON-RPC  POST /WebUntis/jsonrpc.do?school=…
///     authenticate, getSchoolyears, getCurrentSchoolyear, getKlassen,
///     getStudents, logout
///   REST      GET  /WebUntis/api/token/new   (JWT for newer endpoints)
///
/// What differs between schools / versions and is therefore configurable:
///   * which students belong to a class  -> [classStudents] tries the
///     timetable page config; if that fails the app lets you pick students
///     from the full list instead.
///   * the student photo URL             -> template set in Settings.
class WebUntisClient {
  WebUntisClient({required String server, required this.school})
      : host = normalizeHost(server);

  final String host;
  final String school;
  String? _sessionId;
  String? _jwt;
  int _rpcId = 0;

  bool get isLoggedIn => _sessionId != null;

  /// Accepts "nessa.webuntis.com", "https://nessa.webuntis.com/WebUntis/…".
  static String normalizeHost(String input) {
    var s = input.trim();
    if (!s.contains('://')) s = 'https://$s';
    return Uri.tryParse(s)?.host ?? input.trim();
  }

  /// Pulls server + school out of a pasted WebUntis login link, e.g.
  /// https://nessa.webuntis.com/WebUntis/?school=htl-demo#/basic/login
  static ({String server, String school})? parseLoginUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return null;
    var school = uri.queryParameters['school'];
    if (school == null && uri.fragment.contains('school=')) {
      school = Uri.splitQueryString(uri.fragment.split('?').last)['school'];
    }
    return (server: uri.host, school: school ?? '');
  }

  Map<String, String> get _cookies => {
        'Cookie': [
          if (_sessionId != null) 'JSESSIONID=$_sessionId',
          'schoolname="_${base64.encode(utf8.encode(school))}"',
        ].join('; '),
      };

  Future<dynamic> _rpc(String method, [Map<String, dynamic> params = const {}]) async {
    final uri = Uri.https(host, '/WebUntis/jsonrpc.do', {'school': school});
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', ..._cookies},
          body: jsonEncode({'id': '${++_rpcId}', 'method': method, 'params': params, 'jsonrpc': '2.0'}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw WebUntisException('HTTP ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['error'] != null) {
      final err = body['error'];
      final code = err is Map ? err['code'] : null;
      throw WebUntisException(err is Map ? '${err['message']} ($code)' : '$err', code: code);
    }
    return body['result'];
  }

  String? _user, _password, _secret;
  UntisMobileApi? _mobile;

  /// The mobile-app interface, available after logging in.
  UntisMobileApi get mobile => _mobile ??= UntisMobileApi(
        host: host,
        school: school,
        user: _user ?? '',
        password: _password ?? '',
        secret: _secret,
      );

  /// Signs in with username and password.
  Future<void> login(String user, String password) async {
    final r = await _rpc('authenticate', {'user': user, 'password': password, 'client': 'Namio'});
    _sessionId = r['sessionId'];
    _user = user;
    _password = password;
    _mobile = null;
    if (_sessionId == null) throw WebUntisException('Login failed');
  }

  /// Signs in with the app key from the WebUntis QR code (or a key stored
  /// after an earlier login). A successful call opens a normal web session,
  /// so everything else (classes, students, photos) works as after [login].
  Future<void> loginWithSecret(String user, String secret) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.https(host, '/WebUntis/jsonrpc_intern.do', {'m': 'getUserData2017', 'school': school, 'v': 'i2.2'});
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': 'namio',
            'jsonrpc': '2.0',
            'method': 'getUserData2017',
            'params': [
              {
                'auth': {'clientTime': now, 'user': user, 'otp': UntisMobileApi.totp(secret, now)},
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw WebUntisException('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['error'] != null) {
      final err = body['error'];
      throw WebUntisException(err is Map ? '${err['message']} (${err['code']})' : '$err',
          code: err is Map ? err['code'] : null);
    }
    final session = RegExp(r'JSESSIONID=([^;,\s]+)').firstMatch(res.headers['set-cookie'] ?? '')?.group(1);
    if (session == null) throw WebUntisException('No session');
    _sessionId = session;
    _user = user;
    _secret = secret;
    _password = null;
    _mobile = null;
  }

  /// The app key for automatic sign-in later, so the password needn't be
  /// stored. Null if the server doesn't hand it out.
  Future<String?> appSecret() async {
    if (_secret != null) return _secret;
    try {
      return _secret = await mobile.secret();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _rpc('logout');
    } catch (_) {}
    _sessionId = null;
    _jwt = null;
  }

  Future<List<UntisYear>> schoolYears() async {
    final r = await _rpc('getSchoolyears') as List;
    return r.map((e) => UntisYear.fromJson(e)).toList()..sort((a, b) => b.start.compareTo(a.start));
  }

  Future<UntisYear?> currentSchoolYear() async {
    try {
      final r = await _rpc('getCurrentSchoolyear');
      return r == null ? null : UntisYear.fromJson(r);
    } catch (_) {
      return null;
    }
  }

  Future<List<UntisClass>> classes(int schoolYearId) async {
    final r = await _rpc('getKlassen', {'schoolyearId': schoolYearId}) as List;
    return r.map((e) => UntisClass.fromJson(e)).where((c) => c.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// All students of the school (needs read rights on student master data).
  Future<List<UntisStudent>> allStudents() async {
    final r = await _rpc('getStudents') as List;
    return r.map((e) => UntisStudent.fromJson(e)).toList();
  }

  /// Students of one class. The JSON-RPC API has no class membership, so
  /// this uses the student-timetable page config of the WebUntis web UI.
  /// That list is filtered by class: without `filter.klasseId` the server
  /// answers with a default class only, so every request names the class.
  /// Throws [ClassRosterUnavailable] when the server doesn't provide it.
  Future<List<UntisStudent>> classStudents(int classId, DateTime date) async {
    final d = '${date.year}-${_two(date.month)}-${_two(date.day)}';
    final uri = Uri.https(host, '/WebUntis/api/public/timetable/weekly/pageconfig', {
      'type': '5',
      'id': '0',
      'date': d,
      'isMyTimetableSelected': 'false',
      'filter.klasseId': '$classId',
    });
    try {
      final res = await http.get(uri, headers: _cookies).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw ClassRosterUnavailable();
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final elements = ((body['data']?['elements'] as List?) ?? const []).whereType<Map>().toList();
      // Without a class id on each entry we can't be sure the list is
      // really this class, so we don't guess.
      if (elements.isEmpty || !elements.first.containsKey('klasseId')) {
        throw ClassRosterUnavailable();
      }
      final students = elements
          .where((e) => e['klasseId'] == classId)
          .map((e) => UntisStudent(
                id: e['id'],
                firstName: (e['forename'] ?? '').toString(),
                lastName: (e['longName'] ?? e['name'] ?? '').toString(),
              ))
          .toList();
      // The server ignored the filter and sent another class: never import
      // an empty class silently.
      if (students.isEmpty) throw ClassRosterUnavailable();
      return students;
    } on ClassRosterUnavailable {
      rethrow;
    } catch (_) {
      throw ClassRosterUnavailable();
    }
  }

  Future<String?> _token() async {
    if (_jwt != null) return _jwt;
    try {
      final res = await http.get(Uri.https(host, '/WebUntis/api/token/new'), headers: _cookies);
      if (res.statusCode == 200 && res.body.isNotEmpty) _jwt = res.body.trim();
    } catch (_) {}
    return _jwt;
  }

  /// Standard WebUntis photo address (cat=5 = student). Confirmed on
  /// htl-rankweil.webuntis.com. Settings can override it if a server differs.
  static const defaultPhotoTemplate = 'https://{server}/WebUntis/image.do?cat=5&id={id}';

  /// WebUntis answers students without a photo with a generic avatar.
  /// We fetch that avatar once (for an id that can't exist) and skip
  /// every photo that is byte-identical to it.
  Uint8List? _placeholder;
  bool _placeholderLoaded = false;

  Future<Uint8List?> _download(String template, int id) async {
    final url = template
        .replaceAll('{server}', host)
        .replaceAll('{school}', Uri.encodeComponent(school))
        .replaceAll('{id}', '$id');
    final token = await _token();
    final res = await http.get(Uri.parse(url), headers: {
      ..._cookies,
      if (token != null) 'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 20));
    final type = res.headers['content-type'] ?? '';
    if (res.statusCode != 200 || !type.startsWith('image/') || res.bodyBytes.length < 200) return null;
    return res.bodyBytes;
  }

  /// Downloads a student photo. Returns null if the student has none.
  /// An empty [template] uses [defaultPhotoTemplate].
  Future<Uint8List?> photo(String template, int studentId) async {
    final tpl = template.trim().isEmpty ? defaultPhotoTemplate : template.trim();
    if (!_placeholderLoaded) {
      _placeholderLoaded = true;
      try {
        _placeholder = await _download(tpl, -1);
      } catch (_) {}
    }
    final bytes = await _download(tpl, studentId);
    if (bytes == null) return null;
    if (_placeholder != null && _sameBytes(bytes, _placeholder!)) return null;
    return bytes;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class UntisYear {
  UntisYear({required this.id, required this.name, required this.start, required this.end});
  final int id;
  final String name;
  final DateTime start;
  final DateTime end;

  factory UntisYear.fromJson(Map<String, dynamic> j) => UntisYear(
        id: j['id'],
        name: j['name'].toString(),
        start: _date(j['startDate']),
        end: _date(j['endDate']),
      );

  /// A date inside this school year, preferring today.
  DateTime get sampleDate {
    final now = DateTime.now();
    if (now.isAfter(start) && now.isBefore(end)) return now;
    return start.add(const Duration(days: 14));
  }

  static DateTime _date(dynamic v) {
    final s = v.toString(); // yyyymmdd
    return DateTime(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)), int.parse(s.substring(6, 8)));
  }
}

class UntisClass {
  UntisClass({required this.id, required this.name, required this.longName, required this.active});
  final int id;
  final String name;
  final String longName;
  final bool active;

  factory UntisClass.fromJson(Map<String, dynamic> j) => UntisClass(
        id: j['id'],
        name: (j['name'] ?? '').toString(),
        longName: (j['longName'] ?? '').toString(),
        active: j['active'] ?? true,
      );
}

class UntisStudent {
  UntisStudent({required this.id, required this.firstName, required this.lastName});
  final int id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();

  factory UntisStudent.fromJson(Map<String, dynamic> j) => UntisStudent(
        id: j['id'],
        firstName: (j['foreName'] ?? '').toString(),
        lastName: (j['longName'] ?? j['name'] ?? '').toString(),
      );
}

class WebUntisException implements Exception {
  WebUntisException(this.message, {this.code});
  final String message;
  final dynamic code;

  /// -8504 = bad credentials, -8509/-8520 = no rights / not authenticated
  bool get isBadCredentials => code == -8504;
  bool get isNoRights => code == -8509 || code == -8520;

  @override
  String toString() => message;
}

class ClassRosterUnavailable implements Exception {}
