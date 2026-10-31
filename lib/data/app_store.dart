import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Single source of truth for the app. Keeps everything in memory and
/// writes it to one JSON file. Photos live as files in a `photos` folder.
class AppStore extends ChangeNotifier {
  final List<SchoolYear> years = [];
  final List<SchoolClass> classes = [];
  final List<Student> students = [];
  AppSettings settings = AppSettings();

  int xp = 0;
  int streak = 0;
  String? lastPlayedDay; // yyyy-mm-dd

  late Directory _docs;
  late Directory photoDir;
  final _rnd = Random();

  File get _dataFile => File('${_docs.path}/namio_data.json');

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    _docs = await getApplicationDocumentsDirectory();
    photoDir = Directory('${_docs.path}/photos');
    if (!photoDir.existsSync()) photoDir.createSync(recursive: true);

    if (_dataFile.existsSync()) {
      try {
        final j = jsonDecode(await _dataFile.readAsString()) as Map<String, dynamic>;
        years.addAll((j['years'] as List? ?? []).map((e) => SchoolYear.fromJson(e)));
        classes.addAll((j['classes'] as List? ?? []).map((e) => SchoolClass.fromJson(e)));
        students.addAll((j['students'] as List? ?? []).map((e) => Student.fromJson(e)));
        settings = AppSettings.fromJson(j['settings'] ?? {});
        xp = j['xp'] ?? 0;
        streak = j['streak'] ?? 0;
        lastPlayedDay = j['lastPlayedDay'];
      } catch (e) {
        debugPrint('Could not read data file: $e');
      }
    }
  }

  Future<void> _save() async {
    final j = {
      'version': 1,
      'years': years.map((e) => e.toJson()).toList(),
      'classes': classes.map((e) => e.toJson()).toList(),
      'students': students.map((e) => e.toJson()).toList(),
      'settings': settings.toJson(),
      'xp': xp,
      'streak': streak,
      'lastPlayedDay': lastPlayedDay,
    };
    // Write to a temp file first so a crash never leaves a half-written file.
    final tmp = File('${_dataFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(j));
    await tmp.rename(_dataFile.path);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

  // ---------------------------------------------------------------- queries

  List<SchoolYear> get yearsSorted => [...years]..sort((a, b) => b.name.compareTo(a.name));

  List<SchoolClass> classesOf(String yearId) =>
      classes.where((c) => c.yearId == yearId).toList()..sort((a, b) => a.name.compareTo(b.name));

  List<Student> studentsOf(String classId) => students.where((s) => s.classId == classId).toList()
    ..sort((a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));

  SchoolClass? classById(String id) => classes.where((c) => c.id == id).firstOrNull;
  SchoolYear? yearById(String id) => years.where((y) => y.id == id).firstOrNull;

  /// 0..1 – average Leitner level of the class.
  double mastery(String classId) {
    final list = studentsOf(classId);
    if (list.isEmpty) return 0;
    return list.fold<int>(0, (a, s) => a + s.level) / (list.length * Student.maxLevel);
  }

  File? photoOf(Student s) => s.photoFile == null ? null : File('${photoDir.path}/${s.photoFile}');

  // ---------------------------------------------------------------- years & classes

  SchoolYear addYear(String name, {int? untisId}) {
    final existing = years.where((y) => (untisId != null && y.untisId == untisId) || y.name == name).firstOrNull;
    if (existing != null) {
      existing.untisId ??= untisId;
      return existing;
    }
    final y = SchoolYear(id: newId(), name: name, untisId: untisId);
    years.add(y);
    _changed();
    return y;
  }

  void renameYear(SchoolYear y, String name) {
    y.name = name;
    _changed();
  }

  void deleteYear(SchoolYear y) {
    for (final c in classesOf(y.id)) {
      _deleteClassNoSave(c);
    }
    years.remove(y);
    _changed();
  }

  SchoolClass addClass(String yearId, String name, {int? untisId}) {
    final existing = classes
        .where((c) => c.yearId == yearId && ((untisId != null && c.untisId == untisId) || c.name == name))
        .firstOrNull;
    if (existing != null) {
      existing.untisId ??= untisId;
      return existing;
    }
    final c = SchoolClass(id: newId(), yearId: yearId, name: name, untisId: untisId);
    classes.add(c);
    _changed();
    return c;
  }

  void renameClass(SchoolClass c, String name) {
    c.name = name;
    _changed();
  }

  void deleteClass(SchoolClass c) {
    _deleteClassNoSave(c);
    _changed();
  }

  void _deleteClassNoSave(SchoolClass c) {
    for (final s in studentsOf(c.id)) {
      photoOf(s)?.deleteSilently();
    }
    students.removeWhere((s) => s.classId == c.id);
    classes.remove(c);
  }

  // ---------------------------------------------------------------- students

  /// Adds a student, or updates the existing one (matched by WebUntis id or
  /// by name) so learning progress survives a re-import.
  Student upsertStudent({
    required String classId,
    required String firstName,
    required String lastName,
    int? untisId,
    bool notify = true,
  }) {
    final existing = students.where((s) {
      if (s.classId != classId) return false;
      if (untisId != null && s.untisId == untisId) return true;
      return s.firstName.toLowerCase() == firstName.toLowerCase() &&
          s.lastName.toLowerCase() == lastName.toLowerCase();
    }).firstOrNull;

    if (existing != null) {
      existing
        ..firstName = firstName
        ..lastName = lastName
        ..untisId = untisId ?? existing.untisId;
      if (notify) _changed();
      return existing;
    }
    final s = Student(id: newId(), classId: classId, firstName: firstName, lastName: lastName, untisId: untisId);
    students.add(s);
    if (notify) _changed();
    return s;
  }

  void updateStudent(Student s, {String? firstName, String? lastName}) {
    if (firstName != null) s.firstName = firstName;
    if (lastName != null) s.lastName = lastName;
    _changed();
  }

  void deleteStudent(Student s) {
    photoOf(s)?.deleteSilently();
    students.remove(s);
    _changed();
  }

  /// Stores [bytes] as the student's photo. A new file name each time keeps
  /// Flutter's image cache from showing the old picture.
  Future<void> setPhoto(Student s, Uint8List bytes, {bool notify = true}) async {
    photoOf(s)?.deleteSilently();
    final name = '${s.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File('${photoDir.path}/$name').writeAsBytes(bytes);
    s.photoFile = name;
    if (notify) _changed();
  }

  void removePhoto(Student s) {
    photoOf(s)?.deleteSilently();
    s.photoFile = null;
    _changed();
  }

  /// Call after a bulk import that used notify: false.
  void commit() => _changed();

  // ---------------------------------------------------------------- learning

  /// Records one answer and returns XP earned.
  int recordAnswer(Student s, bool correct, {int points = 10}) {
    s.lastSeen = DateTime.now();
    if (correct) {
      s.correct++;
      s.level = min(Student.maxLevel, s.level + 1);
      xp += points;
    } else {
      s.wrong++;
      s.level = max(0, s.level - 2);
    }
    _touchStreak();
    _changed();
    return correct ? points : 0;
  }

  void _touchStreak() {
    final now = DateTime.now();
    final today = _day(now);
    if (lastPlayedDay == today) return;
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    streak = lastPlayedDay == yesterday ? streak + 1 : 1;
    lastPlayedDay = today;
  }

  /// Streak only counts if the last session was today or yesterday.
  int get currentStreak {
    final now = DateTime.now();
    if (lastPlayedDay == _day(now) || lastPlayedDay == _day(now.subtract(const Duration(days: 1)))) {
      return streak;
    }
    return 0;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Picks up to [n] distinct students, favouring weak and long-unseen ones.
  List<Student> pickForPractice(List<Student> pool, int n) {
    final remaining = [...pool];
    final picked = <Student>[];
    while (picked.length < n && remaining.isNotEmpty) {
      final weights = remaining.map(_weight).toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      var r = _rnd.nextDouble() * total;
      var i = 0;
      while (i < weights.length - 1 && r > weights[i]) {
        r -= weights[i];
        i++;
      }
      picked.add(remaining.removeAt(i));
    }
    return picked;
  }

  double _weight(Student s) {
    final days = s.lastSeen == null ? 7 : DateTime.now().difference(s.lastSeen!).inHours / 24;
    return (Student.maxLevel + 1 - s.level) * (1 + min(days, 7.0) / 2);
  }

  /// Random wrong answers from the same class.
  List<Student> distractors(Student target, List<Student> pool, int n) {
    final others = pool.where((s) => s.id != target.id).toList()..shuffle(_rnd);
    return others.take(n).toList();
  }

  // ---------------------------------------------------------------- settings & reset

  void updateSettings(void Function(AppSettings s) change) {
    change(settings);
    _changed();
  }

  void resetProgress() {
    for (final s in students) {
      s
        ..level = 0
        ..correct = 0
        ..wrong = 0
        ..lastSeen = null;
    }
    xp = 0;
    streak = 0;
    lastPlayedDay = null;
    _changed();
  }

  Future<void> deleteEverything() async {
    years.clear();
    classes.clear();
    students.clear();
    xp = 0;
    streak = 0;
    lastPlayedDay = null;
    if (photoDir.existsSync()) {
      await photoDir.delete(recursive: true);
      photoDir.createSync(recursive: true);
    }
    _changed();
  }
}

extension on File {
  void deleteSilently() {
    try {
      if (existsSync()) deleteSync();
    } catch (_) {}
  }
}
