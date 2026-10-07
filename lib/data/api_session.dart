import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class ApiSession {
  /// Clé de stockage du token. Publique pour que les isolates secondaires
  /// (ex: service de tracking en arrière-plan) lisent EXACTEMENT la même clé.
  static const tokenKey = 'api_token';

  /// Stockage chiffré (Keystore Android / Keychain iOS) — remplace
  /// SharedPreferences qui conservait le token en clair.
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? _token;

  static String? get token => _token;

  static final currentUser = ValueNotifier<UserMeDto?>(null);

  static Future<void> load() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString(tokenKey);
        return;
      }
      _token = await secureStorage.read(key: tokenKey);

      // Migration unique : si un token subsiste en clair dans SharedPreferences
      // (ancienne version), on le déplace vers le stockage chiffré.
      if (_token == null || _token!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(tokenKey);
        if (legacy != null && legacy.isNotEmpty) {
          _token = legacy;
          await secureStorage.write(key: tokenKey, value: legacy);
          await prefs.remove(tokenKey);
        }
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString(tokenKey);
      } catch (_) {}
    }
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        if (token == null || token.isEmpty) {
          await prefs.remove(tokenKey);
          currentUser.value = null;
        } else {
          await prefs.setString(tokenKey, token);
        }
        return;
      }

      if (token == null || token.isEmpty) {
        await secureStorage.delete(key: tokenKey);
        currentUser.value = null;
      } else {
        await secureStorage.write(key: tokenKey, value: token);
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (token == null || token.isEmpty) {
          await prefs.remove(tokenKey);
          currentUser.value = null;
        } else {
          await prefs.setString(tokenKey, token);
        }
      } catch (_) {}
    }
  }

  static Future<void> refreshMe() async {
    if (_token == null || _token!.isEmpty) {
      currentUser.value = null;
      return;
    }
    try {
      final me = await ApiClient.me();
      currentUser.value = me;
    } catch (_) {}
  }
}
