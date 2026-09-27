import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/admin_image_picker_field.dart';

const _kShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x04000000), blurRadius: 24, offset: Offset(0, 8)),
];

const _kDefaultLat = 5.3484;
const _kDefaultLng = -4.0083;

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminResidencesAdminScreen extends StatefulWidget {
  const AdminResidencesAdminScreen({super.key});

  @override
  State<AdminResidencesAdminScreen> createState() => _AdminResidencesAdminScreenState();
}

class _AdminResidencesAdminScreenState extends State<AdminResidencesAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<AdminResidenceAdminDto> _all = const [];
  String _search = '';

  bool get _isHotelTab => _tabController.index == 1;

  List<AdminResidenceAdminDto> get _filtered {
    var list = _isHotelTab
        ? _all.where((r) => r.type == 'hotel').toList()
        : _all.where((r) => r.type != 'hotel').toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.name.toLowerCase().contains(q) ||
          (r.address?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    _load();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApiExtra.adminResidencesList();
      if (mounted) setState(() { _all = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openCreate() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ResidenceFormSheet(initialCategory: _isHotelTab ? 'hotel' : 'residence', onDone: _load),
  );

  void _openEdit(AdminResidenceAdminDto r) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ResidenceFormSheet(residence: r, onDone: _load),
  );

  void _openDetail(AdminResidenceAdminDto r) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ResidenceDetailSheet(
      residence: r,
      onEdit: () { Navigator.of(context).pop(); _openEdit(r); },
      onDelete: () { Navigator.of(context).pop(); _confirmDelete(r); },
    ),
  );

  Future<void> _confirmDelete(AdminResidenceAdminDto r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('« ${r.name} » sera supprimé(e) définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try { await AdminApiExtra.adminDeleteResidence(r.id); _load(); }
    catch (e) { if (mounted) _snack(e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(children: [
        // ── Header + tabs ──
        Container(
          color: Colors.white,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                Text('Résidences / Hôtels', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
                const SizedBox(width: 8),
                _CountBadge(count: _filtered.length),
                const SizedBox(width: 12),
                Expanded(child: _SearchField(search: _search, onSearch: (v) => setState(() => _search = v))),
              ]),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AdiakeColors.primaryContainer,
              unselectedLabelColor: AdiakeColors.outline,
              indicatorColor: AdiakeColors.primaryContainer,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [Tab(text: 'Résidences'), Tab(text: 'Hôtels')],
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? _skeleton(isWide)
              : _error != null
                  ? _errorView()
                  : _filtered.isEmpty
                      ? _emptyState()
                      : _buildGrid(isWide),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: Text(_isHotelTab ? 'Nouvel hôtel' : 'Nouvelle résidence', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AdiakeColors.primaryContainer, foregroundColor: Colors.white,
      ),
    );
  }

  Widget _skeleton(bool isWide) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isWide ? 3 : 2, mainAxisExtent: 240, crossAxisSpacing: 12, mainAxisSpacing: 12),
    itemCount: 6,
    itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: double.infinity, borderRadius: 18),
  );

  Widget _errorView() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
    const SizedBox(height: 12),
    Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
  ]));

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(_isHotelTab ? Icons.hotel_rounded : Icons.home_rounded, size: 56, color: AdiakeColors.outline),
    const SizedBox(height: 12),
    Text(_isHotelTab ? 'Aucun hôtel' : 'Aucune résidence', style: const TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Appuyez sur + pour en créer ${_isHotelTab ? 'un' : 'une'}', style: const TextStyle(color: AdiakeColors.outline, fontSize: 12)),
  ]));

  Widget _buildGrid(bool isWide) {
    final list = _filtered;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 16 : 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : 2,
        mainAxisExtent: 252,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _ResidenceCard(
        residence: list[i],
        onTap: () => _openDetail(list[i]),
        onEdit: () => _openEdit(list[i]),
        onDelete: () => _confirmDelete(list[i]),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AdiakeColors.error : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _ResidenceCard extends StatelessWidget {
  const _ResidenceCard({required this.residence, required this.onTap, required this.onEdit, required this.onDelete});
  final AdminResidenceAdminDto residence;
  final VoidCallback onTap, onEdit, onDelete;

  static const _typeColors = {
    'hotel': Color(0xFF1565C0), 'villa': Color(0xFF2E7D32),
    'studio': Color(0xFF6A1B9A), 'apartment': Color(0xFFE65100), 'house': Color(0xFF00838F),
  };

  Color get _color => _typeColors[residence.type] ?? AdiakeColors.primaryContainer;

  String get _typeLabel => switch (residence.type) {
    'hotel' => 'Hôtel', 'villa' => 'Villa', 'studio' => 'Studio',
    'apartment' => 'Appartement', 'house' => 'Maison', _ => residence.type,
  };

  IconData get _typeIcon => switch (residence.type) {
    'hotel' => Icons.hotel_rounded, 'villa' => Icons.villa_rounded,
    _ => Icons.home_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat('#,###', 'fr').format(residence.pricePerNight);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: _kShadow),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image ──
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              residence.imageUrl != null
                  ? Image.network(residence.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
              // Gradient overlay
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x55000000)]))),
              // Type badge
              Positioned(top: 8, left: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8)),
                child: Text(_typeLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              )),
              // Menu
              Positioned(top: 4, right: 4, child: _CardMenu(onEdit: onEdit, onDelete: onDelete)),
              // GPS indicator
              if (residence.lat != null)
                Positioned(bottom: 8, right: 8, child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, size: 12, color: AdiakeColors.primaryContainer),
                )),
            ]),
          ),
          // ── Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(residence.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdiakeColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (residence.description != null) ...[
                  const SizedBox(height: 2),
                  Text(residence.description!, style: const TextStyle(fontSize: 10, color: AdiakeColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (residence.address != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 10, color: AdiakeColors.outline),
                    const SizedBox(width: 2),
                    Expanded(child: Text(residence.address!, style: const TextStyle(fontSize: 10, color: AdiakeColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                const Spacer(),
                Text('$price F / nuit', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdiakeColors.primaryContainer)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.bed_rounded, size: 12, color: AdiakeColors.outline),
                  const SizedBox(width: 3),
                  Text('${residence.capacity} pers.', style: const TextStyle(fontSize: 10, color: AdiakeColors.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  const Icon(Icons.book_online_outlined, size: 12, color: AdiakeColors.outline),
                  const SizedBox(width: 3),
                  Text('${residence.bookingsCount} résa', style: const TextStyle(fontSize: 10, color: AdiakeColors.onSurfaceVariant)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_color.withValues(alpha: 0.3), _color.withValues(alpha: 0.08)])),
    child: Center(child: Icon(_typeIcon, size: 40, color: _color.withValues(alpha: 0.4))),
  );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.9),
    shape: const CircleBorder(),
    child: PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 16, color: AdiakeColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Modifier')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AdiakeColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AdiakeColors.error))])),
      ],
      onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
    ),
  );
}

