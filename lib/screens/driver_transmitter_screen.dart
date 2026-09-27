import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/api_client.dart';
import '../services/background_tracking_service.dart';
import '../widgets/app_toast.dart';
import 'package:geolocator/geolocator.dart';
import '../features/driver/driver_earnings_screen.dart';

class DriverTransmitterScreen extends StatefulWidget {
  final String driverToken;

  const DriverTransmitterScreen({super.key, required this.driverToken});

  @override
  State<DriverTransmitterScreen> createState() => _DriverTransmitterScreenState();
}

class _DriverTransmitterScreenState extends State<DriverTransmitterScreen> {
  bool _isOnline = false;
  bool _loading = false;
  StreamSubscription? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isOnline = isRunning;
    });

    // On écoute les changements d'état du service
    _serviceSubscription = service.on('update').listen((event) {
       // On peut recevoir des infos en temps réel ici
    });
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      AppToast.showError(context, 'Les services de localisation sont désactivés.');
      throw Exception('Location services disabled');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        AppToast.showError(context, 'Les permissions de localisation sont refusées.');
        throw Exception('Permission denied');
      }
    }
    
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      AppToast.showError(context, 'Les permissions sont refusées de façon permanente.');
      throw Exception('Permission denied forever');
    }
  }

  void _toggleOnline() async {
    setState(() => _loading = true);
    try {
      if (_isOnline) {
        await BackgroundTrackingService.stop();
        await ApiClient.updateDriverStatus(false);
        setState(() => _isOnline = false);
        if (mounted) AppToast.showSuccess(context, "Vous êtes maintenant Hors-ligne");
      } else {
        await _checkPermissions();
        await BackgroundTrackingService.start();
        await ApiClient.updateDriverStatus(true);
        setState(() => _isOnline = true);
        if (mounted) AppToast.showSuccess(context, "Tournée démarrée !");
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, "Erreur: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Dark theme consistent with Admin
      appBar: AppBar(
        title: const Text('Mode Livreur', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DriverEarningsScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Mes gains',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Card (Glassmorphic)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: _isOnline ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(
                    _isOnline ? Icons.online_prediction : Icons.offline_bolt_rounded,
                    size: 80,
                    color: _isOnline ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isOnline ? "EN LIGNE" : "HORS-LIGNE",
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      color: _isOnline ? Colors.green : Colors.grey,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline 
                        ? "Votre position est partagée avec l'admin et vos clients en temps réel." 
                        : "Activez votre position pour recevoir des commandes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Toggle Button
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _loading ? null : _toggleOnline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnline ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: _loading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isOnline ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          _isOnline ? "ARRÊTER LA TOURNÉE" : "DÉMARRER MA TOURNÉE",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
              ),
            ),

            const SizedBox(height: 24),
            
            if (_isOnline)
              const Text(
                "Le tracking continue même si vous quittez l'application.",
                style: TextStyle(color: Colors.green, fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}
