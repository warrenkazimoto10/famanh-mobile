import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DeliveryLocationResult {
  const DeliveryLocationResult({
    required this.location,
    required this.addressLabel,
    this.city,
    this.neighborhood,
    this.streetLandmark,
    this.doorDetails,
  });

  final LatLng location;
  final String addressLabel;
  final String? city;
  final String? neighborhood;
  final String? streetLandmark;
  final String? doorDetails;
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.full,
    required this.location,
    required this.distanceKm,
    this.city,
    this.quarter,
  });

  final String title;
  final String subtitle;
  final String full;
  final LatLng location;
  final double distanceKm;
  final String? city;
  final String? quarter;
}

class _LocalLandmark {
  const _LocalLandmark({
    required this.name,
    required this.subtitle,
    required this.location,
    required this.keywords,
    this.city = 'Adiaké',
    this.quarter,
  });

  final String name;
  final String subtitle;
  final LatLng location;
  final List<String> keywords;
  final String city;
  final String? quarter;
}

final List<_LocalLandmark> _knownLocalLandmarks = const [
  // --- ADIAKÉ CENTRE & SITES CLÉS ---
  _LocalLandmark(
    name: "Grande Mosquée d'Adiaké",
    subtitle: "Quartier Résidentiel, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2861, -3.3038),
    keywords: ['mosquée', 'mosquee', 'mosque', 'grande mosquée', 'prière', 'islam', 'adiaké', 'adiake'],
    quarter: "Quartier Résidentiel",
  ),
  _LocalLandmark(
    name: "Église Catholique Saint-Jacques",
    subtitle: "Centre-Ville, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2875, -3.3050),
    keywords: ['église', 'eglise', 'catholique', 'saint-jacques', 'saint jacques', 'paroisse', 'adiaké'],
    quarter: "Centre-Ville",
  ),
  _LocalLandmark(
    name: "Hôpital Général d'Adiaké",
    subtitle: "Avenue Principale, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2882, -3.3021),
    keywords: ['hôpital', 'hopital', 'centre de santé', 'urgences', 'maternité', 'médical', 'adiaké'],
    quarter: "Avenue Principale",
  ),
  _LocalLandmark(
    name: "Pharmacie Moderne d'Adiaké",
    subtitle: "Avenue Principale B101, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2865, -3.3045),
    keywords: ['pharmacie', 'moderne', 'officine', 'médicaments', 'b101', 'adiaké'],
    quarter: "Centre-Ville",
  ),
  _LocalLandmark(
    name: "Pharmacie de la Lagune d'Adiaké",
    subtitle: "Route du Débarcadère, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2845, -3.3030),
    keywords: ['pharmacie', 'lagune', 'officine', 'adiaké'],
    quarter: "Quartier Lagunaire",
  ),
  _LocalLandmark(
    name: "Mairie d'Adiaké",
    subtitle: "Place Publique, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2858, -3.3032),
    keywords: ['mairie', 'hôtel de ville', 'hotel de ville', 'état civil', 'municipalité', 'adiaké'],
    quarter: "Centre-Ville",
  ),
  _LocalLandmark(
    name: "Préfecture d'Adiaké",
    subtitle: "Quartier Administratif, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2870, -3.3028),
    keywords: ['préfecture', 'prefecture', 'sous-préfecture', 'administration', 'adiaké'],
    quarter: "Quartier Administratif",
  ),
  _LocalLandmark(
    name: "Grand Marché d'Adiaké",
    subtitle: "Centre Commerçant, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2855, -3.3060),
    keywords: ['marché', 'marche', 'grand marché', 'commerce', 'boutiques', 'adiaké'],
    quarter: "Centre Commerçant",
  ),
  _LocalLandmark(
    name: "Gare Routière d'Adiaké",
    subtitle: "Entrée de Ville, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2895, -3.3090),
    keywords: ['gare', 'gare routière', 'transport', 'gbaka', 'taxi', 'adiaké'],
    quarter: "Entrée de Ville",
  ),
  _LocalLandmark(
    name: "Débarcadère / Port Lagunaire",
    subtitle: "Bord de Lagune Aby, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2825, -3.3015),
    keywords: ['débarcadère', 'debarcadere', 'port', 'pirogue', 'bateau', 'embarcadère', 'lagune', 'aby', 'adiaké'],
    quarter: "Quartier Lagunaire",
  ),
  _LocalLandmark(
    name: "Brigade de Gendarmerie d'Adiaké",
    subtitle: "Route d'Aboisso, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2898, -3.3040),
    keywords: ['gendarmerie', 'police', 'sécurité', 'brigade', 'adiaké'],
    quarter: "Route d'Aboisso",
  ),
  _LocalLandmark(
    name: "Commissariat de Police d'Adiaké",
    subtitle: "Quartier Administratif, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2868, -3.3025),
    keywords: ['commissariat', 'police', 'sécurité', 'adiaké'],
    quarter: "Quartier Administratif",
  ),
  _LocalLandmark(
    name: "Stade Municipal d'Adiaké",
    subtitle: "Quartier Sportif, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2840, -3.3070),
    keywords: ['stade', 'terrain', 'football', 'sport', 'adiaké'],
    quarter: "Quartier Sportif",
  ),
  _LocalLandmark(
    name: "Lycée Moderne Konan Camille",
    subtitle: "Quartier Scolaire, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2890, -3.3080),
    keywords: ['lycée', 'lycee', 'école', 'ecole', 'collège', 'moderne', 'konan camille', 'adiaké'],
    quarter: "Quartier Scolaire",
  ),
  _LocalLandmark(
    name: "Collège Moderne d'Adiaké",
    subtitle: "Quartier Scolaire, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2878, -3.3085),
    keywords: ['collège', 'college', 'école', 'ecole', 'adiaké'],
    quarter: "Quartier Scolaire",
  ),
  _LocalLandmark(
    name: "Station-Service TotalEnergies Adiaké",
    subtitle: "Avenue Principale, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2872, -3.3048),
    keywords: ['station', 'essence', 'carburant', 'total', 'totalenergies', 'adiaké'],
    quarter: "Avenue Principale",
  ),

  // --- QUARTIERS D'ADIAKÉ ---
  _LocalLandmark(
    name: "Quartier Résidentiel",
    subtitle: "Adiaké, Côte d'Ivoire",
    location: LatLng(5.2860, -3.3035),
    keywords: ['quartier résidentiel', 'résidentiel', 'residentiel', 'adiaké'],
    quarter: "Quartier Résidentiel",
  ),
  _LocalLandmark(
    name: "Quartier Ehourouan",
    subtitle: "Adiaké, Côte d'Ivoire",
    location: LatLng(5.2910, -3.3060),
    keywords: ['ehourouan', 'quartier ehourouan', 'adiaké'],
    quarter: "Quartier Ehourouan",
  ),
  _LocalLandmark(
    name: "Quartier Gnamiendissou",
    subtitle: "Adiaké, Côte d'Ivoire",
    location: LatLng(5.2810, -3.3080),
    keywords: ['gnamiendissou', 'quartier gnamiendissou', 'adiaké'],
    quarter: "Quartier Gnamiendissou",
  ),
  _LocalLandmark(
    name: "Quartier Kennedy",
    subtitle: "Adiaké, Côte d'Ivoire",
    location: LatLng(5.2885, -3.3010),
    keywords: ['kennedy', 'quartier kennedy', 'adiaké'],
    quarter: "Quartier Kennedy",
  ),
  _LocalLandmark(
    name: "Quartier Château",
    subtitle: "Adiaké, Côte d'Ivoire",
    location: LatLng(5.2850, -3.3090),
    keywords: ['château', 'chateau', 'chateau d eau', 'quartier château', 'adiaké'],
    quarter: "Quartier Château",
  ),

  // --- ASSINIE & ASSOUINDÉ ---
  _LocalLandmark(
    name: "Assinie Mafia (Plage & Village)",
    subtitle: "Littoral Assinie, Côte d'Ivoire",
    location: LatLng(5.1481, -3.2928),
    keywords: ['assinie', 'mafia', 'plage', 'mer', 'station balnéaire', 'hôtels'],
    city: "Assinie",
    quarter: "Assinie Mafia",
  ),
  _LocalLandmark(
    name: "Assinie France (Embouchure)",
    subtitle: "Prequ'île d'Assinie, Côte d'Ivoire",
    location: LatLng(5.1320, -3.2510),
    keywords: ['assinie france', 'embouchure', 'presqu ile', 'assinie'],
    city: "Assinie",
    quarter: "Assinie France",
  ),
  _LocalLandmark(
    name: "Débarcadère d'Assouindé",
    subtitle: "Assouindé, Littoral, Côte d'Ivoire",
    location: LatLng(5.1610, -3.4215),
    keywords: ['assouindé', 'assouinde', 'débarcadère', 'lagune', 'plage'],
    city: "Assouindé",
    quarter: "Assouindé Village",
  ),
  _LocalLandmark(
    name: "Coucoué Lodge (Assinie)",
    subtitle: "Bord de Lagune, Assinie, Côte d'Ivoire",
    location: LatLng(5.1420, -3.2850),
    keywords: ['coucoué', 'coucoue', 'lodge', 'hôtel', 'resort', 'assinie'],
    city: "Assinie",
  ),
  _LocalLandmark(
    name: "Les Heures Claires (Assinie)",
    subtitle: "Lagune Assinie, Côte d'Ivoire",
    location: LatLng(5.1450, -3.2880),
    keywords: ['heures claires', 'les heures claires', 'hôtel', 'resort', 'assinie'],
    city: "Assinie",
  ),
  _LocalLandmark(
    name: "Ehouarna Hôtel & Resort",
    subtitle: "Bord de Lagune, Adiaké, Côte d'Ivoire",
    location: LatLng(5.2880, -3.3010),
    keywords: ['ehouarna', 'hôtel', 'resort', 'hébergement', 'adiaké'],
    quarter: "Lagunaire",
  ),

  // --- ABIDJAN & AUTRES ZONES CLÉS ---
  _LocalLandmark(
    name: "Cocody (Abidjan)",
    subtitle: "Abidjan, Côte d'Ivoire",
    location: LatLng(5.3599, -4.0083),
    keywords: ['cocody', 'abidjan', 'riviera', 'ii plateaux'],
    city: "Abidjan",
    quarter: "Cocody",
  ),
  _LocalLandmark(
    name: "Marcory / Biétry (Abidjan)",
    subtitle: "Abidjan, Côte d'Ivoire",
    location: LatLng(5.3020, -3.9850),
    keywords: ['marcory', 'bietry', 'abidjan', 'zone 4'],
    city: "Abidjan",
    quarter: "Marcory",
  ),
  _LocalLandmark(
    name: "Aéroport International Félix Houphouët-Boigny",
    subtitle: "Port-Bouët, Abidjan, Côte d'Ivoire",
    location: LatLng(5.2614, -3.9258),
    keywords: ['aéroport', 'aeroport', 'vol', 'port bouet', 'abidjan'],
    city: "Abidjan",
    quarter: "Port-Bouët",
  ),
];

