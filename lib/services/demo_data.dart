import 'package:flutter/services.dart';

import '../data/app_store.dart';

/// The demo class from the documentation (docs/demo): 28 invented students in
/// classes 3B and 4A with drawn avatars. Bundled with the app, so it can be
/// tried without any real student data.
class DemoData {
  static const csvAsset = 'docs/demo/demo-classes.csv';
  static const avatarDir = 'docs/demo/avatars';

  /// Name of the school year the demo classes go into – kept apart from real
  /// classes, and deleted in one go via the school year's menu.
  static const yearName = 'Demo';

  /// Loads the demo classes with photos. Loading twice doesn't duplicate
  /// anything. Returns the class names.
  static Future<List<String>> load(AppStore store) async {
    final csv = await rootBundle.loadString(csvAsset);
    final year = store.addYear(yearName);
    final classIds = <String, String>{};

    // Klasse;Nachname;Vorname;Foto
    for (final line in csv.split('\n').skip(1)) {
      final c = line.trim().split(';');
      if (c.length < 4 || c[0].isEmpty) continue;
      final classId = classIds[c[0]] ??= store.addClass(year.id, c[0]).id;
      final s = store.upsertStudent(classId: classId, firstName: c[2], lastName: c[1], notify: false);
      if (!s.hasPhoto) {
        try {
          final bytes = await rootBundle.load('$avatarDir/${c[3]}');
          await store.setPhoto(s, bytes.buffer.asUint8List(), notify: false);
        } catch (_) {
          // A missing picture just leaves this student without a photo.
        }
      }
    }
    store.commit();
    return classIds.keys.toList();
  }
}
