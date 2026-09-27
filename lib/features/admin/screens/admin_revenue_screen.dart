import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';

final _fmt = NumberFormat('#,###', 'fr');
String _f(int v) => '${_fmt.format(v)} F';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  AdminRevenueDto? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await AdminApiExtra.adminRevenue();
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Revenus par acteur'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Restaurants'),
            Tab(icon: Icon(Icons.local_fire_department), text: 'Dépôts gaz'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                  ],
                ))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _RestaurantRevenueTab(items: _data!.byRestaurant),
                    _GasDepotRevenueTab(items: _data!.byGasDepot),
                  ],
                ),
    );
  }
}

// ─── Restaurant tab ───────────────────────────────────────────────────────────

class _RestaurantRevenueTab extends StatelessWidget {
  const _RestaurantRevenueTab({required this.items});
  final List<AdminRevenueRestaurantDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyState('Aucune vente complétée encore', Icons.restaurant);

    final total = items.fold(0, (s, e) => s + e.totalFcfa);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TotalBanner(label: 'Total ventes restaurants', total: total, color: const Color(0xFF06C167)),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final item = entry.value;
          final pct = total > 0 ? item.totalFcfa / total : 0.0;
          return _RevenueCard(
            rank: rank,
            name: item.restaurantName,
            totalFcfa: item.totalFcfa,
            orderCount: item.orderCount,
            pct: pct,
            color: const Color(0xFF06C167),
            icon: Icons.restaurant,
          );
        }),
      ],
    );
  }
}

// ─── Gas depot tab ────────────────────────────────────────────────────────────

class _GasDepotRevenueTab extends StatelessWidget {
  const _GasDepotRevenueTab({required this.items});
  final List<AdminRevenueGasDepotDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyState('Aucune livraison gaz complétée encore', Icons.local_fire_department);

    final total = items.fold(0, (s, e) => s + e.totalFcfa);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TotalBanner(label: 'Total frais livraison gaz', total: total, color: const Color(0xFFE65100)),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final item = entry.value;
          final pct = total > 0 ? item.totalFcfa / total : 0.0;
          return _RevenueCard(
            rank: rank,
            name: item.depotName,
            totalFcfa: item.totalFcfa,
            orderCount: item.orderCount,
            pct: pct,
            color: const Color(0xFFE65100),
            icon: Icons.local_fire_department,
          );
        }),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.label, required this.total, required this.color});
  final String label;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Row(children: [
      Expanded(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_f(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      )),
      const Icon(Icons.bar_chart, color: Colors.white38, size: 48),
    ]),
  );
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.rank, required this.name, required this.totalFcfa,
    required this.orderCount, required this.pct, required this.color, required this.icon,
  });
  final int rank;
  final String name;
  final int totalFcfa;
  final int orderCount;
  final double pct;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: rank <= 3 ? color : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('$rank', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900,
              color: rank <= 3 ? Colors.white : Colors.black54,
            ))),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis)),
          Text(_f(totalFcfa), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${(pct * 100).toStringAsFixed(1)}% du total', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const Spacer(),
          Text('$orderCount commande${orderCount > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
      ],
    ),
  );
}

Widget _emptyState(String msg, IconData icon) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 64, color: Colors.black12),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: Colors.black38, fontSize: 15)),
    ],
  ),
);
