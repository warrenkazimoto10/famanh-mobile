import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';

const _kAudit = Color(0xFF6A1B9A);

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  bool _loading = true;
  String? _error;
  List<AuditLogDto> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApi.adminAuditLogs();
      if (!mounted) return;
      setState(() { _logs = list; _loading = false; });
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
        backgroundColor: _kAudit,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Journal d\'audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, color: AdiakeColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(fontSize: 13, color: AdiakeColors.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _kAudit)),
                  ]),
                )
              : _logs.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.history_rounded, size: 56, color: AdiakeColors.outline),
                        const SizedBox(height: 12),
                        const Text('Aucune activité enregistrée', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _kAudit,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _LogRow(log: _logs[i]),
                      ),
                    ),
    );
  }
}

(IconData, Color) _iconFor(String action) {
  if (action.startsWith('user.role_changed')) return (Icons.swap_horiz_rounded, const Color(0xFF1565C0));
  if (action.startsWith('user.deleted')) return (Icons.person_remove_rounded, AdiakeColors.error);
  if (action.startsWith('pricing.')) return (Icons.attach_money_rounded, const Color(0xFFE65100));
  if (action.startsWith('gas_depot.')) return (Icons.warehouse_rounded, const Color(0xFFE65100));
  if (action.startsWith('gas_product.')) return (Icons.propane_tank_rounded, const Color(0xFFE65100));
  if (action.startsWith('settings.')) return (Icons.settings_rounded, const Color(0xFF455A64));
  return (Icons.event_note_rounded, _kAudit);
}

String _labelFor(String action) => switch (action) {
      'user.role_changed' => 'Rôle utilisateur modifié',
      'user.deleted' => 'Utilisateur supprimé',
      'pricing.gas_updated' => 'Tarification gaz modifiée',
      'pricing.parcel_updated' => 'Tarification colis modifiée',
      'pricing.food_updated' => 'Tarification food modifiée',
      'gas_depot.created' => 'Dépôt gaz créé',
      'gas_depot.updated' => 'Dépôt gaz modifié',
      'gas_depot.deleted' => 'Dépôt gaz supprimé',
      'gas_product.created' => 'Produit gaz créé',
      'gas_product.updated' => 'Produit gaz modifié',
      'gas_product.deleted' => 'Produit gaz supprimé',
      'settings.updated' => 'Réglages généraux modifiés',
      _ => action,
    };

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final AuditLogDto log;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(log.action);
    final date = DateFormat('dd/MM/yyyy à HH:mm').format(log.createdAt);

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
                Text(_labelFor(log.action), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdiakeColors.primary)),
                const SizedBox(height: 3),
                Text(
                  'Par ${log.actorName ?? 'Système'} • $date',
                  style: const TextStyle(fontSize: 11.5, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                if (log.changes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    log.changes.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                    style: const TextStyle(fontSize: 11, color: AdiakeColors.outline),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
