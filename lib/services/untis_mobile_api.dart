import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'webuntis_service.dart';

/// The interface the official Untis Mobile app uses
/// (`/WebUntis/jsonrpc_intern.do`). Method names and parameters follow the
/// open-source BetterUntis app.
///
/// Why it's needed: the web interface only gives a teacher the full student
/// list of the class they are Klassenvorstand of. The mobile interface gives
/// every teacher the students of each lesson they teach (that's what the
/// attendance check in the app shows), so we collect students lesson by
/// lesson and group them by class.
class UntisMobileApi {
  UntisMobileApi({
    required this.host,
    required this.school,
    required this.user,
    required this.password,
    String? secret,
  }) : _secret = secret;

  final String host;
  final String school;
  final String user;
  final String password;

  String? _secret;

  Uri get _uri => Uri.https(host, '/WebUntis/jsonrpc_intern.do', {'school': school});

  Future<dynamic> _call(String method, Map<String, dynamic> params) async {
    final res = await http
        .post(
          _uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': 'untis-mobile-android',
            'jsonrpc': '2.0',
            'method': method,
            'params': [params],
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw WebUntisException('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && body['error'] != null) {
      final err = body['error'];
      throw WebUntisException(err is Map ? '${err['message']} (${err['code']})' : '$err',
          code: err is Map ? err['code'] : null);
    }
    return body['result'];
  }

  /// The app key (same as in the WebUntis QR code). Fetched once with the
  /// password unless it was given to the constructor.
  Future<String> secret() async {
    _secret ??= (await _call('getAppSharedSecret', {'userName': user, 'password': password}))?.toString();
    if (_secret == null || _secret!.isEmpty) throw WebUntisException('No app secret');
    return _secret!;
  }

  /// One-time code the mobile interface expects with every call.
  Future<Map<String, dynamic>> _auth() async {
    final key = await secret();
    final now = DateTime.now().millisecondsSinceEpoch;
    return {'user': user, 'otp': totp(key, now), 'clientTime': now};
  }

  /// Students the logged-in teacher teaches around [around], grouped by
  /// class. Lessons shared by several classes (e.g. religion 3A + 3B) are
  /// resolved per student where possible; the rest form a combined group.
  Future<TeachingGroups> teachingGroups(DateTime around) async {
    final userData = await _call('getUserData2017', {
      'elementId': 0,
      'deviceOs': 'AND',
      'deviceOsVersion': '',
      'auth': await _auth(),
    });
    final me = userData['userData'];
    if (me == null || me['elemType'] != 'TEACHER') throw WebUntisException('Not a teacher account');
    final classNames = <int, String>{
      for (final k in (userData['masterData']?['klassen'] as List? ?? const []))
        if (k is Map) (k['id'] as num).toInt(): (k['name'] ?? '').toString(),
    };

    // Two weeks back and forward covers fortnightly lessons.
    String d(DateTime x) => '${x.year}-${_two(x.month)}-${_two(x.day)}';
    final tt = await _call('getTimetable2017', {
      'id': me['elemId'],
      'type': 'TEACHER',
      'startDate': d(around.subtract(const Duration(days: 14))),
      'endDate': d(around.add(const Duration(days: 14))),
      'masterDataTimestamp': 0,
      'timetableTimestamp': 0,
      'timetableTimestamps': [],
      'auth': await _auth(),
    });
    for (final k in (tt['masterData']?['klassen'] as List? ?? const [])) {
      if (k is Map) classNames[(k['id'] as num).toInt()] ??= (k['name'] ?? '').toString();
    }

    // One period per lesson is enough: the closest regular one to [around],
    // preferring periods that already happened.
    final best = <int, ({int ttId, Set<int> classes, int score})>{};
    for (final p in (tt['timetable']?['periods'] as List? ?? const [])) {
      if (p is! Map) continue;
      final states = (p['is'] as List? ?? const []).map((e) => '$e').toSet();
      if (states.contains('CANCELLED')) continue;
      final classes = <int>{
        for (final e in (p['elements'] as List? ?? const []))
          if (e is Map && e['type'] == 'CLASS') (e['id'] as num).toInt(),
      };
      if (classes.isEmpty) continue;
      final start = DateTime.tryParse('${p['startDateTime']}'.replaceAll('Z', '')) ?? around;
      final diff = start.difference(around).inHours;
      final score = diff <= 0 ? -diff : 10000 + diff; // past first, then nearest future
      final lessonId = (p['lessonId'] as num? ?? p['id'] as num).toInt();
      final cur = best[lessonId];
      if (cur == null || score < cur.score) {
        best[lessonId] = (ttId: (p['id'] as num).toInt(), classes: classes, score: score);
      }
    }
    if (best.isEmpty) return TeachingGroups(const {}, classNames);

    // Ask for the student lists in small batches.
    final names = <int, UntisStudent>{};
    final classSetsOf = <int, List<Set<int>>>{}; // student -> class sets of their lessons
    final periods = best.values.toList();
    for (var i = 0; i < periods.length; i += 20) {
      final batch = periods.sublist(i, i + 20 > periods.length ? periods.length : i + 20);
      dynamic r;
      try {
        r = await _call('getPeriodData2017', {
          'ttIds': [for (final p in batch) p.ttId],
          'auth': await _auth(),
        });
      } on WebUntisException {
        continue; // e.g. no right for one of these lessons
      }
      for (final s in (r['referencedStudents'] as List? ?? const [])) {
        if (s is! Map) continue;
        final id = (s['id'] as num).toInt();
        names[id] = UntisStudent(
          id: id,
          firstName: (s['firstName'] ?? '').toString(),
          lastName: (s['lastName'] ?? '').toString(),
        );
      }
      final byTt = (r['dataByTTId'] as Map?) ?? const {};
      for (final p in batch) {
        final data = byTt['${p.ttId}'];
        if (data is! Map) continue;
        for (final sid in (data['studentIds'] as List? ?? const [])) {
          classSetsOf.putIfAbsent((sid as num).toInt(), () => []).add(p.classes);
        }
      }
    }

    // A student belongs to the class shared by all lessons they appear in.
    final groups = <String, TeachingGroup>{};
    classSetsOf.forEach((sid, sets) {
      final student = names[sid];
      if (student == null) return;
      var common = sets.first.toSet();
      for (final s in sets.skip(1)) {
        common = common.intersection(s);
      }
      if (common.isEmpty) {
        // Contradicting lessons: fall back to the class seen most often.
        final count = <int, int>{};
        for (final s in sets) {
          for (final c in s) {
            count[c] = (count[c] ?? 0) + 1;
          }
        }
        final top = count.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        common = {top};
      }
      final ids = common.toList()..sort();
      final key = ids.join('+');
      groups
          .putIfAbsent(
            key,
            () => TeachingGroup(
              classIds: ids,
              name: (ids.map((c) => classNames[c] ?? '$c').toList()..sort()).join(' + '),
              students: [],
            ),
          )
          .students
          .add(student);
    });
    return TeachingGroups(groups, classNames);
  }

  // ------------------------------------------------------------ TOTP

  /// RFC 6238 time-based one-time password (HMAC-SHA1, 30 s, 6 digits),
  /// as the Untis Mobile app computes it.
  static int totp(String base32Secret, int millis) {
    final key = base32Decode(base32Secret);
    var counter = millis ~/ 30000;
    final msg = Uint8List(8);
    for (var i = 7; i >= 0; i--) {
      msg[i] = counter & 0xff;
      counter >>= 8;
    }
    final h = Hmac(sha1, key).convert(msg).bytes;
    final o = h[19] & 0x0f;
    final bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
    return bin % 1000000;
  }

  static List<int> base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in input.toUpperCase().split('')) {
      final v = alphabet.indexOf(ch);
      if (v < 0) continue; // padding, spaces
      buffer = ((buffer << 5) | v) & 0xffff;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return out;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class TeachingGroup {
  TeachingGroup({required this.classIds, required this.name, required this.students});

  /// One id for a normal class, several for a lesson shared by classes.
  final List<int> classIds;
  final String name;
  final List<UntisStudent> students;

  bool get isMixed => classIds.length > 1;
}

class TeachingGroups {
  TeachingGroups(this.byKey, this.classNames);
  final Map<String, TeachingGroup> byKey;
  final Map<int, String> classNames;

  TeachingGroup? forClass(int classId) => byKey['$classId'];
  Iterable<TeachingGroup> get mixed => byKey.values.where((g) => g.isMixed);
  bool get isEmpty => byKey.isEmpty;
}
