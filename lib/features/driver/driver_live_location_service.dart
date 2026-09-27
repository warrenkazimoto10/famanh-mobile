import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../data/api_client.dart';

class DriverLiveLocationService {
  DriverLiveLocationService._();

  static final DriverLiveLocationService instance = DriverLiveLocationService._();

  Timer? _timer;
  bool _running = false;

  /// Retourne `null` si tout est OK, sinon un message d'erreur explicite.
  Future<String?> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return "Les services de localisation sont désactivés. Active le GPS pour partager ta position.";
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return "Permission de localisation refusée. Le suivi de tournée ne peut pas démarrer.";
    }
    if (perm == LocationPermission.deniedForever) {
      return "Permission de localisation bloquée. Autorise-la dans les réglages pour activer le suivi.";
    }
    return null;
  }

  /// Démarre le suivi. [onError] est appelé avec un message lisible si le
  /// démarrage échoue (GPS désactivé, permission refusée…).
  Future<void> start({
    Duration interval = const Duration(seconds: 3),
    void Function(String message)? onError,
  }) async {
    if (_running) return;
    _running = true;

    final error = await _ensurePermission();
    if (error != null) {
      _running = false;
      onError?.call(error);
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        await ApiClient.driverSendLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading.isFinite ? pos.heading : null,
          speed: pos.speed.isFinite ? pos.speed : null,
          accuracy: pos.accuracy.isFinite ? pos.accuracy : null,
        );
      } catch (_) {
        // On ignore (pas bloquant): réseau, GPS, permissions...
      }
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}

