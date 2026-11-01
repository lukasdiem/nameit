/// Plain data classes. Everything is stored as JSON on the device.
library;

class SchoolYear {
  SchoolYear({required this.id, required this.name, this.untisId});

  final String id;
  String name;
  int? untisId;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'untisId': untisId};

  factory SchoolYear.fromJson(Map<String, dynamic> j) =>
      SchoolYear(id: j['id'], name: j['name'], untisId: j['untisId']);
}

class SchoolClass {
  SchoolClass({required this.id, required this.yearId, required this.name, this.untisId});

  final String id;
  final String yearId;
  String name;
  int? untisId;

  Map<String, dynamic> toJson() => {'id': id, 'yearId': yearId, 'name': name, 'untisId': untisId};

  factory SchoolClass.fromJson(Map<String, dynamic> j) =>
      SchoolClass(id: j['id'], yearId: j['yearId'], name: j['name'], untisId: j['untisId']);
}

class Student {
  Student({
    required this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    this.photoFile,
    this.untisId,
    this.level = 0,
    this.correct = 0,
    this.wrong = 0,
    this.lastSeen,
  });

  final String id;
  final String classId;
  String firstName;
  String lastName;

  /// File name inside the app's photo folder (relative, because the
  /// absolute app directory can change on iOS between launches).
  String? photoFile;
  int? untisId;

  /// Leitner-style box 0..5. 5 = mastered.
  int level;
  int correct;
  int wrong;
  DateTime? lastSeen;

  static const maxLevel = 5;

  String get fullName => '$firstName $lastName'.trim();
  bool get hasPhoto => photoFile != null;
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return (a + b).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'classId': classId,
        'firstName': firstName,
        'lastName': lastName,
        'photoFile': photoFile,
        'untisId': untisId,
        'level': level,
        'correct': correct,
        'wrong': wrong,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'],
        classId: j['classId'],
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        photoFile: j['photoFile'],
        untisId: j['untisId'],
        level: j['level'] ?? 0,
        correct: j['correct'] ?? 0,
        wrong: j['wrong'] ?? 0,
        lastSeen: j['lastSeen'] != null ? DateTime.tryParse(j['lastSeen']) : null,
      );
}

class AppSettings {
  AppSettings({
    this.locale = 'system',
    this.untisServer = '',
    this.untisSchool = '',
    this.untisUser = '',
    this.photoUrlTemplate = '',
    this.rememberPassword = false,
  });

  /// 'system', 'de' or 'en'
  String locale;
  String untisServer;
  String untisSchool;
  String untisUser;

  /// URL template for student photos, e.g.
  /// https://{server}/WebUntis/api/…/{id}
  /// Placeholders: {server}, {school}, {id}
  String photoUrlTemplate;
  bool rememberPassword;

  Map<String, dynamic> toJson() => {
        'locale': locale,
        'untisServer': untisServer,
        'untisSchool': untisSchool,
        'untisUser': untisUser,
        'photoUrlTemplate': photoUrlTemplate,
        'rememberPassword': rememberPassword,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        locale: j['locale'] ?? 'system',
        untisServer: j['untisServer'] ?? '',
        untisSchool: j['untisSchool'] ?? '',
        untisUser: j['untisUser'] ?? '',
        photoUrlTemplate: j['photoUrlTemplate'] ?? '',
        rememberPassword: j['rememberPassword'] ?? false,
      );
}

/// Outcome of one game round, used by the result screen.
class GameResult {
  GameResult({
    required this.modeTitleKey,
    required this.correct,
    required this.total,
    required this.xp,
    required this.missed,
    this.headline,
    this.starsOverride,
    this.score,
  });

  final String modeTitleKey;
  final int correct;
  final int total;
  final int xp;
  final List<Student> missed;

  /// Optional extra line, e.g. "€ 16.000" in Millionenshow or "14 moves" in Memory.
  final String? headline;

  /// For games where accuracy isn't the right measure (e.g. Memory moves).
  final int? starsOverride;

  /// Game-specific number used for badges: euros in Millionenshow, points
  /// in Blitz and Reveal, moves in Memory.
  final int? score;

  double get accuracy => total == 0 ? 0 : correct / total;
  int get stars => starsOverride ?? (accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : accuracy >= 0.4 ? 1 : 0);
}
