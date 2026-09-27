import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';
import 'admin_revenue_screen.dart';

const _kShadow = [
  BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x05000000), blurRadius: 20, offset: Offset(0, 6)),
];

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this)..addListener(_onTab);

  static const _types = ['gas', 'parcel', 'food', 'residence'];
  static const _labels = ['Gaz', 'Colis', 'Nourriture', 'Résidence'];

  bool _loading = true;
  String? _error;
  List<AdminOrderDto> _orders = const [];
  int _total = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _loadingMore = false;

  String? _filterStatus;
  String _search = '';

  List<AdminUserDto> _drivers = const [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _load(reset: true);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tab.indexIsChanging) return;
    _filterStatus = null;
    _load(reset: true);
  }

  String get _type => _types[_tab.index];

  Future<void> _loadDrivers() async {
    try {
      final d = await AdminApi.adminDriversList();
      if (mounted) setState(() => _drivers = d);
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _loading = true; _error = null; _orders = []; _page = 1; });
    try {
      final result = await AdminApi.adminOrders(type: _type, page: _page);
      if (!mounted) return;
      setState(() {
        _orders = reset ? result.items : [..._orders, ...result.items];
        _total = result.total;
        _lastPage = result.lastPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; _error = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() { _loadingMore = true; _page++; });
    await _load();
  }

  List<AdminOrderDto> get _filtered {
    var list = _orders;
    if (_filterStatus != null) list = list.where((o) => o.status == _filterStatus).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((o) => (o.clientName?.toLowerCase().contains(q) ?? false) || '#${o.id}'.contains(q)).toList();
    }
    return list;
  }

  void _openAssign(AdminOrderDto order) {
    if (_drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun livreur disponible.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(order: order, drivers: _drivers, type: _type, onDone: () => _load(reset: true)),
    );
  }

  void _openDetail(AdminOrderDto order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        drivers: _drivers,
        onStatusChanged: (newStatus) {
          final idx = _orders.indexWhere((o) => o.id == order.id);
          if (idx != -1 && mounted) setState(() => _orders[idx] = _orders[idx].copyWith(status: newStatus));
        },
        onAssign: () {
          Navigator.of(context).pop();
          _openAssign(order);
        },
        onRefresh: () => _load(reset: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          _TopBar(
            total: _total,
            search: _search,
            onSearch: (v) => setState(() => _search = v),
            onRevenue: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRevenueScreen())),
          ),
          _TabRow(tab: _tab, labels: _labels),
          _FilterChips(
            current: _filterStatus,
            onSelect: (s) => setState(() => _filterStatus = _filterStatus == s ? null : s),
            orderType: _type,
          ),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null
                    ? _buildError()
                    : _buildList(isWide),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const SkeletonLoader(width: double.infinity, height: 82, borderRadius: 14),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AdiakeColors.outline),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AdiakeColors.error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildList(bool isWide) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: AdiakeColors.outline),
          SizedBox(height: 12),
          Text('Aucune commande', style: TextStyle(color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: isWide
          ? _WideTable(orders: filtered, onAssign: _openAssign, onTap: _openDetail, loadingMore: _loadingMore)
          : _CardList(orders: filtered, onAssign: _openAssign, onTap: _openDetail, loadingMore: _loadingMore),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.total, required this.search, required this.onSearch, required this.onRevenue});
  final int total;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onRevenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text('Commandes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AdiakeColors.primary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(999)),
            child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRevenue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF2E7D32)),
                SizedBox(width: 4),
                Text('Revenus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tab, required this.labels});
  final TabController tab;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tab,
        labelColor: AdiakeColors.primaryContainer,
        unselectedLabelColor: AdiakeColors.outline,
        indicatorColor: AdiakeColors.primaryContainer,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: labels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onSelect, required this.orderType});
  final String? current;
  final ValueChanged<String> onSelect;
  final String orderType;

  static const _deliveryStatuses = [
    ('pending', 'En attente'),
    ('accepted', 'Acceptée'),
    ('en_route', 'En route'),
    ('delivered_paid', 'Livrée'),
    ('cancelled', 'Annulée'),
  ];

  static const _residenceStatuses = [
    ('pending', 'En attente'),
    ('confirmed', 'Confirmée'),
    ('checked_in', 'Arrivée'),
    ('checked_out', 'Terminée'),
    ('cancelled', 'Annulée'),
  ];

  @override
  Widget build(BuildContext context) {
    final statuses = orderType == 'residence' ? _residenceStatuses : _deliveryStatuses;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((s) {
            final (key, label) = s;
            final active = current == key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                selected: active,
                onSelected: (_) => onSelect(key),
                selectedColor: AdiakeColors.primaryContainer.withValues(alpha: 0.12),
                checkmarkColor: AdiakeColors.primaryContainer,
                labelStyle: TextStyle(color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant),
                side: BorderSide(color: active ? AdiakeColors.primaryContainer.withValues(alpha: 0.4) : const Color(0xFFE0E0E0)),
                backgroundColor: const Color(0xFFF8F8F8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Wide table ────────────────────────────────────────────────────────────────

class _WideTable extends StatelessWidget {
  const _WideTable({required this.orders, required this.onAssign, required this.onTap, required this.loadingMore});
  final List<AdminOrderDto> orders;
  final ValueChanged<AdminOrderDto> onAssign;
  final ValueChanged<AdminOrderDto> onTap;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _kShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header row
            Container(
              color: const Color(0xFFF8F8F8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  SizedBox(width: 56, child: Text('ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  Expanded(flex: 3, child: Text('Client', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  Expanded(flex: 2, child: Text('Livreur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  SizedBox(width: 80, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                  SizedBox(width: 90, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdiakeColors.onSurfaceVariant))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: orders.length + (loadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF2F2F2)),
                itemBuilder: (_, i) {
                  if (i == orders.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
                  final o = orders[i];
                  return _TableRow(order: o, onAssign: () => onAssign(o), onTap: () => onTap(o));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.order, required this.onAssign, required this.onTap});
  final AdminOrderDto order;
  final VoidCallback onAssign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = order.priceFcfa != null ? NumberFormat('#,###', 'fr').format(order.priceFcfa) + ' F' : '—';

    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
              child: Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AdiakeColors.primary)),
            ),
          ),
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.clientName ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdiakeColors.primary), overflow: TextOverflow.ellipsis),
              if (order.clientPhone != null)
                Text(order.clientPhone!, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant)),
            ],
          )),
          Expanded(flex: 2, child: _StatusChip(status: order.status)),
          Expanded(flex: 2, child: Text(order.driverName ?? '—', style: TextStyle(fontSize: 12, color: order.driverName != null ? const Color(0xFF2E7D32) : AdiakeColors.outline, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 80, child: Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdiakeColors.primary))),
          SizedBox(
            width: 90,
            child: order.status == 'pending'
                ? SizedBox(
                    height: 28,
                    child: FilledButton(
                      onPressed: onAssign,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      child: const Text('Assigner'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ));
  }
}