String _normalizeText(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"[éèêë]"), "e")
      .replaceAll(RegExp(r"[àâä]"), "a")
      .replaceAll(RegExp(r"[îï]"), "i")
      .replaceAll(RegExp(r"[ôö]"), "o")
      .replaceAll(RegExp(r"[ùûü]"), "u")
      .replaceAll(RegExp(r"[ç]"), "c")
      .replaceAll(RegExp(r"['’]"), " ")
      .replaceAll(RegExp(r"[^\w\s]"), " ")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
}

String _formatTitle(
  Map<String, dynamic> address, {
  required String fallback,
  Map<String, dynamic>? fullItem,
  String? query,
}) {
  final poiName = fullItem?['name']?.toString() ??
      address['name']?.toString() ??
      address['pharmacy']?.toString() ??
      address['amenity']?.toString() ??
      address['shop']?.toString() ??
      address['building']?.toString() ??
      address['healthcare']?.toString() ??
      address['hospital']?.toString() ??
      address['hotel']?.toString() ??
      address['commercial']?.toString() ??
      address['office']?.toString() ??
      address['tourism']?.toString() ??
      address['leisure']?.toString();

  if (poiName != null && poiName.trim().isNotEmpty) {
    return poiName.trim();
  }

  final displayParts = fallback.split(',');
  final firstPart = displayParts.isNotEmpty ? displayParts.first.trim() : '';

  final road = address['road']?.toString() ?? address['pedestrian']?.toString() ?? address['path']?.toString();
  final house = address['house_number']?.toString();

  final isGenericRoute = road != null && RegExp(r'^[A-Z]\d+$', caseSensitive: false).hasMatch(road.trim());

  if (firstPart.isNotEmpty && (!isGenericRoute || firstPart.toLowerCase() != road?.toLowerCase())) {
    if (house != null && house.isNotEmpty) {
      return '$house $firstPart'.trim();
    }
    return firstPart;
  }

  if (house != null && house.isNotEmpty && road != null && road.isNotEmpty) {
    return '$house $road'.trim();
  }

  if (query != null && query.trim().isNotEmpty) {
    final q = query.trim();
    return q[0].toUpperCase() + q.substring(1);
  }

  if (road != null && road.isNotEmpty && !isGenericRoute) return road.trim();
  return firstPart.isNotEmpty ? firstPart : (road ?? 'Position sélectionnée');
}

