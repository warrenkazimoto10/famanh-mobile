import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../data/api_client.dart';
import '../../data/osrm_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/glass_card.dart';

enum _ActiveKind { gas, parcel, food }

class ClientTrackingScreen extends StatefulWidget {
  const ClientTrackingScreen({super.key});

  @override
  State<ClientTrackingScreen> createState() => _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends State<ClientTrackingScreen> {
  bool _loading = true;
  String? _error;

  _ActiveKind? _kind;
  int? _id;
  GasOrderDetailDto? _gas;
  ParcelOrderDetailDto? _parcel;
  FoodOrderDetailDto? _food;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 7), (_) => _refreshLive());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _poll = null;
    super.dispose();
  }

  bool _isFinalStatus(String s) => s == 'delivered_paid' || s == 'empty_returned';
  bool _isFinalFood(String s) => s == 'delivered_paid' || s == 'cancelled';
  bool _isInProgress(String s) =>
      s == 'pending' ||
      s == 'accepted' ||
      s == 'depot_selected' ||
      s == 'at_depot' ||
      s == 'picked_up' ||
      s == 'en_route' ||
      s == 'stop_picked_up' ||
      s == 'stop_preparing' ||
      s == 'stop_ready' ||
      s == 'preparing' ||
      s == 'ready';

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'depot_selected':
        return 'Dépôt sélectionné';
      case 'at_depot':
        return 'Au dépôt';
      case 'picked_up':
        return 'Récupéré';
      case 'stop_picked_up':
        return 'Ramassage au restaurant';
      case 'stop_preparing':
      case 'preparing':
        return 'En préparation (Cuisine)';
      case 'stop_ready':
      case 'ready':
        return 'Commande prête !';
      case 'en_route':
        return 'En route';
      case 'delivered_paid':
        return 'Livrée & payée';
      case 'empty_returned':
        return 'Vide retourné';
      case 'cancelled':
        return 'Annulée';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _formatDateTimeFr(DateTime dt) {
    final d = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    if (day == today) return "Aujourd’hui $hh:$mm";
    if (day == today.subtract(const Duration(days: 1))) return "Hier $hh:$mm";

    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _kind = null;
      _id = null;
      _gas = null;
      _parcel = null;
      _food = null;
    });

    try {
      final gas = await ApiClient.getGasOrders();
      final parcel = await ApiClient.getParcelOrders();
      final food = await ApiClient.getFoodOrders();

      final activeGas = gas.where((o) => !_isFinalStatus(o.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final activeParcel = parcel.where((o) => !_isFinalStatus(o.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final activeFood = food.where((o) => !_isFinalFood(o.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final g = activeGas.isNotEmpty ? activeGas.first : null;
      final p = activeParcel.isNotEmpty ? activeParcel.first : null;
      final f = activeFood.isNotEmpty ? activeFood.first : null;

      if (g == null && p == null && f == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final cands = <({_ActiveKind kind, DateTime at, int id})>[
        if (g != null) (kind: _ActiveKind.gas, at: g.createdAt, id: g.id),
        if (p != null) (kind: _ActiveKind.parcel, at: p.createdAt, id: p.id),
        if (f != null) (kind: _ActiveKind.food, at: f.createdAt, id: f.id),
      ]..sort((a, b) => b.at.compareTo(a.at));

      final top = cands.first;

      if (top.kind == _ActiveKind.gas) {
        final detail = await ApiClient.getGasOrder(top.id);
        if (!mounted) return;
        setState(() {
          _kind = _ActiveKind.gas;
          _id = top.id;
          _gas = detail;
          _parcel = null;
          _food = null;
          _loading = false;
        });
      } else if (top.kind == _ActiveKind.parcel) {
        final detail = await ApiClient.getParcelOrder(top.id);
        if (!mounted) return;
        setState(() {
          _kind = _ActiveKind.parcel;
          _id = top.id;
          _parcel = detail;
          _gas = null;
          _food = null;
          _loading = false;
        });
      } else {
        final detail = await ApiClient.getFoodOrder(top.id);
        if (!mounted) return;
        setState(() {
          _kind = _ActiveKind.food;
          _id = top.id;
          _food = detail;
          _gas = null;
          _parcel = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshLive() async {
    if (!mounted) return;
    if (_loading) return;
    if (_kind == null || _id == null) return;

    final status =
        _kind == _ActiveKind.gas ? _gas?.status : (_kind == _ActiveKind.parcel ? _parcel?.status : _food?.status);
    if (status == null || !_isInProgress(status)) return;

    try {
      final oldStatus = _kind == _ActiveKind.gas ? _gas?.status : (_kind == _ActiveKind.parcel ? _parcel?.status : _food?.status);
      
      if (_kind == _ActiveKind.gas) {
        final detail = await ApiClient.getGasOrder(_id!);
        if (!mounted) return;
        _notifyIfChanged(oldStatus, detail.status);
        setState(() => _gas = detail);
      } else if (_kind == _ActiveKind.parcel) {
        final detail = await ApiClient.getParcelOrder(_id!);
        if (!mounted) return;
        _notifyIfChanged(oldStatus, detail.status);
        setState(() => _parcel = detail);
      } else {
        final detail = await ApiClient.getFoodOrder(_id!);
        if (!mounted) return;
        _notifyIfChanged(oldStatus, detail.status);
        setState(() => _food = detail);
      }
    } catch (_) {
    }
  }

  void _notifyIfChanged(String? old, String? current) {
    if (old != null && current != null && old != current) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Statut mis à jour : ${_statusLabel(current)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          backgroundColor: AdiakeColors.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Suivi'.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdiakeColors.primaryContainer,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            actions: [
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                color: AdiakeColors.primaryContainer,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(
                [
                  Text(
                    'Commande active',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AdiakeColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Suivez votre livraison en cours en temps réel.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AdiakeColors.onSurfaceVariant,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AdiakeColors.error,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(onPressed: _load, child: const Text('Réessayer')),
                        ],
                      ),
                    )
                  else if (_kind == null)
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Aucune livraison ou trajet en cours.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AdiakeColors.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    )
                  else ...[
                    _ActiveHeader(
                      kind: _kind!,
                      id: _id!,
                      status: _kind == _ActiveKind.gas
                          ? _gas!.status
                          : (_kind == _ActiveKind.parcel ? _parcel!.status : _food!.status),
                      statusLabel: _statusLabel(_kind == _ActiveKind.gas
                          ? _gas!.status
                          : (_kind == _ActiveKind.parcel ? _parcel!.status : _food!.status)),
                      onMap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClientOrderMapScreen(
                              gas: _gas,
                              parcel: _parcel,
                              food: _food,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: _Timeline(
                        events: (_gas?.events ?? _parcel?.events ?? _food?.events ?? const <StatusEventDto>[])
                          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
                        statusLabel: _statusLabel,
                        formatDate: _formatDateTimeFr,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({
    required this.kind,
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.onMap,
  });

  final _ActiveKind kind;
  final int id;
  final String status;
  final String statusLabel;
  final VoidCallback onMap;

  Color _chipColor() {
    switch (status) {
      case 'delivered_paid':
        return const Color(0xFFB9EEAB);
      case 'accepted':
        return const Color(0xFFFFD9D6);
      case 'en_route':
      case 'stop_picked_up':
        return const Color(0xFFFFDEA5);
      case 'preparing':
      case 'stop_preparing':
        return const Color(0xFFE4EBFF); // Un bleu très clair
      case 'ready':
      case 'stop_ready':
        return const Color(0xFFC9FAD5); // Un vert très clair
      default:
        return const Color(0xFFEDEEEF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _chipColor().withValues(alpha: 0.35),
            ),
            child: Icon(
              kind == _ActiveKind.gas
                  ? Icons.propane_tank
                  : (kind == _ActiveKind.parcel ? Icons.inventory_2 : Icons.restaurant),
              color: AdiakeColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${kind == _ActiveKind.gas ? 'Gaz' : 'Colis'} #$id',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AdiakeColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _chipColor(), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AdiakeColors.primary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onMap,
            icon: const Icon(Icons.map),
            label: const Text('Voir sur la carte'),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.events,
    required this.statusLabel,
    required this.formatDate,
  });

  final List<StatusEventDto> events;
  final String Function(String) statusLabel;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        "Aucun événement de statut.",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AdiakeColors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < events.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == events.length - 1 ? AdiakeColors.primaryContainer : AdiakeColors.outlineVariant,
                    ),
                  ),
                  if (i != events.length - 1)
                    Container(
                      width: 2,
                      height: 26,
                      color: AdiakeColors.outlineVariant.withValues(alpha: 0.6),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel(events[i].status).toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AdiakeColors.primary,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(events[i].createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdiakeColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ClientOrderMapScreen extends StatefulWidget {
  const ClientOrderMapScreen({
    super.key,
    this.gas,
    this.parcel,
    this.food,
    this.orderKind,
    this.orderId,
  });

  final GasOrderDetailDto? gas;
  final ParcelOrderDetailDto? parcel;
  final FoodOrderDetailDto? food;
  final String? orderKind; // 'gas', 'parcel', 'food'
  final int? orderId;

  @override
  State<ClientOrderMapScreen> createState() => _ClientOrderMapScreenState();
}

class _ClientOrderMapScreenState extends State<ClientOrderMapScreen> {
  static const LatLng _adiake = LatLng(5.2867, -3.3042);
  final MapController _map = MapController();
  bool _fittedOnce = false;

  LatLng? _driver;
  LatLng? _prevDriver;
  LatLng? _depot;
  String? _driverName;
  String? _driverPhone;
  DateTime? _driverAt;
  Timer? _timer;
  Timer? _routeTimer;
  final _osrm = OsrmClient();
  LatLng? _lastRouteTarget;
  List<LatLng> _routeFull = const [];
  List<LatLng> _route = const [];
  int _routeGen = 0;

  GasOrderDetailDto? _gas;
  ParcelOrderDetailDto? _parcel;
  FoodOrderDetailDto? _food;

  bool get _isGas => _gas != null || widget.orderKind == 'gas';
  bool get _isFood => _food != null || widget.orderKind == 'food';
  int get _orderId => _gas?.id ?? _parcel?.id ?? _food?.id ?? widget.orderId ?? 0;

  String get _status => _gas?.status ?? _parcel?.status ?? _food?.status ?? '—';

  List<StatusEventDto> get _events {
    final list = _gas?.events ?? _parcel?.events ?? _food?.events ?? const <StatusEventDto>[];
    final copy = [...list]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return copy;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'depot_selected':
        return 'Dépôt sélectionné';
      case 'at_depot':
        return 'Au dépôt';
      case 'picked_up':
        return 'Récupéré';
      case 'stop_picked_up':
        return 'Ramassage au restaurant';
      case 'en_route':
        return 'En route';
      case 'delivered_paid':
        return 'Livrée & payée';
      case 'empty_returned':
        return 'Vide retourné';
      case 'cancelled':
        return 'Annulée';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _formatDateTimeFr(DateTime dt) {
    final d = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (day == today) return "Aujourd’hui $hh:$mm";
    if (day == today.subtract(const Duration(days: 1))) return "Hier $hh:$mm";
    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  bool _isRouteStatus(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
      case 'depot_selected':
      case 'at_depot':
      case 'picked_up':
      case 'en_route':
      case 'stop_picked_up':
        return true;
      default:
        return false;
    }
  }

  FoodOrderStopDto? _nextFoodStop() {
    final f = _food;
    if (f == null) return null;
    final pending = f.stops.where((s) => s.status != 'picked_up').toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return pending.isEmpty ? null : pending.first;
  }

  LatLng? _routeTarget() {
    final st = _status.toLowerCase();
    final gas = _gas;
    final parcel = _parcel;
    final food = _food;
    if (food != null) {
      if (st == 'accepted' || st == 'stop_picked_up') {
        final nx = _nextFoodStop();
        if (nx?.restaurantLat != null && nx?.restaurantLng != null) {
          return LatLng(nx!.restaurantLat!, nx.restaurantLng!);
        }
      }
      if (st == 'en_route' && food.deliveryLat != null && food.deliveryLng != null) {
        return LatLng(food.deliveryLat!, food.deliveryLng!);
      }
      return null;
    }
    if (gas != null) {
      final g = gas;
      final depotPt = _depot;
      if ((st == 'accepted' || st == 'depot_selected') && depotPt != null) return depotPt;
      if ((st == 'at_depot' || st == 'picked_up' || st == 'en_route') &&
          g.deliveryLat != null &&
          g.deliveryLng != null) {
        return LatLng(g.deliveryLat!, g.deliveryLng!);
      }
      return null;
    }
    if (parcel != null) {
      final p = parcel;
      if (st == 'pending' || st == 'accepted') {
        if (p.pickupLat != null && p.pickupLng != null) return LatLng(p.pickupLat!, p.pickupLng!);
      }
      if (st == 'picked_up' || st == 'en_route') {
        if (p.dropoffLat != null && p.dropoffLng != null) return LatLng(p.dropoffLat!, p.dropoffLng!);
      }
    }
    return null;
  }

  bool _sameRouteTarget(LatLng? a, LatLng? b) {
    if (a == null || b == null) return false;
    return const Distance().as(LengthUnit.Meter, a, b) < 8;
  }

  List<LatLng> _trimRoute(List<LatLng> pts, LatLng driver) {
    if (pts.length < 2) return pts;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = const Distance().as(LengthUnit.Meter, driver, pts[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final start = best.clamp(0, pts.length - 1);
    return pts.sublist(start);
  }

  void _clearRoute() {
    _lastRouteTarget = null;
    _routeFull = const [];
    _route = const [];
  }

  Future<void> _refreshRoute() async {
    final gen = ++_routeGen;
    if (!_isRouteStatus(_status)) {
      if (!mounted || gen != _routeGen) return;
      setState(_clearRoute);
      return;
    }

    final target = _routeTarget();
    final from = _driver;
    if (target == null || from == null) {
      if (!mounted || gen != _routeGen) return;
      setState(_clearRoute);
      return;
    }

    if (_lastRouteTarget != null &&
        _sameRouteTarget(_lastRouteTarget, target) &&
        _routeFull.isNotEmpty) {
      if (!mounted || gen != _routeGen) return;
      setState(() => _route = _trimRoute(_routeFull, from));
      return;
    }

    try {
      final r = await _osrm.routeDriving(from: from, to: target);
      if (!mounted || gen != _routeGen) return;
      setState(() {
        _lastRouteTarget = target;
        _routeFull = r.points;
        _route = _trimRoute(r.points, from);
      });
    } catch (_) {
      if (!mounted || gen != _routeGen) return;
      setState(() {
        _lastRouteTarget = target;
        _routeFull = [from, target];
        _route = [from, target];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _gas = widget.gas;
    _parcel = widget.parcel;
    _food = widget.food;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    _routeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshRoute());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _routeTimer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_orderId <= 0) return;
    try {
      // Rafraîchir l'ordre (statut/timeline) pour retirer la route dès qu'on est final.
      if (_isGas) {
        final d = await ApiClient.getGasOrder(_orderId);
        if (!mounted) return;
        setState(() => _gas = d);
      } else if (_isFood) {
        final d = await ApiClient.getFoodOrder(_orderId);
        if (!mounted) return;
        setState(() => _food = d);
      } else {
        final d = await ApiClient.getParcelOrder(_orderId);
        if (!mounted) return;
        setState(() => _parcel = d);
      }

      if (_isFood) {
        final t = await ApiClient.getTrackingFood(_orderId);
        final loc = t.driverLocation;
        final fo = t.order;
        if (!mounted) return;
        setState(() {
          _food = fo;
          _driverName = fo.driverName;
          _driverPhone = fo.driverPhone;
          _driverAt = loc?.recordedAt;
          _prevDriver = _driver;
          _driver = (loc == null) ? null : LatLng(loc.lat, loc.lng);
          _depot = null;
        });
      } else {
        final t = _isGas ? await ApiClient.getTrackingGas(_orderId) : await ApiClient.getTrackingParcel(_orderId);
        final loc = t.driverLocation;
        if (!mounted) return;
        setState(() {
          _driverName = t.driverName;
          _driverPhone = t.driverPhone;
          _driverAt = loc?.recordedAt;
          _prevDriver = _driver;
          _driver = (loc == null) ? null : LatLng(loc.lat, loc.lng);
          _depot = (t.depotLat != null && t.depotLng != null) ? LatLng(t.depotLat!, t.depotLng!) : null;
        });
      }
      await _refreshRoute();
    } catch (_) {
      // Silence: si offline/back down, on garde la dernière position connue.
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = _adiake;
    final markers = <Marker>[];

    final gas = _gas;
    final parcel = _parcel;
    final food = _food;

    if (gas != null && gas.deliveryLat != null && gas.deliveryLng != null) {
      center = LatLng(gas.deliveryLat!, gas.deliveryLng!);
      markers.add(
        Marker(
          point: center,
          width: 60,
          height: 60,
          child: const _MapPin(icon: Icons.location_on, color: Color(0xFF16A34A)), // livraison vert
        ),
      );
    } else if (parcel != null && parcel.dropoffLat != null && parcel.dropoffLng != null) {
      final drop = LatLng(parcel.dropoffLat!, parcel.dropoffLng!);
      center = drop;
      markers.add(
        Marker(
          point: drop,
          width: 60,
          height: 60,
          child: const _MapPin(icon: Icons.location_on, color: Color(0xFF16A34A)), // livraison vert
        ),
      );
      if (parcel.pickupLat != null && parcel.pickupLng != null) {
        final pick = LatLng(parcel.pickupLat!, parcel.pickupLng!);
        markers.add(
          Marker(
            point: pick,
            width: 60,
            height: 60,
            child: const _MapPin(icon: Icons.trip_origin, color: Color(0xFFF59E0B)), // ramassage orange
          ),
        );
      }
    } else if (food != null && food.deliveryLat != null && food.deliveryLng != null) {
      center = LatLng(food.deliveryLat!, food.deliveryLng!);
      markers.add(
        Marker(
          point: center,
          width: 60,
          height: 60,
          child: const _MapPin(icon: Icons.home_work_outlined, color: Color(0xFF16A34A)),
        ),
      );
      for (final s in food.stops) {
        if (s.restaurantLat != null && s.restaurantLng != null) {
          markers.add(
            Marker(
              point: LatLng(s.restaurantLat!, s.restaurantLng!),
              width: 56,
              height: 56,
              child: const _MapPin(icon: Icons.restaurant, color: Color(0xFFEA580C)),
            ),
          );
        }
      }
    }

    if (_driver != null) {
      center = _driver!;
      markers.add(
        Marker(
          point: _driver!,
          width: 80,
          height: 80,
          child: TweenAnimationBuilder<LatLng>(
            tween: LatLngTween(begin: _prevDriver ?? _driver!, end: _driver!),
            duration: const Duration(seconds: 4),
            builder: (context, LatLng pos, child) {
              return Marker(
                point: pos,
                width: 80,
                height: 80,
                child: const _MapPin(icon: Icons.two_wheeler, color: Color(0xFF0052FF)),
              ).child;
            },
          ),
        ),
      );
    }

    if (_depot != null) {
      markers.add(
        Marker(
          point: _depot!,
          width: 70,
          height: 70,
          child: const _MapPin(icon: Icons.propane_tank, color: Color(0xFFF59E0B)), // depot orange gaz
        ),
      );
    }

    // Fit la caméra pour montrer tous les points.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (markers.length < 2) return;
      // Premier fit agressif, puis uniquement quand le livreur bouge.
      if (!_fittedOnce || _driver != null) {
        final pts = markers.map((m) => m.point).toList();
        final bounds = LatLngBounds.fromPoints(pts);
        _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(46)));
        _fittedOnce = true;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Map View
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'adiake_livraison_express',
              ),
              if (_route.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 8,
                      color: const Color(0xFF0052FF).withValues(alpha: 0.25),
                      strokeCap: StrokeCap.round,
                    ),
                    Polyline(
                      points: _route,
                      strokeWidth: 4.5,
                      color: const Color(0xFF0052FF),
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              ],
              MarkerLayer(markers: markers),
            ],
          ),

          // Floating Top Header & Map Focus Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Material(
                        elevation: 6,
                        shadowColor: Colors.black26,
                        shape: const CircleBorder(),
                        color: Colors.white,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const _LivePulsingDot(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_isGas ? 'Gaz' : (_isFood ? 'Nourriture' : 'Colis')} #$_orderId',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _statusLabel(_status),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0052FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        elevation: 6,
                        shadowColor: Colors.black26,
                        shape: const CircleBorder(),
                        color: Colors.white,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            if (markers.isNotEmpty) {
                              final pts = markers.map((m) => m.point).toList();
                              final bounds = LatLngBounds.fromPoints(pts);
                              _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
                            }
                          },
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.my_location_rounded, color: Color(0xFF0052FF), size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3 Map Focus Buttons Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Focus 1: Livreur
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_driver != null) {
                                _map.move(_driver!, 15.8);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Livreur non encore géolocalisé.')),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF0052FF)),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Livreur',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),

                        // Focus 2: Ramassage / Restaurant / Dépôt
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_isFood) {
                                final stop = _food?.stops.firstOrNull;
                                if (stop?.restaurantLat != null && stop?.restaurantLng != null) {
                                  _map.move(LatLng(stop!.restaurantLat!, stop.restaurantLng!), 15.8);
                                }
                              } else if (_isGas) {
                                if (_depot != null) {
                                  _map.move(_depot!, 15.8);
                                }
                              } else if (_parcel != null) {
                                if (_parcel!.pickupLat != null && _parcel!.pickupLng != null) {
                                  _map.move(LatLng(_parcel!.pickupLat!, _parcel!.pickupLng!), 15.8);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isGas ? Icons.propane_tank_rounded : (_isFood ? Icons.restaurant_rounded : Icons.inventory_2_rounded),
                                    size: 16,
                                    color: const Color(0xFFEA580C),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _isGas ? 'Dépôt' : (_isFood ? 'Restaurant' : 'Ramassage'),
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),

                        // Focus 3: Client / Destination
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_isFood && _food?.deliveryLat != null && _food?.deliveryLng != null) {
                                _map.move(LatLng(_food!.deliveryLat!, _food!.deliveryLng!), 15.8);
                              } else if (_isGas && _gas?.deliveryLat != null && _gas?.deliveryLng != null) {
                                _map.move(LatLng(_gas!.deliveryLat!, _gas!.deliveryLng!), 15.8);
                              } else if (_parcel?.dropoffLat != null && _parcel?.dropoffLng != null) {
                                _map.move(LatLng(_parcel!.dropoffLat!, _parcel!.dropoffLng!), 15.8);
                              }
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_pin_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _parcel != null ? 'Destinataire' : 'Client',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
          ),

          // High-End Draggable Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.26,
            maxChildSize: 0.85,
            builder: (context, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Driver Profile Card
                    _DriverHeroCard(
                      driverName: _driverName,
                      driverPhone: _driverPhone,
                      driverAt: _driverAt,
                      status: _status,
                    ),
                    const SizedBox(height: 20),

                    // Module-Specific 4-Step Progress Tracker
                    _ClientOrderProgressTimeline(
                      status: _status,
                      orderKind: _isGas ? 'gas' : (_isFood ? 'food' : 'parcel'),
                    ),
                    const SizedBox(height: 20),

                    // Order Details
                    _OrderDetailsSummaryCard(
                      gas: widget.gas ?? _gas,
                      parcel: widget.parcel ?? _parcel,
                      food: widget.food ?? _food,
                      orderId: _orderId,
                    ),
                    const SizedBox(height: 16),

                    // Detailed Events Timeline History
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: _Timeline(
                        events: _events,
                        statusLabel: _statusLabel,
                        formatDate: _formatDateTimeFr,
                      ),
                    ),
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

class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: _anim.value),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DriverHeroCard extends StatelessWidget {
  const _DriverHeroCard({
    required this.driverName,
    required this.driverPhone,
    required this.driverAt,
    required this.status,
  });

  final String? driverName;
  final String? driverPhone;
  final DateTime? driverAt;
  final String status;

  @override
  Widget build(BuildContext context) {
    final hasDriver = driverName != null && driverName!.trim().isNotEmpty;
    final name = hasDriver ? driverName!.trim() : 'Recherche du livreur...';
    final phone = driverPhone?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasDriver ? const Color(0xFF0052FF) : Colors.grey.shade300,
                  boxShadow: [
                    BoxShadow(
                      color: (hasDriver ? const Color(0xFF0052FF) : Colors.black12).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    hasDriver ? Icons.two_wheeler_rounded : Icons.person_search_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDriver
                          ? 'Livreur Certifié Express Famanh'
                          : 'Nous affectons le livreur le plus proche',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (driverAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Position GPS actualisée à ${driverAt!.toLocal().hour.toString().padLeft(2, '0')}:${driverAt!.toLocal().minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasDriver && phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: Text('Appeler ($phone)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF0052FF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientOrderProgressTimeline extends StatelessWidget {
  const _ClientOrderProgressTimeline({
    required this.status,
    required this.orderKind,
  });

  final String status;
  final String orderKind; // 'food', 'gas', 'parcel'

  int _currentStep() {
    final s = status.toLowerCase();
    if (s == 'delivered_paid' || s == 'empty_returned') return 4;
    if (s == 'en_route') return 3;
    if (s == 'stop_picked_up' || s == 'stop_preparing' || s == 'preparing' || s == 'stop_ready' || s == 'ready' || s == 'at_depot' || s == 'picked_up') return 2;
    return 1; // pending or accepted
  }

  List<(String, IconData)> _getSteps() {
    if (orderKind == 'gas') {
      return const [
        ('Confirmée', Icons.assignment_turned_in_rounded),
        ('Au dépôt', Icons.propane_tank_rounded),
        ('En route', Icons.two_wheeler_rounded),
        ('Livrée', Icons.home_rounded),
      ];
    } else if (orderKind == 'parcel') {
      return const [
        ('Confirmée', Icons.assignment_turned_in_rounded),
        ('Ramassage', Icons.inventory_2_rounded),
        ('En route', Icons.two_wheeler_rounded),
        ('Livré', Icons.location_on_rounded),
      ];
    }
    // Food default
    return const [
      ('Confirmée', Icons.assignment_turned_in_rounded),
      ('En cuisine', Icons.restaurant_rounded),
      ('En route', Icons.two_wheeler_rounded),
      ('Livrée', Icons.home_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep();
    final steps = _getSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVANCEMENT DE LA LIVRAISON',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final itemWidth = width / steps.length;

            return SizedBox(
              height: 68,
              child: Stack(
                children: [
                  // Background line
                  Positioned(
                    left: itemWidth / 2,
                    right: itemWidth / 2,
                    top: 17,
                    child: Container(
                      height: 3,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),

                  // Active progress line
                  Positioned(
                    left: itemWidth / 2,
                    right: itemWidth / 2,
                    top: 17,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 3,
                        width: ((width - itemWidth) / 3) * (current - 1).clamp(0, 3),
                        color: const Color(0xFF0052FF),
                      ),
                    ),
                  ),

                  // 4 Step Nodes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(steps.length, (idx) {
                      final stepNum = idx + 1;
                      final isDone = stepNum <= current;
                      final isCurrent = stepNum == current;
                      final stepData = steps[idx];

                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? (isCurrent ? const Color(0xFF0052FF) : const Color(0xFF10B981))
                                    : const Color(0xFFF1F5F9),
                                border: Border.all(
                                  color: isDone ? Colors.transparent : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                stepData.$2,
                                size: 16,
                                color: isDone ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stepData.$1,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OrderDetailsSummaryCard extends StatelessWidget {
  const _OrderDetailsSummaryCard({
    this.gas,
    this.parcel,
    this.food,
    required this.orderId,
  });

  final GasOrderDetailDto? gas;
  final ParcelOrderDetailDto? parcel;
  final FoodOrderDetailDto? food;
  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DÉTAILS COMMANDE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Paiement Espèces',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (food != null) ...[
            for (final it in food!.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• ${it.dishName ?? 'Plat #${it.dishId}'} × ${it.qty}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      '${it.unitPriceFcfa * it.qty} FCFA',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total à régler à la livraison', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                Text(
                  '${food!.subtotalFcfa + food!.deliveryFeeFcfa} FCFA',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0052FF)),
                ),
              ],
            ),
          ] else if (gas != null) ...[
            Text(
              '${gas!.brand ?? 'Gaz'} ${gas!.size ?? ''} • Qté ${gas!.qty}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Livraison à domicile Adiaké',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                Text(
                  '${gas!.priceFcfa} FCFA',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0052FF)),
                ),
              ],
            ),
          ] else if (parcel != null) ...[
            Text(
              'Colis : ${parcel!.packageLabel ?? 'Pli express'}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Expédition locale Adiaké',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Frais de Livraison', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                Text(
                  '${parcel!.deliveryFeeFcfa} FCFA',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0052FF)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, this.color = const Color(0xFF0052FF)});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}



