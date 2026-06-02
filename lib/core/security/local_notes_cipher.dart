import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_env.dart';
import '../../features/auth/auth_providers.dart';

abstract class LocalNotesCipher {
  Future<String> encrypt(String value);
  Future<String> decrypt(String value);
  bool isEncrypted(String value);
}

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PassthroughLocalNotesCipher implements LocalNotesCipher {
  const PassthroughLocalNotesCipher();

  @override
  Future<String> decrypt(String value) async => value;

  @override
  Future<String> encrypt(String value) async => value;

  @override
  bool isEncrypted(String value) => false;
}

class SecureLocalNotesCipher implements LocalNotesCipher {
  SecureLocalNotesCipher(
    this._secretStore, {
    required String keyNamespace,
  }) : _keyName = 'thinknote.local_cipher.$keyNamespace';

  static const _prefix = 'enc:v1';
  static const _nonceLength = 12;

  final SecretStore _secretStore;
  final String _keyName;
  final AesGcm _cipher = AesGcm.with256bits();
  Future<SecretKey>? _secretKeyFuture;

  @override
  Future<String> encrypt(String value) async {
    if (isEncrypted(value)) {
      return value;
    }

    final secretKey = await _readOrCreateSecretKey();
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: secretKey,
      nonce: nonce,
    );

    return [
      _prefix,
      base64UrlEncode(secretBox.nonce),
      base64UrlEncode(secretBox.cipherText),
      base64UrlEncode(secretBox.mac.bytes),
    ].join(':');
  }

  @override
  Future<String> decrypt(String value) async {
    if (!isEncrypted(value)) {
      return value;
    }

    final parts = value.split(':');
    if (parts.length != 5 || parts[0] != 'enc' || parts[1] != 'v1') {
      return value;
    }

    final secretKey = await _readOrCreateSecretKey();
    final secretBox = SecretBox(
      base64Url.decode(parts[3]),
      nonce: base64Url.decode(parts[2]),
      mac: Mac(base64Url.decode(parts[4])),
    );

    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  @override
  bool isEncrypted(String value) {
    return value.startsWith('$_prefix:');
  }

  Future<SecretKey> _readOrCreateSecretKey() async {
    final cached = _secretKeyFuture;
    if (cached != null) {
      return cached;
    }

    final completer = Completer<SecretKey>();
    _secretKeyFuture = completer.future;

    try {
      final existing = await _secretStore.read(_keyName);
      if (existing != null && existing.isNotEmpty) {
        completer.complete(SecretKey(base64Url.decode(existing)));
        return completer.future;
      }

      final bytes = _randomBytes(32);
      final encoded = base64UrlEncode(bytes);
      await _secretStore.write(_keyName, encoded);
      completer.complete(SecretKey(bytes));
    } catch (error, stackTrace) {
      _secretKeyFuture = null;
      completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final localNotesCipherProvider = Provider<LocalNotesCipher>((ref) {
  final keyNamespace = AppEnv.enableExperimentalSync
      ? ref.watch(
              currentAuthSessionProvider.select((session) => session?.uid)) ??
          'default'
      : 'default';

  return SecureLocalNotesCipher(
    FlutterSecureSecretStore(ref.watch(flutterSecureStorageProvider)),
    keyNamespace: keyNamespace,
  );
});
