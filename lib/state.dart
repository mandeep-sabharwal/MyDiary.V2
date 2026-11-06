import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';
import 'mochi_art.dart';
import 'models.dart';
import 'reminders.dart';
import 'utils.dart';
import 'vault.dart';

/// The one global app state. Entries and photos are stored encrypted on the device.
final AppState app = AppState();

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  late Directory _photoDir;
  final Vault vault = Vault();

  Map<String, dynamic>? account; // {name, email, salt, hash}
  bool signedIn = false;
  bool locked = false;
  bool suppressLock = false; // true while the camera / gallery / fingerprint sheet is open
  final List<Entry> entries = [];

  ThemeMode themeMode = ThemeMode.light;
  Mood mascotMood = Mood.happy;
  int reminderMinutes = 21 * 60;
  bool reminderOn = false;
  int fontIdx = 1;
  bool biometricOn = false;
  String palette = 'pawsie';
  bool biometricAvailable = false;
  bool cloudBackup = false;

  /// Set after an online sign-in on an empty phone when a cloud backup exists.
  bool offerRestore = false;
  String? _passHash, _passSalt;
  final Map<String, String> equipped = {}; // slot name -> reward id

  // ---------- derived ----------
  bool get hasAccount => account != null;
  bool get hasPasscode => _passHash != null;
  double get fontScale => const [0.9, 1.0, 1.15][fontIdx];
  String get fontLabel => const ['Small', 'Medium', 'Large'][fontIdx];
  bool get garden => equipped['theme'] == 'garden_theme';
  String get userName => (account?['name'] as String?) ?? '';
  String get userEmail => (account?['email'] as String?) ?? '';

  // Stats and badges are used by several screens on every rebuild, so compute them once
  // per change of the entries (or per day, since the streak depends on today).
  int _entriesVersion = 0;
  int _statsVersion = -1;
  int _statsDay = -1;
  DiaryStats? _statsCache;
  Set<String> _unlockedCache = {};

  void _refreshStats() {
    final today = dayNum(DateTime.now());
    if (_statsCache != null && _statsVersion == _entriesVersion && _statsDay == today) return;
    final s = DiaryStats.from(entries);
    _statsCache = s;
    _statsVersion = _entriesVersion;
    _statsDay = today;
    _unlockedCache = {
      for (final a in kAchievements)
        if (a.progress(s) >= 1) a.id,
    };
  }

  DiaryStats get stats {
    _refreshStats();
    return _statsCache!;
  }

  Set<String> get unlockedIds {
    _refreshStats();
    return _unlockedCache;
  }

  bool isOwned(Reward r) => unlockedIds.contains(r.achievementId);

  /// Accessory fragments for the equipped items, in drawing order.
  List<String> get equippedFragmentIds {
    final out = <String>[];
    for (final slot in ['neck', 'face', 'theme', 'hat']) {
      final id = equipped[slot];
      if (id != null && kMochiAccessories.containsKey(id)) out.add(id);
    }
    return out;
  }

  List<Entry> entriesOn(DateTime d) => entries.where((e) => sameDay(e.createdAt, d)).toList();

  // ---------- lifecycle ----------
  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    await vault.init();
    final docs = await getApplicationDocumentsDirectory();
    _photoDir = Directory('${docs.path}/photos');
    if (!await _photoDir.exists()) await _photoDir.create(recursive: true);

    final acc = _p.getString('account');
    if (acc != null) account = jsonDecode(acc) as Map<String, dynamic>;
    signedIn = hasAccount && (_p.getBool('signedIn') ?? false);

    final s = _p.getString('settings');
    if (s != null) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == j['themeMode'],
        orElse: () => ThemeMode.light,
      );
      mascotMood = moodFromName(j['mascot'] as String?);
      reminderMinutes = (j['reminder'] as int?) ?? reminderMinutes;
      reminderOn = (j['reminderOn'] as bool?) ?? false;
      fontIdx = ((j['font'] as int?) ?? 1).clamp(0, 2);
      biometricOn = (j['biometric'] as bool?) ?? false;
      palette = (j['palette'] as String?) ?? 'pawsie';
      cloudBackup = (j['cloudBackup'] as bool?) ?? false;
      _passHash = j['passHash'] as String?;
      _passSalt = j['passSalt'] as String?;
      equipped
        ..clear()
        ..addAll(((j['equipped'] as Map?) ?? const {}).cast<String, String>());
    }

    await _loadEntries();
    await _migratePhotos();
    locked = hasPasscode && signedIn;
  }

  Future<void> _loadEntries() async {
    final enc = _p.getString('entries_enc');
    String? json;
    if (enc != null) {
      json = await vault.openString(enc);
    } else {
      // Older versions kept entries as plain text: encrypt them now.
      final legacy = _p.getString('entries');
      if (legacy != null) json = legacy;
    }
    if (json != null) {
      entries
        ..clear()
        ..addAll((jsonDecode(json) as List).map((e) => Entry.fromJson(e as Map<String, dynamic>)));
      _sort();
    }
    if (enc == null && json != null) {
      await _writeEntries();
      await _p.remove('entries');
    }
  }

  /// Encrypts photos saved by older versions of the app.
  Future<void> _migratePhotos() async {
    var changed = false;
    for (final e in entries) {
      for (var i = 0; i < e.photos.length; i++) {
        final old = e.photos[i];
        if (old.endsWith('.enc')) continue;
        final f = photoFile(old);
        if (!await f.exists()) continue;
        final name = 'p_${DateTime.now().microsecondsSinceEpoch}_$i.enc';
        await photoFile(name).writeAsBytes(await vault.seal(await f.readAsBytes()));
        await f.delete();
        e.photos[i] = name;
        changed = true;
      }
    }
    if (changed) await _writeEntries();
  }

  void _sort() {
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _entriesVersion++;
  }

  Future<void> _saving = Future<void>.value();

  Future<void> _writeEntries() async {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _p.setString('entries_enc', await vault.sealString(json));
  }

  void _saveEntries() {
    _saving = _saving.then((_) => _writeEntries()).catchError((Object _) {});
  }

  void _saveSettings() => _p.setString(
    'settings',
    jsonEncode({
      'themeMode': themeMode.name,
      'mascot': mascotMood.name,
      'reminder': reminderMinutes,
      'reminderOn': reminderOn,
      'font': fontIdx,
      'biometric': biometricOn,
      'palette': palette,
      'cloudBackup': cloudBackup,
      'passHash': _passHash,
      'passSalt': _passSalt,
      'equipped': equipped,
    }),
  );

  // ---------- hashing ----------
  String _newSalt() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random.secure().nextInt(1 << 30).toRadixString(36)}';
  String _hash(String salt, String v) => sha256.convert(utf8.encode('$salt:$v')).toString();

  // ---------- account ----------
  Future<void> createAccount(
    String name,
    String email,
    String password, {
    String? passcode,
    bool stay = true,
  }) async {
    final salt = _newSalt();
    account = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'salt': salt,
      'hash': _hash(salt, password),
    };
    await _p.setString('account', jsonEncode(account));
    signedIn = true;
    await _p.setBool('signedIn', stay);
    if (passcode != null) {
      _passSalt = _newSalt();
      _passHash = _hash(_passSalt!, passcode);
      _saveSettings();
    }
    locked = false;
    notifyListeners();
  }

  bool checkPassword(String password) {
    final a = account;
    if (a == null) return false;
    return _hash(a['salt'] as String, password) == a['hash'];
  }

  bool signIn(String email, String password, {bool stay = true}) {
    final a = account;
    if (a == null) return false;
    if (a['email'] != email.trim().toLowerCase() || !checkPassword(password)) {
      return false;
    }
    signInTrusted(stay: stay);
    return true;
  }

  /// Sign in after the cloud (Firebase) has already verified the person.
  void signInTrusted({bool stay = true}) {
    signedIn = true;
    locked = false;
    _p.setBool('signedIn', stay);
    notifyListeners();
    refreshReminders();
  }

  /// Keeps the on-device password in step with a changed cloud password.
  Future<void> updateLocalPassword(String password) async {
    final a = account;
    if (a == null) return;
    final salt = _newSalt();
    a['salt'] = salt;
    a['hash'] = _hash(salt, password);
    await _p.setString('account', jsonEncode(a));
  }

  void signOut() {
    signedIn = false;
    locked = false;
    _p.setBool('signedIn', false);
    reminders.reschedule(on: false, minutes: 0, wroteToday: false, streak: 0);
    notifyListeners();
  }

  Future<void> deleteEverything() async {
    cloud.stopAutoSync();
    for (final e in entries) {
      for (final f in e.photos) {
        final file = photoFile(f);
        if (await file.exists()) await file.delete();
      }
    }
    await _p.clear();
    await vault.wipe();
    await vault.init(); // fresh key for whatever is written next
    await reminders.reschedule(on: false, minutes: 0, wroteToday: false, streak: 0);
    account = null;
    signedIn = false;
    locked = false;
    entries.clear();
    _entriesVersion++;
    equipped.clear();
    themeMode = ThemeMode.light;
    mascotMood = Mood.happy;
    reminderMinutes = 21 * 60;
    reminderOn = false;
    fontIdx = 1;
    biometricOn = false;
    palette = 'pawsie';
    cloudBackup = false;
    _photoCache.clear();
    _passHash = null;
    _passSalt = null;
    notifyListeners();
  }

  // ---------- passcode / biometrics ----------
  void setPasscode(String? code) {
    if (code == null) {
      _passHash = null;
      _passSalt = null;
      biometricOn = false; // fingerprint unlock needs a passcode as the fallback
    } else {
      _passSalt = _newSalt();
      _passHash = _hash(_passSalt!, code);
    }
    _saveSettings();
    notifyListeners();
  }

  bool verifyPasscode(String code) => _passHash != null && _hash(_passSalt!, code) == _passHash;

  void setBiometric(bool on) {
    biometricOn = on;
    _saveSettings();
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void lockIfNeeded() {
    if (hasPasscode && signedIn && !suppressLock && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  bool resetPasscodeWithPassword(String password) {
    if (!checkPassword(password)) return false;
    setPasscode(null);
    unlock();
    return true;
  }

  // ---------- entries ----------
  void addEntry(Entry e) {
    e.updatedAt = DateTime.now().millisecondsSinceEpoch;
    entries.add(e);
    _sort();
    _saveEntries();
    notifyListeners();
    if (cloudBackup) cloud.pushEntry(e);
    refreshReminders();
  }

  void updateEntry(Entry e) {
    e.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _sort();
    _saveEntries();
    notifyListeners();
    if (cloudBackup) cloud.pushEntry(e);
  }

  Future<void> deleteEntry(Entry e) async {
    entries.removeWhere((x) => x.id == e.id);
    _entriesVersion++;
    for (final f in e.photos) {
      await deletePhoto(f);
    }
    _saveEntries();
    notifyListeners();
    if (cloudBackup) cloud.deleteRemote(e.id);
  }

  /// Applies entries downloaded from the cloud (the newest edit wins) and removes
  /// entries another phone deleted. Returns how many entries changed.
  int mergeRemote(List<Entry> remote, {Map<String, int> deleted = const {}}) {
    var changed = 0;
    for (final t in deleted.entries) {
      final i = entries.indexWhere((e) => e.id == t.key);
      if (i >= 0 && entries[i].updatedAt <= t.value) {
        final gone = entries.removeAt(i);
        for (final f in gone.photos) {
          deletePhoto(f);
        }
        changed++;
      }
    }
    for (final r in remote) {
      final i = entries.indexWhere((e) => e.id == r.id);
      if (i < 0) {
        entries.add(r);
        changed++;
      } else if (r.updatedAt > entries[i].updatedAt) {
        entries[i] = r;
        changed++;
      }
    }
    if (changed > 0) {
      _sort();
      _saveEntries();
      notifyListeners();
    }
    return changed;
  }

  // ---------- photos (encrypted files) ----------
  final LinkedHashMap<String, Uint8List> _photoCache = LinkedHashMap();

  Future<String> importPhoto(XFile x) async {
    final bytes = await x.readAsBytes();
    final name = 'p_${DateTime.now().microsecondsSinceEpoch}.enc';
    await photoFile(name).writeAsBytes(await vault.seal(bytes));
    try {
      await File(x.path).delete(); // do not leave a readable copy in the picker cache
    } catch (_) {}
    return name;
  }

  File photoFile(String name) => File('${_photoDir.path}/$name');

  Future<Uint8List?> photoBytes(String name) async {
    final cached = _photoCache.remove(name);
    if (cached != null) {
      _photoCache[name] = cached;
      return cached;
    }
    final f = photoFile(name);
    if (!await f.exists()) return null;
    try {
      final bytes = await vault.open(await f.readAsBytes());
      _photoCache[name] = bytes;
      if (_photoCache.length > 24) _photoCache.remove(_photoCache.keys.first);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePhoto(String name) async {
    _photoCache.remove(name);
    final f = photoFile(name);
    if (await f.exists()) await f.delete();
  }

  // ---------- settings ----------
  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _saveSettings();
    notifyListeners();
  }

  void setPalette(String id) {
    palette = id;
    _saveSettings();
    notifyListeners();
  }

  void setMascot(Mood m) {
    mascotMood = m;
    _saveSettings();
    notifyListeners();
  }

  void setReminder(int minutes) {
    reminderMinutes = minutes;
    _saveSettings();
    notifyListeners();
    refreshReminders();
  }

  void setReminderOn(bool on) {
    reminderOn = on;
    _saveSettings();
    notifyListeners();
    refreshReminders();
  }

  Future<void> refreshReminders() => reminders.reschedule(
    on: reminderOn && signedIn,
    minutes: reminderMinutes,
    wroteToday: entriesOn(DateTime.now()).isNotEmpty,
    streak: stats.current,
    entries: entries,
  );

  void cycleFont() {
    fontIdx = (fontIdx + 1) % 3;
    _saveSettings();
    notifyListeners();
  }

  void setCloudBackup(bool on) {
    cloudBackup = on;
    _saveSettings();
    notifyListeners();
  }

  void toggleEquip(Reward r) {
    final key = r.slot.name;
    if (equipped[key] == r.id) {
      equipped.remove(key);
    } else {
      equipped[key] = r.id;
    }
    _saveSettings();
    notifyListeners();
  }

  // ---------- export ----------
  String exportText() {
    final b = StringBuffer('Pawsie Diary - ${userName.isEmpty ? 'my diary' : userName}\n');
    for (final e in entries.reversed) {
      b
        ..writeln('\n==============================')
        ..writeln('${longDate(e.createdAt)} ${e.createdAt.year}  |  ${e.mood.label}')
        ..writeln(e.displayTitle)
        ..writeln()
        ..writeln(e.body.replaceAll(kImgChar, '[photo]'));
    }
    return b.toString();
  }
}
