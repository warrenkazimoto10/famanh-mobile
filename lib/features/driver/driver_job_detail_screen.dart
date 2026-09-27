import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/osrm_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/slidable_accept_button.dart';
import 'driver_job_success_screen.dart';
import 'driver_jobs_screen.dart';
import 'driver_live_location_service.dart';

class DriverJobDetailScreen extends StatefulWidget {
  const DriverJobDetailScreen({super.key, required this.kind, required this.id});

  final DriverJobKind kind;
  final int id;

  @override
  State<DriverJobDetailScreen> createState() => _DriverJobDetailScreenState();
}

class _DriverJobDetailScreenState extends State<DriverJobDetailScreen> {
  bool _loading = true;
  bool _acting = false;
  String? _error;

  GasOrderDriverDetailDto? _gas;
  ParcelOrderDetailDto? _parcel;
  FoodOrderDetailDto? _food;

  bool _isInProgress(String s) {
    if (s == 'accepted' ||
        s == 'depot_selected' ||
        s == 'at_depot' ||
        s == 'picked_up' ||
        s == 'en_route') {
      return true;
    }
    // Gaz : après « Livrée & payée », il reste le retour de la bouteille vide
    // au dépôt → la mission est encore en cours (suivi GPS maintenu).
    if (widget.kind == DriverJobKind.gas && s == 'delivered_paid') return true;
    return false;
  }

  bool _isFinal(String s) {
    if (widget.kind == DriverJobKind.gas) return s == 'empty_returned';
    return s == 'delivered_paid' || s == 'empty_returned';
  }

  final _map = MapController();
  final _osrm = OsrmClient();
  Timer? _routeTimer;
  List<LatLng> _routeFull = const [];
  List<LatLng> _route = const [];
  double? _routeKm;
  double? _routeMin;
  LatLng? _me;
  StreamSubscription<Position>? _posSub;
  LatLng? _lastTarget;

