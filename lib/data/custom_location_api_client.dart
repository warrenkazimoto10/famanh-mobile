import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'api_config.dart';
import 'api_session.dart';

class CustomLocationApiClient {
  static Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return base.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    return base;
  }

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && ApiSession.token != null && ApiSession.token!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${ApiSession.token}';
    }
    return h;
  }

  /// Récupération des polygones de quartiers enregistrés
  static Future<List<Map<String, dynamic>>> getZones() async {
    final res = await http.get(_uri('/api/locations/zones'), headers: _headers(auth: false));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Récupération des points de repère (POI / Carrefours / Commerces)
  static Future<List<Map<String, dynamic>>> getLandmarks({bool popularOnly = false}) async {
    final query = popularOnly ? {'popular_only': '1'} : <String, dynamic>{};
    final res = await http.get(_uri('/api/locations/landmarks', query), headers: _headers(auth: false));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Recherche textuelle intelligente de quartiers et repères
  static Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await http.get(_uri('/api/locations/search', {'q': query}), headers: _headers(auth: false));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Reverse géocodage personnalisé (Détection de quartier + repères proches)
  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    final res = await http.post(
      _uri('/api/locations/reverse'),
      headers: _headers(auth: false),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Création d'un quartier (Polygone) par l'admin
  static Future<Map<String, dynamic>> storeZone({
    required String name,
    required List<LatLng> points,
    String color = '#EAB308',
    double deliverySurcharge = 0.0,
    String? notes,
  }) async {
    final coords = points.map((p) => [p.latitude, p.longitude]).toList();
    final res = await http.post(
      _uri('/api/admin/locations/zones'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'polygon_coordinates': coords,
        'color': color,
        'delivery_surcharge': deliverySurcharge,
        'notes': notes,
      }),
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Erreur lors de l\'enregistrement du quartier');
  }

  /// Création d'un point de repère précis par l'admin
  static Future<Map<String, dynamic>> storeLandmark({
    required String name,
    required double lat,
    required double lng,
    String category = 'landmark',
    int? zoneId,
    String? addressHint,
    bool isPopular = false,
  }) async {
    final res = await http.post(
      _uri('/api/admin/locations/landmarks'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'lat': lat,
        'lng': lng,
        'category': category,
        'zone_id': zoneId,
        'address_hint': addressHint,
        'is_popular': isPopular,
      }),
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Erreur lors de l\'enregistrement du repère');
  }
}
