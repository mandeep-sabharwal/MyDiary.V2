// Run once after `flutter create`:   dart run tool/setup_android.dart
//
// Patches the generated android/ folder for the features that need native setup:
//   * daily reminders        (flutter_local_notifications)
//   * fingerprint / face     (local_auth)
//   * encrypted storage      (flutter_secure_storage needs minSdk 23+)
// and installs Mochi's launcher icon and notification icon.
// Safe to run more than once.
import 'dart:io';

const _desugarVersion = '2.1.4';

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final android = Directory('${root.path}/android');
  if (!android.existsSync()) {
    stderr.writeln(
      'No android/ folder found. Run this first, from the project folder:\n'
      '  flutter create --platforms=android --org com.pawsie --project-name pawsie_diary .',
    );
    exit(1);
  }
  final log = <String>[];

  _patchManifest(File('${android.path}/app/src/main/AndroidManifest.xml'), log);
  _patchMainActivity(Directory('${android.path}/app/src/main'), log);
  _patchStyles(Directory('${android.path}/app/src/main/res'), log);
  _patchGradle(Directory('${android.path}/app'), log);
  _installIcons(root, Directory('${android.path}/app/src/main/res'), log);

  stdout.writeln('Android setup finished:');
  for (final l in log) {
    stdout.writeln('  - $l');
  }
}

String _read(File f) => f.readAsStringSync();

