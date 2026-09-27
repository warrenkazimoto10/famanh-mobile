import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adiake_livraison_express/data/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> secureStore;

  setUp(() {
    secureStore = <String, String>{};

    // Mock du plugin flutter_secure_storage avec un stockage en mémoire.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return secureStore[key];
        case 'write':
          secureStore[key!] = args['value'] as String;
          return null;
        case 'delete':
          secureStore.remove(key);
          return null;
        case 'readAll':
          return secureStore;
        case 'containsKey':
          return secureStore.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  test('load() migre un token hérité de SharedPreferences vers le secure storage',
      () async {
    SharedPreferences.setMockInitialValues({'api_token': 'legacy-token'});

    await ApiSession.load();

    expect(ApiSession.token, 'legacy-token');
    // Le token est désormais dans le secure storage…
    expect(secureStore['api_token'], 'legacy-token');
    // …et retiré de SharedPreferences (plus en clair).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_token'), isNull);
  });

  test('setToken écrit dans le secure storage et le vide à la déconnexion',
      () async {
    SharedPreferences.setMockInitialValues({});

    await ApiSession.setToken('abc123');
    expect(ApiSession.token, 'abc123');
    expect(secureStore['api_token'], 'abc123');

    await ApiSession.setToken(null);
    expect(ApiSession.token, isNull);
    expect(secureStore.containsKey('api_token'), isFalse);
  });

  test('load() sans token laisse la session vide', () async {
    SharedPreferences.setMockInitialValues({});

    await ApiSession.load();

    expect(ApiSession.token, isNull);
  });
}
