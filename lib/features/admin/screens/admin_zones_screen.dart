import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/custom_location_api_client.dart';

class AdminZonesScreen extends StatefulWidget {
  const AdminZonesScreen({super.key});

  @override
  State<AdminZonesScreen> createState() => _AdminZonesScreenState();
}

class _AdminZonesScreenState extends State<AdminZonesScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  static const LatLng _adiakeCenter = LatLng(5.2863, -3.2981);

  bool _isLoading = true;
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _landmarks = [];

  // Modes de dessin : null, 'polygon', 'landmark'
  String? _drawingMode;
  final List<LatLng> _currentPolygonPoints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final zones = await CustomLocationApiClient.getZones();
      final landmarks = await CustomLocationApiClient.getLandmarks();
      if (mounted) {
        setState(() {
          _zones = zones;
          _landmarks = landmarks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_drawingMode == 'polygon') {
      setState(() {
        _currentPolygonPoints.add(point);
      });
    } else if (_drawingMode == 'landmark') {
      _showAddLandmarkDialog(point);
    }
  }

  void _showSavePolygonDialog() {
    if (_currentPolygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez placer au moins 3 points pour former un quartier.')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final surchargeCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String selectedColor = '#EAB308';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Enregistrer le Quartier', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du Quartier *', hintText: 'Ex: Quartier Habitat'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: surchargeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Supplément Livraison (FCFA)', hintText: '0'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Indications d\'accès', hintText: 'Repères livreurs...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final surcharge = double.tryParse(surchargeCtrl.text.trim()) ?? 0.0;
                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.of(ctx).pop();

                try {
                  await CustomLocationApiClient.storeZone(
                    name: name,
                    points: _currentPolygonPoints,
                    color: selectedColor,
                    deliverySurcharge: surcharge,
                    notes: notesCtrl.text.trim(),
                  );
                  if (mounted) {
                    setState(() {
                      _drawingMode = null;
                      _currentPolygonPoints.clear();
                    });
                    _loadData();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Quartier enregistré avec succès !'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308), foregroundColor: const Color(0xFF0F172A)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLandmarkDialog(LatLng point) {
    final nameCtrl = TextEditingController();
    final hintCtrl = TextEditingController();
    String category = 'landmark';
    bool isPopular = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau Point de Repère', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du Repère *', hintText: 'Ex: Carrefour Deux Poteaux'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hintCtrl,
                  decoration: const InputDecoration(labelText: 'Indication visuelle', hintText: 'Ex: Face au portail vert'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const [
                    DropdownMenuItem(value: 'crossroad', child: Text('Carrefour / Intersection')),
                    DropdownMenuItem(value: 'shop', child: Text('Boutique / Magasin')),
                    DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacie')),
                    DropdownMenuItem(value: 'hospital', child: Text('Hôpital / Santé')),
                    DropdownMenuItem(value: 'school', child: Text('École / Lycée')),
                    DropdownMenuItem(value: 'restaurant', child: Text('Maquis / Restaurant')),
                    DropdownMenuItem(value: 'landmark', child: Text('Autre Repère Clé')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'landmark'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Raccourci populaire', style: TextStyle(fontSize: 13)),
                  value: isPopular,
                  onChanged: (v) => setDialogState(() => isPopular = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _drawingMode = null);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final messenger = ScaffoldMessenger.of(ctx);
                Navigator.of(ctx).pop();
                setState(() => _drawingMode = null);

                try {
                  await CustomLocationApiClient.storeLandmark(
                    name: name,
                    lat: point.latitude,
                    lng: point.longitude,
                    category: category,
                    addressHint: hintCtrl.text.trim(),
                    isPopular: isPopular,
                  );
                  if (mounted) {
                    _loadData();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Point de repère enregistré !'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    // Construction des polygones existants
    final polygons = <Polygon>[];
    for (final zone in _zones) {
      final rawCoords = zone['polygon_coordinates'] as List<dynamic>? ?? [];
      final pts = <LatLng>[];
      for (final c in rawCoords) {
        if (c is List && c.length >= 2) {
          pts.add(LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()));
        }
      }
      if (pts.length >= 3) {
        final color = _parseHexColor(zone['color']?.toString());
        polygons.add(
          Polygon(
            points: pts,
            color: color.withValues(alpha: 0.25),
            borderColor: color,
            borderStrokeWidth: 2.5,
          ),
        );
      }
    }

    // Polygone en cours de dessin
    if (_currentPolygonPoints.length >= 3) {
      polygons.add(
        Polygon(
          points: _currentPolygonPoints,
          color: const Color(0xFFEAB308).withValues(alpha: 0.35),
          borderColor: const Color(0xFFEAB308),
          borderStrokeWidth: 3.0,
        ),
      );
    }

    // Marqueurs des repères (Landmarks)
    final markers = <Marker>[];
    for (final lm in _landmarks) {
      final lat = (lm['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (lm['lng'] as num?)?.toDouble() ?? 0.0;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.place_rounded, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    // Sommets du polygone en cours de dessin
    for (final pt in _currentPolygonPoints) {
      markers.add(
        Marker(
          point: pt,
          width: 14,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cartographie & Quartiers',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _adiakeCenter,
              initialZoom: 14.5,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ci.famanh.adiake',
              ),
              if (polygons.isNotEmpty)
                PolygonLayer(polygons: polygons),
              MarkerLayer(markers: markers),
            ],
          ),

          // En-tête des modes de dessin
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _drawingMode = _drawingMode == 'polygon' ? null : 'polygon';
                          _currentPolygonPoints.clear();
                        });
                      },
                      icon: const Icon(Icons.polyline_rounded, size: 18),
                      label: Text(_drawingMode == 'polygon' ? 'En dessin...' : '+ Quartier'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _drawingMode == 'polygon' ? const Color(0xFFFEF3C7) : Colors.transparent,
                        foregroundColor: _drawingMode == 'polygon' ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                        side: BorderSide(color: _drawingMode == 'polygon' ? const Color(0xFFEAB308) : Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _drawingMode = _drawingMode == 'landmark' ? null : 'landmark';
                          _currentPolygonPoints.clear();
                        });
                      },
                      icon: const Icon(Icons.pin_drop_rounded, size: 18),
                      label: Text(_drawingMode == 'landmark' ? 'Cliquer carte' : '+ Repère'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _drawingMode == 'landmark' ? const Color(0xFFE0F2FE) : Colors.transparent,
                        foregroundColor: _drawingMode == 'landmark' ? const Color(0xFF0369A1) : const Color(0xFF0F172A),
                        side: BorderSide(color: _drawingMode == 'landmark' ? const Color(0xFF0284C7) : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bouton d'action flottant pour finaliser le tracé du polygone
          if (_drawingMode == 'polygon' && _currentPolygonPoints.length >= 3)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: _showSavePolygonDialog,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('Enregistrer le Quartier (${_currentPolygonPoints.length} points)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAB308),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
