// Test de démarrage de l'app.
//
// Les images réseau (logo Google sur l'écran de login) sont mockées via
// network_image_mock pour éviter les erreurs HTTP 400 en environnement de test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:adiake_livraison_express/app/adiake_app.dart';

void main() {
  testWidgets('L’app démarre sans erreur', (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const AdiakeApp());
      // Laisse le splash terminer son animation (2200ms) et sa navigation
      // différée (2500ms) vers l'onboarding, puis vider les timers one-shot.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
