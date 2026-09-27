import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'api_session.dart';

class ApiClient {
  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers({bool auth = false, String? manualToken}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = manualToken ?? ApiSession.token;
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  static Future<String> login({
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/api/auth/login'),
      headers: _headers(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Connexion impossible (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final token = (data is Map<String, dynamic>) ? (data['token']?.toString() ?? '') : '';
    if (token.isEmpty) throw ApiException("Token invalide.");
    return token;
  }

  static Future<String> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/api/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(_tryMessage(res.body) ?? "Inscription impossible (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final token = (data is Map<String, dynamic>) ? (data['token']?.toString() ?? '') : '';
    if (token.isEmpty) throw ApiException("Token invalide.");
    return token;
  }

  /// Change le mot de passe de l'utilisateur connecté.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await http.patch(
      _uri('/api/me/password'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Changement de mot de passe impossible (${res.statusCode}).");
    }
  }

  /// Demande de réinitialisation de mot de passe (traitée par un admin).
  /// Renvoie le message de confirmation du serveur.
  static Future<String> forgotPassword({required String phone}) async {
    final res = await http.post(
      _uri('/api/auth/forgot-password'),
      headers: _headers(),
      body: jsonEncode({'phone': phone}),
    );
    if (res.statusCode == 429) {
      throw ApiException("Trop de demandes. Réessaie dans quelques minutes.");
    }
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Demande impossible (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return "Demande envoyée.";
  }

  static Future<UserMeDto> me() async {
    final res = await http.get(
      _uri('/api/me'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement profil (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) {
      return UserMeDto.fromJson(data);
    }
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<UserMeDto> updateMe({
    String? name,
    String? preferredAddress,
    double? preferredLat,
    double? preferredLng,
  }) async {
    final res = await http.patch(
      _uri('/api/me'),
      headers: _headers(auth: true),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (preferredAddress != null) 'preferred_address': preferredAddress,
        if (preferredLat != null) 'preferred_lat': preferredLat,
        if (preferredLng != null) 'preferred_lng': preferredLng,
      }),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur mise à jour profil (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return UserMeDto.fromJson(data);
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<UserMeDto> uploadAvatar(XFile file) async {
    final req = http.MultipartRequest('POST', _uri('/api/me/avatar'));
    req.headers.addAll(_headers(auth: true)..remove('Content-Type'));
    req.files.add(await http.MultipartFile.fromPath('avatar', file.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur upload photo (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return UserMeDto.fromJson(data);
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<List<AdvertisementDto>> getAdvertisements() async {
    try {
      final res = await http.get(_uri('/api/advertisements'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List? ?? []);
        return list.map((e) => AdvertisementDto.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> trackAdvertisementClick(int adId) async {
    try {
      await http.post(_uri('/api/advertisements/$adId/click'), headers: _headers());
    } catch (_) {}
  }

  static Future<void> logout() async {
    // Clear local session first so the user is logged out even if the network call fails.
    final headers = _headers(auth: true);
    await ApiSession.setToken(null);
    try {
      await http.post(_uri('/api/auth/logout'), headers: headers);
    } catch (_) {
      // best-effort token revocation — ignore network errors
    }
  }

  static Future<Map<String, dynamic>> createParcelOrder({
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String packageLabel,
    double? weightKg,
    required int declaredValueFcfa,
    required int deliveryFeeFcfa,
  }) async {
    final payload = <String, dynamic>{
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'package_label': packageLabel,
      'weight_kg': weightKg,
      'declared_value_fcfa': declaredValueFcfa,
      'delivery_fee_fcfa': deliveryFeeFcfa,
    }..removeWhere((k, v) => v == null);

    final res = await http.post(
      _uri('/api/parcel/orders'),
      headers: _headers(auth: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 201) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) {
        throw ApiException("Non connecté. Merci de te reconnecter.");
      }
      throw ApiException(msg ?? "Erreur création colis (${res.statusCode}).");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<void> driverSendLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    String? token,
  }) async {
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
    }..removeWhere((k, v) => v == null);

    final res = await http.post(
      _uri('/api/driver/location'),
      headers: _headers(auth: true, manualToken: token),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur envoi position (${res.statusCode}).");
    }
  }

  static Future<void> updateDriverStatus(bool isAvailable) async {
    final res = await http.post(
      _uri('/api/driver/status'),
      headers: _headers(auth: true),
      body: jsonEncode({'is_available': isAvailable}),
    );
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Erreur statut");
    }
  }

  static Future<Map<String, dynamic>> getDriverEarnings() async {
    final res = await http.get(_uri('/api/driver/earnings'), headers: _headers(auth: true));
    if (res.statusCode != 200) throw ApiException(_tryMessage(res.body) ?? "Erreur gains");
    return jsonDecode(res.body);
  }

  static Future<TrackingDto> getTrackingGas(int id) async {
    final res = await http.get(_uri('/api/tracking/gas/$id'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur suivi (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return TrackingDto.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<TrackingDto> getTrackingParcel(int id) async {
    final res = await http.get(_uri('/api/tracking/parcel/$id'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur suivi (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return TrackingDto.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<FoodTrackingDto> getTrackingFood(int id) async {
    final res = await http.get(_uri('/api/tracking/food/$id'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur suivi (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return FoodTrackingDto.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<int> getFoodDeliveryFeeFcfa() async {
    final res = await http.get(_uri('/api/food/pricing'), headers: _headers());
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return 0;
    final d = data['data'];
    if (d is! Map) return 0;
    return _toInt(Map<String, dynamic>.from(d)['delivery_fee_fcfa']) ?? 0;
  }

  static Future<List<FoodRestaurantDto>> getFoodRestaurants() async {
    final res = await http.get(_uri('/api/food/restaurants'), headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Erreur restaurants (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => FoodRestaurantDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<FoodDishWithRestaurantDto>> getAllFoodDishes() async {
    final res = await http.get(_uri('/api/food/dishes'), headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? 'Erreur plats (${res.statusCode}).');
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => FoodDishWithRestaurantDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<FoodRestaurantDetailDto> getFoodRestaurant(int id) async {
    final res = await http.get(_uri('/api/food/restaurants/$id'), headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Erreur restaurant (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return FoodRestaurantDetailDto.fromJson(obj);
  }

  static Future<List<FoodOrderDto>> getFoodOrders() async {
    final res = await http.get(_uri('/api/food/orders'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur commandes nourriture (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => FoodOrderDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<FoodOrderDetailDto> getFoodOrder(int id) async {
    final res = await http.get(_uri('/api/food/orders/$id'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur commande nourriture (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return FoodOrderDetailDto.fromJson(obj);
  }

  static Future<FoodOrderDetailDto> cancelFoodOrder(int id) async {
    final res = await http.post(_uri('/api/food/orders/$id/cancel'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Annulation impossible (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return FoodOrderDetailDto.fromJson(obj);
  }

  static Future<Map<String, dynamic>> createFoodOrder({
    required double deliveryLat,
    required double deliveryLng,
    String? deliveryAddress,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = <String, dynamic>{
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'delivery_address': deliveryAddress,
      'notes': notes,
      'items': items,
    }..removeWhere((k, v) => v == null);

    final res = await http.post(
      _uri('/api/food/orders'),
      headers: _headers(auth: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 201) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) {
        throw ApiException("Non connecté. Merci de te reconnecter.");
      }
      throw ApiException(msg ?? "Erreur commande nourriture (${res.statusCode}).");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<List<FoodOrderDto>> getDriverFoodOrders({String? status}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/food/orders')
        .replace(queryParameters: {if (status != null && status.isNotEmpty) 'status': status});
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur missions nourriture (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => FoodOrderDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<FoodOrderDetailDto> getDriverFoodOrder(int id) async {
    final res = await http.get(
      _uri('/api/driver/food/orders/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur mission nourriture (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return FoodOrderDetailDto.fromJson(obj);
  }

  static Future<void> driverAcceptFoodOrder(int id) async {
    final res = await http.post(
      _uri('/api/driver/food/orders/$id/accept'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible d’accepter la mission nourriture (${res.statusCode}).");
    }
  }

  static Future<void> driverFoodPickupStop(int orderId, int sequence) async {
    final res = await http.post(
      _uri('/api/driver/food/orders/$orderId/pickup-stop'),
      headers: _headers(auth: true),
      body: jsonEncode({'sequence': sequence}),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Ramassage impossible (${res.statusCode}).");
    }
  }

  static Future<void> driverFoodDeliver(int orderId) async {
    final res = await http.post(
      _uri('/api/driver/food/orders/$orderId/deliver'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Livraison impossible (${res.statusCode}).");
    }
  }

  static Future<void> driverUpdateFoodStopStatus(int orderId, int sequence, String status) async {
    final res = await http.post(
      _uri('/api/driver/food/orders/$orderId/stop-status'),
      headers: _headers(auth: true),
      body: jsonEncode({'sequence': sequence, 'status': status}),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible de mettre à jour le statut du restaurant (${res.statusCode}).");
    }
  }

  static Future<AppSettingsDto> getAppSettings() async {
    final res = await http.get(
      _uri('/api/settings'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException('Réglages indisponibles (${res.statusCode}).');
    }
    return AppSettingsDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Enregistre/met à jour le token FCM de cet appareil pour l'utilisateur connecté.
  /// À appeler après le login et chaque fois que Firebase rafraîchit le token.
  static Future<void> registerDeviceToken({required String token, String? platform}) async {
    final res = await http.post(
      _uri('/api/device-tokens'),
      headers: _headers(auth: true),
      body: jsonEncode({'token': token, if (platform != null) 'platform': platform}),
    );
    if (res.statusCode != 200) {
      throw ApiException('Enregistrement du token impossible (${res.statusCode}).');
    }
  }

  /// À appeler à la déconnexion pour stopper les notifications sur cet appareil.
  static Future<void> unregisterDeviceToken(String token) async {
    final res = await http.delete(
      _uri('/api/device-tokens'),
      headers: _headers(auth: true),
      body: jsonEncode({'token': token}),
    );
    if (res.statusCode != 200) {
      throw ApiException('Désinscription du token impossible (${res.statusCode}).');
    }
  }

  static Future<List<GasProductDto>> getGasProducts() async {
    final res = await http.get(
      _uri('/api/gas/products'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Erreur chargement gaz (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list
        .whereType<Map>()
        .map((e) => GasProductDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<int> getGasDeliveryFeeFcfa({double? lat, double? lng}) async {
    final uri = _uri('/api/gas/pricing').replace(queryParameters: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    });
    final res = await http.get(uri, headers: _headers(auth: false));
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return 0;
    final d = data['data'];
    if (d is! Map) return 0;
    final m = Map<String, dynamic>.from(d);
    return _toInt(m['delivery_fee_fcfa']) ?? 0;
  }

  static Future<List<DeliveryPointDto>> getDeliveryPoints({String? city, String? type}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/points').replace(
      queryParameters: {
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      },
    );

    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? "Erreur chargement points (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => DeliveryPointDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> driverSetGasDepot(int orderId, int depotPointId) async {
    final res = await http.post(
      _uri('/api/driver/gas/orders/$orderId/depot'),
      headers: _headers(auth: true),
      body: jsonEncode({'depot_point_id': depotPointId}),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Impossible de choisir le dépôt (${res.statusCode}).");
    }
  }

  static Future<Map<String, dynamic>> createGasOrder({
    required int gasProductId,
    required int qty,
    bool hasExchangeBottle = true,
    required double deliveryLat,
    required double deliveryLng,
    String? deliveryAddress,
  }) async {
    final payload = <String, dynamic>{
      'gas_product_id': gasProductId,
      'qty': qty,
      'has_exchange_bottle': hasExchangeBottle,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'delivery_address': deliveryAddress,
    }..removeWhere((k, v) => v == null);

    final res = await http.post(
      _uri('/api/gas/orders'),
      headers: _headers(auth: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 201) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) {
        throw ApiException("Non connecté. Merci de te reconnecter.");
      }
      throw ApiException(msg ?? "Erreur création commande gaz (${res.statusCode}).");
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw ApiException("Réponse serveur invalide.");
  }

  static Future<List<GasOrderDto>> getGasOrders() async {
    final res = await http.get(
      _uri('/api/gas/orders'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement commandes gaz (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list
        .whereType<Map>()
        .map((e) => GasOrderDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<GasOrderDetailDto> getGasOrder(int id) async {
    final res = await http.get(
      _uri('/api/gas/orders/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement commande gaz (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return GasOrderDetailDto.fromJson(obj);
  }

  static Future<List<DriverNotificationDto>> getDriverNotifications() async {
    final res = await http.get(
      _uri('/api/driver/notifications'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      throw ApiException('Notifications indisponibles (${res.statusCode}).');
    }
    final list = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DriverNotificationDto.fromJson).toList();
  }

  static Future<GasOrderDriverDetailDto> getDriverGasOrder(int id) async {
    final res = await http.get(
      _uri('/api/driver/gas/orders/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement mission gaz (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return GasOrderDriverDetailDto.fromJson(obj);
  }

  static Future<List<ParcelOrderDto>> getParcelOrders() async {
    final res = await http.get(
      _uri('/api/parcel/orders'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement commandes colis (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list
        .whereType<Map>()
        .map((e) => ParcelOrderDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<int> estimateParcelDeliveryFeeFcfa({
    double? pickupLat,
    double? pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final uri = _uri('/api/parcel/pricing/estimate').replace(
      queryParameters: {
        if (pickupLat != null) 'pickup_lat': pickupLat.toString(),
        if (pickupLng != null) 'pickup_lng': pickupLng.toString(),
        'dropoff_lat': dropoffLat.toString(),
        'dropoff_lng': dropoffLng.toString(),
      },
    );
    final res = await http.get(uri, headers: _headers(auth: false));
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return 0;
    final d = data['data'];
    if (d is! Map) return 0;
    final m = Map<String, dynamic>.from(d);
    return _toInt(m['delivery_fee_fcfa']) ?? 0;
  }

  static Future<ParcelOrderDetailDto> getParcelOrder(int id) async {
    final res = await http.get(
      _uri('/api/parcel/orders/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement commande colis (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return ParcelOrderDetailDto.fromJson(obj);
  }

  static Future<List<GasOrderDto>> getDriverGasOrders({String? status}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/gas/orders')
        .replace(queryParameters: {if (status != null && status.isNotEmpty) 'status': status});
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement missions gaz (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => GasOrderDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<ParcelOrderDetailDto> getDriverParcelOrder(int id) async {
    final res = await http.get(
      _uri('/api/driver/parcel/orders/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement mission colis (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : null;
    if (obj == null) throw ApiException("Réponse serveur invalide.");
    return ParcelOrderDetailDto.fromJson(obj);
  }

  static Future<List<ParcelOrderDto>> getDriverParcelOrders({String? status}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/driver/parcel/orders')
        .replace(queryParameters: {if (status != null && status.isNotEmpty) 'status': status});
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException("Non connecté. Merci de te reconnecter.");
      throw ApiException(msg ?? "Erreur chargement missions colis (${res.statusCode}).");
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => ParcelOrderDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> driverAcceptGasOrder(int id) async {
    final res = await http.post(
      _uri('/api/driver/gas/orders/$id/accept'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible d’accepter la mission gaz (${res.statusCode}).");
    }
  }

  static Future<void> driverAcceptParcelOrder(int id) async {
    final res = await http.post(
      _uri('/api/driver/parcel/orders/$id/accept'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible d’accepter la mission colis (${res.statusCode}).");
    }
  }

  static Future<void> driverSetGasStatus(int id, String status) async {
    final res = await http.post(
      _uri('/api/driver/gas/orders/$id/status'),
      headers: _headers(auth: true),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible de changer le statut gaz (${res.statusCode}).");
    }
  }

  static Future<void> driverSetParcelStatus(int id, String status) async {
    final res = await http.post(
      _uri('/api/driver/parcel/orders/$id/status'),
      headers: _headers(auth: true),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      throw ApiException(msg ?? "Impossible de changer le statut colis (${res.statusCode}).");
    }
  }

  // ── Résidences ──────────────────────────────────────────────────────────────

  static Future<List<ResidenceDto>> getResidences({
    String? type,
    String? destination,
    int? guests,
    String? search,
  }) async {
    final params = <String, String>{};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (destination != null && destination.isNotEmpty && destination != 'Tous') params['destination'] = destination;
    if (guests != null && guests > 0) params['guests'] = guests.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/residences').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? 'Erreur chargement résidences (${res.statusCode}).');
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) 
        ? (data['data'] as List) 
        : (data is List ? data : const []);
    return list.whereType<Map>().map((e) => ResidenceDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<ResidenceDto> getResidence(int id) async {
    final res = await http.get(
      _uri('/api/residences/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
      throw ApiException(msg ?? 'Résidence introuvable (${res.statusCode}).');
    }
    final data = jsonDecode(res.body);
    final obj = (data is Map<String, dynamic> && data['data'] is Map)
        ? Map<String, dynamic>.from(data['data'])
        : (data is Map<String, dynamic> ? data : null);
    if (obj == null) throw ApiException('Réponse serveur invalide.');
    return ResidenceDto.fromJson(obj);
  }

  static Future<void> bookResidence({
    required int residenceId,
    required String checkIn,
    required String checkOut,
    int guests = 1,
    String? notes,
  }) async {
    final res = await http.post(
      _uri('/api/residences/$residenceId/bookings'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'check_in': checkIn,
        'check_out': checkOut,
        'guests': guests,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      final msg = _tryMessage(res.body);
      if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
      throw ApiException(msg ?? 'Erreur réservation (${res.statusCode}).');
    }
  }

  static Future<List<ResidenceBookingDto>> getMyResidenceBookings() async {
    final res = await http.get(
      _uri('/api/residences/my-bookings'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) {
      throw ApiException(_tryMessage(res.body) ?? 'Erreur chargement historique (${res.statusCode}).');
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => ResidenceBookingDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<ResidenceReviewDto>> getResidenceReviews(int id) async {
    final res = await http.get(_uri('/api/residences/$id/reviews'), headers: _headers(auth: true));
    if (res.statusCode != 200) {
      if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
      throw ApiException(_tryMessage(res.body) ?? 'Erreur avis');
    }
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => ResidenceReviewDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> addResidenceReview(int id, int rating, String? comment) async {
    final res = await http.post(
      _uri('/api/residences/$id/reviews'),
      headers: _headers(auth: true),
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(_tryMessage(res.body) ?? 'Impossible de laisser un avis');
    }
  }

  static Future<List<ResidenceReviewDto>> getRestaurantReviews(int id) async {
    final res = await http.get(_uri('/api/food/restaurants/$id/reviews'), headers: _headers());
    if (res.statusCode != 200) throw ApiException(_tryMessage(res.body) ?? 'Erreur avis');
    final data = jsonDecode(res.body);
    final list = (data is Map<String, dynamic> && data['data'] is List) ? (data['data'] as List) : const [];
    return list.whereType<Map>().map((e) => ResidenceReviewDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

   static Future<void> addRestaurantReview(int id, int rating, String? comment) async {
     final res = await http.post(
       _uri('/api/food/restaurants/$id/reviews'),
       headers: _headers(auth: true),
       body: jsonEncode({'rating': rating, 'comment': comment}),
     );
     if (res.statusCode != 200 && res.statusCode != 201) {
       throw ApiException(_tryMessage(res.body) ?? 'Impossible de laisser un avis');
     }
   }

   // ── Résidences - Paiements ──────────────────────────────────────────────

   static Future<Map<String, dynamic>> confirmResidenceDeposit({
     required int residenceId,
     required String checkIn,
     required String checkOut,
   }) async {
     final res = await http.post(
       _uri('/api/residences/$residenceId/deposit'),
       headers: _headers(auth: true),
       body: jsonEncode({
         'check_in': checkIn,
         'check_out': checkOut,
       }),
     );
     if (res.statusCode != 200 && res.statusCode != 201) {
       final msg = _tryMessage(res.body);
       if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
       throw ApiException(msg ?? 'Erreur confirmation dépôt (${res.statusCode}).');
     }
     final data = jsonDecode(res.body);
     if (data is Map<String, dynamic>) return data;
     throw ApiException('Réponse serveur invalide.');
   }

   static Future<Map<String, dynamic>> getPendingResidencePayments() async {
     final res = await http.get(
       _uri('/api/residences/payments/pending'),
       headers: _headers(auth: true),
     );
     if (res.statusCode != 200) {
       final msg = _tryMessage(res.body);
       if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
       throw ApiException(msg ?? 'Erreur chargement paiements en attente (${res.statusCode}).');
     }
     final data = jsonDecode(res.body);
     if (data is Map<String, dynamic>) return data;
     throw ApiException('Réponse serveur invalide.');
   }

   static Future<void> updateResidenceBookingStatus({
     required int bookingId,
     required String status,
   }) async {
     final res = await http.post(
       _uri('/api/residences/bookings/$bookingId/status'),
       headers: _headers(auth: true),
       body: jsonEncode({'status': status}),
     );
     if (res.statusCode != 200) {
       final msg = _tryMessage(res.body);
       if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
       throw ApiException(msg ?? 'Erreur mise à jour statut réservation (${res.statusCode}).');
     }
   }

   // ── Manual Block/Unblock Functionality ────────────────────────────

   static Future<Map<String, dynamic>> toggleResidenceBlockage({
     required int residenceId,
     required String checkIn,
     required String checkOut,
     required bool block,
   }) async {
     final res = await http.post(
       _uri('/api/residences/$residenceId/toggle-blockage'),
       headers: _headers(auth: true),
       body: jsonEncode({
         'check_in': checkIn,
         'check_out': checkOut,
         'block': block,
       }),
     );
     if (res.statusCode != 200 && res.statusCode != 201) {
       final msg = _tryMessage(res.body);
       if (res.statusCode == 401) throw ApiException('Non connecté. Merci de te reconnecter.');
       throw ApiException(msg ?? 'Erreur modification blocage (${res.statusCode}).');
     }
     final data = jsonDecode(res.body);
     if (data is Map<String, dynamic>) return data;
     throw ApiException('Réponse serveur invalide.');
   }

  static String? _tryMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        if (data['message'] != null) return data['message']?.toString();
        if (data['error'] != null) return data['error']?.toString();
        // Laravel validation errors
        if (data['errors'] is Map) {
          final errors = data['errors'] as Map;
          if (errors.isNotEmpty) {
            final first = errors.values.first;
            if (first is List && first.isNotEmpty) return first.first?.toString();
          }
        }
      }
    } catch (_) {}
    return null;
  }}



int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt();
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

class GasProductDto {
  const GasProductDto({
    required this.id,
    required this.brand,
    required this.size,
    required this.priceFcfa,
    required this.imageUrl,
    this.bottleDepositFcfa = 0,
  });

  final int id;
  final String brand;
  final String size;
  final int priceFcfa;
  final String? imageUrl;

  /// Prix de la bouteille (consigne), facturé quand le client ne rend pas de
  /// bouteille vide (achat d'une bouteille neuve).
  final int bottleDepositFcfa;

  factory GasProductDto.fromJson(Map<String, dynamic> json) {
    return GasProductDto(
      id: _toInt(json['id']) ?? 0,
      brand: json['brand']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      imageUrl: json['image_url']?.toString(),
      bottleDepositFcfa: _toInt(json['bottle_deposit_fcfa']) ?? 0,
    );
  }
}

class UserMeDto {
  const UserMeDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.preferredAddress,
    this.preferredLat,
    this.preferredLng,
    this.isAvailable = false,
  });

  final int id;
  final String? name;
  final String phone;
  final String role;
  final String? avatarUrl;
  final String? preferredAddress;
  final double? preferredLat;
  final double? preferredLng;
  final bool isAvailable;

  factory UserMeDto.fromJson(Map<String, dynamic> json) {
    return UserMeDto(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString(),
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      avatarUrl: json['avatar_url']?.toString(),
      preferredAddress: json['preferred_address']?.toString(),
      preferredLat: _toDouble(json['preferred_lat']),
      preferredLng: _toDouble(json['preferred_lng']),
      isAvailable: json['is_available'] == true || json['is_available'] == 1,
    );
  }
}
class GasOrderDto {
  const GasOrderDto({
    required this.id,
    required this.status,
    required this.priceFcfa,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    required this.brand,
    required this.size,
    required this.qty,
    this.hasExchangeBottle = true,
    required this.deliveryLat,
    required this.deliveryLng,
  });

  final int id;
  final String status;
  final int priceFcfa;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final String? brand;
  final String? size;
  final int qty;
  final bool hasExchangeBottle;
  final double? deliveryLat;
  final double? deliveryLng;

  factory GasOrderDto.fromJson(Map<String, dynamic> json) {
    return GasOrderDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      brand: json['brand']?.toString(),
      size: json['size']?.toString(),
      qty: _toInt(json['qty']) ?? 1,
      hasExchangeBottle: json['has_exchange_bottle'] == true || json['has_exchange_bottle'] == 1,
      deliveryLat: _toDouble(json['delivery_lat']),
      deliveryLng: _toDouble(json['delivery_lng']),
    );
  }
}

class ParcelOrderDto {
  const ParcelOrderDto({
    required this.id,
    required this.status,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    required this.packageLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  final int id;
  final String status;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final String? packageLabel;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  factory ParcelOrderDto.fromJson(Map<String, dynamic> json) {
    return ParcelOrderDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      packageLabel: json['package_label']?.toString(),
      pickupLat: _toDouble(json['pickup_lat']),
      pickupLng: _toDouble(json['pickup_lng']),
      dropoffLat: _toDouble(json['dropoff_lat']),
      dropoffLng: _toDouble(json['dropoff_lng']),
    );
  }
}

class StatusEventDto {
  const StatusEventDto({
    required this.status,
    required this.createdAt,
  });

  final String status;
  final DateTime createdAt;

  factory StatusEventDto.fromJson(Map<String, dynamic> json) {
    return StatusEventDto(
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DriverLocationDto {
  const DriverLocationDto({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
  });

  final int driverId;
  final double lat;
  final double lng;
  final DateTime recordedAt;

  factory DriverLocationDto.fromJson(Map<String, dynamic> json) {
    return DriverLocationDto(
      driverId: _toInt(json['driver_id']) ?? 0,
      lat: _toDouble(json['lat']) ?? 0,
      lng: _toDouble(json['lng']) ?? 0,
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TrackingDto {
  const TrackingDto({
    required this.kind,
    required this.driverName,
    required this.driverPhone,
    required this.driverLocation,
    required this.depotName,
    required this.depotLat,
    required this.depotLng,
  });

  final String kind; // gas | parcel
  final String? driverName;
  final String? driverPhone;
  final DriverLocationDto? driverLocation;
  final String? depotName;
  final double? depotLat;
  final double? depotLng;

  factory TrackingDto.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] is Map<String, dynamic>) ? (json['order'] as Map<String, dynamic>) : null;
    final driver = (order?['driver'] is Map<String, dynamic>) ? (order?['driver'] as Map<String, dynamic>) : null;
    final depot = (order?['depot_point'] is Map<String, dynamic>)
        ? (order?['depot_point'] as Map<String, dynamic>)
        : (order?['depotPoint'] is Map<String, dynamic>)
            ? (order?['depotPoint'] as Map<String, dynamic>)
            : null;
    final loc = (json['driver_location'] is Map<String, dynamic>)
        ? DriverLocationDto.fromJson(Map<String, dynamic>.from(json['driver_location']))
        : null;
    return TrackingDto(
      kind: json['kind']?.toString() ?? '',
      driverName: driver?['name']?.toString(),
      driverPhone: driver?['phone']?.toString(),
      driverLocation: loc,
      depotName: depot?['name']?.toString(),
      depotLat: depot == null ? null : _toDouble(depot['lat']),
      depotLng: depot == null ? null : _toDouble(depot['lng']),
    );
  }
}

class GasOrderDetailDto {
  const GasOrderDetailDto({
    required this.id,
    required this.status,
    required this.priceFcfa,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    required this.brand,
    required this.size,
    required this.qty,
    this.hasExchangeBottle = true,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.events,
    required this.driverName,
    required this.driverPhone,
    required this.driverLat,
    required this.driverLng,
    required this.driverLocationAt,
  });

  final int id;
  final String status;
  final int priceFcfa;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final String? brand;
  final String? size;
  final int qty;
  final bool hasExchangeBottle;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final List<StatusEventDto> events;
  final String? driverName;
  final String? driverPhone;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverLocationAt;

  factory GasOrderDetailDto.fromJson(Map<String, dynamic> json) {
    final eventsRaw = (json['status_events'] is List) ? (json['status_events'] as List) : const [];
    final driver = (json['driver'] is Map<String, dynamic>) ? (json['driver'] as Map<String, dynamic>) : null;
    return GasOrderDetailDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      brand: json['brand']?.toString(),
      size: json['size']?.toString(),
      qty: _toInt(json['qty']) ?? 1,
      hasExchangeBottle: json['has_exchange_bottle'] == true || json['has_exchange_bottle'] == 1,
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLat: _toDouble(json['delivery_lat']),
      deliveryLng: _toDouble(json['delivery_lng']),
      events: eventsRaw
          .whereType<Map>()
          .map((e) => StatusEventDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      driverName: driver?['name']?.toString(),
      driverPhone: driver?['phone']?.toString(),
      driverLat: driver == null ? null : _toDouble(driver['last_lat']),
      driverLng: driver == null ? null : _toDouble(driver['last_lng']),
      driverLocationAt: driver == null ? null : DateTime.tryParse(driver['last_location_at']?.toString() ?? ''),
    );
  }
}

class GasOrderDriverDetailDto {
  const GasOrderDriverDetailDto({
    required this.id,
    required this.status,
    required this.priceFcfa,
    required this.createdAt,
    required this.brand,
    required this.size,
    required this.qty,
    this.hasExchangeBottle = true,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.depotPointId,
    required this.depotName,
    required this.depotLat,
    required this.depotLng,
    this.clientName,
    this.clientPhone,
  });

  final int id;
  final String status;
  final int priceFcfa;
  int get deliveryFeeFcfa => priceFcfa;
  final DateTime createdAt;
  final String? brand;
  final String? size;
  final int qty;
  final bool hasExchangeBottle;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final int? depotPointId;
  final String? depotName;
  final double? depotLat;
  final double? depotLng;
  final String? clientName;
  final String? clientPhone;

  factory GasOrderDriverDetailDto.fromJson(Map<String, dynamic> json) {
    final depot = (json['depot_point'] is Map<String, dynamic>) ? (json['depot_point'] as Map<String, dynamic>) : null;
    final client = (json['client'] is Map<String, dynamic>) ? (json['client'] as Map<String, dynamic>) : null;
    return GasOrderDriverDetailDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      brand: json['brand']?.toString(),
      size: json['size']?.toString(),
      qty: _toInt(json['qty']) ?? 1,
      hasExchangeBottle: json['has_exchange_bottle'] == true || json['has_exchange_bottle'] == 1,
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLat: _toDouble(json['delivery_lat']),
      deliveryLng: _toDouble(json['delivery_lng']),
      depotPointId: _toInt(json['depot_point_id']),
      depotName: depot?['name']?.toString(),
      depotLat: depot == null ? null : _toDouble(depot['lat']),
      depotLng: depot == null ? null : _toDouble(depot['lng']),
      clientName: client?['name']?.toString(),
      clientPhone: client?['phone']?.toString(),
    );
  }
}

class DeliveryPointDto {
  const DeliveryPointDto({
    required this.id,
    required this.city,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
  });

  final int id;
  final String city;
  final String name;
  final String type;
  final double lat;
  final double lng;

  factory DeliveryPointDto.fromJson(Map<String, dynamic> json) {
    return DeliveryPointDto(
      id: _toInt(json['id']) ?? 0,
      city: json['city']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      lat: _toDouble(json['lat']) ?? 0,
      lng: _toDouble(json['lng']) ?? 0,
    );
  }
}

class ParcelOrderDetailDto {
  const ParcelOrderDetailDto({
    required this.id,
    required this.status,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.packageLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.events,
    required this.driverName,
    required this.driverPhone,
    required this.driverLat,
    required this.driverLng,
    required this.driverLocationAt,
    this.clientName,
    this.clientPhone,
  });

  final int id;
  final String status;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? packageLabel;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final List<StatusEventDto> events;
  final String? driverName;
  final String? driverPhone;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverLocationAt;
  final String? clientName;
  final String? clientPhone;

  factory ParcelOrderDetailDto.fromJson(Map<String, dynamic> json) {
    final eventsRaw = (json['status_events'] is List) ? (json['status_events'] as List) : const [];
    final driver = (json['driver'] is Map<String, dynamic>) ? (json['driver'] as Map<String, dynamic>) : null;
    final client = (json['client'] is Map<String, dynamic>) ? (json['client'] as Map<String, dynamic>) : null;
    return ParcelOrderDetailDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      pickupAddress: json['pickup_address']?.toString(),
      dropoffAddress: json['dropoff_address']?.toString(),
      packageLabel: json['package_label']?.toString(),
      pickupLat: _toDouble(json['pickup_lat']),
      pickupLng: _toDouble(json['pickup_lng']),
      dropoffLat: _toDouble(json['dropoff_lat']),
      dropoffLng: _toDouble(json['dropoff_lng']),
      events: eventsRaw
          .whereType<Map>()
          .map((e) => StatusEventDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      driverName: driver?['name']?.toString(),
      driverPhone: driver?['phone']?.toString(),
      driverLat: driver == null ? null : _toDouble(driver['last_lat']),
      driverLng: driver == null ? null : _toDouble(driver['last_lng']),
      driverLocationAt: driver == null ? null : DateTime.tryParse(driver['last_location_at']?.toString() ?? ''),
      clientName: client?['name']?.toString(),
      clientPhone: client?['phone']?.toString(),
    );
  }
}

class FoodRestaurantDto {
  const FoodRestaurantDto({
    required this.id,
    required this.name,
    this.description,
    required this.phone,
    this.slug,
    this.address,
    this.lat,
    this.lng,
    this.imageUrl,
    this.gallery = const [],
    this.tags = const [],
  });

  final int id;
  final String name;
  final String? description;
  final String phone;
  final String? slug;
  final String? address;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final List<String> gallery;
  final List<String> tags;

  factory FoodRestaurantDto.fromJson(Map<String, dynamic> json) {
    final t = (json['tags'] is String) ? (json['tags'] as String).split(',').map((e) => e.trim()).toList() : <String>[];
    final gal = (json['gallery'] is List) ? (json['gallery'] as List).map((e) => e.toString()).toList() : <String>[];
    return FoodRestaurantDto(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      phone: json['phone']?.toString() ?? '',
      slug: json['slug']?.toString(),
      address: json['address']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      imageUrl: json['image_url']?.toString(),
      gallery: gal,
      tags: t,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'phone': phone,
        'slug': slug,
        'address': address,
        'lat': lat,
        'lng': lng,
        'image_url': imageUrl,
        'gallery': gallery,
        'tags': tags.join(','),
      };
}

class FoodRestaurantDetailDto extends FoodRestaurantDto {
  const FoodRestaurantDetailDto({
    required super.id,
    required super.name,
    super.description,
    required super.phone,
    super.slug,
    super.address,
    super.lat,
    super.lng,
    super.imageUrl,
    super.gallery = const [],
    super.tags = const [],
    required this.dishes,
  });

  final List<FoodDishDto> dishes;

  factory FoodRestaurantDetailDto.fromJson(Map<String, dynamic> json) {
    final t = (json['tags'] is String) ? (json['tags'] as String).split(',').map((e) => e.trim()).toList() : <String>[];
    final gal = (json['gallery'] is List) ? (json['gallery'] as List).map((e) => e.toString()).toList() : <String>[];
    final dishList = (json['dishes'] is List) ? (json['dishes'] as List) : const [];
    return FoodRestaurantDetailDto(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      phone: json['phone']?.toString() ?? '',
      slug: json['slug']?.toString(),
      address: json['address']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      imageUrl: json['image_url']?.toString(),
      gallery: gal,
      tags: t,
      dishes: dishList.whereType<Map>().map((e) => FoodDishDto.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class FoodDishDto {
  const FoodDishDto({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.priceFcfa,
    this.imageUrl,
    this.photos = const [],
  });

  final int id;
  final int restaurantId;
  final String name;
  final String? description;
  final int priceFcfa;
  final String? imageUrl;
  final List<String> photos;

  List<String> get allPhotoUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    for (final p in photos) {
      if (p.isNotEmpty && !urls.contains(p)) urls.add(p);
    }
    return urls;
  }

  factory FoodDishDto.fromJson(Map<String, dynamic> json) {
    final photoList = (json['photos'] as List? ?? [])
        .whereType<Map>()
        .map((p) => p['url']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return FoodDishDto(
      id: _toInt(json['id']) ?? 0,
      restaurantId: _toInt(json['restaurant_id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      imageUrl: json['image_url']?.toString(),
      photos: photoList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant_id': restaurantId,
        'name': name,
        'description': description,
        'price_fcfa': priceFcfa,
        'image_url': imageUrl,
      };
}

class FoodDishWithRestaurantDto {
  const FoodDishWithRestaurantDto({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantImageUrl,
    required this.name,
    this.description,
    required this.priceFcfa,
    this.imageUrl,
    this.photos = const [],
  });

  final int id;
  final int restaurantId;
  final String restaurantName;
  final String? restaurantImageUrl;
  final String name;
  final String? description;
  final int priceFcfa;
  final String? imageUrl;
  final List<String> photos;

  List<String> get allPhotoUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    for (final p in photos) {
      if (p.isNotEmpty && !urls.contains(p)) urls.add(p);
    }
    return urls;
  }

  factory FoodDishWithRestaurantDto.fromJson(Map<String, dynamic> json) {
    final rest = json['restaurant'] is Map<String, dynamic> ? json['restaurant'] as Map<String, dynamic> : null;
    final photoList = (json['photos'] as List? ?? [])
        .whereType<Map>()
        .map((p) => p['url']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return FoodDishWithRestaurantDto(
      id: _toInt(json['id']) ?? 0,
      restaurantId: _toInt(json['restaurant_id']) ?? 0,
      restaurantName: rest?['name']?.toString() ?? '',
      restaurantImageUrl: rest?['image_url']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      priceFcfa: _toInt(json['price_fcfa']) ?? 0,
      imageUrl: json['image_url']?.toString(),
      photos: photoList,
    );
  }
}

class FoodOrderStopDto {
  const FoodOrderStopDto({
    required this.sequence,
    required this.status,
    required this.restaurantId,
    this.restaurantPhoneSnapshot,
    this.restaurantNameSnapshot,
    this.restaurantLat,
    this.restaurantLng,
  });

  final int sequence;
  final String status;
  final int restaurantId;
  final String? restaurantPhoneSnapshot;
  final String? restaurantNameSnapshot;
  final double? restaurantLat;
  final double? restaurantLng;

  factory FoodOrderStopDto.fromJson(Map<String, dynamic> json) {
    final rest = (json['restaurant'] is Map<String, dynamic>) ? (json['restaurant'] as Map<String, dynamic>) : null;
    return FoodOrderStopDto(
      sequence: _toInt(json['sequence']) ?? 0,
      status: json['status']?.toString() ?? '',
      restaurantId: _toInt(json['restaurant_id']) ?? 0,
      restaurantPhoneSnapshot: json['restaurant_phone_snapshot']?.toString(),
      restaurantNameSnapshot: json['restaurant_name_snapshot']?.toString(),
      restaurantLat: rest == null ? null : _toDouble(rest['lat']),
      restaurantLng: rest == null ? null : _toDouble(rest['lng']),
    );
  }
}

class FoodOrderItemRowDto {
  const FoodOrderItemRowDto({
    required this.dishId,
    required this.restaurantId,
    required this.qty,
    required this.unitPriceFcfa,
    this.dishName,
    this.note,
  });

  final int dishId;
  final int restaurantId;
  final int qty;
  final int unitPriceFcfa;
  final String? dishName;
  final String? note;

  factory FoodOrderItemRowDto.fromJson(Map<String, dynamic> json) {
    final dish = (json['dish'] is Map<String, dynamic>) ? (json['dish'] as Map<String, dynamic>) : null;
    return FoodOrderItemRowDto(
      dishId: _toInt(json['dish_id']) ?? _toInt(dish?['id']) ?? 0,
      restaurantId: _toInt(json['restaurant_id']) ?? 0,
      qty: _toInt(json['qty']) ?? 0,
      unitPriceFcfa: _toInt(json['unit_price_fcfa']) ?? 0,
      dishName: dish?['name']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class FoodOrderDto {
  const FoodOrderDto({
    required this.id,
    required this.status,
    required this.subtotalFcfa,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    this.deliveryLat,
    this.deliveryLng,
    this.stopCount,
    this.stops = const [],
  });

  final int id;
  final String status;
  final int subtotalFcfa;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final double? deliveryLat;
  final double? deliveryLng;
  final int? stopCount;

  /// Renseignée par `/api/driver/food/orders` (relation `stops.restaurant`).
  final List<FoodOrderStopDto> stops;

  factory FoodOrderDto.fromJson(Map<String, dynamic> json) {
    final stopsRaw = (json['stops'] is List) ? (json['stops'] as List) : const [];
    final stops = stopsRaw
        .whereType<Map>()
        .map((e) => FoodOrderStopDto.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return FoodOrderDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      subtotalFcfa: _toInt(json['subtotal_fcfa']) ?? 0,
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      deliveryLat: _toDouble(json['delivery_lat']),
      deliveryLng: _toDouble(json['delivery_lng']),
      stopCount: stops.isEmpty ? null : stops.length,
      stops: stops,
    );
  }
}

class FoodOrderDetailDto {
  const FoodOrderDetailDto({
    required this.id,
    required this.status,
    required this.subtotalFcfa,
    required this.deliveryFeeFcfa,
    required this.createdAt,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.notes,
    required this.items,
    required this.stops,
    required this.events,
    this.driverName,
    this.driverPhone,
    this.driverLat,
    this.driverLng,
    this.driverLocationAt,
    this.clientName,
    this.clientPhone,
  });

  final int id;
  final String status;
  final int subtotalFcfa;
  final int deliveryFeeFcfa;
  final DateTime createdAt;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? notes;
  final List<FoodOrderItemRowDto> items;
  final List<FoodOrderStopDto> stops;
  final List<StatusEventDto> events;
  final String? driverName;
  final String? driverPhone;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverLocationAt;
  final String? clientName;
  final String? clientPhone;

  factory FoodOrderDetailDto.fromJson(Map<String, dynamic> json) {
    final eventsRaw = (json['status_events'] is List) ? (json['status_events'] as List) : const [];
    final itemsRaw = (json['items'] is List) ? (json['items'] as List) : const [];
    final stopsRaw = (json['stops'] is List) ? (json['stops'] as List) : const [];
    final driver = (json['driver'] is Map<String, dynamic>) ? (json['driver'] as Map<String, dynamic>) : null;
    final client = (json['client'] is Map<String, dynamic>) ? (json['client'] as Map<String, dynamic>) : null;

    return FoodOrderDetailDto(
      id: _toInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      subtotalFcfa: _toInt(json['subtotal_fcfa']) ?? 0,
      deliveryFeeFcfa: _toInt(json['delivery_fee_fcfa']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLat: _toDouble(json['delivery_lat']),
      deliveryLng: _toDouble(json['delivery_lng']),
      notes: json['notes']?.toString(),
      items: itemsRaw.whereType<Map>().map((e) => FoodOrderItemRowDto.fromJson(Map<String, dynamic>.from(e))).toList(),
      stops: stopsRaw.whereType<Map>().map((e) => FoodOrderStopDto.fromJson(Map<String, dynamic>.from(e))).toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence)),
      events: eventsRaw.whereType<Map>().map((e) => StatusEventDto.fromJson(Map<String, dynamic>.from(e))).toList(),
      driverName: driver?['name']?.toString(),
      driverPhone: driver?['phone']?.toString(),
      driverLat: driver == null ? null : _toDouble(driver['last_lat']),
      driverLng: driver == null ? null : _toDouble(driver['last_lng']),
      driverLocationAt: driver == null ? null : DateTime.tryParse(driver['last_location_at']?.toString() ?? ''),
      clientName: client?['name']?.toString(),
      clientPhone: client?['phone']?.toString(),
    );
  }
}

class FoodTrackingDto {
  const FoodTrackingDto({
    required this.kind,
    required this.order,
    this.driverLocation,
  });

  final String kind;
  final FoodOrderDetailDto order;
  final DriverLocationDto? driverLocation;

  factory FoodTrackingDto.fromJson(Map<String, dynamic> json) {
    final orderRaw = json['order'];
    final orderMap = orderRaw is Map<String, dynamic> ? orderRaw : <String, dynamic>{};
    final locRaw = json['driver_location'];
    DriverLocationDto? loc;
    if (locRaw is Map<String, dynamic>) {
      loc = DriverLocationDto.fromJson(Map<String, dynamic>.from(locRaw));
    }
    return FoodTrackingDto(
      kind: json['kind']?.toString() ?? 'food',
      order: FoodOrderDetailDto.fromJson(orderMap),
      driverLocation: loc,
    );
  }
}

class ResidenceDto {
  const ResidenceDto({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.badgeLabel,
    required this.pricePerNight,
    this.capacity = 0,
    this.bedrooms = 1,
    this.beds = 1,
    this.bathrooms = 1,
    this.address,
    this.locationArea,
    this.lat,
    this.lng,
    this.imageUrl,
    required this.gallery,
    required this.amenities,
    this.hostName,
    this.hostAvatar,
    this.hostSubtitle,
    this.rating = 4.8,
    this.reviewsCount = 12,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? description;
  final String type;
  final String? badgeLabel;
  final int pricePerNight;

  /// Capacité maximale de voyageurs (0 = non renseignée).
  final int capacity;
  final int bedrooms;
  final int beds;
  final int bathrooms;
  final String? address;
  final String? locationArea;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final List<String> gallery;
  final List<String> amenities;
  final String? hostName;
  final String? hostAvatar;
  final String? hostSubtitle;
  final double rating;
  final int reviewsCount;
  final bool isActive;

  factory ResidenceDto.fromJson(Map<String, dynamic> json) {
    final am = (json['amenities'] is List) ? (json['amenities'] as List) : const [];
    final gal = (json['gallery'] is List) ? (json['gallery'] as List) : const [];
    return ResidenceDto(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? 'apartment',
      badgeLabel: json['badge_label']?.toString(),
      pricePerNight: _toInt(json['price_per_night']) ?? 0,
      capacity: _toInt(json['capacity']) ?? 0,
      bedrooms: _toInt(json['bedrooms']) ?? 1,
      beds: _toInt(json['beds']) ?? 1,
      bathrooms: _toInt(json['bathrooms']) ?? 1,
      address: json['address']?.toString(),
      locationArea: json['location_area']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      imageUrl: json['image_url']?.toString(),
      gallery: gal.map((e) => e.toString()).toList(),
      amenities: am.map((e) => e.toString()).toList(),
      hostName: json['host_name']?.toString(),
      hostAvatar: json['host_avatar']?.toString(),
      hostSubtitle: json['host_subtitle']?.toString(),
      rating: _toDouble(json['rating']) ?? 4.8,
      reviewsCount: _toInt(json['reviews_count']) ?? 12,
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

class ResidenceBookingDto {
  const ResidenceBookingDto({
    required this.id,
    required this.residenceId,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
    this.notes,
  });

  final int id;
  final int residenceId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int totalPrice;
  final String status;
  final String? notes;

  factory ResidenceBookingDto.fromJson(Map<String, dynamic> json) {
    return ResidenceBookingDto(
      id: _toInt(json['id']) ?? 0,
      residenceId: _toInt(json['residence_id']) ?? 0,
      checkIn: DateTime.tryParse(json['check_in']?.toString() ?? '') ?? DateTime.now(),
      checkOut: DateTime.tryParse(json['check_out']?.toString() ?? '') ?? DateTime.now(),
      totalPrice: _toInt(json['total_price']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
    );
  }
}




class ResidenceReviewDto {
  const ResidenceReviewDto({
    required this.id,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final int id;
  final String userName;
  final String? userAvatarUrl;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory ResidenceReviewDto.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>) ? (json['user'] as Map<String, dynamic>) : null;
    return ResidenceReviewDto(
      id: _toInt(json['id']) ?? 0,
      userName: user?['name']?.toString() ?? 'Client',
      userAvatarUrl: user?['avatar_url']?.toString(),
      rating: _toInt(json['rating']) ?? 0,
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Admin API ───────────────────────────────────────────────────────────────

extension AdminApi on ApiClient {
  static Future<AdminStatsDto> adminStats() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/stats'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Stats: ${res.statusCode}');
    return AdminStatsDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<AdminPageDto<AdminOrderDto>> adminOrders({
    required String type,
    int page = 1,
  }) async {
    final res = await http.get(
      ApiClient._uri('/api/admin/orders?type=$type&page=$page'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Commandes: ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (j['data'] as List).cast<Map<String, dynamic>>();
    return AdminPageDto(
      items: data.map((e) => AdminOrderDto.fromJson(e, type: type)).toList(),
      total: _toInt(j['total']) ?? 0,
      lastPage: _toInt(j['last_page']) ?? 1,
    );
  }

  static Future<void> adminAssignDriver(String type, int orderId, int driverId) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/orders/$type/$orderId/assign'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'driver_id': driverId}),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Assignation impossible (${res.statusCode}).');
    }
  }

  static Future<void> adminUpdateOrderStatus(String type, int orderId, String status) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/orders/$type/$orderId/status'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
    }
  }

  static Future<AdminPageDto<AdminUserDto>> adminUsers({
    required String role,
    int page = 1,
  }) async {
    final res = await http.get(
      ApiClient._uri('/api/admin/users?role=$role&page=$page'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Utilisateurs: ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (j['data'] as List).cast<Map<String, dynamic>>();
    return AdminPageDto(
      items: data.map(AdminUserDto.fromJson).toList(),
      total: _toInt(j['total']) ?? 0,
      lastPage: _toInt(j['last_page']) ?? 1,
    );
  }

  static Future<void> adminUpdateUserRole(int userId, String role) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/users/$userId'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'role': role}),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
    }
  }

  static Future<void> adminDeleteUser(int userId) async {
    final res = await http.delete(
      ApiClient._uri('/api/admin/users/$userId'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Suppression impossible (${res.statusCode}).');
    }
  }

  static Future<List<AdminUserDto>> adminDriversList() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/drivers'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Livreurs: ${res.statusCode}');
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map(AdminUserDto.fromJson).toList();
  }

  static Future<List<AdminDriverDto>> adminDrivers() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/drivers'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Livreurs: ${res.statusCode}');
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map(AdminDriverDto.fromJson).toList();
  }

  static Future<List<AuditLogDto>> adminAuditLogs() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/audit-logs'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Journal: ${res.statusCode}');
    final list = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
    return list.map(AuditLogDto.fromJson).toList();
  }

  static Future<AppSettingsDto> adminGetSettings() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/settings'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Réglages: ${res.statusCode}');
    return AppSettingsDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateSettings(Map<String, dynamic> data) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/settings'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
    }
  }

  static Future<List<AdminResetDto>> adminPasswordResets() async {
    final res = await http.get(
      ApiClient._uri('/api/admin/password-resets'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) throw ApiException('Demandes: ${res.statusCode}');
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map(AdminResetDto.fromJson).toList();
  }

  static Future<void> adminResolveReset(int id, String password) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/password-resets/$id/resolve'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'password': password}),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Résolution impossible (${res.statusCode}).');
    }
  }

  static Future<void> adminDismissReset(int id) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/password-resets/$id/dismiss'),
      headers: ApiClient._headers(auth: true),
    );
    if (res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Rejet impossible (${res.statusCode}).');
    }
  }
}

// ─── Admin DTOs ───────────────────────────────────────────────────────────────

class AdminPageDto<T> {
  const AdminPageDto({required this.items, required this.total, required this.lastPage});
  final List<T> items;
  final int total;
  final int lastPage;
}

class AdminStatsDto {
  const AdminStatsDto({
    required this.clients,
    required this.drivers,
    required this.gasOrders,
    required this.parcelOrders,
    required this.foodOrders,
    required this.residenceBookings,
    required this.totalRevenueFcfa,
    required this.totalGmvFcfa,
    required this.revenueGas,
    required this.revenueParcel,
    required this.revenueFood,
    required this.revenueResidence,
    required this.pendingOrders,
    required this.pendingResets,
  });

  final int clients;
  final int drivers;
  final int gasOrders;
  final int parcelOrders;
  final int foodOrders;
  final int residenceBookings;
  // Revenue = frais livreurs encaissés sur commandes terminées uniquement
  final int totalRevenueFcfa;
  // GMV = total transactions hors annulées
  final int totalGmvFcfa;
  final int revenueGas;
  final int revenueParcel;
  final int revenueFood;
  final int revenueResidence;
  final int pendingOrders;
  final int pendingResets;

  factory AdminStatsDto.fromJson(Map<String, dynamic> j) {
    final breakdown = j['revenue_breakdown'] as Map<String, dynamic>? ?? {};
    return AdminStatsDto(
      clients: _toInt(j['clients']) ?? 0,
      drivers: _toInt(j['drivers']) ?? 0,
      gasOrders: _toInt(j['gas_orders']) ?? 0,
      parcelOrders: _toInt(j['parcel_orders']) ?? 0,
      foodOrders: _toInt(j['food_orders']) ?? 0,
      residenceBookings: _toInt(j['residence_bookings']) ?? 0,
      totalRevenueFcfa: _toInt(j['total_revenue_fcfa']) ?? 0,
      totalGmvFcfa: _toInt(j['total_gmv_fcfa']) ?? 0,
      revenueGas: _toInt(breakdown['gas']) ?? 0,
      revenueParcel: _toInt(breakdown['parcel']) ?? 0,
      revenueFood: _toInt(breakdown['food']) ?? 0,
      revenueResidence: _toInt(breakdown['residence']) ?? 0,
      pendingOrders: _toInt(j['pending_orders']) ?? 0,
      pendingResets: _toInt(j['pending_resets']) ?? 0,
    );
  }
}

class AdminOrderDto {
  const AdminOrderDto({
    required this.id,
    required this.type,
    required this.status,
    this.priceFcfa,
    this.clientName,
    this.clientPhone,
    this.driverName,
    this.driverPhone,
    required this.createdAt,
    required this.raw,
  });

  final int id;
  final String type;
  final String status;
  final int? priceFcfa;
  final String? clientName;
  final String? clientPhone;
  final String? driverName;
  final String? driverPhone;
  final DateTime createdAt;
  final Map<String, dynamic> raw;

  AdminOrderDto copyWith({String? status}) => AdminOrderDto(
        id: id, type: type, status: status ?? this.status,
        priceFcfa: priceFcfa, clientName: clientName, clientPhone: clientPhone,
        driverName: driverName, driverPhone: driverPhone, createdAt: createdAt, raw: raw,
      );

  factory AdminOrderDto.fromJson(Map<String, dynamic> j, {required String type}) {
    final client = j['client'] as Map<String, dynamic>?;
    final user = j['user'] as Map<String, dynamic>?;
    final driver = j['driver'] as Map<String, dynamic>?;
    final payer = client ?? user;
    return AdminOrderDto(
      id: _toInt(j['id']) ?? 0,
      type: type,
      status: j['status']?.toString() ?? 'pending',
      priceFcfa: _toInt(j['price_fcfa'] ?? j['delivery_fee_fcfa'] ?? j['total_price']),
      clientName: payer?['name']?.toString(),
      clientPhone: payer?['phone']?.toString(),
      driverName: driver?['name']?.toString(),
      driverPhone: driver?['phone']?.toString(),
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      raw: j,
    );
  }
}

class AdminUserDto {
  const AdminUserDto({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final DateTime createdAt;

  factory AdminUserDto.fromJson(Map<String, dynamic> j) => AdminUserDto(
        id: _toInt(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        email: j['email']?.toString(),
        role: j['role']?.toString() ?? 'client',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AdminResetDto {
  const AdminResetDto({
    required this.id,
    this.phone,
    this.userId,
    this.userName,
    this.userPhone,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String? phone;
  final int? userId;
  final String? userName;
  final String? userPhone;
  final String status;
  final DateTime createdAt;

  factory AdminResetDto.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    return AdminResetDto(
      id: _toInt(j['id']) ?? 0,
      phone: j['phone']?.toString(),
      userId: _toInt(j['user_id']),
      userName: user?['name']?.toString(),
      userPhone: user?['phone']?.toString(),
      status: j['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Admin extra API (users create, restaurants, dishes, residences) ──────────

extension AdminApiExtra on ApiClient {
  static Future<AdminUserDto> adminCreateUser({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/users'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'name': name, 'phone': phone, 'password': password, 'role': role}),
    );
    if (res.statusCode != 201) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Création impossible (${res.statusCode}).');
    }
    return AdminUserDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Restaurants
  static Future<List<AdminRestaurantDto>> adminRestaurants() async {
    final res = await http.get(ApiClient._uri('/api/admin/restaurants'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Restaurants: ${res.statusCode}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>().map(AdminRestaurantDto.fromJson).toList();
  }

  static Future<AdminRestaurantDto> adminCreateRestaurant({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? imageUrl,
    double? lat,
    double? lng,
  }) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/restaurants'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({
        'name': name,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      }),
    );
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminRestaurantDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateRestaurant(int id, {
    String? name,
    String? description,
    String? phone,
    String? address,
    String? imageUrl,
    double? lat,
    double? lng,
  }) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/restaurants/$id'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        'image_url': imageUrl?.isNotEmpty == true ? imageUrl : null,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      }),
    );
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
  }

  static Future<void> adminDeleteRestaurant(int id) async {
    final res = await http.delete(ApiClient._uri('/api/admin/restaurants/$id'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }

  // Dishes
  static Future<List<AdminDishDto>> adminDishes(int restaurantId) async {
    final res = await http.get(ApiClient._uri('/api/admin/restaurants/$restaurantId/dishes'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Plats: ${res.statusCode}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>().map(AdminDishDto.fromJson).toList();
  }

  static Future<AdminDishDto> adminCreateDish(int restaurantId, {required String name, String? description, required int priceFcfa, String? imageUrl}) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/restaurants/$restaurantId/dishes'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'name': name, if (description != null) 'description': description, 'price_fcfa': priceFcfa, 'active': true, if (imageUrl != null) 'image_url': imageUrl}),
    );
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminDishDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateDish(int dishId, {String? name, String? description, int? priceFcfa, bool? isActive, String? imageUrl}) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/dishes/$dishId'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({if (name != null) 'name': name, if (description != null) 'description': description, if (priceFcfa != null) 'price_fcfa': priceFcfa, if (isActive != null) 'active': isActive, if (imageUrl != null) 'image_url': imageUrl}),
    );
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
  }

  static Future<void> adminDeleteDish(int dishId) async {
    final res = await http.delete(ApiClient._uri('/api/admin/dishes/$dishId'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }

  static Future<String> adminUploadPhoto(XFile file) async {
    final req = http.MultipartRequest('POST', ApiClient._uri('/api/admin/upload-photo'));
    req.headers.addAll(ApiClient._headers(auth: true)..remove('Content-Type'));
    final bytes = await file.readAsBytes();
    req.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: file.name));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur upload (${res.statusCode}).');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  static Future<AdminDishPhotoDto> adminAddDishPhoto(int dishId, String url) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/dishes/$dishId/photos'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({'url': url}),
    );
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminDishPhotoDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminDeleteDishPhoto(int photoId) async {
    final res = await http.delete(ApiClient._uri('/api/admin/dish-photos/$photoId'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }

  // Residences
  static Future<List<AdminResidenceAdminDto>> adminResidencesList() async {
    final res = await http.get(ApiClient._uri('/api/admin/residences'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Résidences: ${res.statusCode}');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>().map(AdminResidenceAdminDto.fromJson).toList();
  }

  static Future<AdminResidenceAdminDto> adminCreateResidence({
    required String name,
    required String type,
    required int pricePerNight,
    int capacity = 1,
    String? address,
    String? description,
    String? imageUrl,
    double? lat,
    double? lng,
  }) async {
    final res = await http.post(
      ApiClient._uri('/api/admin/residences'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({
        'name': name,
        'type': type,
        'price_per_night': pricePerNight,
        'capacity': capacity,
        if (address != null) 'address': address,
        if (description != null) 'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      }),
    );
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminResidenceAdminDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateResidence(int id, Map<String, dynamic> data) async {
    final res = await http.patch(
      ApiClient._uri('/api/admin/residences/$id'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
  }

  static Future<void> adminDeleteResidence(int id) async {
    final res = await http.delete(ApiClient._uri('/api/admin/residences/$id'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }

  static Future<AdminPricingDto> adminGetPricing() async {
    final res = await http.get(ApiClient._uri('/api/admin/pricing'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Impossible de charger la tarification (${res.statusCode}).');
    return AdminPricingDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateGasPricing(Map<String, dynamic> data) async {
    final res = await http.patch(ApiClient._uri('/api/admin/pricing/gas'), headers: ApiClient._headers(auth: true), body: jsonEncode(data));
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
  }

  static Future<void> adminUpdateParcelPricing(Map<String, dynamic> data) async {
    final res = await http.patch(ApiClient._uri('/api/admin/pricing/parcel'), headers: ApiClient._headers(auth: true), body: jsonEncode(data));
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
  }

  static Future<void> adminUpdateFoodPricing(int deliveryFeeFcfa) async {
    final res = await http.patch(ApiClient._uri('/api/admin/pricing/food'), headers: ApiClient._headers(auth: true), body: jsonEncode({'delivery_fee_fcfa': deliveryFeeFcfa}));
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Mise à jour impossible (${res.statusCode}).');
  }

  static Future<AdminRevenueDto> adminRevenue() async {
    final res = await http.get(ApiClient._uri('/api/admin/revenue'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Impossible de charger les revenus (${res.statusCode}).');
    return AdminRevenueDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Gas depots
  static Future<List<AdminGasDepotDto>> adminGasDepots() async {
    final res = await http.get(ApiClient._uri('/api/admin/gas-depots'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Dépôts: ${res.statusCode}');
    return (jsonDecode(res.body) as List).whereType<Map>().map((e) => AdminGasDepotDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<AdminGasDepotDto> adminCreateGasDepot({required String name, String? city, double? lat, double? lng, bool active = true}) async {
    final res = await http.post(ApiClient._uri('/api/admin/gas-depots'), headers: ApiClient._headers(auth: true),
      body: jsonEncode({'name': name, if (city != null) 'city': city, if (lat != null) 'lat': lat, if (lng != null) 'lng': lng, 'active': active}));
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminGasDepotDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateGasDepot(int id, Map<String, dynamic> data) async {
    final res = await http.patch(ApiClient._uri('/api/admin/gas-depots/$id'), headers: ApiClient._headers(auth: true), body: jsonEncode(data));
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
  }

  static Future<void> adminDeleteGasDepot(int id) async {
    final res = await http.delete(ApiClient._uri('/api/admin/gas-depots/$id'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }

  // Gas products
  static Future<List<AdminGasProductDto>> adminGasProducts() async {
    final res = await http.get(ApiClient._uri('/api/admin/gas-products'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Produits gaz: ${res.statusCode}');
    return (jsonDecode(res.body) as List).whereType<Map>().map((e) => AdminGasProductDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<AdminGasProductDto> adminCreateGasProduct({required String brand, required String size, required int priceFcfa, int? depositFcfa, String? imageUrl, bool active = true, int sort = 0}) async {
    final res = await http.post(ApiClient._uri('/api/admin/gas-products'), headers: ApiClient._headers(auth: true),
      body: jsonEncode({'brand': brand, 'size': size, 'price_fcfa': priceFcfa, if (depositFcfa != null) 'bottle_deposit_fcfa': depositFcfa, if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl, 'active': active, 'sort': sort}));
    if (res.statusCode != 201) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
    return AdminGasProductDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> adminUpdateGasProduct(int id, Map<String, dynamic> data) async {
    final res = await http.patch(ApiClient._uri('/api/admin/gas-products/$id'), headers: ApiClient._headers(auth: true), body: jsonEncode(data));
    if (res.statusCode != 200) throw ApiException(ApiClient._tryMessage(res.body) ?? 'Erreur (${res.statusCode}).');
  }

  static Future<void> adminDeleteGasProduct(int id) async {
    final res = await http.delete(ApiClient._uri('/api/admin/gas-products/$id'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Suppression impossible (${res.statusCode}).');
  }
}

// ─── Admin extra DTOs ─────────────────────────────────────────────────────────

class AdminRestaurantDto {
  const AdminRestaurantDto({
    required this.id,
    required this.name,
    this.description,
    this.phone,
    this.address,
    this.imageUrl,
    this.lat,
    this.lng,
    required this.dishesCount,
  });
  final int id;
  final String name;
  final String? description;
  final String? phone;
  final String? address;
  final String? imageUrl;
  final double? lat;
  final double? lng;
  final int dishesCount;

  factory AdminRestaurantDto.fromJson(Map<String, dynamic> j) => AdminRestaurantDto(
        id: _toInt(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        phone: j['phone']?.toString(),
        address: j['address']?.toString(),
        imageUrl: j['image_url']?.toString(),
        lat: j['lat'] != null ? double.tryParse(j['lat'].toString()) : null,
        lng: j['lng'] != null ? double.tryParse(j['lng'].toString()) : null,
        dishesCount: _toInt(j['dishes_count']) ?? 0,
      );
}

class AdminDishPhotoDto {
  const AdminDishPhotoDto({required this.id, required this.url, required this.sortOrder});
  final int id;
  final String url;
  final int sortOrder;

  factory AdminDishPhotoDto.fromJson(Map<String, dynamic> j) => AdminDishPhotoDto(
        id: _toInt(j['id']) ?? 0,
        url: j['url']?.toString() ?? '',
        sortOrder: _toInt(j['sort_order']) ?? 0,
      );
}

class AdminDishDto {
  const AdminDishDto({required this.id, required this.name, this.description, required this.priceFcfa, required this.isActive, this.imageUrl, this.photos = const []});
  final int id;
  final String name;
  final String? description;
  final int priceFcfa;
  final bool isActive;
  final String? imageUrl;
  final List<AdminDishPhotoDto> photos;

  List<String> get allPhotoUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    for (final p in photos) {
      if (p.url.isNotEmpty && !urls.contains(p.url)) urls.add(p.url);
    }
    return urls;
  }

  factory AdminDishDto.fromJson(Map<String, dynamic> j) => AdminDishDto(
        id: _toInt(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        priceFcfa: _toInt(j['price_fcfa']) ?? 0,
        isActive: j['active'] == true || j['active'] == 1 || j['is_active'] == true || j['is_active'] == 1,
        imageUrl: j['image_url']?.toString(),
        photos: (j['photos'] as List? ?? [])
            .whereType<Map>()
            .map((p) => AdminDishPhotoDto.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );
}

class AdminResidenceAdminDto {
  const AdminResidenceAdminDto({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePerNight,
    required this.capacity,
    this.address,
    this.description,
    this.imageUrl,
    this.lat,
    this.lng,
    required this.bookingsCount,
  });
  final int id;
  final String name;
  final String type;
  final int pricePerNight;
  final int capacity;
  final String? address;
  final String? description;
  final String? imageUrl;
  final double? lat;
  final double? lng;
  final int bookingsCount;

  factory AdminResidenceAdminDto.fromJson(Map<String, dynamic> j) => AdminResidenceAdminDto(
        id: _toInt(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? 'apartment',
        pricePerNight: _toInt(j['price_per_night']) ?? 0,
        capacity: _toInt(j['capacity']) ?? 0,
        address: j['address']?.toString(),
        description: j['description']?.toString(),
        imageUrl: j['image_url']?.toString(),
        lat: j['lat'] != null ? double.tryParse(j['lat'].toString()) : null,
        lng: j['lng'] != null ? double.tryParse(j['lng'].toString()) : null,
        bookingsCount: _toInt(j['bookings_count']) ?? 0,
      );
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

// ─── Pricing DTOs ─────────────────────────────────────────────────────────────

class AdminPricingDto {
  const AdminPricingDto({required this.gas, required this.parcel, required this.food});
  final Map<String, dynamic> gas;
  final Map<String, dynamic> parcel;
  final Map<String, dynamic> food;

  factory AdminPricingDto.fromJson(Map<String, dynamic> j) => AdminPricingDto(
        gas: Map<String, dynamic>.from(j['gas'] as Map? ?? {}),
        parcel: Map<String, dynamic>.from(j['parcel'] as Map? ?? {}),
        food: Map<String, dynamic>.from(j['food'] as Map? ?? {}),
      );
}

// ─── Revenue DTOs ─────────────────────────────────────────────────────────────

class AdminRevenueRestaurantDto {
  const AdminRevenueRestaurantDto({required this.restaurantId, required this.restaurantName, required this.totalFcfa, required this.orderCount});
  final int restaurantId;
  final String restaurantName;
  final int totalFcfa;
  final int orderCount;

  factory AdminRevenueRestaurantDto.fromJson(Map<String, dynamic> j) => AdminRevenueRestaurantDto(
        restaurantId: _toInt(j['restaurant_id']) ?? 0,
        restaurantName: j['restaurant_name']?.toString() ?? '',
        totalFcfa: _toInt(j['total_fcfa']) ?? 0,
        orderCount: _toInt(j['order_count']) ?? 0,
      );
}

class AdminRevenueGasDepotDto {
  const AdminRevenueGasDepotDto({required this.depotId, required this.depotName, required this.totalFcfa, required this.orderCount});
  final int depotId;
  final String depotName;
  final int totalFcfa;
  final int orderCount;

  factory AdminRevenueGasDepotDto.fromJson(Map<String, dynamic> j) => AdminRevenueGasDepotDto(
        depotId: _toInt(j['depot_point_id']) ?? 0,
        depotName: j['depot_name']?.toString() ?? '',
        totalFcfa: _toInt(j['total_fcfa']) ?? 0,
        orderCount: _toInt(j['order_count']) ?? 0,
      );
}

class AdminRevenueDto {
  const AdminRevenueDto({required this.byRestaurant, required this.byGasDepot});
  final List<AdminRevenueRestaurantDto> byRestaurant;
  final List<AdminRevenueGasDepotDto> byGasDepot;

  factory AdminRevenueDto.fromJson(Map<String, dynamic> j) => AdminRevenueDto(
        byRestaurant: (j['by_restaurant'] as List? ?? [])
            .whereType<Map>()
            .map((e) => AdminRevenueRestaurantDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        byGasDepot: (j['by_gas_depot'] as List? ?? [])
            .whereType<Map>()
            .map((e) => AdminRevenueGasDepotDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AdminGasDepotDto {
  const AdminGasDepotDto({
    required this.id,
    required this.name,
    this.city,
    this.lat,
    this.lng,
    required this.active,
  });
  final int id;
  final String name;
  final String? city;
  final double? lat;
  final double? lng;
  final bool active;

  factory AdminGasDepotDto.fromJson(Map<String, dynamic> j) => AdminGasDepotDto(
        id: j['id'] as int,
        name: j['name'] as String,
        city: j['city'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        active: j['active'] == true || j['active'] == 1,
      );
}

class AdminGasProductDto {
  const AdminGasProductDto({
    required this.id,
    required this.brand,
    required this.size,
    required this.priceFcfa,
    required this.depositFcfa,
    this.imageUrl,
    required this.active,
    required this.sort,
  });
  final int id;
  final String brand;
  final String size;
  final int priceFcfa;
  final int depositFcfa;
  final String? imageUrl;
  final bool active;
  final int sort;

  factory AdminGasProductDto.fromJson(Map<String, dynamic> j) => AdminGasProductDto(
        id: j['id'] as int,
        brand: j['brand'] as String,
        size: j['size'] as String,
        priceFcfa: (j['price_fcfa'] as num).toInt(),
        depositFcfa: (j['bottle_deposit_fcfa'] as num? ?? 0).toInt(),
        imageUrl: j['image_url'] as String?,
        active: j['active'] == true || j['active'] == 1,
        sort: (j['sort'] as num? ?? 0).toInt(),
      );
}

class AppSettingsDto {
  const AppSettingsDto({this.supportPhone, this.cguText});

  final String? supportPhone;
  final String? cguText;

  factory AppSettingsDto.fromJson(Map<String, dynamic> j) => AppSettingsDto(
        supportPhone: j['support_phone'] as String?,
        cguText: j['cgu_text'] as String?,
      );
}

class AdminDriverDto {
  const AdminDriverDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.isAvailable,
    this.vehicleType,
    this.vehiclePlate,
    this.licenseNumber,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
    required this.activeOrders,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String phone;
  final bool isAvailable;
  final String? vehicleType;
  final String? vehiclePlate;
  final String? licenseNumber;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocationAt;
  final int activeOrders;
  final DateTime createdAt;

  factory AdminDriverDto.fromJson(Map<String, dynamic> j) => AdminDriverDto(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        isAvailable: j['is_available'] == true || j['is_available'] == 1,
        vehicleType: j['vehicle_type'] as String?,
        vehiclePlate: j['vehicle_plate'] as String?,
        licenseNumber: j['license_number'] as String?,
        lastLat: (j['last_lat'] as num?)?.toDouble(),
        lastLng: (j['last_lng'] as num?)?.toDouble(),
        lastLocationAt: j['last_location_at'] != null ? DateTime.tryParse(j['last_location_at'].toString()) : null,
        activeOrders: (j['active_orders'] as num? ?? 0).toInt(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AuditLogDto {
  const AuditLogDto({
    required this.id,
    required this.action,
    this.subjectType,
    this.subjectId,
    required this.changes,
    this.actorName,
    required this.createdAt,
  });

  final int id;
  final String action;
  final String? subjectType;
  final int? subjectId;
  final Map<String, dynamic> changes;
  final String? actorName;
  final DateTime createdAt;

  factory AuditLogDto.fromJson(Map<String, dynamic> j) => AuditLogDto(
        id: (j['id'] as num).toInt(),
        action: j['action']?.toString() ?? '',
        subjectType: j['subject_type'] as String?,
        subjectId: (j['subject_id'] as num?)?.toInt(),
        changes: (j['changes'] is Map) ? Map<String, dynamic>.from(j['changes']) : const {},
        actorName: (j['actor'] is Map) ? (j['actor']['name'] as String?) : null,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class DriverNotificationDto {
  const DriverNotificationDto({
    required this.type,
    required this.orderId,
    required this.status,
    this.actorName,
    this.meta,
    required this.createdAt,
  });

  final String type;
  final int orderId;
  final String status;
  final String? actorName;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  factory DriverNotificationDto.fromJson(Map<String, dynamic> j) => DriverNotificationDto(
        type: j['type']?.toString() ?? '',
        orderId: (j['order_id'] as num?)?.toInt() ?? 0,
        status: j['status']?.toString() ?? '',
        actorName: j['actor_name'] as String?,
        meta: (j['meta'] is Map) ? Map<String, dynamic>.from(j['meta']) : null,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AdvertisementDto {
  const AdvertisementDto({
    required this.id,
    required this.title,
    this.subtitle,
    required this.badgeLabel,
    required this.imageUrl,
    required this.ctaLabel,
    this.targetType,
    this.targetValue,
    this.advertiserName,
    this.advertiserPhone,
    this.clickCount = 0,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String badgeLabel;
  final String imageUrl;
  final String ctaLabel;
  final String? targetType;
  final String? targetValue;
  final String? advertiserName;
  final String? advertiserPhone;
  final int clickCount;

  factory AdvertisementDto.fromJson(Map<String, dynamic> json) {
    return AdvertisementDto(
      id: (json['id'] ?? 0) as int,
      title: json['title']?.toString() ?? 'Offre Spéciale',
      subtitle: json['subtitle']?.toString(),
      badgeLabel: json['badge_label']?.toString() ?? 'VIP EXCLUSIF',
      imageUrl: json['image_full_url']?.toString() ?? json['image_url']?.toString() ?? '',
      ctaLabel: json['cta_label']?.toString() ?? 'Voir l\'offre',
      targetType: json['target_type']?.toString(),
      targetValue: json['target_value']?.toString(),
      advertiserName: json['advertiser_name']?.toString(),
      advertiserPhone: json['advertiser_phone']?.toString(),
      clickCount: (json['click_count'] ?? 0) as int,
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// EVENTS & BILLETTERIE
// ═══════════════════════════════════════════════════════════════════════════

class TicketTypeDto {
  const TicketTypeDto({
    required this.id,
    required this.name,
    required this.priceFcfa,
    required this.remainingQuantity,
    required this.totalQuantity,
    this.benefits,
  });

  final int id;
  final String name;
  final int priceFcfa;
  final int remainingQuantity;
  final int totalQuantity;
  final String? benefits;

  bool get isSoldOut => remainingQuantity <= 0;

  factory TicketTypeDto.fromJson(Map<String, dynamic> j) => TicketTypeDto(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        priceFcfa: (j['price_fcfa'] as num?)?.toInt() ?? 0,
        remainingQuantity: (j['remaining_quantity'] as num?)?.toInt() ?? 0,
        totalQuantity: (j['total_quantity'] as num?)?.toInt() ?? 1,
        benefits: j['benefits']?.toString(),
      );
}

class EventDto {
  const EventDto({
    required this.id,
    required this.title,
    required this.category,
    required this.locationName,
    required this.imageUrl,
    required this.startsAt,
    this.endsAt,
    required this.isFeatured,
    required this.statusLabel,
    required this.ticketTypes,
    this.description,
    this.organizerName,
    this.organizerPhone,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String title;
  final String category;
  final String locationName;
  final String imageUrl;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isFeatured;
  final String statusLabel;
  final List<TicketTypeDto> ticketTypes;
  final String? description;
  final String? organizerName;
  final String? organizerPhone;
  final double? latitude;
  final double? longitude;

  int get minPriceFcfa => ticketTypes.isEmpty
      ? 0
      : ticketTypes.map((t) => t.priceFcfa).reduce((a, b) => a < b ? a : b);

  bool get hasAvailableTickets => ticketTypes.any((t) => !t.isSoldOut);

  factory EventDto.fromJson(Map<String, dynamic> j) {
    final ttRaw = (j['ticket_types'] is List) ? j['ticket_types'] as List : [];
    return EventDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: j['title']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      locationName: j['location_name']?.toString() ?? '',
      imageUrl: j['image_url']?.toString() ?? '',
      startsAt: DateTime.tryParse(j['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endsAt: j['ends_at'] != null ? DateTime.tryParse(j['ends_at'].toString()) : null,
      isFeatured: j['is_featured'] == true,
      statusLabel: j['status_label']?.toString() ?? '',
      ticketTypes: ttRaw.map((e) => TicketTypeDto.fromJson(Map<String, dynamic>.from(e))).toList(),
      description: j['description']?.toString(),
      organizerName: j['organizer_name']?.toString(),
      organizerPhone: j['organizer_phone']?.toString(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
    );
  }
}

class EventBookingDto {
  const EventBookingDto({
    required this.id,
    required this.bookingReference,
    required this.qrCodeToken,
    this.eventTitle,
    this.eventLocation,
    this.eventStartsAt,
    this.eventImageUrl,
    this.ticketTypeName,
    this.ticketTypePriceFcfa,
    required this.quantity,
    required this.totalAmountFcfa,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.isScanned,
    this.scannedAt,
    required this.createdAt,
  });

  final int id;
  final String bookingReference;
  final String qrCodeToken;
  final String? eventTitle;
  final String? eventLocation;
  final DateTime? eventStartsAt;
  final String? eventImageUrl;
  final String? ticketTypeName;
  final int? ticketTypePriceFcfa;
  final int quantity;
  final int totalAmountFcfa;
  final String paymentMethod;
  final String paymentStatus;
  final bool isScanned;
  final DateTime? scannedAt;
  final DateTime createdAt;

  bool get isPaid => paymentStatus == 'paid';

  factory EventBookingDto.fromJson(Map<String, dynamic> j) {
    final ev = (j['event'] is Map) ? Map<String, dynamic>.from(j['event'] as Map) : <String, dynamic>{};
    final tt = (j['ticket_type'] is Map) ? Map<String, dynamic>.from(j['ticket_type'] as Map) : <String, dynamic>{};
    return EventBookingDto(
      id: (j['id'] as num?)?.toInt() ?? 0,
      bookingReference: j['booking_reference']?.toString() ?? '',
      qrCodeToken: j['qr_code_token']?.toString() ?? '',
      eventTitle: ev['title']?.toString(),
      eventLocation: ev['location_name']?.toString(),
      eventStartsAt: ev['starts_at'] != null ? DateTime.tryParse(ev['starts_at'].toString()) : null,
      eventImageUrl: ev['image_url']?.toString(),
      ticketTypeName: tt['name']?.toString(),
      ticketTypePriceFcfa: (tt['price_fcfa'] as num?)?.toInt(),
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      totalAmountFcfa: (j['total_amount_fcfa'] as num?)?.toInt() ?? 0,
      paymentMethod: j['payment_method']?.toString() ?? '',
      paymentStatus: j['payment_status']?.toString() ?? '',
      isScanned: j['is_scanned'] == true,
      scannedAt: j['scanned_at'] != null ? DateTime.tryParse(j['scanned_at'].toString()) : null,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ── API Methods ─────────────────────────────────────────────────────────────

extension EventApi on ApiClient {
  static Future<List<EventDto>> fetchEvents({String? category}) async {
    var uri = ApiClient._uri('/api/events');
    if (category != null) {
      uri = Uri.parse('${ApiConfig.baseUrl}/api/events?category=$category');
    }
    final res = await http.get(uri, headers: ApiClient._headers());
    if (res.statusCode != 200) throw ApiException('Impossible de charger les événements.');
    final data = jsonDecode(res.body);
    final list = (data['data'] is List) ? data['data'] as List : [];
    return list.map((e) => EventDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<EventDto> fetchEventDetail(int eventId) async {
    final res = await http.get(ApiClient._uri('/api/events/$eventId'), headers: ApiClient._headers());
    if (res.statusCode != 200) throw ApiException('Événement introuvable.');
    final data = jsonDecode(res.body);
    return EventDto.fromJson(Map<String, dynamic>.from(data['data']));
  }

  static Future<EventBookingDto> bookEvent({
    required int eventId,
    required int ticketTypeId,
    required int quantity,
    String? paymentMethod,
  }) async {
    final res = await http.post(
      ApiClient._uri('/api/events/$eventId/book'),
      headers: ApiClient._headers(auth: true),
      body: jsonEncode({
        'ticket_type_id': ticketTypeId,
        'quantity': quantity,
        'payment_method': paymentMethod ?? 'Cash',
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException(ApiClient._tryMessage(res.body) ?? 'Réservation impossible.');
    }
    final data = jsonDecode(res.body);
    return EventBookingDto.fromJson(Map<String, dynamic>.from(data['data']));
  }

  static Future<List<EventBookingDto>> fetchMyTickets() async {
    final res = await http.get(ApiClient._uri('/api/events/my-tickets'), headers: ApiClient._headers(auth: true));
    if (res.statusCode != 200) throw ApiException('Impossible de charger vos billets.');
    final data = jsonDecode(res.body);
    final list = (data['data'] is List) ? data['data'] as List : [];
    return list.map((e) => EventBookingDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
