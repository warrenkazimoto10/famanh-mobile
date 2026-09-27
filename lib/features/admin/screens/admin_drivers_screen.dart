import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';

const _kDriver = Color(0xFF1565C0);

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  bool _loading = true;
  String? _error;
  List<AdminDriverDto> _drivers = const [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApi.adminDrivers();
      if (!mounted) return;
      setState(() { _drivers = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<AdminDriverDto> get _filtered {
    if (_search.isEmpty) return _drivers;
    final q = _search.toLowerCase();
    return _drivers.where((d) => d.name.toLowerCase().contains(q) || d.phone.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final available = _drivers.where((d) => d.isAvailable).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: _kDriver,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Livreurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _StatChip(label: 'Total', value: '${_drivers.length}', color: _kDriver)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(label: 'Disponibles', value: '$available', color: const Color(0xFF2E7D32))),
                    const SizedBox(width: 10),
                    Expanded(child: _StatChip(label: 'Hors ligne', value: '${_drivers.length - available}', color: AdiakeColors.outline)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un livreur…',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null
                    ? _buildError()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 90, borderRadius: 16),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
          ],
        ),
      );

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delivery_dining_outlined, size: 56, color: AdiakeColors.outline),
          const SizedBox(height: 12),
          const Text('Aucun livreur trouvé', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _kDriver,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DriverCard(driver: list[i]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});
  final AdminDriverDto driver;

  String _timeAgo(DateTime? d) {
    if (d == null) return 'Jamais';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = driver.lastLat != null && driver.lastLng != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _kDriver.withValues(alpha: 0.12),
                child: Text(driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: _kDriver, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AdiakeColors.primary)),
                    const SizedBox(height: 2),
                    Text(driver.phone, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (driver.isAvailable ? const Color(0xFF2E7D32) : AdiakeColors.outline).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: driver.isAvailable ? const Color(0xFF2E7D32) : AdiakeColors.outline,
                  )),
                  const SizedBox(width: 6),
                  Text(driver.isAvailable ? 'Disponible' : 'Hors ligne',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: driver.isAvailable ? const Color(0xFF2E7D32) : AdiakeColors.outline)),
                ]),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF0F0F0)),
          Row(
            children: [
              Expanded(child: _InfoBit(icon: Icons.local_shipping_outlined, label: 'Véhicule',
                  value: driver.vehicleType?.isNotEmpty == true ? driver.vehicleType! : '—')),
              Expanded(child: _InfoBit(icon: Icons.confirmation_number_outlined, label: 'Plaque',
                  value: driver.vehiclePlate?.isNotEmpty == true ? driver.vehiclePlate! : '—')),
              Expanded(child: _InfoBit(icon: Icons.assignment_outlined, label: 'Courses actives',
                  value: '${driver.activeOrders}')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(hasLocation ? Icons.location_on_rounded : Icons.location_off_outlined,
                  size: 16, color: hasLocation ? _kDriver : AdiakeColors.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasLocation
                      ? '${driver.lastLat!.toStringAsFixed(4)}, ${driver.lastLng!.toStringAsFixed(4)} • ${_timeAgo(driver.lastLocationAt)}'
                      : 'Position inconnue',
                  style: const TextStyle(fontSize: 11.5, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBit extends StatelessWidget {
  const _InfoBit({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 13, color: AdiakeColors.outline),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AdiakeColors.outline, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AdiakeColors.primary),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