String _formatSubtitle(Map<String, dynamic> address, {String? currentTitle}) {
  String pick(List<String> keys) {
    for (final k in keys) {
      final v = address[k]?.toString();
      if (v != null && v.isNotEmpty && v.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) return v;
    }
    return '';
  }

  final road = pick(['road', 'pedestrian', 'path']);
  final quartier = pick(['neighbourhood', 'suburb', 'quarter', 'city_district']);
  final ville = pick(['city', 'town', 'village', 'municipality']);
  final state = pick(['state']);
  final country = pick(['country']);

  final parts = <String>[
    if (road.isNotEmpty && road.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) road,
    if (quartier.isNotEmpty && quartier.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) quartier,
    if (ville.isNotEmpty && ville.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) ville,
    if (state.isNotEmpty && state != ville && state.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) state,
    if (country.isNotEmpty && country.trim().toLowerCase() != currentTitle?.trim().toLowerCase()) country,
  ];

  return parts.join(', ');
}

class GasDeliveryLocationScreen extends StatefulWidget {
  const GasDeliveryLocationScreen({super.key});

  @override
  State<GasDeliveryLocationScreen> createState() => _GasDeliveryLocationScreenState();
}

class _GasDeliveryLocationScreenState extends State<GasDeliveryLocationScreen> {
  static const LatLng _adiake = LatLng(5.2867, -3.3042);
  static const Distance _distance = Distance();

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  final _cityCtrl = TextEditingController(text: 'Adiaké');
  final _neighborhoodCtrl = TextEditingController();
  final _streetLandmarkCtrl = TextEditingController();
  final _doorDetailsCtrl = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  bool _gettingGps = false;
  List<_PlaceSuggestion> _suggestions = const [];

