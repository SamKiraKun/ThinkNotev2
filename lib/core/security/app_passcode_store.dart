import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../storage/local_storage.dart';
import 'local_notes_cipher.dart';

class AppPasscodeSecrets {
  const AppPasscodeSecrets({
    required this.salt,
    required this.hash,
  });

  final String salt;
  final String hash;
}

class AppPasscodeStore {
  AppPasscodeStore({
    required SharedPreferences preferences,
    required FlutterSecureStorage secureStorage,
  })  : _preferences = preferences,
        _secureStorage = secureStorage;

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;

  bool hasConfiguredPasscode() {
    return _preferences.getBool(StorageKeys.hasAppPasscode) ??
        _preferences.getString(StorageKeys.lockPinHash) != null;
  }

  Future<AppPasscodeSecrets?> readSecrets() async {
    final secureSalt = await _secureStorage.read(key: StorageKeys.lockPinSalt);
    final secureHash = await _secureStorage.read(key: StorageKeys.lockPinHash);

    if (_isPresent(secureSalt) && _isPresent(secureHash)) {
      return AppPasscodeSecrets(salt: secureSalt!, hash: secureHash!);
    }

    return migrateLegacyPasscodeIfNeeded();
  }

  Future<AppPasscodeSecrets?> migrateLegacyPasscodeIfNeeded() async {
    final legacySalt = _preferences.getString(StorageKeys.lockPinSalt);
    final legacyHash = _preferences.getString(StorageKeys.lockPinHash);

    if (!_isPresent(legacySalt) || !_isPresent(legacyHash)) {
      return null;
    }

    await _secureStorage.write(key: StorageKeys.lockPinSalt, value: legacySalt);
    await _secureStorage.write(key: StorageKeys.lockPinHash, value: legacyHash);
    await _preferences.setBool(StorageKeys.hasAppPasscode, true);
    await _preferences.remove(StorageKeys.lockPinSalt);
    await _preferences.remove(StorageKeys.lockPinHash);

    return AppPasscodeSecrets(salt: legacySalt!, hash: legacyHash!);
  }

  Future<void> writeSecrets({
    required String salt,
    required String hash,
  }) async {
    await _secureStorage.write(key: StorageKeys.lockPinSalt, value: salt);
    await _secureStorage.write(key: StorageKeys.lockPinHash, value: hash);
    await _preferences.setBool(StorageKeys.hasAppPasscode, true);
    await _preferences.remove(StorageKeys.lockPinSalt);
    await _preferences.remove(StorageKeys.lockPinHash);
  }

  Future<void> clearSecrets() async {
    await _secureStorage.delete(key: StorageKeys.lockPinSalt);
    await _secureStorage.delete(key: StorageKeys.lockPinHash);
    await _preferences.remove(StorageKeys.hasAppPasscode);
    await _preferences.remove(StorageKeys.lockPinSalt);
    await _preferences.remove(StorageKeys.lockPinHash);
  }

  bool _isPresent(String? value) => value != null && value.isNotEmpty;
}

final appPasscodeStoreProvider = Provider<AppPasscodeStore>((ref) {
  return AppPasscodeStore(
    preferences: ref.watch(sharedPreferencesProvider),
    secureStorage: ref.watch(flutterSecureStorageProvider),
  );
});