  Future<void> _callTel(String? raw) async {
    final p = raw?.trim();
    if (p == null || p.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p.replaceAll(RegExp(r'\s+'), ''));
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l’appel.')),
      );
    }
  }

  Future<void> _shareRestaurantOrderViaWhatsApp(FoodOrderStopDto stop) async {
    final phone = stop.restaurantPhoneSnapshot?.trim();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro du restaurant indisponible.')),
        );
      }
      return;
    }

    final food = _food;
    final items = food?.items.where((i) => i.restaurantId == stop.restaurantId).toList() ?? const [];

    final buf = StringBuffer();
    buf.writeln('🛵 Nouvelle commande Famanh');
    buf.writeln('Restaurant: ${stop.restaurantNameSnapshot ?? 'Restaurant'}');
    buf.writeln('');
    buf.writeln('Détail de la commande :');
    for (final it in items) {
      buf.writeln('• ${it.dishName ?? 'Plat #${it.dishId}'} × ${it.qty}${it.note != null && it.note!.trim().isNotEmpty ? ' (note: ${it.note})' : ''}');
    }
    buf.writeln('');
    buf.writeln('Merci de préparer la commande, le livreur arrive pour la récupérer.');

    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$digits');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de passer l’appel.')),
      );
    }
  }

  void _syncLiveLocation(String? status) {
    if (status == null) return;
    if (_isInProgress(status)) {
      DriverLiveLocationService.instance.start(
        onError: (message) {
          if (mounted) AppToast.showError(context, message);
        },
      );
    } else if (_isFinal(status)) {
      DriverLiveLocationService.instance.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _routeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshRoute());
    _startPositionStream();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'at_depot':
        return 'Au dépôt';
      case 'picked_up':
        return 'Récupéré';
      case 'en_route':
        return 'En route';
      case 'delivered_paid':
        return 'Livrée & payée';
      case 'empty_returned':
        return 'Vide retourné';
      case 'stop_picked_up':
        return 'Ramassage restaurant';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.kind == DriverJobKind.gas) {
        final d = await ApiClient.getDriverGasOrder(widget.id);
        if (!mounted) return;
        setState(() {
          _gas = d;
          _parcel = null;
          _food = null;
          _loading = false;
        });
        _syncLiveLocation(d.status);
        if (_isFinal(d.status)) {
          setState(() {
            _lastTarget = null;
            _routeFull = const [];
            _route = const [];
            _routeKm = null;
            _routeMin = null;
          });
        }
      } else if (widget.kind == DriverJobKind.parcel) {
        final d = await ApiClient.getDriverParcelOrder(widget.id);
        if (!mounted) return;
        setState(() {
          _parcel = d;
          _gas = null;
          _food = null;
          _loading = false;
        });
        _syncLiveLocation(d.status);
        if (_isFinal(d.status)) {
          setState(() {
            _lastTarget = null;
            _routeFull = const [];
            _route = const [];
            _routeKm = null;
            _routeMin = null;
          });
        }
      } else {
        final d = await ApiClient.getDriverFoodOrder(widget.id);
        if (!mounted) return;
        setState(() {
          _food = d;
          _gas = null;
          _parcel = null;
          _loading = false;
        });
        _syncLiveLocation(d.status);
        if (_isFinal(d.status)) {
          setState(() {
            _lastTarget = null;
            _routeFull = const [];
            _route = const [];
            _routeKm = null;
            _routeMin = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _accept() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      if (widget.kind == DriverJobKind.gas) {
        await ApiClient.driverAcceptGasOrder(widget.id);
      } else if (widget.kind == DriverJobKind.parcel) {
        await ApiClient.driverAcceptParcelOrder(widget.id);
      } else {
        await ApiClient.driverAcceptFoodOrder(widget.id);
      }
      if (!mounted) return;
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppToast.showSuccess(context, 'Mission acceptée.');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _navigateToSuccessScreen() {
    if (!mounted) return;
    final orderType = widget.kind == DriverJobKind.food
        ? 'food'
        : (widget.kind == DriverJobKind.gas ? 'gas' : 'parcel');

    final earnings = _calculateEarnings();
    final pickupN = _food?.stops.firstOrNull?.restaurantNameSnapshot ??
        (_gas?.depotName ?? (_parcel?.pickupAddress ?? 'Point de retrait'));
    final pickupA = _food?.stops.firstOrNull?.restaurantNameSnapshot != null
        ? 'Restaurant - Adiaké'
        : (_gas?.depotName != null ? 'Dépôt Gaz' : (_parcel?.pickupAddress ?? 'Zone Adiaké'));
    final dropoffN = _food?.clientName ??
        (_gas?.clientName ?? (_parcel?.clientName ?? 'Client'));
    final dropoffA = _food?.deliveryAddress ??
        (_gas?.deliveryAddress ?? (_parcel?.dropoffAddress ?? 'Destination'));
    final itemSum = widget.kind == DriverJobKind.food
        ? 'Commande Repas (Restaurant)'
        : (widget.kind == DriverJobKind.gas ? 'Bouteille de Gaz' : 'Colis Express');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DriverJobSuccessScreen(
          orderId: widget.id.toString(),
          orderType: orderType,
          earningsFcfa: earnings,
          pickupName: pickupN,
          pickupAddress: pickupA,
          dropoffName: dropoffN,
          dropoffAddress: dropoffA,
          itemSummary: itemSum,
        ),
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    if (_acting) return;
    if (widget.kind == DriverJobKind.food) return;
    setState(() => _acting = true);
    try {
      if (widget.kind == DriverJobKind.gas) {
        await ApiClient.driverSetGasStatus(widget.id, status);
      } else if (widget.kind == DriverJobKind.parcel) {
        await ApiClient.driverSetParcelStatus(widget.id, status);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await _refreshRoute();
      if (!mounted) return;
      if (status == 'delivered_paid' || status == 'empty_returned') {
        _navigateToSuccessScreen();
      } else {
        AppToast.showSuccess(context, 'Statut mis à jour.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _chooseDepot() async {
    if (_acting) return;
    if (widget.kind != DriverJobKind.gas) return;
    final gas = _gas;
    if (gas == null) return;

    setState(() => _acting = true);
    try {
      final depots = await ApiClient.getDeliveryPoints(type: 'gas_depot');
      if (!mounted) return;
      setState(() => _acting = false);

      final selected = await showModalBottomSheet<DeliveryPointDto>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(ctx).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44, height: 5,
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store_mall_directory_outlined, color: Color(0xFFB45309), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Choisir un dépôt',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AdiakeColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (depots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "Aucun dépôt gaz actif. Ajoute des points type 'gas_depot' dans le back-office.",
                      style: TextStyle(color: AdiakeColors.onSurfaceVariant),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: depots.length,
                      separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF2F2F2)),
                      itemBuilder: (_, i) {
                        final d = depots[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(d),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on, color: Color(0xFFB45309), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
                                      Text(d.city, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AdiakeColors.outline, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );

      if (selected == null) return;
      setState(() => _acting = true);
      await ApiClient.driverSetGasDepot(gas.id, selected.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dépôt sélectionné.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  void dispose() {
    // On stoppe uniquement si on quitte l’écran et que la mission est déjà terminée.
    final status = widget.kind == DriverJobKind.gas
        ? _gas?.status
        : (widget.kind == DriverJobKind.parcel ? _parcel?.status : _food?.status);
    if (status != null && _isFinal(status)) {
      DriverLiveLocationService.instance.stop();
    }
    _routeTimer?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  void _startPositionStream() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          timeLimit: Duration(seconds: 10),
        ),
      ).listen((pos) {
        final me = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() {
          _me = me;
          if (_routeFull.isNotEmpty) _route = _trimRoute(_routeFull, me);
        });
      });
    } catch (_) {
      // ignore
    }
  }

  List<LatLng> _trimRoute(List<LatLng> pts, LatLng me) {
    if (pts.length < 2) return pts;
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = const Distance().as(LengthUnit.Meter, me, pts[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final start = best.clamp(0, pts.length - 1);
    return pts.sublist(start);
  }

  Future<LatLng?> _getMyPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  LatLng? _targetForRoute() {
    if (widget.kind == DriverJobKind.food) {
      final f = _food;
      if (f == null) return null;
      if (f.status == 'accepted') {
        final pending = f.stops.where((s) => s.status != 'picked_up').toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
        if (pending.isNotEmpty) {
          final s = pending.first;
          if (s.restaurantLat != null && s.restaurantLng != null) {
            return LatLng(s.restaurantLat!, s.restaurantLng!);
          }
        }
      }
      if (f.status == 'en_route' && f.deliveryLat != null && f.deliveryLng != null) {
        return LatLng(f.deliveryLat!, f.deliveryLng!);
      }
      return null;
    }

    if (widget.kind == DriverJobKind.gas) {
      final g = _gas;
      if (g == null) return null;
      // accepted + dépôt choisi => aller au dépôt
      if ((g.status == 'accepted' || g.status == 'depot_selected') &&
          g.depotLat != null &&
          g.depotLng != null) {
        return LatLng(g.depotLat!, g.depotLng!);
      }
      // au dépôt / en route => aller au client
      if ((g.status == 'at_depot' || g.status == 'en_route') && g.deliveryLat != null && g.deliveryLng != null) {
        return LatLng(g.deliveryLat!, g.deliveryLng!);
      }
      // livrée & payée => retour au dépôt pour rendre la bouteille vide
      if (g.status == 'delivered_paid' && g.depotLat != null && g.depotLng != null) {
        return LatLng(g.depotLat!, g.depotLng!);
      }
      return null;
    }

    final p = _parcel;
    if (p == null) return null;
    if (p.status == 'accepted' || p.status == 'pending') {
      if (p.pickupLat != null && p.pickupLng != null) return LatLng(p.pickupLat!, p.pickupLng!);
    }
    if (p.status == 'picked_up' || p.status == 'en_route') {
      if (p.dropoffLat != null && p.dropoffLng != null) return LatLng(p.dropoffLat!, p.dropoffLng!);
    }
    return null;
  }

  Future<void> _refreshRoute() async {
    final target = _targetForRoute();
    if (target == null) {
      if (!mounted) return;
      setState(() {
        _lastTarget = null;
        _routeFull = const [];
        _route = const [];
        _routeKm = null;
        _routeMin = null;
      });
      return;
    }

    final me = _me ?? await _getMyPosition();
    if (!mounted) return;
    if (me == null) return;

    try {
      // Recalcul seulement si cible change, sinon on garde la route et on la "réduit" en temps réel.
      if (_lastTarget != null &&
          (const Distance().as(LengthUnit.Meter, _lastTarget!, target) < 5) &&
          _routeFull.isNotEmpty) {
        setState(() {
          _me = me;
          _route = _trimRoute(_routeFull, me);
        });
        return;
      }

      final r = await _osrm.routeDriving(from: me, to: target);
      if (!mounted) return;
      setState(() {
        _me = me;
        _lastTarget = target;
        _routeFull = r.points;
        _route = _trimRoute(r.points, me);
        _routeKm = r.distanceMeters / 1000.0;
        _routeMin = r.durationSeconds / 60.0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pts = <LatLng>[
          ...?_me == null ? null : <LatLng>[_me!],
          target,
          ..._route,
        ];
        if (pts.length < 2) return;
        final bounds = LatLngBounds.fromPoints(pts);
        _map.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(46)),
        );
      });
    } catch (_) {
      // ignore
    }
  }

  Color _targetMarkerColor() {
    if (widget.kind == DriverJobKind.gas &&
        (_gas?.status == 'accepted' || _gas?.status == 'depot_selected' || _gas?.status == 'delivered_paid')) {
      return const Color(0xFFF59E0B);
    }
    if (widget.kind == DriverJobKind.food && _food?.status == 'accepted') {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF16A34A);
  }

  IconData _targetMarkerIcon() {
    if (widget.kind == DriverJobKind.gas &&
        (_gas?.status == 'accepted' || _gas?.status == 'depot_selected' || _gas?.status == 'delivered_paid')) {
      return Icons.propane_tank;
    }
    if (widget.kind == DriverJobKind.food && _food?.status == 'accepted') {
      return Icons.restaurant;
    }
    return Icons.location_on;
  }

  Future<void> _pickupFoodStop(int sequence) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await ApiClient.driverFoodPickupStop(widget.id, sequence);
      if (!mounted) return;
      await _load();
      await _refreshRoute();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ramassage enregistré.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _deliverFood() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await ApiClient.driverFoodDeliver(widget.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livraison confirmée.')));
      _navigateToSuccessScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _updateFoodStopStatus(int sequence, String status) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await ApiClient.driverUpdateFoodStopStatus(widget.id, sequence, status);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statut restaurant mis à jour.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _targetMarkerTitle() {
    if (widget.kind == DriverJobKind.food) {
      if (_food?.status == 'accepted') {
        final pending = _food?.stops.where((s) => s.status != 'picked_up').toList();
        if (pending != null && pending.isNotEmpty) {
          return pending.first.restaurantNameSnapshot ?? 'Restaurant';
        }
      }
      return _food?.clientName ?? 'Client';
    }
    if (widget.kind == DriverJobKind.gas) {
      if ((_gas?.status == 'accepted' || _gas?.status == 'depot_selected') && _gas?.depotName != null) {
        return _gas!.depotName!;
      }
      return _gas?.clientName ?? 'Client';
    }
    if (widget.kind == DriverJobKind.parcel) {
      if (_parcel?.status == 'accepted' || _parcel?.status == 'pending') {
        return 'Ramassage';
      }
      return _parcel?.clientName ?? 'Livraison';
    }
    return 'Destination';
  }

  String _stepSubtitleStatus(String? status) {
    if (status == null) return 'Chargement...';
    switch (status) {
      case 'accepted':
      case 'depot_selected':
        if (widget.kind == DriverJobKind.gas) return 'Vers Dépôt Gaz • Étape 2';
        if (widget.kind == DriverJobKind.food) return 'Vers Pick-Up • Restaurant';
        return 'Vers Point de Ramassage';
      case 'at_depot':
      case 'picked_up':
      case 'en_route':
        return 'Vers Client Final • Drop-Off';
      case 'delivered_paid':
        if (widget.kind == DriverJobKind.gas) return 'Retour bouteille vide au dépôt';
        return 'Mission Terminée';
      default:
        return 'En cours de livraison';
    }
  }

  int _calculateEarnings() {
    if (widget.kind == DriverJobKind.gas) return _gas?.deliveryFeeFcfa ?? 1500;
    if (widget.kind == DriverJobKind.parcel) return _parcel?.deliveryFeeFcfa ?? 2000;
    return (_food?.deliveryFeeFcfa ?? 1000);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.kind == DriverJobKind.gas
        ? _gas?.status
        : (widget.kind == DriverJobKind.parcel ? _parcel?.status : _food?.status);

    final center = _me ?? _targetForRoute() ?? const LatLng(5.2867, -3.3042);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Fullscreen Map Canvas
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 14.6),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'adiake_livraison_express',
              ),
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 5.5,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 70,
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('Vous', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_targetForRoute() != null)
                    Marker(
                      point: _targetForRoute()!,
                      width: 70,
                      height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _targetMarkerColor(),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: Icon(_targetMarkerIcon(), color: Colors.white, size: 22),
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _targetMarkerColor(),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_targetMarkerTitle(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Floating Top Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    // Back Button
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.95),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(true),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mission Status Pill
                    Expanded(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.95),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.kind == DriverJobKind.gas
                                        ? 'MISSION GAZ #${widget.id}'
                                        : (widget.kind == DriverJobKind.parcel ? 'MISSION COLIS #${widget.id}' : 'MISSION FOOD #${widget.id}'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _stepSubtitleStatus(status),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Recenter GPS Button
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.95),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final pos = _me ?? _targetForRoute();
                          if (pos != null) {
                            _map.move(pos, 16.0);
                          }
                        },
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Quick Floating ETA Banner & Navigation shortcut
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.95),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _routeMin != null && _routeKm != null
                              ? '${_routeMin!.toStringAsFixed(0)} min • ${_routeKm!.toStringAsFixed(1)} km'
                              : 'Calcul itinéraire...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF0F172A),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final target = _targetForRoute();
                      if (target != null) {
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_rounded, color: Color(0xFF34D399), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Naviguer',
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
          ),

          // 4. Interactive Bottom Sheet Modal
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.22,
            maxChildSize: 0.88,
            builder: (context, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 30,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 24),
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                        ],
                      )
                    else ...[
                      // Order Title & Guaranteed Earning Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.kind == DriverJobKind.gas
                                        ? 'Commande Gaz #${widget.id}'
                                        : (widget.kind == DriverJobKind.parcel ? 'Colis Express #${widget.id}' : 'Nourriture #${widget.id}'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(status ?? '').toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Commande prête • Suivi GPS sécurisé',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                              ),
                            ],
                          ),

                          // Earning Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'GAIN GARANTI',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                                ),
                                Text(
                                  '${_calculateEarnings()} F',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quick Summary Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.route_rounded, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Itinéraire: ${_routeKm != null ? "${_routeKm!.toStringAsFixed(1)} km total" : "En cours"}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                                const SizedBox(width: 6),
                                Text(
                                  'Paiement Espèces',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timeline Steps Sequence (Step 1 & Step 2)
                      Column(
                        children: [
                          // Step 1: Pick-Up / Collecte
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF97316),
                                ),
                                alignment: Alignment.center,
                                child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RÉCUPÉRATION (PICK-UP)',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFEA580C)),
                                    ),
                                    Text(
                                      widget.kind == DriverJobKind.food
                                          ? (_food?.stops.firstOrNull?.restaurantNameSnapshot ?? 'Restaurant')
                                          : (widget.kind == DriverJobKind.gas ? (_gas?.depotName ?? 'Dépôt Gaz') : (_parcel?.pickupAddress ?? 'Point de Ramassage')),
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      widget.kind == DriverJobKind.food
                                          ? 'Collecte repas en cuisine'
                                          : (widget.kind == DriverJobKind.gas ? 'Échange bouteille de gaz' : 'Expéditeur'),
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.kind == DriverJobKind.food && _food?.stops.firstOrNull != null)
                                    IconButton(
                                      onPressed: () => _shareRestaurantOrderViaWhatsApp(_food!.stops.first),
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF10B981), size: 18),
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xFFECFDF5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  IconButton(
                                    onPressed: () {
                                      if (widget.kind == DriverJobKind.food) {
                                        _callTel(_food?.stops.firstOrNull?.restaurantPhoneSnapshot);
                                      } else if (widget.kind == DriverJobKind.parcel) {
                                        _callTel(_parcel?.clientPhone);
                                      }
                                    },
                                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF0F172A), size: 18),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 15, top: 4, bottom: 4),
                            child: SizedBox(
                              height: 16,
                              child: VerticalDivider(thickness: 2, color: Color(0xFFCBD5E1)),
                            ),
                          ),

                          // Step 2: Drop-Off / Client
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2563EB),
                                ),
                                alignment: Alignment.center,
                                child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CLIENT FINAL (DROP-OFF)',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                                    ),
                                    Text(
                                      widget.kind == DriverJobKind.food
                                          ? (_food?.clientName ?? 'Client')
                                          : (widget.kind == DriverJobKind.gas ? (_gas?.clientName ?? 'Client') : (_parcel?.clientName ?? 'Destinataire')),
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      widget.kind == DriverJobKind.food
                                          ? (_food?.deliveryAddress ?? 'Adiaké')
                                          : (widget.kind == DriverJobKind.gas ? (_gas?.deliveryAddress ?? 'Adiaké') : (_parcel?.dropoffAddress ?? 'Adiaké')),
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final p = widget.kind == DriverJobKind.food
                                      ? _food?.clientPhone
                                      : (widget.kind == DriverJobKind.gas ? _gas?.clientPhone : _parcel?.clientPhone);
                                  _callTel(p);
                                },
                                icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFECFDF5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Primary Action CTA Button
                      if (status == 'pending')
                        SlidableAcceptButton(
                          label: 'Glisser pour accepter la course',
                          onAccept: () async {
                            await _accept();
                          },
                        )
                      else if (widget.kind == DriverJobKind.food && _food != null)
                        _FoodNextActions(
                          detail: _food!,
                          acting: _acting,
                          onPickup: _pickupFoodStop,
                          onDeliver: _deliverFood,
                          onUpdateStatus: _updateFoodStopStatus,
                        )
                      else
                        _NextStatusAction(
                          kind: widget.kind,
                          acting: _acting,
                          status: status ?? '',
                          gasDepotSelected: _gas?.depotPointId != null,
                          onChooseDepot: _chooseDepot,
                          onSet: _setStatus,
                        ),

                      const SizedBox(height: 10),

                      // Secondary Utility Option
                      Center(
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pour annuler ou signaler un incident, contactez l’Assistance Dispatch.')),
                            );
                          },
                          child: Text(
                            'Signaler un problème ou annuler la course',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FoodNextActions extends StatelessWidget {
  const _FoodNextActions({
    required this.detail,
    required this.acting,
    required this.onPickup,
    required this.onDeliver,
    required this.onUpdateStatus,
  });

  final FoodOrderDetailDto detail;
  final bool acting;
  final void Function(int sequence) onPickup;
  final VoidCallback onDeliver;
  final void Function(int sequence, String status) onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final st = detail.status;
    if (st == 'en_route') {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: acting ? null : onDeliver,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          iconAlignment: IconAlignment.end,
          label: Text(
            'Confirmer la livraison & encaisser (COD)',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
        ),
      );
    }
    if (st != 'accepted') {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'Mission terminée ou annulée.',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
      );
    }
    final pending = detail.stops.where((s) => s.status != 'picked_up').toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }
    final next = pending.first;
    final restName = next.restaurantNameSnapshot ?? 'Restaurant';

    String ctaText = 'Je suis arrivé au restaurant';
    if (next.status == 'preparing') {
      ctaText = 'Commande en préparation...';
    } else if (next.status == 'ready') {
      ctaText = 'Récupérer la commande (Prête !)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next.status == 'accepted' || next.status == 'pending' || next.status == '')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: acting ? null : () => onUpdateStatus(next.sequence, 'preparing'),
              icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
              label: Text('Signaler : En cuisine chez $restName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEA580C),
                side: const BorderSide(color: Color(0xFFEA580C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else if (next.status == 'preparing')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: acting ? null : () => onUpdateStatus(next.sequence, 'ready'),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text('Signaler : Commande prête chez $restName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: acting ? null : () => onPickup(next.sequence),
            style: ElevatedButton.styleFrom(
              backgroundColor: next.status == 'ready' ? const Color(0xFF10B981) : const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ctaText,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NextStatusAction extends StatelessWidget {
  const _NextStatusAction({
    required this.kind,
    required this.acting,
    required this.status,
    required this.gasDepotSelected,
    required this.onChooseDepot,
    required this.onSet,
  });

  final DriverJobKind kind;
  final bool acting;
  final String status;
  final bool gasDepotSelected;
  final VoidCallback onChooseDepot;
  final ValueChanged<String> onSet;

  @override
  Widget build(BuildContext context) {
    (String, String)? next;

    if (kind == DriverJobKind.food) {
      next = null;
    } else if (kind == DriverJobKind.gas) {
      if (status == 'accepted') {
        if (!gasDepotSelected) {
          return SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: acting ? null : onChooseDepot,
              icon: const Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 20),
              iconAlignment: IconAlignment.end,
              label: Text(
                'Choisir le dépôt de gaz',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          );
        } else {
          next = ('Je suis arrivé au dépôt', 'at_depot');
        }
      } else if (status == 'depot_selected') {
        next = ('Je suis arrivé au dépôt', 'at_depot');
      } else if (status == 'at_depot') {
        next = ('Bouteille chargée • Partir chez le client', 'en_route');
      } else if (status == 'en_route') {
        next = ('Confirmer la livraison & encaisser (COD)', 'delivered_paid');
      } else if (status == 'delivered_paid') {
        next = ('Rendre la bouteille vide au dépôt', 'empty_returned');
      } else {
        next = null;
      }
    } else {
      if (status == 'accepted') {
        next = ('Colis récupéré chez l’expéditeur', 'picked_up');
      } else if (status == 'picked_up') {
        next = ('En route vers le destinataire', 'en_route');
      } else if (status == 'en_route') {
        next = ('Confirmer la livraison & encaisser (COD)', 'delivered_paid');
      } else {
        next = null;
      }
    }

    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'Mission terminée ou annulée.',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
      );
    }

    final n = next;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: acting ? null : () => onSet(n.$2),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              n.$1,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