// ── Card list (narrow) ────────────────────────────────────────────────────────

class _CardList extends StatelessWidget {
  const _CardList({required this.orders, required this.onAssign, required this.onTap, required this.loadingMore});
  final List<AdminOrderDto> orders;
  final ValueChanged<AdminOrderDto> onAssign;
  final ValueChanged<AdminOrderDto> onTap;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: orders.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == orders.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
        final o = orders[i];
        return _OrderCard(order: o, onAssign: () => onAssign(o), onTap: () => onTap(o));
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAssign, required this.onTap});
  final AdminOrderDto order;
  final VoidCallback onAssign;
  final VoidCallback onTap;

  static final _typeColors = {
    'gas': const Color(0xFFE65100), 'parcel': const Color(0xFF1565C0),
    'food': const Color(0xFF2E7D32), 'residence': const Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    final price = order.priceFcfa != null ? NumberFormat('#,###', 'fr').format(order.priceFcfa) + ' F' : '—';
    final date = DateFormat('dd/MM · HH:mm').format(order.createdAt);
    final typeColor = _typeColors[order.type] ?? AdiakeColors.primaryContainer;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _kShadow),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: typeColor.withValues(alpha: 0.06),
          highlightColor: typeColor.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Color bar top ──
              Container(height: 3, color: typeColor),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(7)),
                      child: Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AdiakeColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: order.status),
                    const Spacer(),
                    Text(date, style: const TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(order.clientName ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
                      if (order.clientPhone != null)
                        Text(order.clientPhone!, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdiakeColors.primary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('Voir détails', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
                        Icon(Icons.chevron_right_rounded, size: 14, color: typeColor),
                      ]),
                    ]),
                  ]),
                  if (order.driverName != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.delivery_dining_rounded, size: 14, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(order.driverName!, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                    ]),
                  ],
                  if (order.status == 'pending') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Assigner un livreur'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          side: BorderSide(color: typeColor.withValues(alpha: 0.4)),
                          foregroundColor: typeColor,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order detail sheet ────────────────────────────────────────────────────────

