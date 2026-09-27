// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get errorGenericTitle => 'Oups ! Une erreur est survenue';

  @override
  String get errorRetryButton => 'RÉESSAYER';

  @override
  String get foodHubTitle => 'RESTAURATION';

  @override
  String get foodHubSearchHint => 'Rechercher un restaurant...';

  @override
  String get categoryAll => 'Tout';

  @override
  String get categoryLocal => 'Local';

  @override
  String get categoryFastFood => 'Fast Food';

  @override
  String get categoryPizza => 'Pizza';

  @override
  String get categoryBurger => 'Burger';

  @override
  String get categoryGrill => 'Grillades';

  @override
  String get residenceUnknown => 'Inconnu';

  @override
  String get residenceDescription => 'Description';

  @override
  String get residenceNoDescription => 'Aucune description disponible.';

  @override
  String get residenceAmenities => 'Équipements';

  @override
  String get residencePricePerNight => 'Prix par nuit';

  @override
  String get residenceBookButton => 'RÉSERVER';
}
