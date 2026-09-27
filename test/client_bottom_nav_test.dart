import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adiake_livraison_express/widgets/client_bottom_nav.dart';

Widget _wrap(bool isAdmin) {
  return MaterialApp(
    home: Scaffold(
      body: ClientBottomNavBar(
        currentIndex: 0,
        isAdmin: isAdmin,
        onTap: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('affiche 4 onglets pour un client standard', (tester) async {
    await tester.pumpWidget(_wrap(false));

    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('COMMANDES'), findsOneWidget);
    expect(find.text('SERVICE'), findsOneWidget);
    expect(find.text('COMPTE'), findsOneWidget);
    expect(find.text('ADMIN'), findsNothing);
  });

  testWidgets('affiche l\'onglet Admin si isAdmin', (tester) async {
    await tester.pumpWidget(_wrap(true));

    expect(find.text('ADMIN'), findsOneWidget);
  });
}
