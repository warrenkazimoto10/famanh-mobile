import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
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

// ─── Restaurants screen ───────────────────────────────────────────────────────

class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  bool _loading = true;
  String? _error;
  List<AdminRestaurantDto> _restaurants = const [];
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApiExtra.adminRestaurants();
      if (mounted) setState(() { _restaurants = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<AdminRestaurantDto> get _filtered {
    if (_search.isEmpty) return _restaurants;
    final q = _search.toLowerCase();
    return _restaurants.where((r) =>
      r.name.toLowerCase().contains(q) ||
      (r.description?.toLowerCase().contains(q) ?? false) ||
      (r.address?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void _openForm(AdminRestaurantDto? r) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _RestaurantFormSheet(restaurant: r, onDone: _load),
  );

  void _openDishes(AdminRestaurantDto r) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DishesPage(restaurant: r)));

  Future<void> _confirmDelete(AdminRestaurantDto r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce restaurant ?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('« ${r.name} » et tous ses plats seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AdminApiExtra.adminDeleteRestaurant(r.id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(children: [
        _TopBar(count: _filtered.length, search: _search, onSearch: (v) => setState(() => _search = v)),
        Expanded(
          child: _loading ? _buildSkeleton(isWide)
              : _error != null ? _buildError()
              : _filtered.isEmpty ? _emptyState()
              : _buildGrid(isWide: isWide),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Nouveau restaurant', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AdiakeColors.primaryContainer, foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSkeleton(bool isWide) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isWide ? 3 : 1, childAspectRatio: 1.8, crossAxisSpacing: 14, mainAxisSpacing: 14),
    itemCount: 4, itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: double.infinity, borderRadius: 18),
  );

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
    const SizedBox(height: 12),
    Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
  ]));

  Widget _emptyState() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.storefront_outlined, size: 56, color: AdiakeColors.outline),
    SizedBox(height: 12),
    Text('Aucun restaurant', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
  ]));

  Widget _buildGrid({required bool isWide}) {
    final filtered = _filtered;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 16 : 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : 1,
        childAspectRatio: isWide ? 1.1 : 2.4,
        crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _RestaurantCard(
        restaurant: filtered[i],
        onEdit: () => _openForm(filtered[i]),
        onDishes: () => _openDishes(filtered[i]),
        onDelete: () => _confirmDelete(filtered[i]),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.count, required this.search, required this.onSearch});
  final int count; final String search; final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Text('Restaurants', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(999)), child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant))),
        const SizedBox(width: 12),
        Expanded(child: TextField(
          onChanged: onSearch,
          decoration: InputDecoration(hintText: 'Rechercher…', hintStyle: const TextStyle(fontSize: 13), prefixIcon: const Icon(Icons.search_rounded, size: 18), filled: true, fillColor: const Color(0xFFF4F5F7), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), isDense: true),
        )),
      ]),
    );
  }
}

// ── Restaurant card ───────────────────────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.onEdit, required this.onDishes, required this.onDelete});
  final AdminRestaurantDto restaurant; final VoidCallback onEdit; final VoidCallback onDishes; final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: _kShadow),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onDishes,
        child: Row(children: [
          // Image côté gauche
          SizedBox(
            width: 110,
            child: Stack(fit: StackFit.expand, children: [
              restaurant.imageUrl != null
                  ? Image.network(restaurant.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0x00000000), Color(0x00000000)]))),
            ]),
          ),
          // Info droite
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdiakeColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _CardMenu(onEdit: onEdit, onDelete: onDelete),
                ]),
                if (restaurant.description != null) ...[
                  const SizedBox(height: 2),
                  Text(restaurant.description!, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const Spacer(),
                if (restaurant.phone != null)
                  _InfoChip(icon: Icons.phone_rounded, text: restaurant.phone!),
                if (restaurant.address != null)
                  _InfoChip(icon: Icons.location_on_rounded, text: restaurant.address!),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.restaurant_menu_rounded, size: 13, color: AdiakeColors.primaryContainer),
                    const SizedBox(width: 5),
                    Text('${restaurant.dishesCount} plat${restaurant.dishesCount > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdiakeColors.primaryContainer)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: AdiakeColors.primaryContainer),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF7043), AdiakeColors.primaryContainer])),
    child: const Center(child: Icon(Icons.storefront_rounded, size: 32, color: Colors.white)),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon; final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Icon(icon, size: 11, color: AdiakeColors.outline),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit; final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AdiakeColors.outline),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: EdgeInsets.zero,
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Modifier')])),
      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AdiakeColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AdiakeColors.error))])),
    ],
    onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
  );
}

