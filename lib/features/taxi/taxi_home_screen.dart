import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/custom_location_api_client.dart';
import '../../data/osrm_client.dart';
import '../../data/taxi_api_client.dart';
import '../../widgets/app_toast.dart';
import 'widgets/taxi_address_search_sheet.dart';
import 'widgets/taxi_corridor_match_card.dart';
import 'widgets/taxi_passenger_success_dialog.dart';
import 'widgets/taxi_perimeter_badge.dart';
import 'widgets/taxi_radar_overlay.dart';
import 'widgets/taxi_radar_pulse_view.dart';
import 'widgets/taxi_seat_selector_card.dart';
import 'widgets/taxi_visual_landmarks_grid.dart';
import 'widgets/taxi_voice_booking_sheet.dart';

class TaxiHomeScreen extends StatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  State<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends State<TaxiHomeScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Coordonnées de référence Adiaké Centre
  static const LatLng _adiakeCenter = LatLng(5.2863, -3.2981);

  // État de réservation
  String _rideType = 'shared'; // 'shared' ou 'private'
  int _seatsBooked = 1;

  String? _pickupAddress;
  LatLng? _pickupLatLng;

  String? _dropoffAddress;
  LatLng? _dropoffLatLng;

  // Mode Pinpoint interactif sur la carte
  bool _isPinpointMode = false;
  bool _isPinpointingPickup = false;
  LatLng _pinpointTempCenter = const LatLng(5.2863, -3.2981);

  // Données radar & tarification
  List<Map<String, dynamic>> _availableTaxis = [];
  Map<String, dynamic>? _estimatedFare;
  bool _isOrdering = false;
  bool _isNightActive = false;

  // Course active en cours
  Map<String, dynamic>? _activeRide;
  Timer? _refreshTimer;

  // Tracé OSRM et Animation
  final OsrmClient _osrm = OsrmClient();
  List<LatLng> _routePoints = [];
  late final AnimationController _routeAnimController;

  // Suivi des notifications d'état
  String? _lastKnownStatus;
  bool _hasNotifiedArrival = false;

  // Quartiers (Polygones) et Repères personnalisés
  List<Map<String, dynamic>> _customZones = [];
  List<Map<String, dynamic>> _customLandmarks = [];

  @override
  void initState() {
    super.initState();
    _routeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkNightTime();
    _fetchSettings();
    _fetchCustomLocations();
    _fetchRadarAndActiveRide(isInitial: true);

    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchRadarAndActiveRide();
      _checkNightTime();
    });
  }

  void _checkNightTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final isNight = (hour >= 20 || hour < 6);
    if (_isNightActive != isNight) {
      if (mounted) setState(() => _isNightActive = isNight);
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await TaxiApiClient.getSettings();
      if (mounted) {
        setState(() {
          if (settings['is_night_active'] != null) {
            _isNightActive = settings['is_night_active'] as bool;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCustomLocations() async {
    try {
      final zones = await CustomLocationApiClient.getZones();
      final landmarks = await CustomLocationApiClient.getLandmarks(popularOnly: true);
      if (mounted) {
        setState(() {
          _customZones = zones;
          if (landmarks.isNotEmpty) {
            _customLandmarks = landmarks;
          }
        });
      }
    } catch (_) {}
  }

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFEAB308);
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFFEAB308);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _routeAnimController.dispose();
    super.dispose();
  }

  /// Récupérer et définir la position GPS actuelle pour le point de départ
  Future<void> _useCurrentGpsLocationForPickup() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) AppToast.showError(context, 'Veuillez activer le service GPS sur votre appareil.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) AppToast.showError(context, 'Permission GPS refusée.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) AppToast.showError(context, 'Permission GPS refusée définitivement dans les paramètres.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final targetLatLng = LatLng(pos.latitude, pos.longitude);
      String resolvedName = 'Ma position actuelle';

      try {
        final reverse = await CustomLocationApiClient.reverseGeocode(pos.latitude, pos.longitude);
        if (reverse != null && reverse['address'] != null) {
          resolvedName = reverse['address'];
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _pickupLatLng = targetLatLng;
          _pickupAddress = resolvedName;
        });
        _mapController.move(targetLatLng, 15.5);
        _calculateEstimate();
        _fetchRoute(fitBounds: true);
        AppToast.showSuccess(context, 'Départ défini sur votre position GPS !');
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Impossible de récupérer la position GPS.');
    }
  }

  /// Calcul et tracé de l'itinéraire OSRM
  Future<void> _fetchRoute({bool fitBounds = false}) async {
    if (!mounted) return;

    LatLng? from;
    LatLng? to;

    if (_activeRide != null) {
      final status = _activeRide!['status'];
      final driver = _activeRide!['driver'];

      final pickupLat = (_activeRide!['pickup_lat'] as num?)?.toDouble() ?? _pickupLatLng?.latitude ?? _adiakeCenter.latitude;
      final pickupLng = (_activeRide!['pickup_lng'] as num?)?.toDouble() ?? _pickupLatLng?.longitude ?? _adiakeCenter.longitude;
      final dropoffLat = (_activeRide!['dropoff_lat'] as num?)?.toDouble() ?? _dropoffLatLng?.latitude ?? _adiakeCenter.latitude;
      final dropoffLng = (_activeRide!['dropoff_lng'] as num?)?.toDouble() ?? _dropoffLatLng?.longitude ?? _adiakeCenter.longitude;

      if (driver != null && (status == 'accepted' || status == 'arrived_pickup' || status == 'requested')) {
        // Étape 1 : Le chauffeur se déplace vers le point de ramassage du client
        from = LatLng((driver['lat'] as num).toDouble(), (driver['lng'] as num).toDouble());
        to = LatLng(pickupLat, pickupLng);
      } else if (status == 'picked_up') {
        // Étape 2 : Le passager est à bord, trajet vers la destination finale
        from = driver != null
            ? LatLng((driver['lat'] as num).toDouble(), (driver['lng'] as num).toDouble())
            : LatLng(pickupLat, pickupLng);
        to = LatLng(dropoffLat, dropoffLng);
      } else {
        from = LatLng(pickupLat, pickupLng);
        to = LatLng(dropoffLat, dropoffLng);
      }
    } else {
      if (_pickupLatLng != null && _dropoffLatLng != null) {
        from = _pickupLatLng;
        to = _dropoffLatLng;
      }
    }

    if (from == null || to == null) {
      if (mounted && _routePoints.isNotEmpty) {
        setState(() => _routePoints = []);
      }
      return;
    }

    try {
      final route = await _osrm.routeDriving(
        from: from,
        to: to,
      );

      if (mounted) {
        setState(() {
          _routePoints = route.points;
        });

        if (fitBounds && _routePoints.length >= 2) {
          _fitRouteBounds();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [from!, to!];
        });
      }
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;
    try {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;

      for (final p in _routePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 14.2);
    } catch (_) {}
  }

  Future<void> _fetchRadarAndActiveRide({bool isInitial = false}) async {
    try {
      final taxis = await TaxiApiClient.getAvailableTaxis(
        lat: _pickupLatLng?.latitude ?? _adiakeCenter.latitude,
        lng: _pickupLatLng?.longitude ?? _adiakeCenter.longitude,
      );

      final active = await TaxiApiClient.getActivePassengerRide();

      if (!mounted) return;
      setState(() {
        _availableTaxis = taxis;
        _activeRide = active;
        if (active != null && _isOrdering) {
          _isOrdering = false;
        }
      });

      if (active != null) {
        _handleActiveRideUpdates(active);
      }

      _fetchRoute();
    } catch (_) {}
  }

  void _handleActiveRideUpdates(Map<String, dynamic> active) {
    final status = active['status'] as String?;
    final driver = active['driver'] as Map<String, dynamic>?;

    if (driver != null && (status == 'accepted' || status == 'in_progress' || status == 'arrived_pickup')) {
      final driverLat = (driver['lat'] as num?)?.toDouble() ?? 0.0;
      final driverLng = (driver['lng'] as num?)?.toDouble() ?? 0.0;
      final pickupLat = (active['pickup_lat'] as num?)?.toDouble() ?? _pickupLatLng?.latitude ?? _adiakeCenter.latitude;
      final pickupLng = (active['pickup_lng'] as num?)?.toDouble() ?? _pickupLatLng?.longitude ?? _adiakeCenter.longitude;

      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        LatLng(driverLat, driverLng),
        LatLng(pickupLat, pickupLng),
      );

      // 🔔 Alerte Proximité : Déclencher dès que le taxi est à moins de 100 mètres !
      if ((distanceMeters <= 100 || status == 'arrived_pickup') && !_hasNotifiedArrival) {
        _hasNotifiedArrival = true;
        _triggerDriverArrivalAlert(driver);
      }
    }

    if (status != _lastKnownStatus) {
      _lastKnownStatus = status;
      if (status == 'picked_up') {
        AppToast.showInfo(context, 'Vous êtes à bord. Bonne route avec votre taxi Famanh !');
      } else if (status == 'completed') {
        _showRideCompletedDialog();
      }
    }
  }

  void _triggerDriverArrivalAlert(Map<String, dynamic> driver) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF08A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF854D0E), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Votre Taxi est arrivé !',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le chauffeur ${driver['name'] ?? 'Famanh Taxi'} (${driver['vehicle_plate'] ?? 'Adiaké'}) vous attend au point de ramassage.',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_rounded, color: Color(0xFFEAB308), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Code OTP : ${_activeRide?['otp_code'] ?? '----'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'J\'arrive !',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF0284C7)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRideCompletedDialog() {
    if (_activeRide == null) return;
    TaxiPassengerSuccessDialog.show(
      context,
      rideData: _activeRide!,
      onDismiss: () {
        setState(() {
          _activeRide = null;
          _hasNotifiedArrival = false;
        });
        _fetchRadarAndActiveRide();
      },
    );
  }

  Future<void> _calculateEstimate() async {
    if (_pickupLatLng == null || _dropoffLatLng == null) {
      if (mounted) setState(() => _estimatedFare = null);
      return;
    }
    try {
      final estimate = await TaxiApiClient.estimateFare(
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        type: _rideType,
        seatsBooked: _rideType == 'private' ? 4 : _seatsBooked,
      );
      if (mounted) {
        setState(() => _estimatedFare = estimate);
      }
    } catch (_) {}
  }

  Future<void> _orderTaxi() async {
    if (_pickupLatLng == null || _pickupAddress == null || _pickupAddress!.trim().isEmpty) {
      AppToast.showInfo(context, 'Veuillez choisir votre point de départ.');
      _openSearchSheet(true);
      return;
    }

    if (_dropoffLatLng == null || _dropoffAddress == null || _dropoffAddress!.trim().isEmpty) {
      AppToast.showInfo(context, 'Veuillez indiquer votre destination.');
      _openSearchSheet(false);
      return;
    }

    setState(() => _isOrdering = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await TaxiApiClient.requestRide(
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        pickupAddress: _pickupAddress!,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        dropoffAddress: _dropoffAddress!,
        type: _rideType,
        seatsBooked: _rideType == 'private' ? 4 : _seatsBooked,
      );

      if (mounted) {
        AppToast.showSuccess(context, res['message'] ?? 'Demande transmise avec succès !');
        _fetchRadarAndActiveRide();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOrdering = false);
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ── Ouvre la feuille de recherche coulissante ─────────────────────
  Future<void> _openSearchSheet(bool isPickup) async {
    final result = await TaxiAddressSearchSheet.show(
      context,
      initialQuery: isPickup ? (_pickupAddress ?? '') : (_dropoffAddress ?? ''),
      isPickup: isPickup,
      currentCenter: (isPickup ? _pickupLatLng : _dropoffLatLng) ?? _adiakeCenter,
      customZones: _customZones,
      customLandmarks: _customLandmarks,
    );

    if (result == null) return;

    if (result.isPinpointMap) {
      setState(() {
        _isPinpointMode = true;
        _isPinpointingPickup = isPickup;
        _pinpointTempCenter = (isPickup ? _pickupLatLng : _dropoffLatLng) ?? _adiakeCenter;
      });
      _mapController.move(_pinpointTempCenter, 16.0);
    } else {
      setState(() {
        if (isPickup) {
          _pickupAddress = result.title;
          _pickupLatLng = result.latLng;
        } else {
          _dropoffAddress = result.title;
          _dropoffLatLng = result.latLng;
        }
      });
      _calculateEstimate();
      _fetchRoute(fitBounds: true);
    }
  }

  // ── Validation de l'emplacement Pinpointé au curseur ───────────────
  Future<void> _confirmPinpointLocation() async {
    final targetPos = _mapController.camera.center;
    setState(() => _isPinpointMode = false);

    try {
      final reverse = await CustomLocationApiClient.reverseGeocode(targetPos.latitude, targetPos.longitude);
      final resolvedName = reverse?['address'] ?? reverse?['zone'] ?? 'Position pointée sur carte';

      if (mounted) {
        setState(() {
          if (_isPinpointingPickup) {
            _pickupAddress = resolvedName;
            _pickupLatLng = targetPos;
          } else {
            _dropoffAddress = resolvedName;
            _dropoffLatLng = targetPos;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_isPinpointingPickup) {
            _pickupAddress = 'Position précise Adiaké (${targetPos.latitude.toStringAsFixed(4)}, ${targetPos.longitude.toStringAsFixed(4)})';
            _pickupLatLng = targetPos;
          } else {
            _dropoffAddress = 'Destination pointée (${targetPos.latitude.toStringAsFixed(4)}, ${targetPos.longitude.toStringAsFixed(4)})';
            _dropoffLatLng = targetPos;
          }
        });
      }
    }

    _calculateEstimate();
    _fetchRoute(fitBounds: true);
    if (mounted) {
      AppToast.showSuccess(context, 'Emplacement sélectionné avec succès !');
    }
  }

  // ── Ouvre le sélecteur visuel par repères illustrés d'Adiaké ──────────
  Future<void> _openVisualLandmarkPicker(bool isPickup) async {
    final item = await TaxiVisualLandmarksGrid.show(
      context,
      title: isPickup ? 'Point de Départ (Repère Visuel)' : 'Destination (Repère Visuel)',
      subtitle: isPickup
          ? 'Touchez l\'icône de l\'endroit où vous êtes'
          : 'Touchez l\'endroit où vous désirez aller',
    );

    if (item == null) return;

    setState(() {
      if (isPickup) {
        _pickupAddress = item.name;
        _pickupLatLng = item.coords;
      } else {
        _dropoffAddress = item.name;
        _dropoffLatLng = item.coords;
      }
    });

    _calculateEstimate();
    _fetchRoute(fitBounds: true);
    if (mounted) {
      AppToast.showSuccess(context, '${item.name} sélectionné');
    }
  }

  // ── Ouvre la modale de commande vocale directe ─────────────────────
  Future<void> _openVoiceBookingSheet() async {
    final res = await TaxiVoiceBookingSheet.show(context);
    if (res == null) return;

    setState(() {
      _pickupAddress ??= 'Position actuelle (Dictée vocale)';
      _pickupLatLng ??= _adiakeCenter;
      _dropoffAddress = 'Destination enregistrée (${res.voiceNoteDuration})';
      _dropoffLatLng = const LatLng(5.2863, -3.2981);
      _seatsBooked = res.seats;
    });

    AppToast.showSuccess(context, 'Demande vocale enregistrée (${res.voiceNoteDuration}) !');
    _orderTaxi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── 1. CARTE FLUTTER MAP ────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _adiakeCenter,
              initialZoom: 14.5,
              minZoom: 11.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ci.famanh.adiake',
              ),

              // Tracé d'itinéraire OSRM
              if (_routePoints.length >= 2) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.5,
                      color: const Color(0xFF0284C7).withValues(alpha: 0.85),
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 2.5,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ],

              // Marqueurs Départ & Destination
              MarkerLayer(
                markers: [
                  // Départ
                  if (_pickupLatLng != null)
                    Marker(
                      point: _pickupLatLng!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.4), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  // Destination
                  if (_dropoffLatLng != null)
                    Marker(
                      point: _dropoffLatLng!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.4), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),

              // Marqueurs Taxis Dynamiques en Direct (Visibles UNIQUEMENT lors du lancement de la commande)
              if (_isOrdering && _availableTaxis.isNotEmpty)
                MarkerLayer(
                  markers: _availableTaxis.map((t) {
                    final lat = (t['lat'] as num).toDouble();
                    final lng = (t['lng'] as num).toDouble();
                    final seats = (t['available_seats'] as int?) ?? 4;
                    final isFree = seats >= 3;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 54,
                      height: 54,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0F172A), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEAB308).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF0F172A), size: 24),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isFree ? const Color(0xFF10B981) : const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                '$seats pl.',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              // Marqueur Taxi Assigné (Visible en temps réel dès que le chauffeur a accepté)
              if (_activeRide != null && _activeRide!['driver'] != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        (_activeRide!['driver']['lat'] as num?)?.toDouble() ?? _adiakeCenter.latitude,
                        (_activeRide!['driver']['lng'] as num?)?.toDouble() ?? _adiakeCenter.longitude,
                      ),
                      width: 54,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAB308),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEAB308).withValues(alpha: 0.6),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_taxi_rounded, color: Colors.black, size: 28),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── 2. PINPOINT MODE CURSEUR INTERACTIF (Si actif) ──────────
          if (_isPinpointMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        _isPinpointingPickup ? '📍 Pointez votre départ exact' : '🏁 Pointez votre destination',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: _isPinpointingPickup ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
            ),

          // ── 3. TOP APP BAR & NIGHT FARE BADGE ───────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                          onPressed: () {
                            if (_isPinpointMode) {
                              setState(() => _isPinpointMode = false);
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEAB308),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Taxi Communal Adiaké',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isOrdering || _activeRide != null)
                                Text(
                                  '${_availableTaxis.length} taxis actifs',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEAB308),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 🌙 Badge Lumineux Tarif Nuit (Si actif)
                  if (_isNightActive) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF312E81).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.nightlight_round, color: Color(0xFFFACC15), size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Tarif de Nuit Actif (20h - 6h) • 300F / place',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFEF08A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── 4. BOUTON VALIDATION EN MODE PINPOINT ───────────────────
          if (_isPinpointMode)
            Positioned(
              bottom: 30,
              left: 24,
              right: 24,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                ),
                onPressed: _confirmPinpointLocation,
                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF0F172A), size: 22),
                label: Text(
                  'Valider cet emplacement exact',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),

          // ── 5. PANNEAU DE RÉSERVATION FLOTTANT (SaaS Style) ─────────
          if (!_isPinpointMode && !_isOrdering)
            Align(
              alignment: Alignment.bottomCenter,
              child: _activeRide != null
                  ? _buildActiveRideTrackingCard()
                  : _buildBookingFloatingCard(),
            ),

          // ── 6. OVERLAY RADAR MATCHING ──────────────────────────────
          if (_isOrdering)
            TaxiRadarOverlay(
              rideType: _rideType,
              seats: _seatsBooked,
              pickupAddress: _pickupAddress ?? 'Départ Adiaké',
              onCancel: () {
                setState(() => _isOrdering = false);
              },
            ),
        ],
      ),
    );
  }

  // ── WIDGET : Panneau Flottant de Réservation ───────────────────────
  Widget _buildBookingFloatingCard() {
    final pLat = _pickupLatLng?.latitude ?? _adiakeCenter.latitude;
    final pLng = _pickupLatLng?.longitude ?? _adiakeCenter.longitude;
    final dLat = _dropoffLatLng?.latitude;
    final dLng = _dropoffLatLng?.longitude;

    double distanceKm = 0.0;
    if (dLat != null && dLng != null) {
      distanceKm = Geolocator.distanceBetween(pLat, pLng, dLat, dLng) / 1000.0;
    }

    final double baseFare = _rideType == 'private'
        ? (_isNightActive ? 1200.0 : 800.0)
        : (_isNightActive ? 300.0 : 200.0) * _seatsBooked;

    final double extraKm = (distanceKm - 3.5).clamp(0.0, 999.0);
    final double extraFare = extraKm * 150.0;
    final double totalCalculatedFare = baseFare + extraFare;

    final fare = (_estimatedFare?['total_fare'] as num?)?.toDouble() ?? totalCalculatedFare;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── INNOVATION ADIAKÉ: BARRE D'ACCESSIBILITÉ RAPIDE ───────
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openVisualLandmarkPicker(false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.place_rounded, color: Color(0xFFD97706), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Repères Visuels',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _openVoiceBookingSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Commander à la voix',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── SÉLECTEUR ADRESSES DÉPART / DESTINATION ───────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Départ
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openSearchSheet(true),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.radio_button_checked, color: Color(0xFF0284C7), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DÉPART',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8)),
                            ),
                            Text(
                              _pickupAddress?.isNotEmpty == true ? _pickupAddress! : 'Où êtes-vous ? (Choisir départ)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: _pickupAddress?.isNotEmpty == true ? FontWeight.w700 : FontWeight.w500,
                                color: _pickupAddress?.isNotEmpty == true ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Choisir parmi les repères visuels',
                        icon: const Icon(Icons.pin_drop_rounded, color: Color(0xFFF59E0B), size: 20),
                        onPressed: () => _openVisualLandmarkPicker(true),
                      ),
                      IconButton(
                        tooltip: 'Ma position GPS actuelle',
                        icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 20),
                        onPressed: _useCurrentGpsLocationForPickup,
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),

                // Destination
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openSearchSheet(false),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DESTINATION',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8)),
                            ),
                            Text(
                              _dropoffAddress?.isNotEmpty == true ? _dropoffAddress! : 'Où allez-vous ? (Choisir destination)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: _dropoffAddress?.isNotEmpty == true ? FontWeight.w700 : FontWeight.w500,
                                color: _dropoffAddress?.isNotEmpty == true ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Choisir parmi les repères visuels',
                        icon: const Icon(Icons.pin_drop_rounded, color: Color(0xFFF59E0B), size: 20),
                        onPressed: () => _openVisualLandmarkPicker(false),
                      ),
                      const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (distanceKm > 0.1) ...[
            TaxiPerimeterBadge(
              distanceKm: distanceKm,
              urbanPerimeterKm: 3.5,
              baseFare: baseFare,
              perKmFare: 150.0,
              totalFare: fare,
              isNight: _isNightActive,
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 14),
          ],

          // ── SÉLECTEUR VISUEL DE PLACES & COVOITURAGE ──────────────
          TaxiSeatSelectorCard(
            rideType: _rideType,
            seatsBooked: _seatsBooked,
            isNight: _isNightActive,
            baseSeatFare: 200,
            privateFare: 800,
            onChanged: (newType, newSeats) {
              setState(() {
                _rideType = newType;
                _seatsBooked = newSeats;
              });
              _calculateEstimate();
            },
          ),

          const SizedBox(height: 16),

          // ── RÉCAPITULATIF PRIX & CTA BUTTON ────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement Espèces',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${fare.toStringAsFixed(0)} FCFA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (_isNightActive)
                    Text(
                      'Majoration nuit incluse',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF4338CA), fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 3,
                  ),
                  onPressed: _orderTaxi,
                  child: Text(
                    'Commander Taxi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MODALE D'ANNULATION AVEC MOTIFS ────────────────────────────────
  void _showCancellationModal(int passengerId) {
    final reasons = [
      'Temps d\'attente trop long',
      'Le chauffeur ne se déplace pas',
      'J\'ai trouvé un autre moyen de transport',
      'Erreur dans le lieu de prise en charge',
      'Changement de programme / Autre motif',
    ];
    String selectedReason = reasons.first;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Annuler la course',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Veuillez sélectionner le motif de votre annulation :',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setModalState(() => selectedReason = r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              await TaxiApiClient.cancelPassengerRide(
                                passengerId: passengerId,
                                reason: selectedReason,
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                setState(() {
                                  _activeRide = null;
                                  _routePoints = [];
                                });
                                AppToast.showSuccess(context, 'Course annulée avec succès.');
                                _fetchRadarAndActiveRide();
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Confirmer l\'annulation',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── WIDGET : Carte de Suivi de Course Active ───────────────────────
  Widget _buildActiveRideTrackingCard() {
    final driver = _activeRide!['driver'] as Map<String, dynamic>?;
    final status = _activeRide!['status'] as String?;
    final fare = _activeRide!['fare_amount'] ?? 0;
    final otp = _activeRide!['otp_code'] ?? '----';
    final bookingId = _activeRide!['id'] as int? ?? _activeRide!['booking_id'] as int? ?? 0;
    final avatarUrl = driver?['avatar_url'] as String?;

    String statusLabel = 'Taxi en route vers vous';
    Color statusColor = const Color(0xFF0284C7);

    if (status == 'arrived_pickup') {
      statusLabel = '🚖 Taxi arrivé au point de ramassage !';
      statusColor = const Color(0xFF10B981);
    } else if (status == 'picked_up') {
      statusLabel = 'Course en cours vers votre destination';
      statusColor = const Color(0xFF8B5CF6);
    }

    final canCancel = status != 'picked_up' && status != 'completed';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEAB308), width: 2),
                  color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_taxi_rounded,
                            color: Color(0xFFEAB308),
                            size: 28,
                          ),
                        )
                      : const Icon(Icons.local_taxi_rounded, color: Color(0xFFEAB308), size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driver?['name'] ?? 'Chauffeur Kouassi Taxi',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF08A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFF854D0E)),
                              const SizedBox(width: 2),
                              Text(
                                '${driver?['rating'] ?? '4.9'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF854D0E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Plaque : ${driver?['vehicle_plate'] ?? '1234-AB-01'}',
                      style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (driver?['phone'] != null)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:${driver!['phone']}')),
                ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF08A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Code OTP : $otp',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFEF08A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── CODE PIN D'EMBARQUEMENT SÉCURISÉ ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFFEAB308), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'CODE EMBARQUEMENT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEAB308),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Donnez ce code au chauffeur',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEAB308)),
                  ),
                  child: Text(
                    otp.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFEF08A),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Montant à régler en espèces :',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
              ),
              Text(
                '$fare FCFA',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEAB308),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick Action Buttons (SOS & Cancel)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final shareText = 'Je suis à bord du taxi Famanh (Plaque: ${driver?['vehicle_plate'] ?? '1234-AB-01'}) à Adiaké. Code course: $bookingId';
                    launchUrl(Uri.parse('sms:?body=${Uri.encodeComponent(shareText)}'));
                  },
                  icon: const Icon(Icons.share_location_rounded, size: 16, color: Color(0xFF38BDF8)),
                  label: Text(
                    'SOS / Partager',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancellationModal(bookingId),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFF87171)),
                    label: Text(
                      'Annuler course',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF87171),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
