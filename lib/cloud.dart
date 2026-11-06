import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'models.dart';
import 'state.dart';

final Cloud cloud = Cloud();

/// Only needed if Google sign-in says "serverClientId must be provided".
/// Paste your *Web client ID* here: Firebase console > Authentication > Sign-in method >
/// Google > Web SDK configuration > Web client ID (looks like 1234-abc.apps.googleusercontent.com).
const String kGoogleWebClientId = '';

/// Optional online features: Google / Apple sign-in, password reset email and
/// end-to-end encrypted backup. Everything here is inert until a Firebase project
/// is connected (README). Entries are encrypted on the phone with a key derived
/// from your backup passphrase, so Firebase only ever stores unreadable data.
/// Photos are not uploaded (that needs Firebase Storage, a paid plan).
class Cloud {
  bool available = false;
  String? initError;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      available = true;
    } catch (e) {
      available = false;
      initError = '$e';
    }
  }

  User? get user => available ? FirebaseAuth.instance.currentUser : null;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _meta => _db.collection('users').doc(user!.uid);
  CollectionReference<Map<String, dynamic>> get _entries => _meta.collection('entries');

  // ---------- accounts ----------
  String _msg(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email already has an account. Try signing in.';
      case 'invalid-email':
        return 'That email does not look right.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password did not match.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many tries. Please wait a moment.';
      case 'canceled':
      case 'popup-closed-by-user':
      case 'web-context-canceled':
        return 'Sign-in was cancelled.';
      default:
        return e.message ?? 'Something went wrong (${e.code}).';
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (e) {
      return 'Could not reach the cloud: $e';
    }
  }

  Future<String?> signInEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (e) {
      return 'Could not reach the cloud: $e';
    }
  }

  Future<String?> signInWith(AuthProvider provider) async {
    try {
      await FirebaseAuth.instance.signInWithProvider(provider);
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (e) {
      return 'Could not reach the cloud: $e';
    }
  }

  bool _googleReady = false;

  /// Google sign-in with Android's own account picker (the list of every Google account
  /// on the phone), instead of opening a web page in Chrome.
  Future<String?> signInGoogle() async {
    try {
      final gsi = GoogleSignIn.instance;
      if (!_googleReady) {
        await gsi.initialize(
          serverClientId: kGoogleWebClientId.isEmpty ? null : kGoogleWebClientId,
        );
        _googleReady = true;
      }
      if (!gsi.supportsAuthenticate()) return await signInWith(GoogleAuthProvider());
      try {
        await gsi.signOut(); // forget the last pick so the sheet lists every account again
      } catch (_) {}
      final account = await gsi.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return 'Google did not return a sign-in token. Check the SHA fingerprints in Firebase (README).';
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was cancelled. If you did pick an account and it still cancelled, '
            'the SHA-1 and SHA-256 of this build are probably missing in Firebase.';
      }
      return 'Google sign-in failed: ${e.code.name}${e.description == null ? '' : ' - ${e.description}'}';
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  Future<String?> signInApple() => signInWith(AppleAuthProvider());

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e);
    } catch (e) {
      return 'Could not reach the cloud: $e';
    }
  }

  Future<void> signOut() async {
    stopAutoSync();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (!available) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  // ---------- encrypted backup ----------
  static const String _checkText = 'pawsie-ok';

  /// Turns backup on. First time: creates the passphrase check. On another phone:
  /// verifies the passphrase against the one already stored. Returns an error or null.
  Future<String?> enableBackup(String passphrase) async {
    if (user == null) return 'Sign in with an online account first.';
    try {
      final snap = await _meta.get();
      final data = snap.data();
      if (data != null && data['salt'] != null && data['check'] != null) {
        final salt = base64Decode(data['salt'] as String);
        final key = await app.vault.deriveSyncKey(passphrase, salt);
        try {
          final plain = await app.vault.openString(data['check'] as String, key: key);
          if (plain != _checkText) return 'That passphrase is not the one used for this backup.';
        } catch (_) {
          return 'That passphrase is not the one used for this backup.';
        }
        await app.vault.storeSyncKey(key);
      } else {
        final salt = app.vault.newSalt();
        final key = await app.vault.deriveSyncKey(passphrase, salt);
        await _meta.set({
          'salt': base64Encode(salt),
          'check': await app.vault.sealString(_checkText, key: key),
        });
        await app.vault.storeSyncKey(key);
      }
      app.setCloudBackup(true);
      await syncNow();
      _startListener();
      return null;
    } catch (e) {
      return 'Backup failed: $e';
    }
  }

  /// True if this online account already has an encrypted backup in the cloud.
  Future<bool> hasBackup() async {
    if (user == null) return false;
    try {
      final data = (await _meta.get()).data();
      return data != null && data['salt'] != null && data['check'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableBackup() async {
    stopAutoSync();
    app.setCloudBackup(false);
    await app.vault.clearSyncKey();
  }

  /// Uploads one entry (encrypted). Returns an error message, or null on success.
  Future<String?> pushEntry(Entry e) async {
    final key = app.vault.syncKey;
    if (user == null || key == null) return 'Backup is not turned on.';
    try {
      await _entries.doc(e.id).set({
        'blob': await app.vault.sealString(jsonEncode(e.toJson()), key: key),
        'updatedAt': e.updatedAt,
      });
      return null;
    } catch (err) {
      return '$err';
    }
  }

  /// Marks an entry as deleted in the cloud, so your other phones delete it too.
  Future<void> deleteRemote(String id) async {
    if (user == null) return;
    try {
      await _entries.doc(id).set({
        'deleted': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Decrypts downloaded documents into entries and "deleted" markers.
  Future<_Pulled> _decode(Iterable<DocumentSnapshot<Map<String, dynamic>>> docs) async {
    final out = _Pulled();
    for (final d in docs) {
      final data = d.data();
      if (data == null) continue;
      if (data['deleted'] == true) {
        out.deleted[d.id] = (data['updatedAt'] as int?) ?? 0;
        continue;
      }
      try {
        final json = await app.vault.openString(data['blob'] as String, key: app.vault.syncKey);
        out.entries.add(Entry.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } catch (_) {
        // skip anything that cannot be decrypted
      }
    }
    return out;
  }

  // ---------- automatic sync ----------
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _subUid;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);

  /// Keeps this phone in step with your other devices without you doing anything:
  /// listens for changes live, and also runs a full sync when the app opens or resumes.
  Future<void> autoSync({bool force = false}) async {
    if (!available || user == null || !app.cloudBackup || app.vault.syncKey == null) {
      stopAutoSync();
      return;
    }
    _startListener();
    if (!force && DateTime.now().difference(_lastSync) < const Duration(seconds: 30)) return;
    _lastSync = DateTime.now();
    await syncNow();
  }

  void _startListener() {
    final u = user;
    if (u == null) return;
    if (_sub != null && _subUid == u.uid) return;
    stopAutoSync();
    _subUid = u.uid;
    _sub = _entries.snapshots().listen((snap) async {
      final changed = snap.docChanges
          .where((c) => c.type != DocumentChangeType.removed)
          .map((c) => c.doc)
          .toList();
      if (changed.isEmpty) return;
      final pulled = await _decode(changed);
      app.mergeRemote(pulled.entries, deleted: pulled.deleted);
    }, onError: (Object _) {});
  }

  void stopAutoSync() {
    _sub?.cancel();
    _sub = null;
    _subUid = null;
  }

  // ---------- manual / full sync ----------
  /// What the last sync did, shown to the person in Settings.
  String lastSyncMessage = '';

  /// True only if the last full sync finished with nothing left un-uploaded.
  bool lastSyncOk = false;

  /// Uploads everything new, downloads anything newer. Returns a message for the UI.
  Future<String> syncNow() async {
    final key = app.vault.syncKey;
    lastSyncOk = false;
    if (user == null || key == null) return 'Backup is not turned on.';
    try {
      final snap = await _entries.get();
      final pulledData = await _decode(snap.docs);
      final pulled = app.mergeRemote(pulledData.entries, deleted: pulledData.deleted);
      final inCloud = {for (final r in pulledData.entries) r.id: r.updatedAt};
      var uploaded = 0, failed = 0;
      String? firstError;
      for (final e in List<Entry>.of(app.entries)) {
        final at = inCloud[e.id];
        final gone = pulledData.deleted[e.id];
        if (gone != null && gone >= e.updatedAt) continue;
        if (at == null || e.updatedAt > at) {
          final err = await pushEntry(e);
          if (err == null) {
            uploaded++;
            inCloud[e.id] = e.updatedAt;
          } else {
            failed++;
            firstError ??= err;
          }
        }
      }
      final String msg;
      if (failed > 0) {
        msg = 'Could not upload $failed of ${uploaded + failed} entries: $firstError';
      } else if (app.entries.isEmpty) {
        msg = 'No entries on this phone yet, so nothing to back up. Write one, then tap Sync now.';
      } else {
        msg =
            'Uploaded $uploaded, restored $pulled. Your cloud backup holds '
            '${inCloud.length} ${inCloud.length == 1 ? 'entry' : 'entries'}.';
      }
      lastSyncOk = failed == 0;
      lastSyncMessage = msg;
      return msg;
    } catch (e) {
      lastSyncMessage = 'Sync failed: $e';
      return lastSyncMessage;
    }
  }
}

class _Pulled {
  final List<Entry> entries = [];
  final Map<String, int> deleted = {};
}