// ── Detail sheet ──────────────────────────────────────────────────────────────

class _ResidenceDetailSheet extends StatelessWidget {
  const _ResidenceDetailSheet({required this.residence, required this.onEdit, required this.onDelete});
  final AdminResidenceAdminDto residence;
  final VoidCallback onEdit, onDelete;

  static const _typeColors = {
    'hotel': Color(0xFF1565C0), 'villa': Color(0xFF2E7D32),
    'studio': Color(0xFF6A1B9A), 'apartment': Color(0xFFE65100), 'house': Color(0xFF00838F),
  };

  Color get _color => _typeColors[residence.type] ?? AdiakeColors.primaryContainer;

  String get _typeLabel => switch (residence.type) {
    'hotel' => 'Hôtel', 'villa' => 'Villa', 'studio' => 'Studio',
    'apartment' => 'Appartement', 'house' => 'Maison', _ => residence.type,
  };

  String get _categoryLabel => residence.type == 'hotel' ? 'Hôtel' : 'Résidence';

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat('#,###', 'fr').format(residence.pricePerNight);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => ListView(controller: sc, padding: EdgeInsets.zero, children: [
          // ── Hero image ──
          Stack(children: [
            SizedBox(
              height: 220, width: double.infinity,
              child: residence.imageUrl != null
                  ? Image.network(residence.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder())
                  : _heroPlaceholder(),
            ),
            Container(height: 220, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x88000000)]))),
            // Type + Category badges
            Positioned(bottom: 12, left: 16, child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(_categoryLabel, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w900))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8)), child: Text(_typeLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
            ])),
            // Drag handle on top
            Positioned(top: 10, left: 0, right: 0, child: Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3))))),
          ]),

          // ── Content ──
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name + ID
              Row(children: [
                Expanded(child: Text(residence.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AdiakeColors.primary))),
                Text('#${residence.id}', style: const TextStyle(fontSize: 11, color: AdiakeColors.outline)),
              ]),
              const SizedBox(height: 8),
              // Price
              Row(children: [
                Text('$price F', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: AdiakeColors.primaryContainer)),
                const Text(' / nuit', style: TextStyle(fontSize: 14, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 14),
              // Stats row
              Row(children: [
                _StatChip(icon: Icons.bed_rounded, label: '${residence.capacity} pers.', color: const Color(0xFF1565C0)),
                const SizedBox(width: 10),
                _StatChip(icon: Icons.book_online_rounded, label: '${residence.bookingsCount} réservation${residence.bookingsCount > 1 ? 's' : ''}', color: const Color(0xFF2E7D32)),
              ]),
              const SizedBox(height: 16),
              const _Divider(),
              const SizedBox(height: 14),

              // Description
              if (residence.description != null && residence.description!.isNotEmpty) ...[
                const _SectionTitle('Description'),
                const SizedBox(height: 6),
                Text(residence.description!, style: const TextStyle(fontSize: 14, color: AdiakeColors.primary, height: 1.6)),
                const SizedBox(height: 16),
              ],

              // Adresse
              if (residence.address != null) ...[
                const _SectionTitle('Adresse'),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: AdiakeColors.primaryContainer),
                  const SizedBox(width: 6),
                  Expanded(child: Text(residence.address!, style: const TextStyle(fontSize: 14, color: AdiakeColors.primary))),
                ]),
                const SizedBox(height: 16),
              ],

              // Carte
              if (residence.lat != null) ...[
                const _SectionTitle('Localisation'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: Stack(children: [
                      FlutterMap(
                        options: MapOptions(initialCenter: LatLng(residence.lat!, residence.lng!), initialZoom: 15),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.adiake.express'),
                          MarkerLayer(markers: [Marker(point: LatLng(residence.lat!, residence.lng!), child: const Icon(Icons.location_pin, color: AdiakeColors.primaryContainer, size: 40))]),
                        ],
                      ),
                      Positioned(bottom: 8, right: 8, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: _kShadow),
                        child: Text('${residence.lat!.toStringAsFixed(5)}, ${residence.lng!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
                      )),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const _Divider(),
              const SizedBox(height: 16),

              // Actions
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AdiakeColors.primaryContainer), foregroundColor: AdiakeColors.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AdiakeColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _heroPlaceholder() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_color.withValues(alpha: 0.3), _color.withValues(alpha: 0.08)])),
    child: Center(child: Icon(residence.type == 'hotel' ? Icons.hotel_rounded : Icons.home_rounded, size: 64, color: _color.withValues(alpha: 0.3))),
  );
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.color});
  final IconData icon; final String label; final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AdiakeColors.onSurfaceVariant, letterSpacing: 0.5));
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: const Color(0xFFF0F0F0));
}

