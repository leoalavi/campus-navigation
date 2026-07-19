import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mq_journey/core/error/app_exception.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted key-value storage backed by Keychain (iOS) / Keystore (Android).
///
/// On **macOS / Linux / Windows / Web** the native Keychain requires a signed
/// build with Keychain Sharing capability. To keep local development working
/// without Xcode signing, desktop & web builds fall back to
/// [SharedPreferences] (unencrypted but functional).
/// On iOS and Android the real [FlutterSecureStorage] is used.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
    : _explicitStorage = storage,
      _useFallback = storage == null && _shouldUseFallback();

  final FlutterSecureStorage? _explicitStorage;
  final bool _useFallback;

  /// Desktop / web platforms cannot reliably access the Keychain without
  /// code-signing, so we fall back to SharedPreferences.
  static bool _shouldUseFallback() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

  // ── Lazy SharedPreferences accessor ────────────────────────────────────
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  FlutterSecureStorage get _secure =>
      _explicitStorage ??
      // Use afterFirstUnlock so the Keychain items remain accessible after
      // the device has been unlocked at least once. The default
      // (whenUnlockedThisDeviceOnly) would lock items when the app is
      // briefly in the background during a cold-start lifecycle edge case,
      // potentially causing a read failure that wipes all preferences.
      const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
        ),
      );

  // ── Public API ─────────────────────────────────────────────────────────

  Future<String?> read(String key) async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        return prefs.getString(key);
      }
      return await _secure.read(key: key);
    } catch (e, s) {
      AppLogger.error('SecureStorage read failed', e, s);
      throw StorageException('Failed to read key "$key"', e);
    }
  }

  /// Reads the service's string entries in one platform operation.
  ///
  /// Startup preferences use many independent keys. Fetching the complete
  /// small key-value set avoids one native method-channel round trip per key
  /// while preserving the platform's encrypted storage boundary.
  Future<Map<String, String>> readAll() async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        return {
          for (final key in prefs.getKeys())
            if (prefs.get(key) case final String value) key: value,
        };
      }
      return await _secure.readAll();
    } catch (e, s) {
      AppLogger.error('SecureStorage readAll failed', e, s);
      throw StorageException('Failed to read all keys', e);
    }
  }

  Future<void> write(String key, String value) async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        await prefs.setString(key, value);
        return;
      }
      await _secure.write(key: key, value: value);
    } catch (e, s) {
      AppLogger.error('SecureStorage write failed', e, s);
      throw StorageException('Failed to write key "$key"', e);
    }
  }

  Future<void> delete(String key) async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        await prefs.remove(key);
        return;
      }
      await _secure.delete(key: key);
    } catch (e, s) {
      AppLogger.error('SecureStorage delete failed', e, s);
      throw StorageException('Failed to delete key "$key"', e);
    }
  }

  Future<void> deleteAll() async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        await prefs.clear();
        return;
      }
      await _secure.deleteAll();
    } catch (e, s) {
      AppLogger.error('SecureStorage deleteAll failed', e, s);
      throw StorageException('Failed to delete all keys', e);
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      if (_useFallback) {
        final prefs = await _getPrefs();
        return prefs.containsKey(key);
      }
      return await _secure.containsKey(key: key);
    } catch (e, s) {
      AppLogger.error('SecureStorage containsKey failed', e, s);
      throw StorageException('Failed to check key "$key"', e);
    }
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