class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({
    required this.order,
    required this.drivers,
    required this.onStatusChanged,
    required this.onAssign,
    required this.onRefresh,
  });
  final AdminOrderDto order;
  final List<AdminUserDto> drivers;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onAssign;
  final VoidCallback onRefresh;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  late AdminOrderDto _order;
  bool _updating = false;

  static const _gasStatuses = [
    ('pending', 'En attente'), ('accepted', 'Acceptée'), ('depot_selected', 'Dépôt choisi'),
    ('at_depot', 'Au dépôt'), ('en_route', 'En route'), ('delivered_paid', 'Livrée'),
    ('empty_returned', 'Terminée'), ('cancelled', 'Annulée'),
  ];
  static const _parcelStatuses = [
    ('pending', 'En attente'), ('accepted', 'Acceptée'), ('picked_up', 'Récupéré'),
    ('en_route', 'En route'), ('delivered_paid', 'Livrée'), ('cancelled', 'Annulée'),
  ];
  static const _foodStatuses = [
    ('pending', 'En attente'), ('accepted', 'Acceptée'), ('preparing', 'En préparation'), ('en_route', 'En route'),
    ('delivered_paid', 'Livrée'), ('cancelled', 'Annulée'),
  ];
  static const _residenceStatuses = [
    ('pending', 'En attente'), ('confirmed', 'Confirmée'), ('checked_in', 'Arrivée'),
    ('checked_out', 'Terminée'), ('cancelled', 'Annulée'),
  ];

  List<(String, String)> get _statuses => switch (_order.type) {
    'gas'       => _gasStatuses,
    'parcel'    => _parcelStatuses,
    'food'      => _foodStatuses,
    'residence' => _residenceStatuses,
    _           => _deliveryStatuses,
  };

  static const _deliveryStatuses = [
    ('pending', 'En attente'), ('accepted', 'Acceptée'), ('en_route', 'En route'),
    ('delivered_paid', 'Livrée'), ('cancelled', 'Annulée'),
  ];

  /// Reflète App\Http\Controllers\Api\AdminApiController::ORDER_TRANSITIONS
  /// côté backend, pour griser les statuts non atteignables avant même
  /// l'appel API (le backend reste la source de vérité et revalide).
  static const _orderTransitions = <String, Map<String, List<String>>>{
    'gas': {
      'pending': ['accepted'],
      'accepted': ['depot_selected', 'at_depot'],
      'depot_selected': ['at_depot'],
      'at_depot': ['en_route'],
      'en_route': ['delivered_paid'],
      'delivered_paid': ['empty_returned'],
      'empty_returned': [],
      'cancelled': [],
    },
    'parcel': {
      'pending': ['accepted'],
      'accepted': ['picked_up'],
      'picked_up': ['en_route'],
      'en_route': ['delivered_paid'],
      'delivered_paid': [],
      'cancelled': [],
    },
    'food': {
      'pending': ['accepted'],
      'accepted': ['preparing', 'en_route'],
      'preparing': ['en_route'],
      'en_route': ['delivered_paid'],
      'delivered_paid': [],
      'cancelled': [],
    },
    'residence': {
      'pending': ['confirmed'],
      'confirmed': ['checked_in'],
      'checked_in': ['checked_out'],
      'checked_out': [],
      'cancelled': [],
    },
  };

  static const _orderTerminalStatuses = <String, List<String>>{
    'gas': ['empty_returned', 'cancelled'],
    'parcel': ['delivered_paid', 'cancelled'],
    'food': ['delivered_paid', 'cancelled'],
    'residence': ['checked_out', 'cancelled'],
  };

  static List<String> _allowedNextStatuses(String type, String current) {
    final next = List<String>.from(_orderTransitions[type]?[current] ?? const []);
    final terminal = _orderTerminalStatuses[type] ?? const [];
    if (!terminal.contains(current)) next.add('cancelled');
    return next;
  }

  @override
  void initState() { super.initState(); _order = widget.order; }

  Future<void> _updateStatus(String status) async {
    if (status == _order.status) return;
    setState(() => _updating = true);
    try {
      await AdminApi.adminUpdateOrderStatus(_order.type, _order.id, status);
      final updated = _order.copyWith(status: status);
      if (mounted) {
        setState(() { _order = updated; _updating = false; });
        widget.onStatusChanged(status);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AdiakeColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _order.raw;
    final price = _order.priceFcfa != null ? NumberFormat('#,###', 'fr').format(_order.priceFcfa) + ' F CFA' : '—';
    final date = DateFormat('dd/MM/yyyy · HH:mm').format(_order.createdAt);
    final tc = _typeColor(_order.type);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.98, expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: EdgeInsets.zero,
          children: [
            // ── Colored header ──
            Container(
              decoration: BoxDecoration(
                color: tc,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_typeIcon(_order.type), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_typeLabel(_order.type)} #${_order.id}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(date, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                  ])),
                ]),
                const SizedBox(height: 16),
                // Price + status row
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                    Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  ])),
                  _StatusBadgeLarge(status: _order.status),
                ]),
              ]),
            ),

            // ── Status stepper ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Changer le statut', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
                  const SizedBox(width: 8),
                  if (_updating) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _statuses.map((s) {
                    final (key, label) = s;
                    final isCurrent = _order.status == key;
                    final isAllowed = isCurrent || _allowedNextStatuses(_order.type, _order.status).contains(key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: (_updating || !isAllowed) ? null : () => _updateStatus(key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrent ? tc : const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isCurrent ? tc : const Color(0xFFE0E0E0), width: isCurrent ? 0 : 1),
                          ),
                          child: Opacity(
                            opacity: isAllowed ? 1.0 : 0.35,
                            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : AdiakeColors.onSurfaceVariant)),
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                ),
              ]),
            ),
            const SizedBox(height: 8),

            // ── Client + Driver ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Personnes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
                const SizedBox(height: 12),
                _PersonRow(
                  icon: Icons.person_rounded,
                  color: tc,
                  title: _order.clientName ?? 'Client inconnu',
                  subtitle: _order.clientPhone,
                  badge: 'CLIENT',
                ),
                const Divider(height: 20, color: Color(0xFFF0F0F0)),
                if (_order.driverName != null)
                  _PersonRow(
                    icon: Icons.delivery_dining_rounded,
                    color: const Color(0xFF2E7D32),
                    title: _order.driverName!,
                    subtitle: _order.driverPhone,
                    badge: 'LIVREUR',
                  )
                else
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.delivery_dining_rounded, size: 20, color: AdiakeColors.outline),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Aucun livreur assigné', style: TextStyle(fontSize: 13, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600))),
                    if (_order.type != 'residence')
                      TextButton.icon(
                        onPressed: widget.onAssign,
                        icon: const Icon(Icons.person_add_rounded, size: 14),
                        label: const Text('Assigner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(foregroundColor: tc),
                      ),
                  ]),
              ]),
            ),
            const SizedBox(height: 8),

            // ── Type-specific details ──
            ..._buildTypeDetails(j),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTypeDetails(Map<String, dynamic> j) {
    return switch (_order.type) {
      'gas'       => _gasDetails(j),
      'parcel'    => _parcelDetails(j),
      'food'      => _foodDetails(j),
      'residence' => _residenceDetails(j),
      _           => [],
    };
  }

  List<Widget> _gasDetails(Map<String, dynamic> j) => [
    _DetailCard(
      title: 'Commande de gaz',
      icon: Icons.local_fire_department_rounded,
      color: _typeColor('gas'),
      rows: [
        if (j['brand'] != null) _DetailRow(label: 'Produit', value: '${j['brand']} ${j['size'] ?? ''}kg × ${j['qty'] ?? 1}'),
        if (j['delivery_address'] != null) _DetailRow(label: 'Adresse livraison', value: j['delivery_address'].toString()),
        if (j['payment_method'] != null) _DetailRow(label: 'Paiement', value: j['payment_method'].toString().toUpperCase()),
        if (j['has_exchange_bottle'] == true) _DetailRow(label: 'Échange bouteille', value: 'Oui'),
        if (j['bottle_deposit_fcfa'] != null && j['bottle_deposit_fcfa'] != 0) _DetailRow(label: 'Caution bouteille', value: '${NumberFormat('#,###', 'fr').format(j['bottle_deposit_fcfa'])} F'),
        if (j['delivery_fee_fcfa'] != null) ...[
          _DetailRow(
            label: 'Sous-total produit',
            value: '${NumberFormat('#,###', 'fr').format(((j['price_fcfa'] ?? 0) as num) - ((j['delivery_fee_fcfa'] ?? 0) as num) - ((j['bottle_deposit_fcfa'] ?? 0) as num))} F',
          ),
          _DetailRow(label: 'Frais livraison', value: '${NumberFormat('#,###', 'fr').format(j['delivery_fee_fcfa'])} F'),
        ],
        _DetailRow(label: 'Total', value: '${NumberFormat('#,###', 'fr').format(j['price_fcfa'] ?? 0)} F', bold: true),
      ],
    ),
  ];

  List<Widget> _parcelDetails(Map<String, dynamic> j) => [
    _DetailCard(
      title: 'Détails du colis',
      icon: Icons.inventory_2_rounded,
      color: _typeColor('parcel'),
      rows: [
        if (j['package_label'] != null) _DetailRow(label: 'Étiquette', value: j['package_label'].toString()),
        if (j['weight_kg'] != null) _DetailRow(label: 'Poids', value: '${j['weight_kg']} kg'),
        if (j['pickup_address'] != null) _DetailRow(label: 'Prise en charge', value: j['pickup_address'].toString()),
        if (j['dropoff_address'] != null) _DetailRow(label: 'Livraison', value: j['dropoff_address'].toString()),
        if (j['declared_value_fcfa'] != null) _DetailRow(label: 'Valeur déclarée', value: '${NumberFormat('#,###', 'fr').format(j['declared_value_fcfa'])} F'),
        if (j['delivery_fee_fcfa'] != null) _DetailRow(label: 'Frais livraison', value: '${NumberFormat('#,###', 'fr').format(j['delivery_fee_fcfa'])} F', bold: true),
      ],
    ),
  ];

  List<Widget> _foodDetails(Map<String, dynamic> j) {
    final items = j['items'] as List? ?? [];
    return [
      _DetailCard(
        title: 'Commande alimentaire',
        icon: Icons.restaurant_rounded,
        color: _typeColor('food'),
        rows: [
          if (j['delivery_address'] != null) _DetailRow(label: 'Adresse livraison', value: j['delivery_address'].toString()),
          if (j['payment_method'] != null) _DetailRow(label: 'Paiement', value: j['payment_method'].toString().toUpperCase()),
          if (j['notes'] != null && j['notes'].toString().isNotEmpty) _DetailRow(label: 'Note', value: j['notes'].toString()),
          if (j['subtotal_fcfa'] != null) _DetailRow(label: 'Sous-total', value: '${NumberFormat('#,###', 'fr').format(j['subtotal_fcfa'])} F'),
          if (j['delivery_fee_fcfa'] != null) _DetailRow(label: 'Livraison', value: '${NumberFormat('#,###', 'fr').format(j['delivery_fee_fcfa'])} F'),
        ],
      ),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: _typeColor('food').withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.receipt_long_rounded, size: 16, color: _typeColor('food'))),
              const SizedBox(width: 10),
              Text('Articles (${items.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
            ]),
            const SizedBox(height: 14),
            ...items.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value as Map<String, dynamic>? ?? {};
              final dish = item['dish'] as Map<String, dynamic>?;
              final name = dish?['name']?.toString() ?? item['name']?.toString() ?? '—';
              final qty = item['qty'] ?? item['quantity'] ?? 1;
              final price = item['price_fcfa'] ?? item['unit_price_fcfa'];
              return Column(children: [
                if (idx > 0) const Divider(height: 1, color: Color(0xFFF4F5F7)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: const Color(0xFFF4F5F7), borderRadius: BorderRadius.circular(7)),
                      child: Center(child: Text('$qty×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AdiakeColors.primary))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdiakeColors.primary))),
                    if (price != null) Text('${NumberFormat('#,###', 'fr').format(price)} F', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _typeColor('food'))),
                  ]),
                ),
              ]);
            }),
          ]),
        ),
      ],
    ];
  }

  List<Widget> _residenceDetails(Map<String, dynamic> j) {
    final residence = j['residence'] as Map<String, dynamic>?;
    String? nights;
    if (j['check_in'] != null && j['check_out'] != null) {
      try {
        final ci = DateTime.parse(j['check_in'].toString());
        final co = DateTime.parse(j['check_out'].toString());
        nights = '${co.difference(ci).inDays} nuit(s)';
      } catch (_) {}
    }
    return [
      _DetailCard(
        title: 'Réservation',
        icon: Icons.hotel_rounded,
        color: _typeColor('residence'),
        rows: [
          if (residence != null) _DetailRow(label: 'Hébergement', value: residence['name']?.toString() ?? '—'),
          if (j['check_in'] != null) _DetailRow(label: 'Arrivée', value: _fmtDate(j['check_in'].toString())),
          if (j['check_out'] != null) _DetailRow(label: 'Départ', value: _fmtDate(j['check_out'].toString())),
          if (nights != null) _DetailRow(label: 'Durée', value: nights),
          if (j['total_price'] != null) _DetailRow(label: 'Total', value: '${NumberFormat('#,###', 'fr').format(j['total_price'])} F CFA', bold: true),
          if (j['notes'] != null && j['notes'].toString().isNotEmpty) _DetailRow(label: 'Note', value: j['notes'].toString()),
        ],
      ),
    ];
  }

  String _fmtDate(String iso) {
    try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso)); } catch (_) { return iso; }
  }

  Color _typeColor(String type) => switch (type) {
    'gas'       => const Color(0xFFE65100),
    'parcel'    => const Color(0xFF1565C0),
    'food'      => const Color(0xFF2E7D32),
    'residence' => const Color(0xFF6A1B9A),
    _           => AdiakeColors.primaryContainer,
  };

  IconData _typeIcon(String type) => switch (type) {
    'gas'       => Icons.local_fire_department_rounded,
    'parcel'    => Icons.inventory_2_rounded,
    'food'      => Icons.restaurant_rounded,
    'residence' => Icons.hotel_rounded,
    _           => Icons.receipt_long_rounded,
  };

  String _typeLabel(String type) => switch (type) {
    'gas'       => 'Gaz',
    'parcel'    => 'Colis',
    'food'      => 'Nourriture',
    'residence' => 'Réservation',
    _           => type,
  };
}

