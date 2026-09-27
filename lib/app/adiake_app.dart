import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adiake_livraison_express/l10n/app_localizations.dart';

import '../theme/adiake_theme.dart';
import 'routes.dart';

class AdiakeApp extends StatelessWidget {
  const AdiakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famanh',
      debugShowCheckedModeBanner: false,
      theme: AdiakeTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

