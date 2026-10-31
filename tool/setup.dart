// Run once after `flutter create`:   dart run tool/setup.dart
// Adds the permissions the app needs to the generated Android/iOS files.
// Works on Windows, macOS and Linux.
import 'dart:io';

void main() {
  _patch(
    'android/app/src/main/AndroidManifest.xml',
    marker: 'android.permission.INTERNET',
    find: RegExp(r'(<manifest[^>]*>)'),
    insert: (m) => '${m[1]}\n    <uses-permission android:name="android.permission.INTERNET"/>',
  );
  _patch(
    'ios/Runner/Info.plist',
    marker: 'NSCameraUsageDescription',
    find: RegExp(r'(</dict>\s*</plist>)'),
    insert: (m) => '''\t<key>NSCameraUsageDescription</key>
\t<string>Namio uses the camera to take student photos.</string>
\t<key>NSPhotoLibraryUsageDescription</key>
\t<string>Namio uses your photos to add student pictures.</string>
${m[1]}''',
  );
  stdout.writeln('Done. Now run: flutter run');
}

void _patch(String path, {required String marker, required RegExp find, required String Function(Match) insert}) {
  final f = File(path);
  if (!f.existsSync()) {
    stdout.writeln('skip  $path (not found – did you run flutter create?)');
    return;
  }
  final s = f.readAsStringSync();
  if (s.contains(marker)) {
    stdout.writeln('ok    $path (already set up)');
    return;
  }
  f.writeAsStringSync(s.replaceFirstMapped(find, insert));
  stdout.writeln('patched $path');
}
