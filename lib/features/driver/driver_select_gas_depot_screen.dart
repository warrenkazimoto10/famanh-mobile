import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/osrm_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/skeleton_card.dart';

class DriverSelectGasDepotScreen extends StatefulWidget {
  const DriverSelectGasDepotScreen({
    super.key,
    required this.orderId,
    required this.deliveryLat,
    required this.deliveryLng,
    this.city,
    this.initialDepotPointId,
  });

  final int orderId;
  final double deliveryLat;
  final double deliveryLng;
  final String? city;
  final int? initialDepotPointId;

  @override
  State<DriverSelectGasDepotScreen> createState() => _DriverSelectGasDepotScreenState();
}

class _DriverSelectGasDepotScreenState extends State<DriverSelectGasDepotScreen> {
  static const Distance _distance = Distance();
  final _mapController = MapController();
  final _osrm = OsrmClient();

  bool _loading = true;
  String? _error;
  List<DeliveryPointDto> _depots = const [];
  DeliveryPointDto? _selected;
  LatLng? _me;
  List<LatLng> _route = const [];
  double? _routeKm;
  double? _routeMin;

  LatLng get _delivery => LatLng(widget.deliveryLat, widget.deliveryLng);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _getMyPosition();
      final depots = await ApiClient.getDeliveryPoints(city: widget.city, type: 'gas_depot');
      depots.sort((a, b) {
        final base = me ?? _delivery;
        final da = _distance.as(LengthUnit.Meter, base, LatLng(a.lat, a.lng));
        final db = _distance.as(LengthUnit.Meter, base, LatLng(b.lat, b.lng));
        return da.compareTo(db);
      });

      DeliveryPointDto? selected;
      if (widget.initialDepotPointId != null) {
        selected = depots.where((d) => d.id == widget.initialDepotPointId).cast<DeliveryPointDto?>().firstOrNull;
      }
      selected ??= depots.isEmpty ? null : depots.first;

      if (!mounted) return;
      setState(() {
        _depots = depots;
        _selected = selected;
        _me = me;
        _route = const [];
        _routeKm = null;
        _routeMin = null;
        _loading = false;
      });

      await _refreshRoute();

      // Fit bounds around delivery + nearest depots
      final points = <LatLng>[
        _delivery,
        ...?((me == null) ? null : [me]),
        for (final d in depots.take(8)) LatLng(d.lat, d.lng),
      ];
      if (points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(42)),
        );
      } else {
        _mapController.move(_delivery, 14.5);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<LatLng?> _getMyPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _refreshRoute() async {
    final me = _me;
    final sel = _selected;
    if (me == null || sel == null) return;

    try {
      final r = await _osrm.routeDriving(from: me, to: LatLng(sel.lat, sel.lng));
      if (!mounted) return;
      setState(() {
        _route = r.points;
        _routeKm = r.distanceMeters / 1000.0;
        _routeMin = r.durationSeconds / 60.0;
      });

      if (_route.length >= 2) {
        final bounds = LatLngBounds.fromPoints(_route);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(46)));
      }
    } catch (_) {
      // fallback: ligne droite si OSRM indisponible
      if (!mounted) return;
      setState(() {
        _route = [me, LatLng(sel.lat, sel.lng)];
        _routeKm = _distance.as(LengthUnit.Meter, me, LatLng(sel.lat, sel.lng)) / 1000.0;
        _routeMin = null;
      });
    }
  }

  Future<void> _confirmDepot() async {
    final depot = _selected;
    if (depot == null) return;
    try {
      await ApiClient.driverSetGasDepot(widget.orderId, depot.id);
      if (!mounted) return;
      Navigator.of(context).pop(depot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openNavigation(DeliveryPointDto depot) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${depot.lat},${depot.lng}&travelmode=driving',
    );
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d’ouvrir Google Maps.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _delivery,
                initialZoom: 14.5,
                onTap: (tapPosition, latLng) {},
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'adiake_livraison_express',
                ),
                if (_route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        strokeWidth: 5,
                        color: const Color(0xFF0052FF).withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_me != null)
                      Marker(
                        point: _me!,
                        width: 66,
                        height: 66,
                        child: const _DriverPin(),
                      ),
                    Marker(
                      point: _delivery,
                      width: 60,
                      height: 60,
                      child: const _DeliveryPin(),
                    ),
                    for (final d in _depots)
                      Marker(
                        point: LatLng(d.lat, d.lng),
                        width: 66,
                        height: 66,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selected = d);
                            _mapController.move(LatLng(d.lat, d.lng), math.max(15, _mapController.camera.zoom));
                            _refreshRoute();
                          },
                          child: _DepotPin(selected: _selected?.id == d.id, label: d.name),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      Colors.white.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.22, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AdiakeColors.primaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Choisir le dépôt de gaz',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AdiakeColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        color: AdiakeColors.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SkeletonCard(height: 90, lines: 2)
                  else if (_error != null)
                    InlineBanner(text: _error!, tone: BannerTone.danger, icon: Icons.error_outline)
                  else
                    AppCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        "Orange (gaz) = dépôts • bleu (moto) = vous • vert = livraison.\nTap sur un dépôt pour le sélectionner.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AdiakeColors.onSurfaceVariant,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  const Spacer(),
                  AppCard(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dépôt sélectionné'.toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AdiakeColors.onSurfaceVariant,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selected?.name ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AdiakeColors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              if (_routeKm != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _routeMin == null
                                      ? '${_routeKm!.toStringAsFixed(1)} km'
                                      : '${_routeKm!.toStringAsFixed(1)} km • ${_routeMin!.round()} min',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AdiakeColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_selected != null)
                          IconButton(
                            onPressed: () => _openNavigation(_selected!),
                            icon: const Icon(Icons.directions),
                            color: AdiakeColors.primaryContainer,
                            tooltip: 'Itinéraire (Google Maps)',
                          ),
                        FilledButton(
                          onPressed: _selected == null ? null : _confirmDepot,
                          child: const Text('Confirmer'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 92,
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _load,
                color: AdiakeColors.primaryContainer,
                displacement: 18,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 1)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepotPin extends StatelessWidget {
  const _DepotPin({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFF59E0B) : const Color(0xFFB45309); // orange
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: bg.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AdiakeColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: selected ? 44 : 40,
          height: selected ? 44 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.propane_tank, color: Colors.white),
        ),
      ],
    );
  }
}

class _DeliveryPin extends StatelessWidget {
  const _DeliveryPin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16A34A).withValues(alpha: 0.18),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF16A34A),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white),
        ),
      ],
    );
  }
}

class _DriverPin extends StatelessWidget {
  const _DriverPin();

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0052FF);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: blue.withValues(alpha: 0.18),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: blue,
            boxShadow: [
              BoxShadow(
                color: blue.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.two_wheeler, color: Colors.white),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

