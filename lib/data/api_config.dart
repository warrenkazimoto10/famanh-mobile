import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  /// URL de l'API Laravel.
  /// Peut être surchargée lors du build (Codemagic, etc.) via:
  /// flutter build apk --dart-define=API_URL=https://votre-domaine.com
  static const String _envUrl = String.fromEnvironment('API_URL');
  static const _localDeviceHost = 'http://172.20.10.11:8000';
  static const _webHost = 'http://127.0.0.1:8000';

  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }
    if (kIsWeb) {
      if (kReleaseMode) {
        return '${Uri.base.origin}/backend';
      }
      return _webHost;
    }
    return _localDeviceHost;
  }
}