// ── Form sheet ────────────────────────────────────────────────────────────────

class _ResidenceFormSheet extends StatefulWidget {
  const _ResidenceFormSheet({this.residence, required this.onDone, this.initialCategory = 'residence'});
  final AdminResidenceAdminDto? residence;
  final VoidCallback onDone;
  final String initialCategory;

  @override
  State<_ResidenceFormSheet> createState() => _ResidenceFormSheetState();
}

class _ResidenceFormSheetState extends State<_ResidenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.residence?.name ?? '');
  late final _desc = TextEditingController(text: widget.residence?.description ?? '');
  late final _price = TextEditingController(text: widget.residence != null ? widget.residence!.pricePerNight.toString() : '');
  late final _capacity = TextEditingController(text: widget.residence?.capacity.toString() ?? '1');
  late final _address = TextEditingController(text: widget.residence?.address ?? '');
  String? _uploadedImageUrl;
  late String _category;
  late String _type;
  LatLng? _position;
  bool _loading = false;
  String? _error;

  static const _residenceTypes = [
    ('apartment', 'Appartement'), ('villa', 'Villa'), ('studio', 'Studio'), ('house', 'Maison'),
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.residence?.type ?? widget.initialCategory;
    _category = t == 'hotel' ? 'hotel' : 'residence';
    _type = widget.residence?.type ?? (widget.initialCategory == 'hotel' ? 'hotel' : 'apartment');
    _uploadedImageUrl = widget.residence?.imageUrl;
    if (widget.residence?.lat != null) _position = LatLng(widget.residence!.lat!, widget.residence!.lng!);
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); _price.dispose(); _capacity.dispose(); _address.dispose(); super.dispose(); }

  String get _effectiveType => _category == 'hotel' ? 'hotel' : _type;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final priceVal = int.tryParse(_price.text.replaceAll(' ', '').replaceAll(',', ''));
    if (priceVal == null) { setState(() => _error = 'Prix invalide'); return; }
    final capVal = int.tryParse(_capacity.text) ?? 1;
    setState(() { _loading = true; _error = null; });
    try {
      final imgUrl = _uploadedImageUrl;
      if (widget.residence == null) {
        await AdminApiExtra.adminCreateResidence(
          name: _name.text.trim(), type: _effectiveType, pricePerNight: priceVal, capacity: capVal,
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          imageUrl: imgUrl,
          lat: _position?.latitude, lng: _position?.longitude,
        );
      } else {
        await AdminApiExtra.adminUpdateResidence(widget.residence!.id, {
          'name': _name.text.trim(), 'type': _effectiveType, 'price_per_night': priceVal, 'capacity': capVal,
          if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          'image_url': imgUrl,
          if (_position != null) 'lat': _position!.latitude,
          if (_position != null) 'lng': _position!.longitude,
        });
      }
      if (mounted) { Navigator.of(context).pop(); widget.onDone(); _showSnack(context, widget.residence == null ? '${_category == 'hotel' ? 'Hôtel' : 'Résidence'} créé(e).' : 'Mis à jour.'); }
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  void _openMapPicker() async {
    final r = await showModalBottomSheet<LatLng>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(initial: _position ?? const LatLng(_kDefaultLat, _kDefaultLng)),
    );
    if (r != null && mounted) setState(() => _position = r);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.residence != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, sc) => Form(
            key: _formKey,
            child: ListView(
              controller: sc,
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
              children: [
                const _SheetDragHandle(),
                const SizedBox(height: 16),
                // Header
                Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(isEdit ? Icons.edit_rounded : Icons.add_home_rounded, size: 18, color: AdiakeColors.primaryContainer)),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'Modifier' : _category == 'hotel' ? 'Nouvel hôtel' : 'Nouvelle résidence', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
                ]),
                const SizedBox(height: 20),

                // Catégorie
                _FieldLabel('Catégorie'),
                const SizedBox(height: 8),
                Row(children: [
                  _CatChip(label: 'Résidence', icon: Icons.home_rounded, active: _category == 'residence', onTap: () => setState(() { _category = 'residence'; _type = 'apartment'; })),
                  const SizedBox(width: 10),
                  _CatChip(label: 'Hôtel', icon: Icons.hotel_rounded, active: _category == 'hotel', onTap: () => setState(() { _category = 'hotel'; _type = 'hotel'; })),
                ]),
                const SizedBox(height: 14),

                // Type résidence
                if (_category == 'residence') ...[
                  _FieldLabel('Type de résidence'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: _residenceTypes.map((t) {
                    final active = _type == t.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? AdiakeColors.primaryContainer.withValues(alpha: 0.10) : const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AdiakeColors.primaryContainer : const Color(0xFFE0E0E0), width: active ? 1.5 : 1),
                        ),
                        child: Text(t.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 14),
                ],

                TextFormField(controller: _name, validator: (v) => v!.trim().isEmpty ? 'Requis' : null, decoration: _fd('Nom', _category == 'hotel' ? Icons.hotel_rounded : Icons.home_rounded)),
                const SizedBox(height: 12),
                TextFormField(controller: _desc, maxLines: 3, decoration: _fd('Description (équipements, services…)', Icons.description_outlined)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(flex: 2, child: TextFormField(controller: _price, keyboardType: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Requis' : null, decoration: InputDecoration(labelText: 'Prix / nuit (F CFA)', suffixText: 'F', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _capacity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Capacité', suffixText: 'pers.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _address, decoration: _fd('Adresse complète', Icons.location_on_outlined)),
                const SizedBox(height: 12),

                // Photo principale
                AdminImagePickerField(
                  initialUrl: _uploadedImageUrl,
                  label: _category == 'hotel' ? 'Photo de l\'hôtel' : 'Photo de la résidence',
                  onUploaded: (url) => setState(() => _uploadedImageUrl = url),
                ),
                const SizedBox(height: 12),

                // Carte picker
                _FieldLabel('Position sur la carte'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openMapPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: _position != null ? AdiakeColors.primaryContainer : const Color(0xFFBBBBBB)),
                      borderRadius: BorderRadius.circular(14),
                      color: _position != null ? AdiakeColors.primaryContainer.withValues(alpha: 0.05) : Colors.transparent,
                    ),
                    child: Row(children: [
                      Icon(Icons.map_rounded, size: 20, color: _position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        _position != null ? '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}' : 'Sélectionner sur la carte',
                        style: TextStyle(fontSize: 13, color: _position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline, fontWeight: _position != null ? FontWeight.w700 : FontWeight.w400),
                      )),
                      Icon(Icons.chevron_right_rounded, color: _position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline),
                    ]),
                  ),
                ),
                if (_position != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(height: 150, child: FlutterMap(
                      options: MapOptions(initialCenter: _position!, initialZoom: 15),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.adiake.express'),
                        MarkerLayer(markers: [Marker(point: _position!, child: const Icon(Icons.location_pin, color: AdiakeColors.primaryContainer, size: 36))]),
                      ],
                    )),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEF9A9A))),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AdiakeColors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AdiakeColors.error, fontSize: 12))),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(isEdit ? 'Enregistrer' : _category == 'hotel' ? 'Créer l\'hôtel' : 'Créer la résidence', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fd(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.icon, required this.active, required this.onTap});
  final String label; final IconData icon; final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AdiakeColors.primaryContainer.withValues(alpha: 0.10) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AdiakeColors.primaryContainer : const Color(0xFFE0E0E0), width: active ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant)),
        ]),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdiakeColors.onSurfaceVariant));
}

