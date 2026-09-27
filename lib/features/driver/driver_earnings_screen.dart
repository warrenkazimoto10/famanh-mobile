import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../widgets/money_text.dart';
import '../../widgets/app_toast.dart';
import 'package:intl/intl.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _loading = true;
  double _totalEarnings = 0;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getDriverEarnings();
      setState(() {
        _totalEarnings = (res['total_earnings'] as num).toDouble();
        _history = res['history'] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) AppToast.showError(context, "Erreur chargement gains: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Mes Gains', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
        : RefreshIndicator(
            onRefresh: _loadEarnings,
            child: CustomScrollView(
              slivers: [
                // Total Earnings Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "TOTAL DES GAINS",
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 12),
                        MoneyText(
                          _totalEarnings.toInt(),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Payé hebdomadairement",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      "HISTORIQUE DES COURSES",
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                ),

                // History List
                _history.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text("Aucune course terminée pour le moment.", style: TextStyle(color: Colors.white38)),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _history[index];
                          final type = item['type'] as String;
                          final amount = item['delivery_fee_fcfa'] as int;
                          final date = DateTime.parse(item['updated_at']);

                          IconData iconData;
                          Color iconColor;
                          String label;

                          switch (type) {
                            case 'gas':
                              iconData = Icons.local_gas_station_rounded;
                              iconColor = Colors.green;
                              label = "Livraison Gaz";
                              break;
                            case 'food':
                              iconData = Icons.restaurant_rounded;
                              iconColor = Colors.orange;
                              label = "Livraison Food";
                              break;
                            default:
                              iconData = Icons.inventory_2_rounded;
                              iconColor = Colors.blue;
                              label = "Livraison Colis";
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: iconColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(
                                        DateFormat('dd MMM yyyy - HH:mm').format(date),
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                MoneyText(
                                  amount,
                                  style: TextStyle(color: iconColor, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _history.length,
                      ),
                    ),
                
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
    );
  }
}
