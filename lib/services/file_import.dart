import 'dart:convert';
import 'dart:typed_data';

// `show`: csv also exports a top-level `excel` codec that would clash with package:excel.
import 'package:csv/csv.dart' show CsvDecoder;
import 'package:excel/excel.dart';

/// One parsed row from a CSV/Excel file.
class ImportRow {
  ImportRow(this.firstName, this.lastName, this.className);
  final String firstName;
  final String lastName;
  final String? className;
}

class ImportParseResult {
  ImportParseResult(this.rows, {required this.hasClassColumn});
  final List<ImportRow> rows;
  final bool hasClassColumn;
}

/// Reads student lists exported from WebUntis (or any spreadsheet).
/// Recognised headers (case-insensitive, German or English):
///   first name: Vorname, First name, Firstname, Forename, foreName
///   last name:  Nachname, Familienname, Last name, Lastname, Surname, Name, longName
///   class:      Klasse, Class, Klassen
/// A single "Name" column without a first-name column is split at the last space.
class FileImporter {
  static ImportParseResult parse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    final table = (lower.endsWith('.xlsx') || lower.endsWith('.xls')) ? _readExcel(bytes) : _readCsv(bytes);
    return _interpret(table);
  }

  static List<List<String>> _readCsv(Uint8List bytes) {
    var text = _decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    final firstLine = text.split('\n').first;
    final delimiter = [';', ',', '\t']
        .reduce((a, b) => firstLine.split(a).length >= firstLine.split(b).length ? a : b);
    // dynamicTyping is off by default, so values like "007" stay text.
    final rows = CsvDecoder(fieldDelimiter: delimiter).convert(text.replaceAll('\r\n', '\n'));
    return rows.map((r) => r.map((c) => c.toString().trim()).toList()).toList();
  }

  /// Excel CSVs from German Windows are often Latin-1, not UTF-8.
  static String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static List<List<String>> _readExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables.values.first;
    return sheet.rows.map((r) => r.map((c) => c?.value?.toString().trim() ?? '').toList()).toList();
  }

  static const _first = ['vorname', 'first name', 'firstname', 'forename', 'given name'];
  static const _last = ['nachname', 'familienname', 'last name', 'lastname', 'surname', 'longname', 'family name'];
  static const _name = ['name', 'schüler', 'schueler', 'student', 'schüler*in'];
  static const _class = ['klasse', 'class', 'klassen', 'klassenname'];

  static int _find(List<String> header, List<String> keys) =>
      header.indexWhere((h) => keys.contains(h.toLowerCase().trim()));

  static ImportParseResult _interpret(List<List<String>> table) {
    final rows = table.where((r) => r.any((c) => c.isNotEmpty)).toList();
    if (rows.isEmpty) return ImportParseResult([], hasClassColumn: false);

    // The header is usually in the first row, but some exports have a title line.
    var headerIdx = 0;
    for (var i = 0; i < rows.length && i < 5; i++) {
      final h = rows[i];
      if (_find(h, _first) >= 0 || _find(h, _last) >= 0 || _find(h, _name) >= 0) {
        headerIdx = i;
        break;
      }
    }
    final header = rows[headerIdx];
    var iFirst = _find(header, _first);
    var iLast = _find(header, _last);
    final iName = _find(header, _name);
    final iClass = _find(header, _class);
    var dataStart = headerIdx + 1;

    // "Name" + "Vorname" → Name is the last name.
    if (iLast < 0 && iFirst >= 0 && iName >= 0) iLast = iName;

    // No header at all: assume "last name, first name[, class]".
    if (iFirst < 0 && iLast < 0 && iName < 0) {
      iLast = 0;
      iFirst = header.length > 1 ? 1 : -1;
      dataStart = 0;
    }

    final out = <ImportRow>[];
    for (final r in rows.skip(dataStart)) {
      String at(int i) => i >= 0 && i < r.length ? r[i] : '';
      String first, last;
      if (iFirst >= 0 || iLast >= 0) {
        first = at(iFirst);
        last = at(iLast);
      } else {
        // Only a full-name column.
        final full = at(iName);
        final cut = full.lastIndexOf(' ');
        first = cut > 0 ? full.substring(0, cut) : full;
        last = cut > 0 ? full.substring(cut + 1) : '';
      }
      if (first.isEmpty && last.isEmpty) continue;
      final cls = at(iClass);
      out.add(ImportRow(first, last, cls.isEmpty ? null : cls));
    }
    return ImportParseResult(out, hasClassColumn: iClass >= 0);
  }
}
