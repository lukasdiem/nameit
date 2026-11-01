# nameIT (Namio prototype)

App to memorize student names with WebUntis import.

Flutter prototype for Android (iOS-ready). Data is organised as
**School year → Class → Students**, everything stays on the device.

## Run it

Requires Flutter 3.32 or newer (`flutter --version`).

```bash
cd namio
flutter create --platforms=android,ios --org at.namio .   # generates android/ and ios/, keeps lib/
dart run tool/setup.dart                                  # adds internet + camera permissions
flutter pub get
flutter run                                               # with a phone or emulator connected
```

APK for your phone: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

## What's inside

```
lib/
  main.dart                    app start, theme, language
  l10n/strings.dart            German + English strings (switchable in Settings)
  models/models.dart           SchoolYear, SchoolClass, Student, GameResult
  data/app_store.dart          state + JSON storage + photo files + spaced repetition
  services/webuntis_service.dart  WebUntis login, years, classes, students, photos
  services/file_import.dart    CSV / Excel import (German + English headers)
  services/photo_service.dart  camera / gallery fallback
  ui/screens/                  home, class, student, import, settings
  ui/games/                    7 game modes + result screen
```

## Game modes

| Mode | Direction | Idea |
|---|---|---|
| Millionenshow | face → name | 15 questions, ladder to € 1.000.000, safety levels at € 500 and € 15.000, jokers 50:50 / audience / initials, wrong answer ends the run |
| Memory | both | find photo + name pairs; fewer moves = more stars |
| Wer ist das? | name → face | one name, four faces |
| Blitzrunde | face ↔ name | 60 s yes/no, combo multiplier ×2 / ×3 |
| Aufdecken | face → name | photo uncovers tile by tile; early answers score more |
| Eintippen | face → name | type the first name, small typos forgiven (recall, not just recognition) |
| Lernkarten | both | flip cards, rate yourself, unknown cards come back |

Every answer updates a 0–5 level per student. Games pick weak and
long-unseen students more often, so practice goes where it's needed.
XP and a daily streak sit on the home screen.

## WebUntis

* Login, school years, classes: official JSON-RPC API (`authenticate`, `getSchoolyears`, `getKlassen`).
* Students of a class, in this order:
  1. The web timetable's student list (`pageconfig` with `filter.klasseId`). WebUntis only
     allows this for the class you are Klassenvorstand of, and then gives the full class.
  2. The Untis Mobile interface (`jsonrpc_intern.do`, as used by the official app and
     BetterUntis): `getAppSharedSecret` → `getTimetable2017` for your teacher timetable →
     `getPeriodData2017`, which lists the students of each lesson you teach (the attendance
     list). Students are grouped by class; lessons shared by several classes become their
     own group (e.g. "3A + 3B") when the class can't be told apart.
  3. If neither works: `getStudents` and tick the students by hand.
* Photos: loaded from `https://<server>/WebUntis/image.do?cat=5&id=<studentId>` with the
  login session. Students without a photo get WebUntis' generic avatar; the app detects it
  and leaves those students without a photo. Settings can override the address if needed.
* Camera / gallery always works as a fallback, per student.

The password is only stored (in the Android Keystore / iOS Keychain) if you tick
*remember password*.

## Privacy

Names and photos of students are personal data (GDPR). The app has no backend:
everything lives in the app's private storage and is removed with
*Settings → Delete all data* or by uninstalling.
