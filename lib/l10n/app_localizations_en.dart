// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorGenericTitle => 'Oops! An error occurred';

  @override
  String get errorRetryButton => 'RETRY';

  @override
  String get foodHubTitle => 'FOOD DELIVERY';

  @override
  String get foodHubSearchHint => 'Search for a restaurant...';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryLocal => 'Local';

  @override
  String get categoryFastFood => 'Fast Food';

  @override
  String get categoryPizza => 'Pizza';

  @override
  String get categoryBurger => 'Burger';

  @override
  String get categoryGrill => 'Grill';

  @override
  String get residenceUnknown => 'Unknown';

  @override
  String get residenceDescription => 'Description';

  @override
  String get residenceNoDescription => 'No description available.';

  @override
  String get residenceAmenities => 'Amenities';

  @override
  String get residencePricePerNight => 'Price per night';

  @override
  String get residenceBookButton => 'BOOK';
}