// ── Restaurant form ───────────────────────────────────────────────────────────

class _RestaurantFormSheet extends StatefulWidget {
  const _RestaurantFormSheet({this.restaurant, required this.onDone});
  final AdminRestaurantDto? restaurant; final VoidCallback onDone;

  @override
  State<_RestaurantFormSheet> createState() => _RestaurantFormSheetState();
}

class _RestaurantFormSheetState extends State<_RestaurantFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.restaurant?.name ?? '');
  late final _desc = TextEditingController(text: widget.restaurant?.description ?? '');
  late final _phone = TextEditingController(text: widget.restaurant?.phone ?? '');
  late final _address = TextEditingController(text: widget.restaurant?.address ?? '');
  String? _uploadedImageUrl;
  LatLng? _position;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _uploadedImageUrl = widget.restaurant?.imageUrl;
    if (widget.restaurant?.lat != null) _position = LatLng(widget.restaurant!.lat!, widget.restaurant!.lng!);
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); _phone.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.restaurant == null) {
        await AdminApiExtra.adminCreateRestaurant(name: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), address: _address.text.trim().isEmpty ? null : _address.text.trim(), imageUrl: _uploadedImageUrl, lat: _position?.latitude, lng: _position?.longitude);
      } else {
        await AdminApiExtra.adminUpdateRestaurant(widget.restaurant!.id, name: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), address: _address.text.trim().isEmpty ? null : _address.text.trim(), imageUrl: _uploadedImageUrl, lat: _position?.latitude, lng: _position?.longitude);
      }
      if (mounted) { Navigator.of(context).pop(); widget.onDone(); _snack(context, widget.restaurant == null ? 'Restaurant créé.' : 'Restaurant mis à jour.'); }
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  void _openMapPicker() async {
    final r = await showModalBottomSheet<LatLng>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _MapPickerSheet(initial: _position ?? const LatLng(_kDefaultLat, _kDefaultLng), title: 'Positionner le restaurant'));
    if (r != null && mounted) setState(() => _position = r);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      initialChildSize: 0.9,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _SheetHeader(title: widget.restaurant == null ? 'Nouveau restaurant' : 'Modifier le restaurant', icon: Icons.storefront_rounded),
          TextFormField(controller: _name, validator: (v) => v!.trim().isEmpty ? 'Requis' : null, decoration: _fd('Nom du restaurant', Icons.storefront_outlined)),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 3, decoration: _fd('Description (spécialités, cuisine…)', Icons.description_outlined)),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _fd('Téléphone', Icons.phone_rounded)),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: _fd('Adresse', Icons.location_on_outlined)),
          const SizedBox(height: 12),
          AdminImagePickerField(
            initialUrl: _uploadedImageUrl,
            label: 'Photo du restaurant',
            onUploaded: (url) => setState(() => _uploadedImageUrl = url),
          ),
          const SizedBox(height: 12),
          _MapPickerButton(position: _position, onTap: _openMapPicker),
          if (_position != null) ...[
            const SizedBox(height: 8),
            _MiniMap(position: _position!),
          ],
          _SheetError(error: _error),
          const SizedBox(height: 16),
          _SheetPrimaryButton(loading: _loading, label: widget.restaurant == null ? 'Créer le restaurant' : 'Enregistrer', onTap: _submit),
        ]),
      ),
    );
  }

  InputDecoration _fd(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
}

// ── Dishes page ───────────────────────────────────────────────────────────────

class _DishesPage extends StatefulWidget {
  const _DishesPage({required this.restaurant});
  final AdminRestaurantDto restaurant;

  @override
  State<_DishesPage> createState() => _DishesPageState();
}

class _DishesPageState extends State<_DishesPage> {
  bool _loading = true;
  String? _error;
  List<AdminDishDto> _dishes = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await AdminApiExtra.adminDishes(widget.restaurant.id);
      if (mounted) setState(() { _dishes = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openForm({AdminDishDto? dish}) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _DishFormSheet(restaurantId: widget.restaurant.id, dish: dish, onDone: _load),
  );

  void _openDetail(AdminDishDto dish) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _DishDetailSheet(
      dish: dish,
      onEdit: () { Navigator.of(context).pop(); _openForm(dish: dish); },
      onToggle: () { Navigator.of(context).pop(); _toggleActive(dish); },
      onDelete: () { Navigator.of(context).pop(); _confirmDelete(dish); },
    ),
  );

