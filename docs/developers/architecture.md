# Code tour

A deliberately small codebase: plain `ChangeNotifier` state, JSON on disk, no
code generation.

```text
lib/
  main.dart                      app start, theme, language
  l10n/strings.dart              German + English strings – context.tr('key')
  models/models.dart             SchoolYear, SchoolClass, Student, AppSettings, GameResult
  data/
    app_store.dart               state, JSON storage, photo files, spaced repetition, stats
    badges.dart                  the 15 badges and their conditions
  services/
    webuntis_service.dart        WebUntis login, years, classes, students, photos
    untis_mobile_api.dart        Untis Mobile interface (app key / TOTP, timetable, attendance lists)
    untis_credentials.dart       QR code parsing, several accounts (app keys) in secure storage
    file_import.dart             CSV / Excel parser (German + English headers)
    demo_data.dart               loads the bundled demo class (docs/demo) into a "Demo" year
    photo_service.dart           camera / gallery
  ui/
    theme.dart                   brand colours, light + dark theme
    screens/                     home, class, student, import, QR scan, stats, settings
    games/                       7 games, game picker (game_modes.dart), shared widgets + result screen
    widgets/                     logo, student photo, learning bar
```

## Data

`AppStore` is the single source of truth, provided at the top of the widget
tree with `provider`. Every change calls `notifyListeners()` and writes
`nameit_data.json` in the app's documents folder (to a temp file first, then
renamed, so a crash never leaves half a file). Saves are queued one after
another, so quick successive changes – an import adding several classes –
never race for the temp file.

Photos are files in a `photos/` folder. A student stores only the **file
name** – the absolute app folder can change on iOS between launches. Each new
photo gets a new file name so Flutter's image cache never shows the old one.

### Schools and school years

* **School years** are shared by name across schools ("2026/27").
* **Classes** remember the WebUntis school they came from (`school`, a
  `server/school` key). Classes and students are matched per school on
  re-import, so two schools' *3B* never mix. Display names for schools come
  from WebUntis' public school search (`schools` map).
* The home screen groups a year's classes by school only when there is more
  than one (`classesBySchool()`).

### Accounts

`UntisCredentials` keeps a list of accounts in secure storage
(`untis_accounts`) plus the active one (`untis_active`). Only app keys are
stored; a password only if the server hands out no app key. The single login
of earlier versions is moved into the list on first load.

## Learning

* `recordAnswer()` – level +1 on a correct answer, −2 on a wrong one
  (0…5), updates XP, the per-day history and the streak.
* Per-day history: `days["yyyy-mm-dd"] = [answers, correct, xp, games]`
  (older two-value entries count 10 XP per correct answer).
* Stats are per **school year**, 1 August to 31 July: `totalsIn(yearName)`
  sums the days of that range, `xpThisYear` is shown on the home screen.
  Year names without a year number (e.g. *Demo*) count as the current year.
  Streak and badges are not per year.
* `pickForPractice()` – weighted random choice without repetition. Weight =
  `(6 − level) × (1 + min(days unseen, 7) / 2)`.
* `distractors()` – wrong options from the same class.

## Games

Each game is a `StatefulWidget` taking `classId` and the `pool` of students
with photos. They share `GameShell` (app bar + progress), `AnswerButton`,
`GamePhoto` and finish with `finishGame()`, which records the game, checks
badges and opens `ResultScreen`.

To add a game, write the widget and add a `GameMode` to `gameModes` in
`game_modes.dart` (key, icon, colour, minimum number of photos), plus the
strings `<key>` and `<key>Sub` in `strings.dart`.

## Design

| Role | Colour | Use |
|---|---|---|
| Primary | `#7C2AD6` violet | icon background, buttons, "IT" in the wordmark |
| Secondary | `#4FE0B0` mint | logo head, progress; `#0E7A5A` where it carries white text |
| Tertiary | `#FFB627` amber | stars and rewards only |
| Ink | `#1E1433` | text |

The version line at the end of Settings comes from `package_info_plus`
(version name from `pubspec.yaml`, build number from CI).

The logo is a lowercase "n" that is also a person. Icon sources (SVG masters
and 1024 px PNGs) are in `assets/icon/`; in the app it is drawn in code
(`ui/widgets/nameit_logo.dart`).