  LatLng _selected = _adiake;
  String _selectedTitle = "Adiaké";
  String _selectedSubtitle = "Côte d’Ivoire";
  double _zoom = 15.5;
  int _reverseSeq = 0;
  bool _reversing = false;

  final List<({String name, String cat, LatLng pos})> _popularLocations = const [
    (name: 'Adiaké Centre', cat: 'Ville', pos: LatLng(5.2867, -3.3042)),
    (name: 'Assinie Mafia', cat: 'Plage', pos: LatLng(5.1481, -3.2928)),
    (name: 'Débarcadère Assouindé', cat: 'Lagune', pos: LatLng(5.1610, -3.4215)),
    (name: 'Hôpital Général', cat: 'Santé', pos: LatLng(5.2882, -3.3021)),
    (name: 'Grand Marché', cat: 'Commerce', pos: LatLng(5.2855, -3.3060)),
    (name: 'Cocody Abidjan', cat: 'Capitale', pos: LatLng(5.3599, -4.0083)),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _cityCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _streetLandmarkCtrl.dispose();
    _doorDetailsCtrl.dispose();
    super.dispose();
  }

  String get _computedFullAddress {
    final parts = <String>[];
    if (_neighborhoodCtrl.text.trim().isNotEmpty) {
      parts.add('Quartier ${_neighborhoodCtrl.text.trim()}');
    }
    if (_streetLandmarkCtrl.text.trim().isNotEmpty) {
      parts.add(_streetLandmarkCtrl.text.trim());
    }
    if (_doorDetailsCtrl.text.trim().isNotEmpty) {
      parts.add(_doorDetailsCtrl.text.trim());
    }
    if (_cityCtrl.text.trim().isNotEmpty) {
      parts.add(_cityCtrl.text.trim());
    } else {
      parts.add(_selectedTitle);
    }
    if (parts.isEmpty) return _selectedTitle;
    return parts.join(', ');
  }

