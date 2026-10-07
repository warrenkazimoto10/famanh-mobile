import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_session.dart';

class TaxiApiClient {
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

  /// Récupération des réglages tarifaires du Taxi
  static Future<Map<String, dynamic>> getSettings() async {
    final res = await http.get(_uri('/api/taxi/settings'), headers: _headers(auth: false));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    return {
      'base_fare_per_seat': 200,
      'private_ride_fare': 800,
      'per_km_fare': 150,
      'commission_percentage': 10,
    };
  }

  /// Radar des taxis disponibles en circulation
  static Future<List<Map<String, dynamic>>> getAvailableTaxis({double? lat, double? lng}) async {
    final query = <String, dynamic>{};
    if (lat != null) query['lat'] = lat;
    if (lng != null) query['lng'] = lng;

    final res = await http.get(_uri('/api/taxi/available', query), headers: _headers(auth: false));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final list = json['data'] as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Estimation de tarif pour un trajet
  static Future<Map<String, dynamic>> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String type, // 'shared' ou 'private'
    int seatsBooked = 1,
  }) async {
    final res = await http.post(
      _uri('/api/taxi/estimate'),
      headers: _headers(auth: false),
      body: jsonEncode({
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'type': type,
        'seats_booked': seatsBooked,
      }),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception('Erreur lors du calcul du tarif');
  }

  /// Commander un taxi (Partagé ou Privatisé)
  static Future<Map<String, dynamic>> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String type, // 'shared' ou 'private'
    int seatsBooked = 1,
  }) async {
    final res = await http.post(
      _uri('/api/taxi/request'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'type': type,
        'seats_booked': seatsBooked,
      }),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Impossible de commander le taxi');
  }

  /// Suivi de la course active du passager
  static Future<Map<String, dynamic>?> getActivePassengerRide() async {
    final res = await http.get(_uri('/api/taxi/active'), headers: _headers(auth: true));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['data'] != null) {
        return json['data'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Espace Chauffeur Taxi : Dashboard
  static Future<Map<String, dynamic>> getDriverDashboard() async {
    final res = await http.get(_uri('/api/driver/taxi/dashboard'), headers: _headers(auth: true));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception('Impossible de charger le tableau de bord taxi');
  }

  /// Chauffeur accepte une course entrante du pool (Premier qui accepte l'emporte)
  static Future<Map<String, dynamic>> acceptIncomingRide({
    required int passengerId,
  }) async {
    final res = await http.post(
      _uri('/api/driver/taxi/passenger/$passengerId/accept'),
      headers: _headers(auth: true),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception(json['message'] ?? 'Impossible d\'accepter la course');
  }

  /// Chauffeur valide une étape
  static Future<Map<String, dynamic>> updatePassengerStep({
    required int passengerId,
    required String step, // 'arrived_pickup', 'picked_up', 'completed', 'cancelled'
  }) async {
    final res = await http.post(
      _uri('/api/driver/taxi/passenger/$passengerId/step'),
      headers: _headers(auth: true),
      body: jsonEncode({'step': step}),
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception('Impossible de mettre à jour le statut');
  }

  /// Basculer en ligne / hors ligne pour le chauffeur Taxi
  static Future<Map<String, dynamic>> toggleDriverAvailability({bool? isAvailable, double? lat, double? lng}) async {
    final body = <String, dynamic>{};
    if (isAvailable != null) body['is_available'] = isAvailable;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;

    final res = await http.post(
      _uri('/api/driver/taxi/toggle-status'),
      headers: _headers(auth: true),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Impossible de mettre à jour la disponibilité');
  }

  /// Annulation de la course par le passager (avant la prise en charge)
  static Future<Map<String, dynamic>> cancelPassengerRide({
    required int passengerId,
    required String reason,
  }) async {
    final res = await http.post(
      _uri('/api/taxi/cancel/$passengerId'),
      headers: _headers(auth: true),
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Impossible d\'annuler la course');
  }

  /// Upload de photo de profil pour le chauffeur
  static Future<Map<String, dynamic>> uploadDriverAvatar(dynamic file) async {
    final req = http.MultipartRequest('POST', _uri('/api/me/avatar'));
    req.headers.addAll(_headers(auth: true)..remove('Content-Type'));
    final bytes = await file.readAsBytes();
    req.files.add(http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: file.name ?? 'avatar.jpg',
    ));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur lors de l\'enregistrement de la photo');
  }

  /// Rechargement portefeuille chauffeur
  static Future<Map<String, dynamic>> topupWallet({
    required double amount,
    required String channel, // 'wave', 'orange_money', 'mtn_momo'
    String? reference,
  }) async {
    final res = await http.post(
      _uri('/api/driver/taxi/wallet/topup'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'amount': amount,
        'channel': channel,
        'reference': reference,
      }),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return json['data'] as Map<String, dynamic>;
    }
    throw Exception(json['message'] ?? 'Impossible de recharger le portefeuille');
  }
}
