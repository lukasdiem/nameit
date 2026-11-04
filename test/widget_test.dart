import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nameit/services/demo_data.dart';
import 'package:nameit/services/file_import.dart';
import 'package:nameit/services/webuntis_service.dart';
import 'package:nameit/services/untis_mobile_api.dart';
import 'package:nameit/data/app_store.dart';
import 'package:nameit/models/models.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  test('CSV with German headers and semicolons', () {
    final csv = 'Klasse;Nachname;Vorname\n3B;Huber;Max\n3B;Berger;Anna\n';
    final r = FileImporter.parse('liste.csv', Uint8List.fromList(utf8.encode(csv)));
    expect(r.rows.length, 2);
    expect(r.hasClassColumn, true);
    expect(r.rows.first.firstName, 'Max');
    expect(r.rows.first.lastName, 'Huber');
    expect(r.rows.first.className, '3B');
  });

  test('CSV with commas, quotes, Windows line endings and BOM', () {
    final csv = '﻿Nachname,Vorname,Klasse\r\n"Huber, Jr.",Max,3B\r\n"O""Brien",Anna,007\r\n';
    final r = FileImporter.parse('liste.csv', Uint8List.fromList(utf8.encode(csv)));
    expect(r.rows.length, 2);
    expect(r.rows[0].lastName, 'Huber, Jr.');
    expect(r.rows[0].firstName, 'Max');
    expect(r.rows[1].lastName, 'O"Brien');
    expect(r.rows[1].className, '007'); // stays text, not the number 7
  });

  test('Latin-1 CSV (Excel on German Windows)', () {
    final csv = 'Klasse;Nachname;Vorname\n4A;Müller;Jürgen\n';
    final r = FileImporter.parse('liste.csv', Uint8List.fromList(latin1.encode(csv)));
    expect(r.rows.single.lastName, 'Müller');
    expect(r.rows.single.firstName, 'Jürgen');
  });

  test('WebUntis login link is parsed', () {
    final p = WebUntisClient.parseLoginUrl('https://nessa.webuntis.com/WebUntis/?school=htl-demo#/basic/login');
    expect(p?.server, 'nessa.webuntis.com');
    expect(p?.school, 'htl-demo');
  });

  test('Mobile login code matches RFC 6238 test vectors', () {
    // Secret "12345678901234567890" in Base32; expected codes are the last
    // six digits of the RFC's 8-digit SHA1 values.
    const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    expect(UntisMobileApi.totp(secret, 59 * 1000), 287082);
    expect(UntisMobileApi.totp(secret, 1111111109 * 1000), 81804);
    expect(UntisMobileApi.totp(secret, 1234567890 * 1000), 5924);
    expect(UntisMobileApi.totp(secret.toLowerCase(), 2000000000 * 1000), 279037);
  });

  test('Badges unlock from a finished game', () {
    final store = AppStore();
    store.gamesByMode['gMillion'] = 1;
    final fresh = store.checkBadges(GameResult(
      modeTitleKey: 'gMillion',
      correct: 15,
      total: 15,
      xp: 300,
      missed: const [],
      score: 1000000,
    ));
    final ids = fresh.map((b) => b.id).toSet();
    expect(ids, containsAll(['firstGame', 'millionaire', 'perfect']));
    expect(ids.contains('streak3'), isFalse);
    // Unlocked badges are not reported twice.
    expect(store.checkBadges().map((b) => b.id), isNot(contains('millionaire')));
  });

  test('Demo class is bundled with every avatar', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final rows = (await rootBundle.loadString(DemoData.csvAsset))
        .split('\n')
        .skip(1)
        .map((l) => l.trim().split(';'))
        .where((c) => c.length >= 4)
        .toList();
    expect(rows.length, 28);
    expect(rows.map((c) => c[0]).toSet(), {'3B', '4A'});
    for (final c in rows) {
      expect((await rootBundle.load('${DemoData.avatarDir}/${c[3]}')).lengthInBytes, greaterThan(1000));
    }
  });

  test('Same class name in two schools stays apart, grouped by school', () {
    final store = AppStore();
    final year = store.addYear('2026/27');
    final a = AppStore.schoolKey('htl-rankweil.webuntis.com', 'htl-rankweil');
    final b = AppStore.schoolKey('bg.webuntis.com', 'bg-feldkirch');
    store.setSchoolName(a, 'HTL Rankweil');
    final c1 = store.addClass(year.id, '3B', untisId: 7, school: a);
    final c2 = store.addClass(year.id, '3B', untisId: 7, school: b);
    store.addClass(year.id, 'Hand', school: null);
    expect(c1.id, isNot(c2.id));
    expect(store.addClass(year.id, '3B', untisId: 7, school: a).id, c1.id);
    // Years are shared by name, whatever the WebUntis year id.
    expect(store.addYear('2026/27', untisId: 99).id, year.id);
    final groups = store.classesBySchool(year.id);
    expect(groups.map((g) => g.$1), [b, a, null]); // bg-feldkirch < HTL Rankweil, no school last
    expect(store.classLabel(c1), '3B · HTL Rankweil');
  });

  test('Stats count per school year', () {
    final store = AppStore();
    store.days['2025-10-01'] = [10, 8]; // older entry: XP = 10 per correct answer
    store.days['2026-09-15'] = [5, 4, 50, 2];
    store.days['2027-07-31'] = [1, 1, 10, 1];
    store.days['2027-08-01'] = [3, 3, 30, 1]; // already next school year
    final y26 = store.totalsIn('2026/27');
    expect(y26.answers, 6);
    expect(y26.xp, 60);
    expect(y26.games, 3);
    expect(store.totalsIn('2025/26').xp, 80);
    expect(AppStore.yearRange('2026/27').start, DateTime(2026, 8, 1));
  });
}
