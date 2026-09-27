import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/inline_banner.dart';
import '../../widgets/skeleton_card.dart';

/// Couleurs des pins nourriture (restaurant vs livraison client).
abstract final class _FoodMapPins {
  static const pickup = Color(0xFF9333EA);
  static const drop = Color(0xFF16A34A);
}

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  static const LatLng _adiake = LatLng(5.2867, -3.3042);

  final MapController _mapController = MapController();

  bool _loading = true;
  String? _error;
  List<Marker> _markers = const [];
  LatLng? _me;
  bool _sending = false;
  DateTime? _lastSentAt;
  late final _timer = Stream.periodic(const Duration(seconds: 5));
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _timer.listen((_) => _tickSendLocation());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  bool _isMine(String s) =>
      s == 'accepted' || s == 'depot_selected' || s == 'at_depot' || s == 'picked_up' || s == 'en_route';

  /// Mission repas assignée / en cours (hors « pending » disponible pour tous).
  bool _isMineFood(String s) => s == 'accepted' || s == 'stop_picked_up' || s == 'en_route';

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

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    final next = (cam.zoom + delta).clamp(3.0, 19.0);
    _mapController.move(cam.center, next);
  }

  Future<void> _centerOnMe() async {
    try {
      final me = await _getMyPosition();
      if (me == null) return;
      if (mounted) setState(() => _me = me);
      _mapController.move(me, 16.2);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _tickSendLocation() async {
    if (_sending) return;
    _sending = true;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await ApiClient.driverSendLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        heading: pos.heading.isNaN ? null : pos.heading,
        speed: pos.speed.isNaN ? null : pos.speed,
        accuracy: pos.accuracy.isNaN ? null : pos.accuracy,
      );
      if (!mounted) return;
      setState(() {
        _lastSentAt = DateTime.now();
        _me = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {
      // silence: ne pas polluer l'UI (backend down/offline)
    } finally {
      _sending = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.getDriverGasOrders(),
        ApiClient.getDriverParcelOrders(),
        ApiClient.getDriverFoodOrders(),
      ]);
      final gas = results[0] as List<GasOrderDto>;
      final parcel = results[1] as List<ParcelOrderDto>;
      final food = results[2] as List<FoodOrderDto>;

      final markers = <Marker>[];

      for (final g in gas.where((e) => _isMine(e.status))) {
        final lat = g.deliveryLat;
        final lng = g.deliveryLng;
        if (lat == null || lng == null) continue;
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 60,
            height: 60,
            child: const _Pin(icon: Icons.location_on, color: Color(0xFF16A34A)), // livraison vert
          ),
        );
      }

      for (final p in parcel.where((e) => _isMine(e.status))) {
        final dlat = p.dropoffLat;
        final dlng = p.dropoffLng;
        if (dlat != null && dlng != null) {
          markers.add(
            Marker(
              point: LatLng(dlat, dlng),
              width: 60,
              height: 60,
              child: const _Pin(icon: Icons.location_on, color: Color(0xFF16A34A)), // livraison vert
            ),
          );
        }
        final plat = p.pickupLat;
        final plng = p.pickupLng;
        if (plat != null && plng != null) {
          markers.add(
            Marker(
              point: LatLng(plat, plng),
              width: 60,
              height: 60,
              child: const _Pin(icon: Icons.trip_origin, color: Color(0xFFF59E0B)), // ramassage orange
            ),
          );
        }
      }

      for (final f in food.where((e) => e.status != 'cancelled' && _isMineFood(e.status))) {
        if (f.status == 'en_route') {
          final lat = f.deliveryLat;
          final lng = f.deliveryLng;
          if (lat != null && lng != null) {
            markers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 60,
                height: 60,
                child: const _Pin(icon: Icons.location_on_rounded, color: _FoodMapPins.drop),
              ),
            );
          }
        } else {
          for (final stop in f.stops) {
            if (stop.status == 'picked_up') continue;
            final lat = stop.restaurantLat;
            final lng = stop.restaurantLng;
            if (lat == null || lng == null) continue;
            markers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 60,
                height: 60,
                child: const _Pin(icon: Icons.restaurant_rounded, color: _FoodMapPins.pickup),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _markers = markers;
        _loading = false;
      });

      // Fit camera to show me + missions
      final pts = <LatLng>[
        ...?(_me == null ? null : [_me!]),
        for (final m in markers) m.point,
      ];
      if (pts.length >= 2) {
        final bounds = LatLngBounds.fromPoints(pts);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(46)));
      } else if (pts.length == 1) {
        _mapController.move(pts.first, 14.5);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _me ?? (_markers.isNotEmpty ? _markers.first.point : _adiake);
    final markers = <Marker>[
      if (_me != null)
        Marker(
          point: _me!,
          width: 66,
          height: 66,
          child: const _Pin(icon: Icons.two_wheeler, color: Color(0xFF0052FF)), // moto bleu
        ),
      ..._markers,
    ];

    final mapStack = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.8,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'adiake_livraison_express',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AdiakeColors.surface.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.18],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Carte & missions',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AdiakeColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdiakeColors.tertiaryFixed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Adiaké',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdiakeColors.onTertiaryFixedVariant,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _centerOnMe,
                  icon: const Icon(Icons.my_location_rounded),
                  color: AdiakeColors.primaryContainer,
                  tooltip: 'Ma position',
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100.withValues(alpha: 0.5)),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AdiakeColors.primaryContainer,
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Positioned(left: 24, right: 24, top: 78, child: SkeletonCard(height: 120, lines: 3)),
        if (_error != null)
          Positioned(
            left: 24,
            right: 24,
            top: 78,
            child: InlineBanner(text: _error!, tone: BannerTone.danger, icon: Icons.error_outline),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: GlassCard(
            borderRadius: 18,
            borderColor: AdiakeColors.primaryContainer.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: const [
                    _LegendDot(icon: Icons.two_wheeler_rounded, label: 'Livreur', color: Color(0xFF0052FF)),
                    _LegendDot(icon: Icons.location_on_rounded, label: 'Livraison', color: Color(0xFF16A34A)),
                    _LegendDot(icon: Icons.trip_origin_rounded, label: 'Ramassage', color: Color(0xFFF59E0B)),
                    _LegendDot(icon: Icons.restaurant_rounded, label: 'Repas · resto', color: _FoodMapPins.pickup),
                    _LegendDot(icon: Icons.location_on_rounded, label: 'Repas · client', color: _FoodMapPins.drop),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_lastSentAt != null)
                      Text(
                        'GPS ${_lastSentAt!.hour.toString().padLeft(2, '0')}:${_lastSentAt!.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AdiakeColors.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    if (_lastSentAt != null) const SizedBox(width: 10),
                    const Spacer(),
                    Text(
                      '${_markers.length} repère(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AdiakeColors.outline,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 104,
          child: Column(
            children: [
              _MapFab(
                icon: Icons.add_rounded,
                onTap: () => _zoomBy(0.8),
                tooltip: 'Zoom +',
              ),
              const SizedBox(height: 10),
              _MapFab(
                icon: Icons.remove_rounded,
                onTap: () => _zoomBy(-0.8),
                tooltip: 'Zoom -',
              ),
            ],
          ),
        ),
      ],
    );

    // Pull-to-refresh sur carte: zone en haut (n’empêche pas le pan/zoom sur la carte).
    return Stack(
      children: [
        mapStack,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 72,
          child: RefreshIndicator(
            onRefresh: _load,
            color: AdiakeColors.primaryContainer,
            displacement: 12,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 1)],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: AdiakeColors.primary.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: Icon(icon, color: AdiakeColors.primaryContainer)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.icon, required this.label, this.color = AdiakeColors.primaryContainer});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AdiakeColors.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, this.color = AdiakeColors.primaryContainer});
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: AdiakeColors.primary.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}