  Future<void> _toggleActive(AdminDishDto d) async {
    try {
      await AdminApiExtra.adminUpdateDish(d.id, isActive: !d.isActive);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete(AdminDishDto d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce plat ?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('« ${d.name} » sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try { await AdminApiExtra.adminDeleteDish(d.id); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: AdiakeColors.primary),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.restaurant.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdiakeColors.primary)),
          const Text('Gestion des plats', style: TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AdiakeColors.primaryContainer), onPressed: _load),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? ListView.separated(padding: const EdgeInsets.all(16), itemCount: 6, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 90, borderRadius: 16))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!, style: const TextStyle(color: AdiakeColors.error)), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Réessayer'))]))
              : _dishes.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.restaurant_menu_outlined, size: 56, color: AdiakeColors.outline),
                      SizedBox(height: 12),
                      Text('Aucun plat', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Appuyez sur + pour ajouter un plat', style: TextStyle(color: AdiakeColors.outline, fontSize: 13)),
                    ]))
                  : isWide
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
                          itemCount: _dishes.length,
                          itemBuilder: (_, i) => _DishCard(dish: _dishes[i], onTap: () => _openDetail(_dishes[i]), onToggle: () => _toggleActive(_dishes[i])),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _dishes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _DishCard(dish: _dishes[i], onTap: () => _openDetail(_dishes[i]), onToggle: () => _toggleActive(_dishes[i])),
                        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un plat', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AdiakeColors.primaryContainer, foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Dish card ─────────────────────────────────────────────────────────────────

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.onTap, required this.onToggle});
  final AdminDishDto dish; final VoidCallback onTap; final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat('#,###', 'fr').format(dish.priceFcfa);
    final active = dish.isActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _kShadow),
        clipBehavior: Clip.hardEdge,
        child: Row(children: [
          // Photo / placeholder
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(fit: StackFit.expand, children: [
              dish.allPhotoUrls.isNotEmpty
                  ? Image.network(dish.allPhotoUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder(active))
                  : _imgPlaceholder(active),
              if (!active)
                Container(color: Colors.black.withValues(alpha: 0.35)),
              if (!active)
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Inactif', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                )),
            ]),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, mainAxisSize: MainAxisSize.min, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(dish.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdiakeColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (dish.description != null && dish.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dish.description!, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ]),
                Row(children: [
                  Text('$price F', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdiakeColors.primaryContainer)),
                  const Spacer(),
                  // Status toggle inline
                  GestureDetector(
                    onTap: onToggle,
                    child: Row(children: [
                      Text(active ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF2E7D32) : AdiakeColors.outline)),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: active,
                          onChanged: (_) => onToggle(),
                          activeColor: const Color(0xFF2E7D32),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder(bool active) => Container(
    color: active ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
    child: Center(child: Icon(Icons.lunch_dining_rounded, size: 32, color: active ? const Color(0xFFFF7043) : AdiakeColors.outline)),
  );
}

// ── Dish detail sheet ─────────────────────────────────────────────────────────

class _DishDetailSheet extends StatelessWidget {
  const _DishDetailSheet({required this.dish, required this.onEdit, required this.onToggle, required this.onDelete});
  final AdminDishDto dish; final VoidCallback onEdit; final VoidCallback onToggle; final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat('#,###', 'fr').format(dish.priceFcfa);
    final active = dish.isActive;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const _DragHandle(),
        // Hero photo / carousel
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
          child: _PhotoCarousel(photoUrls: dish.allPhotoUrls, active: active),
        ),
        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(dish.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AdiakeColors.primary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(active ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? const Color(0xFF2E7D32) : AdiakeColors.outline)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('$price F CFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AdiakeColors.primaryContainer)),
            if (dish.description != null && dish.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(dish.description!, style: const TextStyle(fontSize: 14, color: AdiakeColors.primary, height: 1.5)),
            ],
            const SizedBox(height: 20),
            // Status toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(active ? Icons.visibility_rounded : Icons.visibility_off_outlined, size: 18, color: active ? const Color(0xFF2E7D32) : AdiakeColors.outline),
                const SizedBox(width: 10),
                Text('Plat ${active ? 'visible' : 'masqué'} sur l\'application', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(value: active, onChanged: (_) => onToggle(), activeColor: const Color(0xFF2E7D32)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: AdiakeColors.primaryContainer), foregroundColor: AdiakeColors.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), backgroundColor: AdiakeColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

}

// ── Photo carousel ────────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photoUrls, required this.active});
  final List<String> photoUrls; final bool active;
  @override State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _ctrl = PageController();
  int _page = 0;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) return _banner();
    return SizedBox(
      height: 200, width: double.infinity,
      child: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          onPageChanged: (i) => setState(() => _page = i),
          itemCount: widget.photoUrls.length,
          itemBuilder: (_, i) => Image.network(
            widget.photoUrls[i], fit: BoxFit.cover, width: double.infinity,
            errorBuilder: (_, __, ___) => _banner(),
          ),
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photoUrls.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 16.0 : 6.0,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? Colors.white : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ]),
    );
  }

  Widget _banner() => Container(
    height: 200, width: double.infinity,
    color: widget.active ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
    child: Center(child: Icon(Icons.lunch_dining_rounded, size: 64,
      color: widget.active ? const Color(0xFFFF7043).withValues(alpha: 0.5) : AdiakeColors.outline.withValues(alpha: 0.3))),
  );
}