// ── Map picker sheet ──────────────────────────────────────────────────────────

class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({required this.initial});
  final LatLng initial;

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  late LatLng _current;
  final _mc = MapController();

  @override
  void initState() { super.initState(); _current = widget.initial; }

  @override
  void dispose() { _mc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(children: [
        const _SheetDragHandle(),
        const SizedBox(height: 12),
        const Text('Sélectionner la position', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdiakeColors.primary)),
        const SizedBox(height: 4),
        const Text('Touchez la carte pour placer le marqueur', style: TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mc,
                options: MapOptions(initialCenter: _current, initialZoom: 14, onTap: (_, ll) => setState(() => _current = ll)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.adiake.express'),
                  MarkerLayer(markers: [Marker(point: _current, child: const Icon(Icons.location_pin, color: AdiakeColors.primaryContainer, size: 42))]),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
          child: Column(children: [
            Text('${_current.latitude.toStringAsFixed(6)}, ${_current.longitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_current),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmer cette position', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(3)))),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.search, required this.onSearch});
  final String search; final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onSearch,
    decoration: InputDecoration(
      hintText: 'Rechercher…', hintStyle: const TextStyle(fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      filled: true, fillColor: const Color(0xFFF4F5F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      isDense: true,
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(999)),
    child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
  );
}

void _showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: const Color(0xFF2E7D32),
    behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}
