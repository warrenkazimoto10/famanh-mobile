import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';

// Brand color for gas management
const _kGas = Color(0xFFE65100);
const _kBg  = Color(0xFFF5F4F6);

// ── Entry point ───────────────────────────────────────────────────────────────

class AdminGasScreen extends StatefulWidget {
  const AdminGasScreen({super.key});

  @override
  State<AdminGasScreen> createState() => _AdminGasScreenState();
}

class _AdminGasScreenState extends State<AdminGasScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gestion du Gaz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.propane_tank_rounded, size: 18), text: 'Produits'),
            Tab(icon: Icon(Icons.warehouse_rounded, size: 18), text: 'Dépôts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ProductsTab(),
          _DepotsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 – PRODUITS
// ══════════════════════════════════════════════════════════════════════════════

class _ProductsTab extends StatefulWidget {
  const _ProductsTab();

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  bool _loading = true;
  String? _error;
  List<AdminGasProductDto> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApiExtra.adminGasProducts();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleActive(AdminGasProductDto p) async {
    try {
      await AdminApiExtra.adminUpdateGasProduct(p.id, {'active': !p.active});
      await _load();
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    }
  }

  Future<void> _delete(AdminGasProductDto p) async {
    final ok = await _confirm(context, 'Supprimer "${p.brand} ${p.size}" ?');
    if (!ok || !mounted) return;
    try {
      await AdminApiExtra.adminDeleteGasProduct(p.id);
      await _load();
      if (mounted) _snackOk(context, 'Produit supprimé.');
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    }
  }

  Future<void> _openForm([AdminGasProductDto? p]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductForm(product: p, onSaved: () => Navigator.of(context).pop(true)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGas));
    if (_error != null) {
      return Center(child: _ErrorBody(message: _error!, onRetry: _load));
    }
    return Stack(
      children: [
        _items.isEmpty
            ? const Center(child: _EmptyState(icon: Icons.propane_tank_outlined, label: 'Aucun produit configuré'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ProductCard(
                  product: _items[i],
                  onEdit: () => _openForm(_items[i]),
                  onDelete: () => _delete(_items[i]),
                  onToggle: () => _toggleActive(_items[i]),
                ),
              ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: _kGas,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouveau produit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AdminGasProductDto product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  String _fmt(int v) => NumberFormat('#,###', 'fr').format(v);

  @override
  Widget build(BuildContext context) {
    final active = product.active;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? _kGas.withValues(alpha: 0.15) : const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header band
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: _kGas.withValues(alpha: active ? 0.08 : 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kGas.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.propane_tank, color: _kGas, size: 22)),
                        )
                      : const Icon(Icons.propane_tank, color: _kGas, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${product.brand}  •  ${product.size}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdiakeColors.primary)),
                      const SizedBox(height: 2),
                      Text(active ? 'Actif' : 'Inactif',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: active ? const Color(0xFF2E7D32) : AdiakeColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  activeTrackColor: _kGas,
                  activeThumbColor: Colors.white,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(child: _Chip(label: 'Prix', value: '${_fmt(product.priceFcfa)} F')),
                const SizedBox(width: 8),
                Expanded(child: _Chip(label: 'Consigne', value: product.depositFcfa > 0 ? '${_fmt(product.depositFcfa)} F' : '—')),
                const SizedBox(width: 8),
                Expanded(child: _Chip(label: 'Ordre', value: '${product.sort}')),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: _kGas,
                  tooltip: 'Modifier',
                  style: IconButton.styleFrom(backgroundColor: _kGas.withValues(alpha: 0.08)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AdiakeColors.error,
                  tooltip: 'Supprimer',
                  style: IconButton.styleFrom(backgroundColor: AdiakeColors.error.withValues(alpha: 0.07)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product, required this.onSaved});
  final AdminGasProductDto? product;
  final VoidCallback onSaved;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _size;
  late final TextEditingController _price;
  late final TextEditingController _deposit;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sort;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _brand    = TextEditingController(text: p?.brand ?? '');
    _size     = TextEditingController(text: p?.size ?? '');
    _price    = TextEditingController(text: p != null ? '${p.priceFcfa}' : '');
    _deposit  = TextEditingController(text: p != null && p.depositFcfa > 0 ? '${p.depositFcfa}' : '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _sort     = TextEditingController(text: p != null ? '${p.sort}' : '0');
    _active   = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [_brand, _size, _price, _deposit, _imageUrl, _sort]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'brand':               _brand.text.trim(),
        'size':                _size.text.trim(),
        'price_fcfa':          int.parse(_price.text.trim()),
        'bottle_deposit_fcfa': _deposit.text.trim().isEmpty ? 0 : int.parse(_deposit.text.trim()),
        'image_url':           _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
        'sort':                int.tryParse(_sort.text.trim()) ?? 0,
        'active':              _active,
      };
      if (widget.product == null) {
        await AdminApiExtra.adminCreateGasProduct(
          brand: data['brand'] as String,
          size: data['size'] as String,
          priceFcfa: data['price_fcfa'] as int,
          depositFcfa: data['bottle_deposit_fcfa'] as int,
          imageUrl: data['image_url'] as String?,
          active: data['active'] as bool,
          sort: data['sort'] as int,
        );
      } else {
        await AdminApiExtra.adminUpdateGasProduct(widget.product!.id, data);
      }
      if (mounted) { _snackOk(context, 'Produit enregistré.'); widget.onSaved(); }
    } catch (e) {
      if (mounted) { _snackError(context, e.toString()); setState(() => _saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return _BottomSheet(
      title: isEdit ? 'Modifier le produit' : 'Nouveau produit',
      color: _kGas,
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _Field(ctrl: _brand, label: 'Marque', hint: 'ex: Sodigaz', required: true)),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _size, label: 'Taille', hint: 'ex: 12kg', required: true)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(ctrl: _price, label: 'Prix (FCFA)', hint: '5000', required: true, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _deposit, label: 'Consigne (FCFA)', hint: '0', numeric: true)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 2, child: _Field(ctrl: _imageUrl, label: 'URL image', hint: 'https://...')),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _sort, label: 'Ordre', hint: '0', numeric: true)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Actif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
              const Spacer(),
              Switch(
                value: _active,
                activeTrackColor: _kGas,
                activeThumbColor: Colors.white,
                onChanged: (v) => setState(() => _active = v),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 – DÉPÔTS
// ══════════════════════════════════════════════════════════════════════════════

class _DepotsTab extends StatefulWidget {
  const _DepotsTab();

  @override
  State<_DepotsTab> createState() => _DepotsTabState();
}

class _DepotsTabState extends State<_DepotsTab> {
  bool _loading = true;
  String? _error;
  List<AdminGasDepotDto> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApiExtra.adminGasDepots();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleActive(AdminGasDepotDto d) async {
    try {
      await AdminApiExtra.adminUpdateGasDepot(d.id, {'active': !d.active});
      await _load();
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    }
  }

  Future<void> _delete(AdminGasDepotDto d) async {
    final ok = await _confirm(context, 'Supprimer le dépôt "${d.name}" ?');
    if (!ok || !mounted) return;
    try {
      await AdminApiExtra.adminDeleteGasDepot(d.id);
      await _load();
      if (mounted) _snackOk(context, 'Dépôt supprimé.');
    } catch (e) {
      if (mounted) _snackError(context, e.toString());
    }
  }

  Future<void> _openForm([AdminGasDepotDto? d]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepotForm(depot: d, onSaved: () => Navigator.of(context).pop(true)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGas));
    if (_error != null) {
      return Center(child: _ErrorBody(message: _error!, onRetry: _load));
    }
    return Stack(
      children: [
        _items.isEmpty
            ? const Center(child: _EmptyState(icon: Icons.warehouse_outlined, label: 'Aucun dépôt configuré'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DepotCard(
                  depot: _items[i],
                  onEdit: () => _openForm(_items[i]),
                  onDelete: () => _delete(_items[i]),
                  onToggle: () => _toggleActive(_items[i]),
                ),
              ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: _kGas,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouveau dépôt', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _DepotCard extends StatelessWidget {
  const _DepotCard({
    required this.depot,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AdminGasDepotDto depot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = depot.active;
    final hasCoords = depot.lat != null && depot.lng != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? _kGas.withValues(alpha: 0.15) : const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: _kGas.withValues(alpha: active ? 0.08 : 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _kGas.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.warehouse_rounded, color: _kGas, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(depot.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdiakeColors.primary)),
                      const SizedBox(height: 2),
                      Text(
                        depot.city?.isNotEmpty == true ? depot.city! : (active ? 'Actif' : 'Inactif'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: active ? const Color(0xFF2E7D32) : AdiakeColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  activeTrackColor: _kGas,
                  activeThumbColor: Colors.white,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: _Chip(
                    label: 'Coordonnées',
                    value: hasCoords
                        ? '${depot.lat!.toStringAsFixed(4)}, ${depot.lng!.toStringAsFixed(4)}'
                        : 'Non définies',
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: _kGas,
                  tooltip: 'Modifier',
                  style: IconButton.styleFrom(backgroundColor: _kGas.withValues(alpha: 0.08)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AdiakeColors.error,
                  tooltip: 'Supprimer',
                  style: IconButton.styleFrom(backgroundColor: AdiakeColors.error.withValues(alpha: 0.07)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DepotForm extends StatefulWidget {
  const _DepotForm({this.depot, required this.onSaved});
  final AdminGasDepotDto? depot;
  final VoidCallback onSaved;

  @override
  State<_DepotForm> createState() => _DepotFormState();
}

class _DepotFormState extends State<_DepotForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.depot;
    _name   = TextEditingController(text: d?.name ?? '');
    _city   = TextEditingController(text: d?.city ?? '');
    _lat    = TextEditingController(text: d?.lat != null ? '${d!.lat}' : '');
    _lng    = TextEditingController(text: d?.lng != null ? '${d!.lng}' : '');
    _active = d?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _lat, _lng]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final latVal = double.tryParse(_lat.text.trim());
      final lngVal = double.tryParse(_lng.text.trim());
      final data = {
        'name':   _name.text.trim(),
        'city':   _city.text.trim().isEmpty ? null : _city.text.trim(),
        'lat':    latVal,
        'lng':    lngVal,
        'active': _active,
      };
      if (widget.depot == null) {
        await AdminApiExtra.adminCreateGasDepot(
          name: data['name'] as String,
          city: data['city'] as String?,
          lat: latVal,
          lng: lngVal,
          active: _active,
        );
      } else {
        await AdminApiExtra.adminUpdateGasDepot(widget.depot!.id, data);
      }
      if (mounted) { _snackOk(context, 'Dépôt enregistré.'); widget.onSaved(); }
    } catch (e) {
      if (mounted) { _snackError(context, e.toString()); setState(() => _saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.depot != null;
    return _BottomSheet(
      title: isEdit ? 'Modifier le dépôt' : 'Nouveau dépôt',
      color: _kGas,
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _Field(ctrl: _name, label: 'Nom du dépôt', hint: 'ex: Dépôt Adiaké Centre', required: true),
            const SizedBox(height: 12),
            _Field(ctrl: _city, label: 'Ville / Zone', hint: 'ex: Adiaké'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(ctrl: _lat, label: 'Latitude', hint: '5.2867',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < -90 || n > 90) return 'Invalide';
                    return null;
                  })),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _lng, label: 'Longitude', hint: '-3.3042',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < -180 || n > 180) return 'Invalide';
                    return null;
                  })),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Actif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
              const Spacer(),
              Switch(
                value: _active,
                activeTrackColor: _kGas,
                activeThumbColor: Colors.white,
                onChanged: (v) => setState(() => _active = v),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.title,
    required this.color,
    required this.saving,
    required this.onSave,
    required this.child,
  });

  final String title;
  final Color color;
  final bool saving;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(width: 44, height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.edit_rounded, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AdiakeColors.outline,
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: AdiakeColors.onSurfaceVariant, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AdiakeColors.primary),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.required = false,
    this.numeric = false,
    this.validator,
  });

  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool required;
  final bool numeric;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGas, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      validator: validator ?? (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Champ requis';
        if (numeric && v != null && v.trim().isNotEmpty) {
          if (int.tryParse(v.trim()) == null && double.tryParse(v.trim()) == null) return 'Nombre invalide';
        }
        return null;
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: _kGas.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: Icon(icon, color: _kGas, size: 36),
        ),
        const SizedBox(height: 14),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AdiakeColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        const Text('Appuyez sur + pour en ajouter un.',
            style: TextStyle(fontSize: 13, color: AdiakeColors.outline)),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AdiakeColors.error, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AdiakeColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: FilledButton.styleFrom(backgroundColor: _kGas),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AdiakeColors.error, size: 22),
        SizedBox(width: 8),
        Text('Confirmer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error),
          child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result == true;
}

void _snackOk(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: const Color(0xFF2E7D32),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));
}

void _snackError(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: AdiakeColors.primaryContainer,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 4),
  ));
}
