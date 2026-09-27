import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  const OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class OsrmClient {
  OsrmClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<OsrmRoute> routeDriving({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
        'steps': 'false',
      },
    );

    final res = await _client.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('OSRM HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final routes = (data is Map<String, dynamic>) ? (data['routes'] as List?) : null;
    if (routes == null || routes.isEmpty) throw Exception('OSRM: aucune route');

    final r0 = routes.first as Map<String, dynamic>;
    final distance = (r0['distance'] as num?)?.toDouble() ?? 0;
    final duration = (r0['duration'] as num?)?.toDouble() ?? 0;
    final geometry = r0['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    if (coords == null || coords.isEmpty) throw Exception('OSRM: géométrie vide');

    final points = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        points.add(LatLng(lat, lon));
      }
    }

    return OsrmRoute(points: points, distanceMeters: distance, durationSeconds: duration);
  }
}

