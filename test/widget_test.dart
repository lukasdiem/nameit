import 'package:flutter_test/flutter_test.dart';
import 'package:nameit/services/file_import.dart';
import 'package:nameit/services/webuntis_service.dart';
import 'package:nameit/services/untis_mobile_api.dart';
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

  test('Mobile login code matches RFC 6238 test vectors', () {
    // Secret "12345678901234567890" in Base32; expected codes are the last
    // six digits of the RFC's 8-digit SHA1 values.
    const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    expect(UntisMobileApi.totp(secret, 59 * 1000), 287082);
    expect(UntisMobileApi.totp(secret, 1111111109 * 1000), 81804);
    expect(UntisMobileApi.totp(secret, 1234567890 * 1000), 5924);
    expect(UntisMobileApi.totp(secret.toLowerCase(), 2000000000 * 1000), 279037);
  });
}
