# Google Play release

Everything the store needs lives in this repository, so it stays in sync with
the app:

```text
fastlane/metadata/android/
  de-DE/ en-US/
    title.txt                 30 characters max
    short_description.txt     80 max
    full_description.txt      4000 max
    changelogs/default.txt    release notes (or <versionCode>.txt per build)
    images/
      icon.png                512 × 512, from assets/icon/icon.svg
      featureGraphic.png      1024 × 500, from tool/store/feature-graphic.html
      phoneScreenshots/       1080 × 1920, rendered by CI (Screenshots workflow)
docs/legal/                   privacy policy, terms, legal notice (on the docs site)
tool/store/                   compose.py (screenshot captions), render_graphics.sh
```

The folder layout is the one [fastlane supply](https://docs.fastlane.tools/actions/supply/)
uses, so it can later be uploaded automatically. Until then, copy texts and
images into Play Console by hand.

| What | How it's made |
|---|---|
| Phone screenshots | The **Screenshots** workflow renders a second set (`SHOT_SET=store`, 9:16, German + English) and frames it with captions (`tool/store/compose.py`). Change captions there. |
| Feature graphic, icon | `tool/store/render_graphics.sh` (Chrome, librsvg, ImageMagick) – run after changing the HTML template or the icon, commit the PNGs. |
| App bundle (`.aab`) | **Build APK** workflow on version tags and manual runs, if the `PLAY_UPLOAD_KEYSTORE` secrets exist → artifact `play-bundle`. |

## Before the first upload

### 1. Signing – new upload key { #signing }

The APKs on GitHub are signed with a **debug keystore** (alias
`androiddebugkey`). Google Play rejects anything signed with a debug
certificate, so Play needs its own key:

1. Create an upload key (keep the file and passwords somewhere safe, e.g. a
   password manager):

    ```bash
    keytool -genkeypair -v -keystore nameit-upload.jks -keyalg RSA -keysize 4096 \
      -validity 10000 -alias nameit-upload
    ```

2. Add four repository secrets: `PLAY_UPLOAD_KEYSTORE` (`base64 -w0 nameit-upload.jks`),
   `PLAY_UPLOAD_KEYSTORE_PASSWORD`, `PLAY_UPLOAD_KEY_ALIAS` (`nameit-upload`),
   `PLAY_UPLOAD_KEY_PASSWORD`.
3. In Play Console use **Play App Signing** (default): Google keeps the app
   signing key, you sign uploads with the upload key.

!!! warning "Play and GitHub builds can't update each other"
    The Play version is signed with Google's key, the GitHub APKs with the
    debug key. Android won't install one over the other – switching means
    uninstalling, which deletes classes and progress. Tell existing testers,
    or consider a small export/import of the data file before the switch.

### 2. Package name

The app ID comes from `flutter create --org at.nameit` → **`at.nameit.nameit`**.
It can never change once the app is on Play. If you'd rather have something
else (e.g. a domain you own), change it before the first upload.

### 3. Testing requirement

Personal developer accounts created after 13 Nov 2023 must run a **closed
test with at least 12 testers, opted in for 14 days in a row**, before they
can apply for production ([Play Console
Help](https://support.google.com/googleplay/android-developer/answer/14151465)).
Colleagues are ideal testers – they can use the demo classes.

### 4. Legal pages

The legal pages in `docs/legal/` contain **FILL IN placeholders** for your
name, place and contact email (Google requires the developer named in the
store listing to appear in the privacy policy). The **Docs** workflow refuses
to publish while any placeholder is left. Fill them in, set the dates, and
have the texts checked by someone qualified – see [Legal
review](#legal-review).

## Play Console answers

### Store listing

* **App name, descriptions, graphics:** from `fastlane/metadata/android/`.
* **Category:** Education. **Tags:** e.g. *Teaching tools*.
* **Contact email:** the one in the legal notice. **Website:**
  `https://lukasdiem.github.io/nameit/`.
* **Privacy policy URL:** `https://lukasdiem.github.io/nameit/legal/privacy/`
  (also linked in the app: Settings → Legal).

### App content

| Question | Answer | Why |
|---|---|---|
| Ads | No | |
| App access | All functionality available without special access | Demo classes (+ → Load demo classes) unlock every game without any login. Mention this in the reviewer notes. |
| Target audience | **18 and over** only | The app is for teachers. Choosing younger ages pulls in the Families policy. |
| Content rating | Questionnaire → no violence, no user-generated content shared with others, no user interaction, no location | Expect the lowest age rating |
| News app, government app, financial features, health | No | |

### Data safety { #data-safety }

Google's definitions: data is **collected** when it is sent off the device,
and **shared** when it goes to a third party. Data processed only on the
device is not declared.

| Data | On device only? | Declare? |
|---|---|---|
| Students' names, photos, learning progress | Yes – never leaves the device | No |
| WebUntis login (user name, app key/password) | Sent to the **school's WebUntis server** on the user's action, to sign in | Conservative choice: **Personal info → User IDs: collected, optional, app functionality, encrypted in transit, not shared**. Defensible alternative: not declared, as a user-initiated transfer to a service the user chose. |
| ML Kit (QR scanner) | Device info, app info, performance data and an installation ID go to **Google** | **App info and performance → Diagnostics** and **Device or other IDs: collected, optional (only when scanning), analytics/app functionality, encrypted in transit, not shared**. Google's [ML Kit data disclosure](https://developers.google.com/ml-kit/android-data-disclosure) lists this data; declaring it is the developer's responsibility. |

Further answers: data is **encrypted in transit** – yes (HTTPS). Users can
**request deletion** – the app deletes everything locally (Settings → Delete
all data; Sign out); the developer holds no data. No data is used for ads or
sold.

## WebUntis and Untis GmbH { #untis }

nameIT is not an official Untis app and must never look like one.

**What the listing may and may not do**

* ✅ Say the app *imports from WebUntis* / *works with WebUntis*, with the
  footnote that nameIT is independent and Untis and WebUntis are trademarks of
  Untis GmbH. Describing compatibility like this is referential use of a
  trademark.
* ❌ "Untis" or "WebUntis" in the **app name**, icon, developer name or
  screenshots' captions; the Untis logo; words like *official*, *for Untis*,
  *Untis app*. Google's [impersonation
  policy](https://support.google.com/googleplay/android-developer/answer/9888374)
  forbids implying an affiliation that doesn't exist.

**The bigger risk is technical, not the name.** Of the interfaces nameIT uses
(see the table in the README), only the JSON-RPC API is documented by Untis.
The class list, the Untis Mobile interface (`jsonrpc_intern.do`, used for the
app-key login and attendance lists) and photo loading are **internal,
undocumented interfaces of Untis's own apps**. Using them:

* may conflict with the terms under which Untis licenses WebUntis to schools
  (and which apply to teachers through their school);
* can break at any time, and Untis could block it or complain to Google, which
  may suspend the app;
* is common in open-source clients (e.g. BetterUntis on F-Droid), but that
  is no permission.

The sanctioned way for third-party apps is the [Untis Platform
API](https://developer.untis.com/api-reference/api-overview/), which needs an
approved platform application. Options, from safest:

1. **Ask Untis** (they're in Austria too) whether a teacher-facing app may use
   these interfaces, or apply for Platform API access.
2. **Play version without the WebUntis import** (file import, list and demo
   classes only) until that's settled; keep WebUntis in the GitHub builds.
3. Publish as is, with the disclaimers – accepting the risk above.

The texts in this repository are written so that options 2 and 3 both work:
the disclaimers stay correct, and the store description only needs its
WebUntis bullet and footnote removed for option 2.

## Other trademarks

Two game names were changed because they are protected names: *Millionenshow*
(ORF's quiz show) → **Millionenquiz / Million Quiz**, and *Memory*
(Ravensburger) → **Paare finden / Pairs**. Keep new names generic.

## Legal review { #legal-review }

The privacy policy, terms and legal notice were drafted carefully but **not by
a lawyer**. Before publishing, have them checked – in Austria e.g. by a lawyer
for IT/data protection law. A school's data protection officer is a good
second reader for the teacher-facing parts. Points worth asking about:

* whether the liability clause holds for a free app under Austrian law;
* what the legal notice must contain for your situation (§ 25 MedienG,
  § 5 ECG);
* your role under the GDPR for the ML Kit telemetry;
* the WebUntis interface question above.

## Release steps

1. Fill in the legal placeholders, merge, check the site is published.
2. Create the upload key and secrets ([Signing](#signing)).
3. Bump `version:` in `pubspec.yaml`, merge, tag `vX.Y.Z` → the **Build APK**
   run produces the `play-bundle` artifact.
4. Play Console: create the app, fill in store listing and app content from
   this page, upload the `.aab` to **Closed testing**, invite ≥ 12 testers.
5. After 14 days: apply for production access, then promote the release.
