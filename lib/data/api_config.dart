import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  /// URL de l'API Laravel selon la cible d'exécution.
  /// - Web (Edge/Chrome sur le même PC): http://127.0.0.1:8000
  /// - Android emulator: http://10.0.2.2:8000
  /// - Device physique sur le même Wi‑Fi: http://IP_PC:8000
  static const _webHost = 'http://127.0.0.1:8000';
  static const _deviceHost = 'http://172.20.10.11:8000';

  static String get baseUrl {
    if (kIsWeb) {
      if (kReleaseMode) {
        // En production/release web, on pointe vers le sous-dossier backend du même domaine
        return '${Uri.base.origin}/backend';
      }
      return _webHost;
    }
    return _deviceHost;
  }
}

