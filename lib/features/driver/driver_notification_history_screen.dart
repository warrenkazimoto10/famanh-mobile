import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/skeleton_loader.dart';

class DriverNotificationHistoryScreen extends StatefulWidget {
  const DriverNotificationHistoryScreen({super.key});

  @override
  State<DriverNotificationHistoryScreen> createState() => _DriverNotificationHistoryScreenState();
}

class _DriverNotificationHistoryScreenState extends State<DriverNotificationHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<DriverNotificationDto> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiClient.getDriverNotifications();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F6),
      appBar: AppBar(
        backgroundColor: AdiakeColors.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load), const SizedBox(width: 4)],
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 8,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 64, borderRadius: 14),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, color: AdiakeColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AdiakeColors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
                    ]),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.notifications_none_rounded, size: 56, color: AdiakeColors.outline),
                        const SizedBox(height: 12),
                        const Text('Aucune notification pour le moment', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AdiakeColors.primaryContainer,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotificationRow(item: _items[i]),
                      ),
                    ),
    );
  }
}

(IconData, Color, String) _presentationFor(DriverNotificationDto n) {
  final typeLabel = switch (n.type) {
    'gas' => 'Gaz',
    'parcel' => 'Colis',
    'food' => 'Nourriture',
    _ => n.type,
  };

  return switch (n.status) {
    'accepted' => (Icons.check_circle_outline_rounded, const Color(0xFF2E7D32), '$typeLabel #${n.orderId} acceptée'),
    'depot_selected' => (Icons.store_mall_directory_outlined, const Color(0xFFE65100), 'Dépôt sélectionné • $typeLabel #${n.orderId}'),
    'at_depot' => (Icons.warehouse_rounded, const Color(0xFFE65100), 'Arrivé au dépôt • $typeLabel #${n.orderId}'),
    'picked_up' => (Icons.shopping_bag_outlined, const Color(0xFF1565C0), 'Colis récupéré • $typeLabel #${n.orderId}'),
    'stop_picked_up' => (Icons.restaurant_rounded, const Color(0xFF1565C0), 'Plats récupérés • $typeLabel #${n.orderId}'),
    'preparing' => (Icons.soup_kitchen_outlined, const Color(0xFFB45309), 'En préparation • $typeLabel #${n.orderId}'),
    'ready' => (Icons.task_alt_rounded, const Color(0xFF2E7D32), 'Commande prête • $typeLabel #${n.orderId}'),
    'en_route' => (Icons.local_shipping_rounded, const Color(0xFF1565C0), 'En route • $typeLabel #${n.orderId}'),
    'delivered_paid' => (Icons.verified_rounded, const Color(0xFF2E7D32), '$typeLabel #${n.orderId} livrée'),
    'empty_returned' => (Icons.repeat_rounded, AdiakeColors.outline, 'Bouteille vide retournée • $typeLabel #${n.orderId}'),
    'cancelled' => (Icons.cancel_outlined, AdiakeColors.error, '$typeLabel #${n.orderId} annulée'),
    _ => (Icons.event_note_rounded, AdiakeColors.primaryContainer, '$typeLabel #${n.orderId} • ${n.status}'),
  };
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});
  final DriverNotificationDto item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _presentationFor(item);
    final date = DateFormat('dd/MM/yyyy à HH:mm').format(item.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdiakeColors.primary)),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(fontSize: 11.5, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
