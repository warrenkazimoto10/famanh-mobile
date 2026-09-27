import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_client_fixed/pusher_client_fixed.dart';
import 'dart:math' as math;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/api_config.dart';

class LiveTrackingScreen extends StatefulWidget {
  final int orderId;
  final String orderType; // 'gas', 'parcel', 'food'
  final String clientToken;

  const LiveTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderType,
    required this.clientToken,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  Echo? _echo;

  // Variables du livreur
  LatLng _driverPosition = const LatLng(5.2863, -3.2981); // Position par défaut (Adiaké)
  double _driverHeading = 0.0;
  String _vehicleType = 'moto';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialPosition();
  }

  // 1. Récupérer la position de départ avant que le Websocket ne prenne le relais
  Future<void> _fetchInitialPosition() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/tracking/${widget.orderType}/${widget.orderId}'),
        headers: {
          'Authorization': 'Bearer ${widget.clientToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'];
        
        final loc = data['driver_location'];
        if (loc != null) {
          _driverPosition = LatLng(
            double.parse(loc['lat'].toString()),
            double.parse(loc['lng'].toString())
          );
          _driverHeading = double.parse(loc['heading'].toString());
        }

        final driver = data['order']?['driver'];
        if (driver != null && driver['vehicle_type'] != null) {
          _vehicleType = driver['vehicle_type'];
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération de la position initiale : $e");
    }
    
    _setupWebsockets();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // 2. Connexion à Laravel Reverb
  void _setupWebsockets() {
    PusherOptions options = PusherOptions(
      host: Uri.parse(ApiConfig.baseUrl).host, // Récupère l'IP depuis la configuration
      wsPort: 8080,
      encrypted: false,
      auth: PusherAuth(
        '${ApiConfig.baseUrl}/api/broadcasting/auth', // URL backend d'authentification
        headers: {'Authorization': 'Bearer ${widget.clientToken}'},
      ),
    );

    PusherClient pusher = PusherClient('adiake_express_key', options, autoConnect: true);
    _echo = Echo(broadcaster: EchoBroadcasterType.Pusher, client: pusher);

    // Écoute des déplacements en direct
    _echo!.private('order.${widget.orderType}.${widget.orderId}.tracking')
        .listen('DriverLocationUpdated', (data) {
          
      setState(() {
        _driverPosition = LatLng(data['lat'].toDouble(), data['lng'].toDouble());
        _driverHeading = (data['heading'] ?? 0).toDouble();
        _vehicleType = data['vehicle_type'] ?? 'moto';
      });

      // Suivre automatiquement la moto avec la caméra
      _mapController.move(_driverPosition, 16.0);
    });
  }

  @override
  void dispose() {
    _echo?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi en Direct 🚀", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _driverPosition,
          initialZoom: 16.0,
        ),
        children: [
          TileLayer(
            // Carte OpenStreetMap claire et sans filigrane API key
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'adiake_livraison_express',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _driverPosition,
                width: 60,
                height: 60,
                child: TweenAnimationBuilder<LatLng>(
                  // Custom Tween pour glisser doucement entre les coordonnées GPS
                  tween: LatLngTween(begin: _driverPosition, end: _driverPosition),
                  duration: const Duration(seconds: 2), // Le temps de glissement
                  builder: (context, animatedPosition, child) {
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: _driverHeading, end: _driverHeading),
                      duration: const Duration(seconds: 1), // Rotation fluide
                      builder: (context, animatedHeading, child) {
                        return Transform.rotate(
                          angle: animatedHeading * (math.pi / 180), // Conversion en radians
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: Center(
                              child: Icon(
                                _vehicleType == 'car' 
                                    ? Icons.directions_car 
                                    : Icons.two_wheeler,
                                size: 30,
                                color: const Color(0xFF0052FF), // Bleu Famanh
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Classe utilitaire pour interpoler deux points GPS
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end}) : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}