// ── Order detail helper widgets ───────────────────────────────────────────────

class _StatusBadgeLarge extends StatelessWidget {
  const _StatusBadgeLarge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'pending'        => ('En attente', const Color(0xFFE65100), Colors.white.withValues(alpha: 0.20)),
      'accepted'       => ('Acceptée', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'confirmed'      => ('Confirmée', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'en_route'       => ('En route', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'delivered_paid' => ('Livrée ✓', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.25)),
      'checked_out'    => ('Terminée ✓', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.25)),
      'cancelled'      => ('Annulée', const Color(0xFFFFCDD2), Colors.black.withValues(alpha: 0.20)),
      'picked_up'      => ('Ramassé', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'depot_selected' => ('Dépôt sélect.', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'at_depot'       => ('Au dépôt', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'empty_returned' => ('Bouteille retournée', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      'checked_in'     => ('Arrivé', const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.20)),
      _                => (status, const Color(0xFFFFFFFF), Colors.white.withValues(alpha: 0.15)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.icon, required this.color, required this.title, this.subtitle, required this.badge});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 22, color: color),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdiakeColors.primary)),
      if (subtitle != null)
        Text(subtitle!, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant, height: 1.3)),
    ])),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
    ),
  ]);
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.icon, required this.color, required this.rows});
  final String title;
  final IconData icon;
  final Color color;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
      ]),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(12)),
        child: Column(children: rows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          return Column(children: [
            if (idx > 0) const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 110,
                  child: Text(row.label, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Text(
                  row.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: AdiakeColors.primary,
                    fontWeight: row.bold ? FontWeight.w800 : FontWeight.w600,
                  ),
                )),
              ]),
            ),
          ]);
        }).toList()),
      ),
    ]),
  );
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;
}

