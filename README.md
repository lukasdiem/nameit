# nameIT

An app **for teachers** to learn their students' names and faces with short
games. Classes can be imported from WebUntis, a CSV/Excel file or typed in;
everything stays on the phone.

> nameIT is an independent project, not affiliated with or endorsed by Untis
> GmbH. Untis and WebUntis are trademarks of Untis GmbH.
> [Privacy policy](https://lukasdiem.github.io/nameit/legal/privacy/) ·
> [Terms of use & disclaimer](https://lukasdiem.github.io/nameit/legal/terms/)

📲 **Download:** [newest release (APK)](https://github.com/lukasdiem/nameit/releases/latest/download/nameit.apk)
· [all builds](https://github.com/lukasdiem/nameit/releases)

📖 **Documentation:** <https://lukasdiem.github.io/nameit/> – user guide with
screenshots, game rules, import formats and developer notes (sources in
[`docs/`](docs/), see [Docs & screenshots](docs/developers/docs-and-screenshots.md)).

Flutter prototype for Android (iOS-ready). Data is organised as
**School year → Class → Students**, everything stays on the device.

## Run it

Requires Flutter 3.38 or newer (`flutter --version`).

```bash
cd nameit
flutter create --platforms=android,ios --org at.nameit --project-name nameit .   # generates android/ and ios/, keeps lib/
dart run tool/setup.dart                                  # adds permissions, sets the app name
flutter pub get
dart run flutter_launcher_icons                           # app icon for Android + iOS
flutter run                                               # with a phone or emulator connected
```

APK for your phone: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

## Builds and versions

GitHub Actions (`.github/workflows/build-apk.yml`) runs tests and builds the APK on
every pull request and every push to `main`.

* **Version name** comes from `version:` in `pubspec.yaml` (e.g. `0.2.0`).
* **Build number** (Android `versionCode`) is the workflow run number, so it always
  goes up and new builds install over old ones.
* Every push to `main` publishes a **pre-release** `v0.2.0-build.42` with the APK.
* To publish a **release**: bump `version:` in `pubspec.yaml`, merge, then tag:

  ```bash
  git tag v0.2.0 && git push origin v0.2.0
  ```

  The build fails if the tag doesn't match `pubspec.yaml`. The release gets
  auto-generated notes from the merged pull requests and is marked *Latest*.
* Pull request builds attach the APK as a workflow artifact (kept 14 days) instead
  of creating a release.

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

## Design

| Role | Colour | Use |
|---|---|---|
| Primary | `#7C2AD6` violet | icon background, buttons, "IT" in the wordmark |
| Secondary | `#4FE0B0` mint | logo head, progress; `#0E7A5A` where it carries white text (correct answers) |
| Tertiary | `#FFB627` amber | stars and rewards only |
| Ink | `#1E1433` | text |

The logo is a lowercase "n" that is also a person. Icon sources are in
`assets/icon/` (SVG masters + 1024 px PNGs); in the app it is drawn in code
(`lib/ui/widgets/nameit_logo.dart`). Colours live in `lib/ui/theme.dart`.

## Game modes

| Mode | Direction | Idea |
|---|---|---|
| Million Quiz (Millionenquiz) | face → name | 15 questions, ladder to € 1.000.000, safety levels at € 500 and € 15.000, jokers 50:50 / audience / initials, wrong answer ends the run |
| Pairs (Paare finden) | both | find photo + name pairs; fewer moves = more stars |
| Wer ist das? | name → face | one name, four faces |
| Blitzrunde | face ↔ name | 60 s yes/no, combo multiplier ×2 / ×3 |
| Aufdecken | face → name | photo uncovers tile by tile; early answers score more |
| Eintippen | face → name | type the first name, small typos forgiven (recall, not just recognition) |
| Lernkarten | both | flip cards, rate yourself, unknown cards come back |

Every answer updates a 0–5 level per student. Games pick weak and
long-unseen students more often, so practice goes where it's needed.
XP and a daily streak sit on the home screen; tapping them opens **Stats**: streak and
record, XP, accuracy, a 14-day activity chart, mastery per class, the students who need
practice most, and **15 badges** (streaks, perfect rounds, the million, whole class mastered,
early bird / night owl …). New badges are announced on the result screen.

## WebUntis

Which interfaces are used, and how official they are, matters for publishing
(see [Google Play release](docs/developers/play-store.md#untis)):

| Interface | Used for | Status |
|---|---|---|
| JSON-RPC `jsonrpc.do` | login, school years, classes, `getStudents` | documented by Untis (WebUntis JSON-RPC API) |
| `api/public/timetable/weekly/pageconfig`, `api/token/new` | class list of your own class | web client interface, undocumented |
| Untis Mobile `jsonrpc_intern.do` | app-key login, your lessons' attendance lists | mobile app interface, undocumented |
| `image.do` | student photos | web client interface, undocumented |
| `schoolsearch.webuntis.com` | school display name | public school search, undocumented |

Details:

* Login, school years, classes: the documented JSON-RPC API (`authenticate`, `getSchoolyears`, `getKlassen`).
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

Sign-in: scan the QR code from WebUntis (Profil → Freigaben → Zugriff über Untis Mobile →
Anzeigen) or use username and password. After the first successful sign-in the app keeps
only the app key (the one inside the QR code) in the Android Keystore / iOS Keychain and
signs in automatically; if that fails it shows the first-time page again. *Sign out* deletes it.

## Privacy

Names and photos of students are personal data (GDPR). The app has no backend:
everything lives in the app's private storage and is removed with
*Settings → Delete all data* or by uninstalling. The QR scanner (Google ML Kit)
sends technical usage data to Google. Full text:
[privacy policy](https://lukasdiem.github.io/nameit/legal/privacy/) (sources in
`docs/legal/`).
