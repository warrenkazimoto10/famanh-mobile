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
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8000';
      }
      if (host.startsWith('192.168.') || host.startsWith('172.') || host.startsWith('10.')) {
        return '${Uri.base.scheme}://$host:8000';
      }
      return '${Uri.base.origin}/backend';
    }
    return _localDeviceHost;
  }
}