// ── Dish form ─────────────────────────────────────────────────────────────────

class _DishFormSheet extends StatefulWidget {
  const _DishFormSheet({required this.restaurantId, this.dish, required this.onDone});
  final int restaurantId; final AdminDishDto? dish; final VoidCallback onDone;

  @override
  State<_DishFormSheet> createState() => _DishFormSheetState();
}

class _DishFormSheetState extends State<_DishFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.dish?.name ?? '');
  late final _desc = TextEditingController(text: widget.dish?.description ?? '');
  late final _price = TextEditingController(text: widget.dish != null ? widget.dish!.priceFcfa.toString() : '');
  String? _uploadedImageUrl;
  late bool _active = widget.dish?.isActive ?? true;
  late final List<AdminDishPhotoDto> _photos = List.from(widget.dish?.photos ?? []);
  bool _loading = false; bool _photoAdding = false; String? _error;

  @override
  void initState() {
    super.initState();
    _uploadedImageUrl = widget.dish?.imageUrl;
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); _price.dispose(); super.dispose(); }

  Future<void> _addExtraPhoto() async {
    if (widget.dish == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _photoAdding = true);
    try {
      final url = await AdminApiExtra.adminUploadPhoto(file);
      final p = await AdminApiExtra.adminAddDishPhoto(widget.dish!.id, url);
      if (mounted) setState(() { _photos.add(p); _photoAdding = false; });
    } catch (e) {
      if (mounted) setState(() { _photoAdding = false; _error = e.toString(); });
    }
  }

  Future<void> _removeExtraPhoto(AdminDishPhotoDto photo) async {
    try {
      await AdminApiExtra.adminDeleteDishPhoto(photo.id);
      if (mounted) setState(() => _photos.removeWhere((p) => p.id == photo.id));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final priceVal = int.tryParse(_price.text.replaceAll(' ', '').replaceAll(',', ''));
    if (priceVal == null) { setState(() => _error = 'Prix invalide'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.dish == null) {
        await AdminApiExtra.adminCreateDish(widget.restaurantId, name: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), priceFcfa: priceVal, imageUrl: _uploadedImageUrl);
      } else {
        await AdminApiExtra.adminUpdateDish(widget.dish!.id, name: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), priceFcfa: priceVal, isActive: _active, imageUrl: _uploadedImageUrl);
      }
      if (mounted) { Navigator.of(context).pop(); widget.onDone(); _snack(context, widget.dish == null ? 'Plat ajouté.' : 'Plat mis à jour.'); }
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      initialChildSize: 0.85,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _SheetHeader(title: widget.dish == null ? 'Nouveau plat' : 'Modifier le plat', icon: Icons.lunch_dining_rounded),
          AdminImagePickerField(
            initialUrl: _uploadedImageUrl,
            label: 'Photo principale du plat',
            height: 130,
            onUploaded: (url) => setState(() => _uploadedImageUrl = url),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _name, validator: (v) => v!.trim().isEmpty ? 'Requis' : null, decoration: _fd('Nom du plat', Icons.lunch_dining_rounded)),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 2, decoration: _fd('Description (ingrédients, allergènes…)', Icons.description_outlined)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
            decoration: InputDecoration(labelText: 'Prix (F CFA)', prefixIcon: const Icon(Icons.payments_outlined, size: 18), suffixText: 'F', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          // Photos supplémentaires (edition uniquement)
          if (widget.dish != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Text('Photos supplémentaires', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
              const Spacer(),
              _photoAdding
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _addExtraPhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 16, color: AdiakeColors.primaryContainer),
                          SizedBox(width: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.primaryContainer)),
                        ]),
                      ),
                    ),
            ]),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = _photos[i];
                    return Stack(clipBehavior: Clip.none, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(p.url, width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.broken_image_outlined, color: AdiakeColors.outline))),
                      ),
                      Positioned(
                        top: -4, right: -4,
                        child: GestureDetector(
                          onTap: () => _removeExtraPhoto(p),
                          child: Container(
                            width: 22, height: 22,
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
          ],
          if (widget.dish != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Text('Statut du plat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_active ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _active ? const Color(0xFF2E7D32) : AdiakeColors.outline)),
                const SizedBox(width: 8),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v), activeColor: const Color(0xFF2E7D32)),
              ]),
            ),
          ],
          _SheetError(error: _error),
          const SizedBox(height: 16),
          _SheetPrimaryButton(loading: _loading, label: widget.dish == null ? 'Ajouter le plat' : 'Enregistrer', onTap: _submit),
        ]),
      ),
    );
  }

  InputDecoration _fd(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
}