  Future<void> _getCurrentGpsLocation() async {
    setState(() => _gettingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez activer le service de géolocalisation GPS sur votre téléphone.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La permission de géolocalisation a été refusée.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Géolocalisation bloquée. Activez-la dans les paramètres.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final latLng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      _selectOnMap(latLng);
      _mapController.move(latLng, 16.5);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS exacte détectée !'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur GPS : ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingGps = false);
    }
  }

  Future<void> _search(String q) async {
    final rawQuery = q.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    final normQ = _normalizeText(rawQuery);
    final results = <_PlaceSuggestion>[];
    final titlesSeen = <String>{};

    // 1. RECHERCHE DANS LE DICTIONNAIRE LOCAL DES LIEUX D'ADIAKÉ / ASSINIE
    if (normQ.isNotEmpty) {
      for (final lm in _knownLocalLandmarks) {
        final normName = _normalizeText(lm.name);
        final normSub = _normalizeText(lm.subtitle);
        final matchKw = lm.keywords.any((kw) {
          final nKw = _normalizeText(kw);
          return normQ.contains(nKw) || nKw.contains(normQ);
        });

        if (normName.contains(normQ) || normSub.contains(normQ) || matchKw) {
          final distM = _distance.as(LengthUnit.Meter, _selected, lm.location);
          titlesSeen.add(lm.name.toLowerCase());
          results.add(
            _PlaceSuggestion(
              title: lm.name,
              subtitle: lm.subtitle,
              full: "${lm.name}, ${lm.subtitle}",
              location: lm.location,
              distanceKm: (distM / 1000.0),
              city: lm.city,
              quarter: lm.quarter,
            ),
          );
        }
      }
    }

    // 2. RECHERCHE MULTI-STRATÉGIE EN LIGNE NOMINATIM (OSM)
    try {
      Future<List<_PlaceSuggestion>> fetchQuery(String queryString, {required bool bounded}) async {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': queryString,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '10',
          'countrycodes': 'ci',
          if (bounded) 'viewbox': '-3.45,5.43,-3.12,5.20',
          if (bounded) 'bounded': '1',
        });

        final res = await http.get(
          uri,
          headers: const {
            'User-Agent': 'adiake_livraison_express/1.0 (mobile; Flutter)',
            'Accept-Language': 'fr',
          },
        );

        if (res.statusCode != 200) return [];
        final data = jsonDecode(res.body);
        final list = (data is List) ? data : <dynamic>[];

        final fetched = <_PlaceSuggestion>[];
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final display = m['display_name']?.toString() ?? '';
          final lat = double.tryParse(m['lat']?.toString() ?? '');
          final lon = double.tryParse(m['lon']?.toString() ?? '');
          if (display.isEmpty || lat == null || lon == null) continue;

          final address = (m['address'] is Map<String, dynamic>)
              ? (m['address'] as Map<String, dynamic>)
              : <String, dynamic>{};

          final title = _formatTitle(address, fallback: display, fullItem: m, query: rawQuery);
          final subtitle = _formatSubtitle(address, currentTitle: title);
          final loc = LatLng(lat, lon);
          final distMeters = _distance.as(LengthUnit.Meter, _selected, loc);

          fetched.add(
            _PlaceSuggestion(
              title: title,
              subtitle: subtitle,
              full: display,
              location: loc,
              distanceKm: (distMeters / 1000.0),
              city: address['city']?.toString() ?? address['town']?.toString() ?? address['village']?.toString(),
              quarter: address['neighbourhood']?.toString() ?? address['suburb']?.toString() ?? address['quarter']?.toString(),
            ),
          );
        }
        return fetched;
      }

      // 2a. Requête directe restreinte
      var onlineResults = await fetchQuery(rawQuery, bounded: true);

      // 2b. Requête nettoyée si pas de résultat
      if (onlineResults.isEmpty) {
        onlineResults = await fetchQuery("$normQ Adiaké", bounded: false);
      }

      // 2c. Requête large toute Côte d'Ivoire
      if (onlineResults.isEmpty) {
        onlineResults = await fetchQuery(rawQuery, bounded: false);
      }

      // Fusion et déduplication
      for (final item in onlineResults) {
        if (!titlesSeen.contains(item.title.toLowerCase())) {
          titlesSeen.add(item.title.toLowerCase());
          results.add(item);
        }
      }
    } catch (_) {}

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(v));
  }

  void _selectSuggestion(_PlaceSuggestion s) {
    setState(() {
      _selected = s.location;
      _suggestions = const [];
      _searchCtrl.text = s.title;
      _selectedTitle = s.title;
      _selectedSubtitle = s.subtitle;
      if (s.city != null && s.city!.isNotEmpty) _cityCtrl.text = s.city!;
      if (s.quarter != null && s.quarter!.isNotEmpty) _neighborhoodCtrl.text = s.quarter!;
    });
    _focusNode.unfocus();
    _mapController.move(_selected, 16.5);
  }

  void _selectOnMap(LatLng p) {
    setState(() {
      _selected = p;
      _suggestions = const [];
      _selectedTitle = "Géolocalisation en cours...";
      _selectedSubtitle = "Recherche de l’adresse...";
      _reversing = true;
    });
    _reverseGeocode(p);
  }

  Future<void> _reverseGeocode(LatLng p) async {
    final seq = ++_reverseSeq;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': p.latitude.toString(),
        'lon': p.longitude.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
      });

      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'adiake_livraison_express/1.0 (mobile; Flutter)',
          'Accept-Language': 'fr',
        },
      );

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body);
      if (!mounted || seq != _reverseSeq) return;

      final itemMap = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
      final address = (itemMap['address'] is Map<String, dynamic>)
          ? (itemMap['address'] as Map<String, dynamic>)
          : <String, dynamic>{};
      final display = itemMap['display_name']?.toString() ?? '';

      final title = _formatTitle(address, fallback: display.isEmpty ? 'Position sélectionnée' : display, fullItem: itemMap);
      final subtitle = _formatSubtitle(address, currentTitle: title);

      final city = address['city'] ?? address['town'] ?? address['village'] ?? 'Adiaké';
      final quarter = address['neighbourhood'] ?? address['suburb'] ?? address['quarter'] ?? '';
      final road = address['road'] ?? address['pedestrian'] ?? '';

      setState(() {
        _selectedTitle = title;
        _selectedSubtitle = subtitle.isEmpty ? 'Côte d’Ivoire' : subtitle;
        _cityCtrl.text = city.toString();
        if (quarter.toString().isNotEmpty) _neighborhoodCtrl.text = quarter.toString();
        if (road.toString().isNotEmpty) _streetLandmarkCtrl.text = road.toString();
        _reversing = false;
      });
    } catch (_) {
      if (!mounted || seq != _reverseSeq) return;
      setState(() {
        _selectedTitle = "Position repérée sur la carte";
        _selectedSubtitle = "${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";
        _reversing = false;
      });
    }
  }

  void _showAddressDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Icon(Icons.edit_location_alt_rounded, color: Color(0xFF006194), size: 22),
                SizedBox(width: 8),
                Text(
                  'Préciser les détails de livraison',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0A2540)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Aidez le livreur à vous retrouver rapidement avec des repères visuels.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _cityCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_city_rounded, size: 20),
                labelText: 'Ville / Localité',
                hintText: 'ex: Adiaké, Assinie, Abidjan',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _neighborhoodCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.holiday_village_rounded, size: 20),
                labelText: 'Quartier / Secteur',
                hintText: 'ex: Quartier Résidentiel, Assinie Mafia',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _streetLandmarkCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.add_road_rounded, size: 20),
                labelText: 'Rue / Repère visuel',
                hintText: 'ex: Face à la pharmacie, Carrefour Château',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _doorDetailsCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.door_front_door_rounded, size: 20),
                labelText: 'Complément (Porte / Villa / Étage)',
                hintText: 'ex: Villa N°12, Porte 4, 2ème étage',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Enregistrer les précisions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. CARTE INTERACTIVE FLUTTER_MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _adiake,
              initialZoom: _zoom,
              onTap: (_, p) => _selectOnMap(p),
              onPositionChanged: (pos, _) {
                _zoom = pos.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'adiake_livraison_express',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 70,
                    height: 70,
                    alignment: Alignment.topCenter,
                    child: _CustomMapPin(title: _selectedTitle),
                  ),
                ],
              ),
            ],
          ),

          // 2. HEADER SUPÉRIEUR AVEC BARRE DE RECHERCHE ET RICHE SUGGESTION
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A2540), size: 20),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _focusNode,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Rechercher ville, quartier, lieu…',
                                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                                  border: InputBorder.none,
                                  suffixIcon: _loading
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0052FF)),
                                          ),
                                        )
                                      : (_searchCtrl.text.isEmpty
                                          ? null
                                          : IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 20),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                _onSearchChanged('');
                                                _focusNode.unfocus();
                                              },
                                            )),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // SUGGESTIONS LIST (SI RECHERCHE EN COURS)
                      if (_suggestions.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, i) {
                                final s = _suggestions[i];
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.place_rounded, color: Color(0xFF0052FF), size: 18),
                                  ),
                                  title: Text(
                                    s.title,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A2540)),
                                  ),
                                  subtitle: Text(
                                    s.subtitle,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  trailing: Text(
                                    '~ ${s.distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () => _selectSuggestion(s),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. BARRE DE CHIPS DE LIEUX POPULAIRES (Adiaké, Assinie, Abidjan)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _popularLocations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final item = _popularLocations[i];
                      return ActionChip(
                        avatar: const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF0052FF)),
                        label: Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        backgroundColor: Colors.white,
                        elevation: 2,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          _selectOnMap(item.pos);
                          _mapController.move(item.pos, 16.0);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4. BOUTONS D'ACTION FLOTTANTS SUR LA CARTE (GPS & ZOOM)
          Positioned(
            right: 16,
            bottom: 155,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'gps_fab',
                  backgroundColor: const Color(0xFF0052FF),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: _gettingGps ? null : _getCurrentGpsLocation,
                  child: _gettingGps
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location_rounded, size: 20),
                ),
                const SizedBox(height: 8),

                FloatingActionButton.small(
                  heroTag: 'zoom_in_fab',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0A2540),
                  elevation: 3,
                  onPressed: () => _mapController.move(_selected, (_zoom + 1).clamp(3, 19)),
                  child: const Icon(Icons.add_rounded, size: 20),
                ),
                const SizedBox(height: 8),

                FloatingActionButton.small(
                  heroTag: 'zoom_out_fab',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0A2540),
                  elevation: 3,
                  onPressed: () => _mapController.move(_selected, (_zoom - 1).clamp(3, 19)),
                  child: const Icon(Icons.remove_rounded, size: 20),
                ),
              ],
            ),
          ),

          // 5. CARTE INFÉRIEURE DE CONFIRMATION AVEC PRÉCISION D'ADRESSE
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.place_rounded, color: Color(0xFF059669), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'POSITION DE LIVRAISON SÉLECTIONNÉE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 0.8),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showAddressDetailsModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.edit_rounded, size: 12, color: Color(0xFF0052FF)),
                              SizedBox(width: 4),
                              Text('Préciser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052FF))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    _reversing ? 'Recherche de l\'adresse en cours...' : _computedFullAddress,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0A2540)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _reversing
                          ? null
                          : () {
                              Navigator.of(context).pop(
                                DeliveryLocationResult(
                                  location: _selected,
                                  addressLabel: _computedFullAddress,
                                  city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
                                  neighborhood: _neighborhoodCtrl.text.trim().isEmpty ? null : _neighborhoodCtrl.text.trim(),
                                  streetLandmark: _streetLandmarkCtrl.text.trim().isEmpty ? null : _streetLandmarkCtrl.text.trim(),
                                  doorDetails: _doorDetailsCtrl.text.trim().isEmpty ? null : _doorDetailsCtrl.text.trim(),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _reversing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirmer cette position', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomMapPin extends StatelessWidget {
  const _CustomMapPin({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2540),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0052FF),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0052FF).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}
