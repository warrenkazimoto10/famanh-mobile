import 'package:flutter/material.dart';

import 'app/adiake_app.dart';
import 'data/api_session.dart';
import 'features/food/food_cart.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiSession.load();
  await FoodCart.instance.init();
  await FcmService.instance.initialize(navigatorKey: AdiakeApp.navigatorKey);
  try {
    await ApiSession.refreshMe();
  } catch (_) {
    // Ignore: l'app peut démarrer même si /me échoue (offline, backend down, etc.)
  }
  runApp(const AdiakeApp());
}
