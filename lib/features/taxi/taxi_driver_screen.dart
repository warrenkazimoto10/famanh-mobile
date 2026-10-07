import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../data/api_session.dart';
import '../../data/osrm_client.dart';
import '../../data/taxi_api_client.dart';
import '../../widgets/app_toast.dart';
import 'widgets/swipe_to_accept_slider.dart';
import 'widgets/taxi_corridor_match_card.dart';
import 'widgets/taxi_driver_success_dialog.dart';

class TaxiDriverScreen extends StatefulWidget {
  const TaxiDriverScreen({super.key});

  @override
  State<TaxiDriverScreen> createState() => _TaxiDriverScreenState();
}

class _TaxiDriverScreenState extends State<TaxiDriverScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final OsrmClient _osrm = OsrmClient();

  // Coordonnées de base Adiaké
  static const LatLng _adiakeCenter = LatLng(5.2863, -3.2981);
  LatLng _driverLocation = _adiakeCenter;

  bool _isLoading = true;
  bool _isAvailable = true;
  bool _isTogglingStatus = false;
  bool _isUploadingPhoto = false;
  bool _isLocatingGps = false;

  Map<String, dynamic>? _driverInfo;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _activeRide;
  Map<String, dynamic>? _incomingRide;

  // Passager sélectionné pour la navigation prioritaire
  int _selectedPassengerIndex = 0;

  // Couleurs distinctes pour les itinéraires multi-passagers
  final List<Color> _passengerColors = [
    const Color(0xFF0284C7), // Passager 1 : Cyan vibrant
    const Color(0xFFF59E0B), // Passager 2 : Ambre / Or
    const Color(0xFF10B981), // Passager 3 : Émeraude
    const Color(0xFF8B5CF6), // Passager 4 : Violet
  ];

  // Tracés d'itinéraires pour chaque passager actif
  final Map<int, List<LatLng>> _passengerRoutes = {};

  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStreamSub;
  late AnimationController _pulseController;
  late AnimationController _colorAnimController;
  late Animation<double> _colorAnim;

  List<double> _getSaturationMatrix(double s) {
    final invS = 1.0 - s;
    final r = 0.213 * invS;
    final g = 0.715 * invS;
    final b = 0.072 * invS;
    return [
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1.0,
    );
    _colorAnim = CurvedAnimation(
      parent: _colorAnimController,
      curve: Curves.easeInOutCubic,
    );

    _initDriverLocation();
    _fetchDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchDashboard());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    _colorAnimController.dispose();
    super.dispose();
  }

  bool _isNight() {
    final now = DateTime.now();
    return now.hour >= 20 || now.hour < 6;
  }

  /// Initialisation et écoute de la position GPS réelle du chauffeur
  Future<void> _initDriverLocation() async {
    try {
      final pos = await _getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _driverLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_driverLocation, 15.0);
      }
    } catch (_) {}

    // Écoute du flux de position en temps réel
    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _driverLocation = LatLng(pos.latitude, pos.longitude);
        });
        if (_isAvailable) {
          TaxiApiClient.toggleDriverAvailability(
            isAvailable: true,
            lat: pos.latitude,
            lng: pos.longitude,
          ).catchError((_) => <String, dynamic>{});
        }
      });
    } catch (_) {}
  }

  /// Obtention de la position GPS avec gestion des permissions et fallback
  Future<Position?> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Recentrer la carte sur la position GPS réelle
  Future<void> _recenterOnGps() async {
    if (mounted) AppToast.showInfo(context, 'Actualisation de votre position GPS...');
    final pos = await _getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _driverLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_driverLocation, 15.5);
      AppToast.showSuccess(context, '📍 Position GPS trouvée (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})');
      if (_isAvailable) {
        TaxiApiClient.toggleDriverAvailability(
          isAvailable: true,
          lat: pos.latitude,
          lng: pos.longitude,
        ).catchError((_) => <String, dynamic>{});
      }
    } else {
      if (mounted) {
        AppToast.showError(context, 'Signal GPS inaccessible. Autorisez la localisation dans votre navigateur.');
      }
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await TaxiApiClient.getDriverDashboard();
      if (mounted) {
        final driver = data['driver'] as Map<String, dynamic>?;
        final ride = data['active_ride'] as Map<String, dynamic>?;
        final incoming = data['incoming_ride'] as Map<String, dynamic>?;
        final isAvail = data['is_available'] ?? true;

        setState(() {
          _isAvailable = isAvail;
          _driverInfo = driver;
          _wallet = data['wallet'] as Map<String, dynamic>?;
          _activeRide = ride;
          _incomingRide = incoming;
          _isLoading = false;
        });

        if (isAvail && _colorAnimController.value < 0.5) {
          _colorAnimController.forward();
        } else if (!isAvail && _colorAnimController.value > 0.5) {
          _colorAnimController.reverse();
        }

        _syncPassengerRoutes(ride);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Synchronisation des itinéraires OSRM
  Future<void> _syncPassengerRoutes(Map<String, dynamic>? ride) async {
    if (ride == null) {
      if (_passengerRoutes.isNotEmpty) {
        setState(() => _passengerRoutes.clear());
      }
      return;
    }

    final passengers = (ride['passengers'] as List<dynamic>?) ?? [];
    for (int i = 0; i < passengers.length; i++) {
      final p = passengers[i] as Map<String, dynamic>;
      final id = p['id'] as int;
      final status = p['status'] as String?;
      final pLat = (p['pickup_lat'] as num?)?.toDouble();
      final pLng = (p['pickup_lng'] as num?)?.toDouble();
      final dLat = (p['dropoff_lat'] as num?)?.toDouble();
      final dLng = (p['dropoff_lng'] as num?)?.toDouble();

      if (pLat != null && pLng != null && dLat != null && dLng != null) {
        LatLng from;
        LatLng to;

        if (status == 'accepted' || status == 'arrived_pickup' || status == 'requested') {
          from = _driverLocation;
          to = LatLng(pLat, pLng);
        } else {
          from = _driverLocation;
          to = LatLng(dLat, dLng);
        }

        try {
          final route = await _osrm.routeDriving(from: from, to: to);
          if (mounted && route.points.isNotEmpty) {
            setState(() {
              _passengerRoutes[id] = route.points;
            });
          }
        } catch (_) {}
      }
    }
  }

  /// Basculer en ligne / en pause avec récupération automatique de la position GPS
  Future<void> _toggleOnlineStatus() async {
    setState(() => _isTogglingStatus = true);
    final target = !_isAvailable;

    // Animation immédiate de transition de couleur
    if (target) {
      _colorAnimController.forward();
    } else {
      _colorAnimController.reverse();
    }

    double? lat;
    double? lng;

    if (target) {
      setState(() => _isLocatingGps = true);
      try {
        final pos = await _getCurrentPosition();
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
          if (mounted) {
            setState(() {
              _driverLocation = LatLng(lat!, lng!);
              _isLocatingGps = false;
            });
            _mapController.move(_driverLocation, 15.2);
          }
        }
      } catch (_) {
        if (mounted) setState(() => _isLocatingGps = false);
      }
    }

    try {
      final res = await TaxiApiClient.toggleDriverAvailability(
        isAvailable: target,
        lat: lat ?? _driverLocation.latitude,
        lng: lng ?? _driverLocation.longitude,
      );
      if (mounted) {
        setState(() {
          _isAvailable = target;
          _isTogglingStatus = false;
          _isLocatingGps = false;
        });
        AppToast.showSuccess(
          context,
          res['message'] ?? (target ? '🟢 Vous êtes EN LIGNE (GPS activé)' : '⚪ Vous êtes HORS LIGNE'),
        );
        _fetchDashboard();
      }
    } catch (e) {
      if (mounted) {
        // Reverser l'animation en cas d'échec
        if (target) {
          _colorAnimController.reverse();
        } else {
          _colorAnimController.forward();
        }
        setState(() {
          _isTogglingStatus = false;
          _isLocatingGps = false;
        });
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Accepter une course partagée entrante sur l'itinéraire (Covoiturage Corridor)
  Future<void> _handleAcceptIncoming(int passengerId) async {
    try {
      await TaxiApiClient.acceptIncomingRide(passengerId: passengerId);
      if (mounted) {
        setState(() => _incomingRide = null);
        AppToast.showSuccess(context, 'Passager ajouté à votre trajet covoiturage ! 🚗');
        _fetchDashboard();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Ignorer la course entrante
  void _handleDeclineIncoming() {
    setState(() => _incomingRide = null);
  }

  /// Upload de photo de profil chauffeur
  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Photo de profil du Chauffeur',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7)),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);
      final res = await TaxiApiClient.uploadDriverAvatar(pickedFile);

      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          if (_driverInfo != null) {
            _driverInfo!['avatar_url'] = res['avatar_url'] ?? res['avatar_path'];
          }
        });
        AppToast.showSuccess(context, 'Photo de profil mise à jour avec succès !');
        _fetchDashboard();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        AppToast.showError(context, 'Erreur lors du téléversement : $e');
      }
    }
  }

  /// Validation d'une étape de passager
  Future<void> _handleStepUpdate(int passengerId, String step, {String? reason}) async {
    try {
      final res = await TaxiApiClient.updatePassengerStep(
        passengerId: passengerId,
        step: step,
      );
      if (mounted) {
        if (step == 'completed') {
          final data = res['data'] as Map<String, dynamic>?;
          final fareCollected = (data?['fare_collected_cash'] as num?)?.toDouble() ?? 200.0;
          final commissionDeducted = (data?['commission_deducted'] as num?)?.toDouble() ?? (fareCollected * 0.1);
          final netEarnings = fareCollected - commissionDeducted;
          final currentBal = (_wallet?['balance'] as num?)?.toDouble() ?? 0.0;
          final newBal = currentBal - commissionDeducted;

          TaxiDriverSuccessDialog.show(
            context,
            passengerName: 'Passager #$passengerId',
            fareCollected: fareCollected,
            commissionDeducted: commissionDeducted,
            driverNetEarnings: netEarnings,
            updatedBalance: newBal,
            onDismiss: () {
              _fetchDashboard();
            },
          );
        } else {
          AppToast.showSuccess(context, res['message'] ?? 'Statut mis à jour !');
          _fetchDashboard();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Lancement direct du guidage GPS externe (Google Maps / Waze)
  Future<void> _launchExternalNavigation(double lat, double lng, String label) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl);
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, 'Impossible d\'ouvrir Google Maps');
    }
  }

  /// Modale d'annulation de course par le chauffeur
  void _showDriverCancelModal(int passengerId, String passengerName) {
    final reasons = [
      'Client ne répond pas au téléphone',
      'Client absent après 5 min d\'attente',
      'Client a annulé oralement sur place',
      'Embouteillage majeur / Impossibilité d\'accès',
    ];
    String selectedReason = reasons.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Annuler la course de $passengerName',
                    style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444)),
                  ),
                  const SizedBox(height: 6),
                  const Text('Sélectionnez la raison pour libérer la place :', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 14),
                  ...reasons.map((r) {
                    final isSel = selectedReason == r;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setModalState(() => selectedReason = r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: isSel ? const Color(0xFFEF4444) : Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(child: Text(r, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.normal))),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleStepUpdate(passengerId, 'cancelled', reason: selectedReason);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Confirmer l\'annulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Modale de vérification du code PIN à l'embarquement
  void _showPinVerificationModal(int passengerId, String name, dynamic expectedOtp) {
    final otpStr = expectedOtp?.toString() ?? '----';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pin_rounded, color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code PIN d\'embarquement',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Demandez le code à 4 chiffres à $name',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Code client :', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  Text(
                    otpStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 4,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleStepUpdate(passengerId, 'picked_up');
              },
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Valider & Démarrer le trajet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modale de rechargement du portefeuille
  void _showTopupModal() {
    final amountController = TextEditingController(text: '1000');
    String selectedChannel = 'wave';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recharger le Portefeuille',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Moyen de paiement :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌊 Wave')),
                          selected: selectedChannel == 'wave',
                          onSelected: (_) => setModalState(() => selectedChannel = 'wave'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🍊 Orange')),
                          selected: selectedChannel == 'orange_money',
                          onSelected: (_) => setModalState(() => selectedChannel = 'orange_money'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('💛 MTN')),
                          selected: selectedChannel == 'mtn_momo',
                          onSelected: (_) => setModalState(() => selectedChannel = 'mtn_momo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Montant à créditer',
                      prefixIcon: const Icon(Icons.payments_rounded),
                      suffixText: 'FCFA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final amt = double.tryParse(amountController.text) ?? 1000;
                      try {
                        await TaxiApiClient.topupWallet(amount: amt, channel: selectedChannel);
                        if (mounted) {
                          AppToast.showSuccess(context, 'Portefeuille crédité de $amt FCFA avec succès !');
                          _fetchDashboard();
                        }
                      } catch (e) {
                        if (mounted) {
                          AppToast.showError(context, e.toString());
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Valider le Rechargement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFEAB308)),
              SizedBox(height: 16),
              Text('Chargement du cockpit plein écran...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0.0;
    final isBlocked = _wallet?['is_blocked'] ?? false;
    final occupiedSeats = _activeRide?['occupied_seats'] ?? 0;
    final isPrivate = _activeRide?['type'] == 'private';
    final passengers = (_activeRide?['passengers'] as List<dynamic>?) ?? [];
    final nightMode = _isNight();
    final driverName = _driverInfo?['name'] ?? 'Kouassi Chauffeur';
    final vehiclePlate = _driverInfo?['vehicle_plate'] ?? '1234-AB-01';
    final avatarUrl = _driverInfo?['avatar_url'] as String?;

    // Déterminer la prochaine étape prioritaire
    Map<String, dynamic>? priorityPassenger;
    Color priorityColor = const Color(0xFF0284C7);

    if (passengers.isNotEmpty) {
      if (_selectedPassengerIndex >= passengers.length) {
        _selectedPassengerIndex = 0;
      }
      priorityPassenger = passengers[_selectedPassengerIndex] as Map<String, dynamic>;
      final idx = _selectedPassengerIndex;
      priorityColor = _passengerColors[idx % _passengerColors.length];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AnimatedBuilder(
        animation: _colorAnim,
        builder: (context, _) {
          return ColorFiltered(
            colorFilter: ColorFilter.matrix(_getSaturationMatrix(_colorAnim.value)),
            child: Stack(
              children: [
                // ── 1. CARTE FULL-SCREEN 100% ──────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _driverLocation,
                    initialZoom: 15.0,
                    minZoom: 11.0,
                    maxZoom: 18.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ci.famanh.adiake.driver',
                    ),

                    // Tracés d'itinéraires multi-passagers avec couleurs distinctes
                    if (_passengerRoutes.isNotEmpty)
                      PolylineLayer(
                        polylines: _passengerRoutes.entries.map((entry) {
                          final passengerIndex = passengers.indexWhere((p) => p['id'] == entry.key);
                          final isFocused = passengerIndex == _selectedPassengerIndex;
                          final color = _passengerColors[passengerIndex >= 0 ? passengerIndex % _passengerColors.length : 0];

                          return Polyline(
                            points: entry.value,
                            strokeWidth: isFocused ? 6.0 : 3.5,
                            color: isFocused ? color : color.withValues(alpha: 0.5),
                          );
                        }).toList(),
                      ),

                    // Marqueurs : Position Chauffeur & Passagers
                    MarkerLayer(
                      markers: [
                        // Position du Taxi Chauffeur en temps réel
                        Marker(
                          point: _driverLocation,
                          width: 50,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isAvailable)
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (_, __) => Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25 * _pulseController.value),
                                    ),
                                  ),
                                ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAB308),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: const Icon(Icons.local_taxi_rounded, color: Colors.black, size: 22),
                              ),
                            ],
                          ),
                        ),

                        // Marqueurs des passagers
                        ...passengers.asMap().entries.expand((entry) {
                          final idx = entry.key;
                          final p = entry.value as Map<String, dynamic>;
                          final color = _passengerColors[idx % _passengerColors.length];
                          final pLat = (p['pickup_lat'] as num?)?.toDouble();
                          final pLng = (p['pickup_lng'] as num?)?.toDouble();
                          final dLat = (p['dropoff_lat'] as num?)?.toDouble();
                          final dLng = (p['dropoff_lng'] as num?)?.toDouble();
                          final st = p['status'];

                          final markers = <Marker>[];
                          if (pLat != null && pLng != null && (st == 'accepted' || st == 'arrived_pickup' || st == 'requested')) {
                            markers.add(
                              Marker(
                                point: LatLng(pLat, pLng),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'P${idx + 1}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          if (dLat != null && dLng != null) {
                            markers.add(
                              Marker(
                                point: LatLng(dLat, dLng),
                                width: 32,
                                height: 32,
                                child: Icon(Icons.location_on_rounded, color: color, size: 32),
                              ),
                            );
                          }
                          return markers;
                        }),
                      ],
                    ),
                  ],
                ),

                // ── 2. TOP HEADER FLOTTANT CHAUFFEUR & STATUT GPS ───────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Photo Avatar
                              Stack(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFEAB308), width: 2),
                                      color: const Color(0xFF1E293B),
                                    ),
                                    child: ClipOval(
                                      child: _isUploadingPhoto
                                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308), strokeWidth: 2))
                                          : (avatarUrl != null && avatarUrl.isNotEmpty
                                              ? Image.network(
                                                  avatarUrl,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Color(0xFFEAB308)),
                                                )
                                              : const Icon(Icons.person_rounded, color: Color(0xFFEAB308))),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickAndUploadPhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(color: Color(0xFFEAB308), shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt_rounded, size: 10, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),

                              // Nom & Plaque
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            driverName,
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(color: const Color(0xFFFEF08A), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('⭐ 4.9', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF854D0E))),
                                        ),
                                      ],
                                    ),
                                    Text(vehiclePlate, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),

                              // Bouton Disponible / En Pause avec prise GPS
                              ElevatedButton.icon(
                                onPressed: _isTogglingStatus ? null : _toggleOnlineStatus,
                                icon: _isLocatingGps
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Icon(_isAvailable ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 16),
                                label: Text(
                                  _isAvailable ? 'EN LIGNE' : 'HORS LIGNE',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAvailable ? const Color(0xFF10B981) : const Color(0xFF475569),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: _isAvailable ? 4 : 0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Barre Solde Portefeuille & Majoration Nuit
                        Row(
                          children: [
                            // Chip Portefeuille
                            GestureDetector(
                              onTap: _showTopupModal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFEAB308), size: 15),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${balance.toStringAsFixed(0)} FCFA',
                                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFEF08A), fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 14),
                                  ],
                                ),
                              ),
                            ),

                            if (nightMode) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF312E81).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF818CF8)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.nightlight_round, color: Color(0xFFFDE047), size: 13),
                                    SizedBox(width: 4),
                                    Text('Service de Nuit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],

                            const Spacer(),

                            // Bouton Déconnexion rapide
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                tooltip: 'Déconnexion',
                                onPressed: () async {
                                  await ApiSession.setToken(null);
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 2.5 BANNIÈRE FLOTTANTE ANIMÉE HORS LIGNE ───────────
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 105,
                  left: 14,
                  right: 14,
                  child: AnimatedSlide(
                    offset: _isAvailable ? const Offset(0, -0.6) : Offset.zero,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _isAvailable ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      child: IgnorePointer(
                        ignoring: _isAvailable,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF94A3B8).withValues(alpha: 0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF334155),
                                  border: Border.all(color: const Color(0xFF94A3B8)),
                                ),
                                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFCBD5E1), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'VOUS ÊTES HORS LIGNE',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Votre taxi est masqué pour les clients.',
                                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isTogglingStatus ? null : _toggleOnlineStatus,
                                icon: const Icon(Icons.flash_on_rounded, size: 14),
                                label: const Text('EN LIGNE'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 3. BOUTONS FLOTTANTS DE CONTRÔLE CARTE ──────────────────
          Positioned(
            right: 14,
            bottom: passengers.isNotEmpty ? 290 : 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_gps',
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFEAB308),
                  elevation: 4,
                  onPressed: _recenterOnGps,
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 3,
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // ── 3.5 ALERTE COVOITURAGE COULOIR / CORRIDOR DETOUR ───────
          if (_incomingRide != null)
            Positioned(
              bottom: passengers.isNotEmpty ? 290 : 160,
              left: 0,
              right: 0,
              child: TaxiCorridorMatchCard(
                passengerName: _incomingRide!['passenger_name'] ?? 'Nouveau Passager',
                pickupLandmark: _incomingRide!['pickup_address'] ?? 'Point de ramassage',
                dropoffLandmark: _incomingRide!['dropoff_address'] ?? 'Destination',
                seats: _incomingRide!['seats_booked'] ?? 1,
                fare: (_incomingRide!['fare_amount'] as num?)?.toDouble() ?? 200.0,
                detourMinutes: (_incomingRide!['detour_minutes'] as num?)?.toInt() ?? 2,
                detourMeters: (_incomingRide!['detour_meters'] as num?)?.toDouble() ?? 350.0,
                onAccept: () {
                  final id = _incomingRide!['id'] as int? ?? _incomingRide!['passenger_id'] as int? ?? 0;
                  if (id > 0) _handleAcceptIncoming(id);
                },
                onDecline: _handleDeclineIncoming,
              ),
            ),

          // ── 4. PANNEAU INFÉRIEUR FLOTTANT (SAAS COCKPIT) ────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle pill
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Jauge des 4 places
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Capacité à Bord (4 Places)',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        isPrivate ? 'Privatisé VIP' : '$occupiedSeats / 4 Places prises',
                        style: GoogleFonts.inter(color: const Color(0xFFEAB308), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: List.generate(4, (index) {
                      final isSeatOccupied = isPrivate || (index < occupiedSeats);
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSeatOccupied ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSeatOccupied ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSeatOccupied ? Icons.person_rounded : Icons.airline_seat_recline_extra_rounded,
                                size: 14,
                                color: isSeatOccupied ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'P${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSeatOccupied ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Si aucun passager actif
                  if (passengers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAvailable ? Icons.radar_rounded : Icons.pause_circle_outline_rounded,
                            color: _isAvailable ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isAvailable ? 'Radar actif • En attente de courses...' : 'Passez en ligne pour recevoir des courses',
                            style: GoogleFonts.plusJakartaSans(
                              color: _isAvailable ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Onglets passagers (si plusieurs)
                    if (passengers.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: passengers.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final isSel = idx == _selectedPassengerIndex;
                            final color = _passengerColors[idx % _passengerColors.length];

                            return GestureDetector(
                              onTap: () => setState(() => _selectedPassengerIndex = idx),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? color : Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSel ? Colors.white : Colors.white24),
                                ),
                                child: Text(
                                  'P${idx + 1} : ${entry.value['passenger_name'] ?? 'Client'}',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Fiche détaillée du passager sélectionné
                    Builder(builder: (context) {
                      final p = priorityPassenger!;
                      final id = p['id'] as int;
                      final name = p['passenger_name'] ?? 'Passager';
                      final phone = p['passenger_phone'] ?? '';
                      final pickup = p['pickup_address'] ?? 'Point de départ';
                      final dropoff = p['dropoff_address'] ?? 'Destination';
                      final pLat = (p['pickup_lat'] as num?)?.toDouble() ?? 5.2863;
                      final pLng = (p['pickup_lng'] as num?)?.toDouble() ?? -3.2981;
                      final dLat = (p['dropoff_lat'] as num?)?.toDouble() ?? 5.2863;
                      final dLng = (p['dropoff_lng'] as num?)?.toDouble() ?? -3.2981;
                      final fare = p['fare_amount'] ?? 200;
                      final seats = p['seats_booked'] ?? 1;
                      final status = p['status'] ?? 'accepted';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: priorityColor.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: priorityColor,
                                      child: Text(
                                        'P${_selectedPassengerIndex + 1}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text('($seats pl.)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                                  child: Text('$fare FCFA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Colors.white12),

                            // Adresse avec bouton Google Maps 1-Clic
                            Row(
                              children: [
                                Icon(
                                  status == 'picked_up' ? Icons.location_on_rounded : Icons.my_location_rounded,
                                  size: 16,
                                  color: status == 'picked_up' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status == 'picked_up' ? 'Vers : $dropoff' : 'Prendre à : $pickup',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Guidage Google Maps',
                                  icon: const Icon(Icons.navigation_rounded, color: Color(0xFFEAB308), size: 18),
                                  onPressed: () => _launchExternalNavigation(
                                    status == 'picked_up' ? dLat : pLat,
                                    status == 'picked_up' ? dLng : pLng,
                                    status == 'picked_up' ? dropoff : pickup,
                                  ),
                                ),
                                if (phone.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Appeler le client',
                                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Bouton Action Principal
                            Row(
                              children: [
                                if (status == 'accepted' || status == 'requested') ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _handleStepUpdate(id, 'arrived_pickup'),
                                      icon: const Icon(Icons.pin_drop_rounded, size: 16),
                                      label: const Text('Arrivé au ramassage 📍'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEAB308),
                                        foregroundColor: const Color(0xFF0F172A),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Client absent',
                                    icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                                    onPressed: () => _showDriverCancelModal(id, name),
                                  ),
                                ],
                                if (status == 'arrived_pickup') ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showPinVerificationModal(id, name, p['otp_code'] ?? p['pin_code'] ?? p['security_code']),
                                      icon: const Icon(Icons.pin_rounded, size: 16),
                                      label: const Text('Vérifier PIN & Embarquer 🔐'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0284C7),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Client absent',
                                    icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                                    onPressed: () => _showDriverCancelModal(id, name),
                                  ),
                                ],
                                if (status == 'picked_up')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _handleStepUpdate(id, 'completed'),
                                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                                      label: Text('Déposé & Encaisser $fare F ✅'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // ── 5. MODALE FLOTTANTE DE NOUVELLE DEMANDE (SWIPE TO ACCEPT) ─────────
          if (_incomingRide != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, -6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🚖 NOUVELLE DEMANDE DE COURSE',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEAB308),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_incomingRide!['passenger_name']} • ${_incomingRide!['seats_booked']} place(s)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'De : ${_incomingRide!['pickup_address']}',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                    ),
                    Text(
                      'Vers : ${_incomingRide!['dropoff_address']}',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SwipeToAcceptSlider(
                      onAccept: () async {
                        final bookingId = _incomingRide!['id'] as int;
                        try {
                          final res = await TaxiApiClient.acceptIncomingRide(passengerId: bookingId);
                          if (mounted) {
                            setState(() => _incomingRide = null);
                            AppToast.showSuccess(context, res['message'] ?? 'Course acceptée avec succès !');
                            _fetchDashboard();
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _incomingRide = null);
                            AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
                            _fetchDashboard();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  },
),
    );
  }
}