void _patchManifest(File f, List<String> log) {
  if (!f.existsSync()) {
    log.add('AndroidManifest.xml not found (skipped)');
    return;
  }
  var s = _read(f);
  var changed = false;

  const perms = [
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.USE_BIOMETRIC',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.SCHEDULE_EXACT_ALARM',
  ];
  final add = StringBuffer();
  for (final p in perms) {
    if (!s.contains('"$p"')) add.writeln('    <uses-permission android:name="$p"/>');
  }
  if (add.isNotEmpty) {
    s = s.replaceFirstMapped(RegExp(r'<manifest[^>]*>'), (m) => '${m.group(0)}\n$add');
    changed = true;
  }

  const receivers = '''
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
  if (!s.contains('ScheduledNotificationReceiver')) {
    s = s.replaceFirst('</application>', '$receivers    </application>');
    changed = true;
  }
  // The encryption key lives in the phone's Keystore and cannot move to another
  // phone, so Android's cloud backup of the (encrypted) files would be unreadable.
  if (!RegExp(r'<application[^>]*android:allowBackup').hasMatch(s)) {
    s = s.replaceFirst('<application', '<application\n        android:allowBackup="false"');
    changed = true;
  }
  if (changed) f.writeAsStringSync(s);
  log.add(
    changed
        ? 'AndroidManifest.xml: permissions + notification receivers added'
        : 'AndroidManifest.xml already patched',
  );
}

void _patchMainActivity(Directory main, List<String> log) {
  File? found;
  for (final sub in ['kotlin', 'java']) {
    final d = Directory('${main.path}/$sub');
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is File &&
          (e.path.endsWith('MainActivity.kt') || e.path.endsWith('MainActivity.java'))) {
        found = e;
      }
    }
  }
  if (found == null) {
    log.add('MainActivity not found (skipped)');
    return;
  }
  var s = _read(found);
  if (s.contains('FlutterFragmentActivity')) {
    log.add('MainActivity already uses FlutterFragmentActivity');
    return;
  }
  s = s.replaceAll(RegExp(r'\bFlutterActivity\b'), 'FlutterFragmentActivity');
  found.writeAsStringSync(s);
  log.add('MainActivity now extends FlutterFragmentActivity (needed for fingerprint unlock)');
}

void _patchStyles(Directory res, List<String> log) {
  var n = 0;
  for (final dir in ['values', 'values-night']) {
    final f = File('${res.path}/$dir/styles.xml');
    if (!f.existsSync()) continue;
    var s = _read(f);
    final re = RegExp(r'(<style name="LaunchTheme" parent=")@android:style/Theme\.[A-Za-z.]+(")');
    if (re.hasMatch(s)) {
      s = s.replaceFirstMapped(
        re,
        (m) => '${m.group(1)}Theme.AppCompat.DayNight.NoActionBar${m.group(2)}',
      );
      f.writeAsStringSync(s);
      n++;
    }
  }
  log.add(
    n > 0
        ? 'LaunchTheme switched to an AppCompat theme (needed for fingerprint prompt)'
        : 'LaunchTheme already patched',
  );
}

void _patchGradle(Directory app, List<String> log) {
  final kts = File('${app.path}/build.gradle.kts');
  final groovy = File('${app.path}/build.gradle');
  final isKts = kts.existsSync();
  final f = isKts ? kts : groovy;
  if (!f.existsSync()) {
    log.add('app/build.gradle(.kts) not found (skipped)');
    return;
  }
  var s = _read(f);
  var changed = false;

  if (!s.contains('oreLibraryDesugaring')) {
    if (isKts) {
      s = s.replaceFirstMapped(
        RegExp(r'compileOptions\s*\{'),
        (m) => '${m.group(0)}\n        isCoreLibraryDesugaringEnabled = true',
      );
      s = s.replaceFirstMapped(
        RegExp(r'\nflutter\s*\{'),
        (m) =>
            '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:$_desugarVersion")\n}\n${m.group(0)}',
      );
    } else {
      s = s.replaceFirstMapped(
        RegExp(r'compileOptions\s*\{'),
        (m) => '${m.group(0)}\n        coreLibraryDesugaringEnabled true',
      );
      if (RegExp(r'\ndependencies\s*\{').hasMatch(s)) {
        s = s.replaceFirstMapped(
          RegExp(r'\ndependencies\s*\{'),
          (m) =>
              "${m.group(0)}\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:$_desugarVersion'",
        );
      } else {
        s = s.replaceFirstMapped(
          RegExp(r'\nflutter\s*\{'),
          (m) =>
              "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:$_desugarVersion'\n}\n${m.group(0)}",
        );
      }
    }
    changed = true;
  }

  // flutter_secure_storage needs minSdk 23+, notifications need compileSdk 35+.
  s = s.replaceFirstMapped(RegExp(r'minSdk(Version)?\s*=?\s*(\d+)'), (m) {
    final v = int.parse(m.group(2)!);
    if (v >= 24) return m.group(0)!;
    changed = true;
    return m.group(0)!.replaceFirst(m.group(2)!, '24');
  });
  s = s.replaceFirstMapped(RegExp(r'compileSdk(Version)?\s*=?\s*(\d+)'), (m) {
    final v = int.parse(m.group(2)!);
    if (v >= 36) return m.group(0)!;
    changed = true;
    return m.group(0)!.replaceFirst(m.group(2)!, '36');
  });

  if (changed) f.writeAsStringSync(s);
  log.add(
    changed
        ? '${isKts ? 'build.gradle.kts' : 'build.gradle'}: core library desugaring on, SDK levels checked'
        : 'build.gradle already patched',
  );
}

void _installIcons(Directory root, Directory res, List<String> log) {
  final src = Directory('${root.path}/tool/android_res');
  if (!src.existsSync()) return;
  var n = 0;
  for (final e in src.listSync()) {
    if (e is Directory) {
      final name = e.uri.pathSegments.where((p) => p.isNotEmpty).last;
      final dest = Directory('${res.path}/$name')..createSync(recursive: true);
      for (final f in e.listSync().whereType<File>()) {
        f.copySync('${dest.path}/${f.uri.pathSegments.last}');
        n++;
      }
    }
  }
  final noti = File('${src.path}/ic_notification.xml');
  if (noti.existsSync()) {
    final dest = Directory('${res.path}/drawable')..createSync(recursive: true);
    noti.copySync('${dest.path}/ic_notification.xml');
    n++;
  }
  log.add('Installed Mochi launcher icons + notification icon ($n files)');
}
