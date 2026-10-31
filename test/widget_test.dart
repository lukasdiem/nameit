import 'package:flutter_test/flutter_test.dart';
import 'package:namio/services/file_import.dart';
import 'package:namio/services/webuntis_service.dart';
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

  test('WebUntis login link is parsed', () {
    final p = WebUntisClient.parseLoginUrl('https://nessa.webuntis.com/WebUntis/?school=htl-demo#/basic/login');
    expect(p?.server, 'nessa.webuntis.com');
    expect(p?.school, 'htl-demo');
  });
}
