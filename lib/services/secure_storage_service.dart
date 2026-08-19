import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service d'abstraction pour le stockage local sécurisé des états et préférences de l'utilisateur.
/// Pour les secrets / jetons d'authentification sensibles, il est fortement recommandé
/// d'utiliser la dépendance flutter_secure_storage (qui s'appuie sur KeyStore Android / KeyChain iOS).
class SecureStorageService {
  static SharedPreferences? _prefs;

  static Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Stocke un indicateur booléen (ex: onboardingCompleted)
  static Future<bool> setBool(String key, bool value) async {
    await _init();
    return _prefs!.setBool(key, value);
  }

  /// Lit un indicateur booléen
  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _init();
    return _prefs!.getBool(key) ?? defaultValue;
  }

  /// Stocke une chaîne de caractères
  static Future<bool> setString(String key, String value) async {
    await _init();
    return _prefs!.setString(key, value);
  }

  /// Lit une chaîne de caractères
  static Future<String?> getString(String key) async {
    await _init();
    return _prefs!.getString(key);
  }

  /// Efface une clé spécifique
  static Future<bool> remove(String key) async {
    await _init();
    return _prefs!.remove(key);
  }

  /// Efface tout le stockage local
  static Future<bool> clearAll() async {
    await _init();
    debugPrint('Clear storage local effectué.');
    return _prefs!.clear();
  }
}
