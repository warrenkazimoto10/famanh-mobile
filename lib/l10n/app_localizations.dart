import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @errorGenericTitle.
  ///
  /// In fr, this message translates to:
  /// **'Oups ! Une erreur est survenue'**
  String get errorGenericTitle;

  /// No description provided for @errorRetryButton.
  ///
  /// In fr, this message translates to:
  /// **'RÉESSAYER'**
  String get errorRetryButton;

  /// No description provided for @foodHubTitle.
  ///
  /// In fr, this message translates to:
  /// **'RESTAURATION'**
  String get foodHubTitle;

  /// No description provided for @foodHubSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un restaurant...'**
  String get foodHubSearchHint;

  /// No description provided for @categoryAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get categoryAll;

  /// No description provided for @categoryLocal.
  ///
  /// In fr, this message translates to:
  /// **'Local'**
  String get categoryLocal;

  /// No description provided for @categoryFastFood.
  ///
  /// In fr, this message translates to:
  /// **'Fast Food'**
  String get categoryFastFood;

  /// No description provided for @categoryPizza.
  ///
  /// In fr, this message translates to:
  /// **'Pizza'**
  String get categoryPizza;

  /// No description provided for @categoryBurger.
  ///
  /// In fr, this message translates to:
  /// **'Burger'**
  String get categoryBurger;

  /// No description provided for @categoryGrill.
  ///
  /// In fr, this message translates to:
  /// **'Grillades'**
  String get categoryGrill;

  /// No description provided for @residenceUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get residenceUnknown;

  /// No description provided for @residenceDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get residenceDescription;

  /// No description provided for @residenceNoDescription.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description disponible.'**
  String get residenceNoDescription;

  /// No description provided for @residenceAmenities.
  ///
  /// In fr, this message translates to:
  /// **'Équipements'**
  String get residenceAmenities;

  /// No description provided for @residencePricePerNight.
  ///
  /// In fr, this message translates to:
  /// **'Prix par nuit'**
  String get residencePricePerNight;

  /// No description provided for @residenceBookButton.
  ///
  /// In fr, this message translates to:
  /// **'RÉSERVER'**
  String get residenceBookButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
