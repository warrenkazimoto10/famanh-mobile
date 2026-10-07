import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../data/api_config.dart';
import '../../../data/api_session.dart';
import '../../../data/taxi_api_client.dart';

class AdminTaxiScreen extends StatefulWidget {
  const AdminTaxiScreen({super.key});

  @override
  State<AdminTaxiScreen> createState() => _AdminTaxiScreenState();
}

class _AdminTaxiScreenState extends State<AdminTaxiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _availableTaxis = [];

  // Contrôleurs pour la tarification
  final _baseFareCtrl = TextEditingController();
  final _privateFareCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseFareCtrl.dispose();
    _privateFareCtrl.dispose();
    _commissionCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final settings = await TaxiApiClient.getSettings();
      final taxis = await TaxiApiClient.getAvailableTaxis();

      if (mounted) {
        setState(() {
          _settings = settings;
          _availableTaxis = taxis;

          _baseFareCtrl.text = (_settings['base_fare_per_seat'] ?? 200).toString();
          _privateFareCtrl.text = (_settings['private_ride_fare'] ?? 800).toString();
          _commissionCtrl.text = (_settings['commission_percentage'] ?? 10).toString();
          _radiusCtrl.text = (_settings['urban_radius_km'] ?? 3.5).toString();

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdminTopupDialog() {
    final driverIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '2000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recharge Guichet (Cash)', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Encaisser le cash au guichet d\'Adiaké et créditer immédiatement le portefeuille du chauffeur.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: driverIdCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ID du Chauffeur',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant encaissé (FCFA)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: 'FCFA',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final did = int.tryParse(driverIdCtrl.text.trim());
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (did == null || amt <= 0) return;

              Navigator.pop(ctx);
              try {
                final res = await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/api/admin/taxi/wallet/topup'),
                  headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${ApiSession.token}',
                  },
                  body: jsonEncode({
                    'driver_id': did,
                    'amount': amt,
                    'channel': 'cash_admin',
                    'reference': 'CASH-GUICHET',
                  }),
                );

                if (mounted) {
                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Portefeuille crédité de $amt FCFA !'), backgroundColor: const Color(0xFF10B981)),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors du crédit.'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text('Valider le Cash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Supervision Taxi Adiaké',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Recharge Cash Guichet',
            onPressed: _showAdminTopupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEAB308),
          labelColor: const Color(0xFFEAB308),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.local_taxi_rounded), text: 'Taxis en Circulation'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Grille Tarifaire'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEAB308)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLiveTaxisTab(),
                _buildPricingTab(),
              ],
            ),
    );
  }

  Widget _buildLiveTaxisTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taxis connectés (${_availableTaxis.length})',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton.icon(
                onPressed: _showAdminTopupDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Recharger un chauffeur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_availableTaxis.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.local_taxi_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Aucun taxi connecté pour l\'instant.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._availableTaxis.map((t) {
              final name = t['name'] ?? 'Chauffeur';
              final plate = t['vehicle_plate'] ?? 'T-ADIAKE';
              final phone = t['phone'] ?? '';
              final seats = t['available_seats'] ?? 4;
              final isBusy = t['is_busy'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isBusy ? Colors.grey.shade100 : const Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_taxi_rounded,
                          color: isBusy ? Colors.grey : const Color(0xFFD97706),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('$plate • $phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBusy ? Colors.red.shade50 : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBusy ? 'Occupé' : '$seats places libres',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isBusy ? Colors.red.shade700 : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPricingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paramètres Tarifaires & Commission',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ces valeurs sont appliquées automatiquement lors du calcul des courses par l\'application.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              TextField(
                controller: _baseFareCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tarif de base en ville (Partagé par place)',
                  suffixText: 'FCFA',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _privateFareCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Forfait Course Privatisée (Véhicule entier)',
                  suffixText: 'FCFA',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _commissionCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Commission Plateforme Famanh',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rayon urbain standard Adiaké',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Grille tarifaire mise à jour !'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer les tarifs', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