// ── Assign bottom sheet ───────────────────────────────────────────────────────

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.order, required this.drivers, required this.type, required this.onDone});
  final AdminOrderDto order;
  final List<AdminUserDto> drivers;
  final String type;
  final VoidCallback onDone;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  AdminUserDto? _selected;
  bool _loading = false;

  Future<void> _assign() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    try {
      await AdminApi.adminAssignDriver(widget.type, widget.order.id, _selected!.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selected!.name} assigné à la commande #${widget.order.id}'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AdiakeColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AdiakeColors.primaryContainer.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: AdiakeColors.primaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande #${widget.order.id}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdiakeColors.primary),
                    ),
                    Text(
                      'Client : ${widget.order.clientName ?? "—"}',
                      style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Choisir un livreur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdiakeColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.drivers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = widget.drivers[i];
                final selected = _selected?.id == d.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected ? AdiakeColors.primaryContainer.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AdiakeColors.primaryContainer : const Color(0xFFEEEEEE),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AdiakeColors.primaryContainer.withValues(alpha: 0.12),
                          child: Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AdiakeColors.primaryContainer, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdiakeColors.primary)),
                            Text(d.phone, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant)),
                          ]),
                        ),
                        if (selected) const Icon(Icons.check_circle_rounded, color: AdiakeColors.primaryContainer, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _selected == null || _loading ? null : _assign,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _selected == null ? 'Sélectionner un livreur' : 'Assigner ${_selected!.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'pending'        => ('En attente',  AdiakeColors.primaryContainer, const Color(0xFFFFEBEE)),
      'accepted'       => ('Acceptée',    const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      'depot_selected' => ('Dépôt OK',   const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      'at_depot'       => ('Au dépôt',   const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
      'en_route'       => ('En route',   const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'picked_up'      => ('Récupéré',   const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'delivered_paid' => ('Livrée ✓',   const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'empty_returned' => ('Terminée',   const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'cancelled'      => ('Annulée',    const Color(0xFF757575), const Color(0xFFF5F5F5)),
      _                => (status,        AdiakeColors.outline,    const Color(0xFFF5F5F5)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}