// ── Map picker ────────────────────────────────────────────────────────────────

class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({required this.initial, required this.title});
  final LatLng initial; final String title;

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
        const _DragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdiakeColors.primary)),
            const SizedBox(height: 4),
            const Text('Touchez la carte pour placer le marqueur', style: TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
          ]),
        ),
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
            _SheetPrimaryButton(loading: false, label: 'Confirmer cette position', onTap: () => Navigator.of(context).pop(_current), icon: Icons.check_rounded),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared sheet design system ────────────────────────────────────────────────

class _SheetWrapper extends StatelessWidget {
  const _SheetWrapper({required this.child, this.initialChildSize = 0.8});
  final Widget child; final double initialChildSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.icon});
  final String title; final IconData? icon;

  @override
  Widget build(BuildContext context) => Column(children: [
    const _DragHandle(),
    const SizedBox(height: 16),
    Row(children: [
      if (icon != null) ...[
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AdiakeColors.primaryContainer.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: AdiakeColors.primaryContainer)),
        const SizedBox(width: 12),
      ],
      Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdiakeColors.primary))),
    ]),
    const SizedBox(height: 20),
  ]);
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(3))),
  );
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEF9A9A))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AdiakeColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(error!, style: const TextStyle(color: AdiakeColors.error, fontSize: 12))),
        ]),
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  const _SheetPrimaryButton({required this.loading, required this.label, required this.onTap, this.icon});
  final bool loading; final String label; final VoidCallback onTap; final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
    ),
  );
}

class _MapPickerButton extends StatelessWidget {
  const _MapPickerButton({required this.position, required this.onTap});
  final LatLng? position; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: position != null ? AdiakeColors.primaryContainer : const Color(0xFFBBBBBB)),
        borderRadius: BorderRadius.circular(14),
        color: position != null ? AdiakeColors.primaryContainer.withValues(alpha: 0.05) : Colors.transparent,
      ),
      child: Row(children: [
        Icon(Icons.map_rounded, size: 20, color: position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline),
        const SizedBox(width: 10),
        Expanded(child: Text(
          position != null ? '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}' : 'Sélectionner la position sur la carte',
          style: TextStyle(fontSize: 13, color: position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline, fontWeight: position != null ? FontWeight.w700 : FontWeight.w400),
        )),
        Icon(Icons.chevron_right_rounded, color: position != null ? AdiakeColors.primaryContainer : AdiakeColors.outline),
      ]),
    ),
  );
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.position});
  final LatLng position;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 140,
      child: FlutterMap(
        options: MapOptions(initialCenter: position, initialZoom: 15),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.adiake.express'),
          MarkerLayer(markers: [Marker(point: position, child: const Icon(Icons.location_pin, color: AdiakeColors.primaryContainer, size: 36))]),
        ],
      ),
    ),
  );
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF2E7D32), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
}
