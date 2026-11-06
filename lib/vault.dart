import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for everything the app stores on disk.
///
/// The random 256-bit key lives in the Android Keystore (through
/// flutter_secure_storage), never in the app's own files.
// These run on a background isolate (see Vault.seal / Vault.open).
Future<Uint8List> _sealOffThread(List<int> keyBytes, List<int> plain) async {
  final box = await AesGcm.with256bits().encrypt(plain, secretKey: SecretKey(keyBytes));
  return box.concatenation();
}

Future<Uint8List> _openOffThread(List<int> keyBytes, List<int> data) async {
  final box = SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
  final clear = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(keyBytes));
  return Uint8List.fromList(clear);
}

class Vault {
  /// Payloads bigger than this (photos, a long diary) are encrypted on another isolate,
  /// because plain-Dart AES would freeze the screen for a moment otherwise.
  static const int _isolateThreshold = 16 * 1024;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _localKeyName = 'pawsie_local_key';
  static const String _syncKeyName = 'pawsie_sync_key';
  static const int _nonceLen = 12;
  static const int _macLen = 16;

  final AesGcm _gcm = AesGcm.with256bits();
  SecretKey? _key;
  SecretKey? _syncKey;

  Future<void> init() async {
    var b64 = await _storage.read(key: _localKeyName);
    if (b64 == null) {
      final r = Random.secure();
      final bytes = Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
      b64 = base64Encode(bytes);
      await _storage.write(key: _localKeyName, value: b64);
    }
    _key = SecretKey(base64Decode(b64));
    final s = await _storage.read(key: _syncKeyName);
    _syncKey = s == null ? null : SecretKey(base64Decode(s));
  }

  /// Forgets every key. Anything encrypted before this can no longer be read.
  Future<void> wipe() async {
    await _storage.delete(key: _localKeyName);
    await _storage.delete(key: _syncKeyName);
    _key = null;
    _syncKey = null;
  }

  // ---------- local data ----------
  Future<Uint8List> seal(List<int> plain, {SecretKey? key}) async {
    final k = key ?? _key!;
    if (plain.length >= _isolateThreshold) {
      final keyBytes = await k.extractBytes();
      return Isolate.run(() => _sealOffThread(keyBytes, plain));
    }
    final box = await _gcm.encrypt(plain, secretKey: k);
    return box.concatenation();
  }

  Future<Uint8List> open(List<int> data, {SecretKey? key}) async {
    final k = key ?? _key!;
    if (data.length >= _isolateThreshold) {
      final keyBytes = await k.extractBytes();
      return Isolate.run(() => _openOffThread(keyBytes, data));
    }
    final box = SecretBox.fromConcatenation(data, nonceLength: _nonceLen, macLength: _macLen);
    return Uint8List.fromList(await _gcm.decrypt(box, secretKey: k));
  }

  Future<String> sealString(String s, {SecretKey? key}) async =>
      base64Encode(await seal(utf8.encode(s), key: key));

  Future<String> openString(String b64, {SecretKey? key}) async =>
      utf8.decode(await open(base64Decode(b64), key: key));

  // ---------- cloud backup key (derived from a passphrase) ----------
  bool get hasSyncKey => _syncKey != null;
  SecretKey? get syncKey => _syncKey;

  List<int> newSalt() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256));
  }

  Future<SecretKey> deriveSyncKey(String passphrase, List<int> salt) async {
    // 100,000 rounds of hashing takes seconds in plain Dart, so do it on another
    // isolate to keep the app responsive.
    final bytes = await Isolate.run<List<int>>(() async {
      final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
      final key = await kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
      return key.extractBytes();
    });
    return SecretKey(bytes);
  }

  Future<void> storeSyncKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    await _storage.write(key: _syncKeyName, value: base64Encode(bytes));
    _syncKey = SecretKey(bytes);
  }

  Future<void> clearSyncKey() async {
    await _storage.delete(key: _syncKeyName);
    _syncKey = null;
  }
}
