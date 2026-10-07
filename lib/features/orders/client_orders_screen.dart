import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/taxi_api_client.dart';
import '../tracking/client_tracking_screen.dart';

const _kPrimary = Color(0xFF006194);
const _kBrandBlue = Color(0xFF0052FF);
const _kBg = Color(0xFFFAF8FF);

enum ClientOrderKind { gas, parcel, food, taxi }

String _formatDateTimeFr(DateTime dt) {
  final d = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');

  if (day == today) return "Aujourd’hui $hh:$mm";
  if (day == today.subtract(const Duration(days: 1))) return "Hier $hh:$mm";

  final dd = d.day.toString().padLeft(2, '0');
  final mo = d.month.toString().padLeft(2, '0');
  return '$dd/$mo $hh:$mm';
}

String _fmtFcfa(int v) {
  return NumberFormat('#,###', 'fr').format(v);
}

class ClientOrderListItem {
  const ClientOrderListItem({
    required this.kind,
    required this.id,
    required this.status,
    required this.amountFcfa,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    this.driverName,
    this.driverPhone,
    this.deliveryAddress,
    this.dishImageUrl,
  });

  final ClientOrderKind kind;
  final int id;
  final String status;
  final int amountFcfa;
  final DateTime createdAt;
  final String title;
  final String subtitle;
  final String? driverName;
  final String? driverPhone;
  final String? deliveryAddress;
  final String? dishImageUrl;

  bool get isActive {
    final s = status.toLowerCase();
    return s != 'delivered_paid' && s != 'empty_returned' && s != 'cancelled' && s != 'completed';
  }

  double get progressFactor {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0.25; // Validé
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
      case 'ready':
      case 'stop_ready':
        return 0.60; // Préparé
      case 'at_depot':
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return 0.85; // En route
      case 'delivered_paid':
      case 'empty_returned':
        return 1.0; // Livré
      default:
        return 0.25;
    }
  }

  String get stepLabel {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Recherche de livreur…';
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
        return 'En préparation en cuisine';
      case 'ready':
      case 'stop_ready':
        return 'Commande prête au restaurant';
      case 'at_depot':
      case 'picked_up':
      case 'stop_picked_up':
        return 'Récupérée par le livreur';
      case 'en_route':
        return 'Livreur en route ~12 min';
      case 'delivered_paid':
      case 'empty_returned':
        return 'Livrée & payée';
      default:
        return 'Commande validée';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Root Orders Screen
// ═══════════════════════════════════════════════════════════════

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<ClientOrderListItem> _allItems = const [];
  
  // Segmented tab: 0 = Active orders, 1 = History
  int _selectedTab = 0;
  
  // Category filter: null = Tous, gas, parcel, food
  ClientOrderKind? _selectedCategory;

  // Search toggle & text
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetchData();
  }

  Future<void> _loadSilent() async {
    if (!mounted || _loading) return;
    await _fetchData(silent: true);
  }

  Future<void> _fetchData({bool silent = false}) async {
    try {
      final results = await Future.wait([
        ApiClient.getGasOrders(),
        ApiClient.getParcelOrders(),
        ApiClient.getFoodOrders(),
      ]);

      final gas = results[0] as List<GasOrderDto>;
      final parcel = results[1] as List<ParcelOrderDto>;
      final food = results[2] as List<FoodOrderDto>;

      final list = <ClientOrderListItem>[
        for (final g in gas)
          ClientOrderListItem(
            kind: ClientOrderKind.gas,
            id: g.id,
            status: g.status,
            amountFcfa: g.priceFcfa,
            createdAt: g.createdAt,
            title: 'Dépôt Gaz • ${g.brand ?? 'B12'}',
            subtitle: 'Taille : ${g.size ?? 'B12'} • Qté ${g.qty}',
          ),
        for (final p in parcel)
          ClientOrderListItem(
            kind: ClientOrderKind.parcel,
            id: p.id,
            status: p.status,
            amountFcfa: p.deliveryFeeFcfa,
            createdAt: p.createdAt,
            title: 'Express Colis #${p.id}',
            subtitle: 'Colis : ${p.packageLabel ?? 'Pli express'}',
          ),
        for (final f in food)
          ClientOrderListItem(
            kind: ClientOrderKind.food,
            id: f.id,
            status: f.status,
            amountFcfa: f.subtotalFcfa + f.deliveryFeeFcfa,
            createdAt: f.createdAt,
            title: (f.stops.isNotEmpty && f.stops.first.restaurantNameSnapshot != null)
                ? f.stops.first.restaurantNameSnapshot!
                : 'Repas Restaurant #${f.id}',
            subtitle: '${f.stops.length} restaurant${f.stops.length > 1 ? 's' : ''} partenaire${f.stops.length > 1 ? 's' : ''}',
          ),
      ];

      // Récupération de la course taxi active du passager si existante
      try {
        final activeTaxi = await TaxiApiClient.getActivePassengerRide();
        if (activeTaxi != null) {
          list.add(
            ClientOrderListItem(
              kind: ClientOrderKind.taxi,
              id: (activeTaxi['booking_id'] as num?)?.toInt() ?? 0,
              status: activeTaxi['status']?.toString() ?? 'accepted',
              amountFcfa: (activeTaxi['fare_amount'] as num?)?.toInt() ?? 200,
              createdAt: DateTime.now(),
              title: 'Taxi Communal • ${activeTaxi['type'] == 'private' ? 'Course Privatisée' : 'Course Partagée'}',
              subtitle: '${activeTaxi['pickup_address'] ?? 'Ramassage'} ➔ ${activeTaxi['dropoff_address'] ?? 'Dépose'}',
              driverName: activeTaxi['driver']?['name']?.toString(),
              driverPhone: activeTaxi['driver']?['phone']?.toString(),
            ),
          );
        }
      } catch (_) {}

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _allItems = list;
        if (!silent) _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<ClientOrderListItem> get _activeItems => _allItems.where((i) => i.isActive).toList();
  List<ClientOrderListItem> get _historyItems => _allItems.where((i) => !i.isActive).toList();

  List<ClientOrderListItem> _filterList(List<ClientOrderListItem> source) {
    var res = source;
    if (_selectedCategory != null) {
      res = res.where((i) => i.kind == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      res = res.where((i) {
        final titleMatch = i.title.toLowerCase().contains(_searchQuery);
        final subMatch = i.subtitle.toLowerCase().contains(_searchQuery);
        final idMatch = i.id.toString().contains(_searchQuery);
        final addrMatch = i.deliveryAddress?.toLowerCase().contains(_searchQuery) ?? false;
        return titleMatch || subMatch || idMatch || addrMatch;
      }).toList();
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _filterList(_activeItems);
    final historyList = _filterList(_historyItems);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── 1. Top Bar Header ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVITÉ & HISTORIQUE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mes Commandes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Search Button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSearch = !_showSearch;
                              if (!_showSearch) {
                                _searchController.clear();
                              }
                            });
                          },
                          icon: Icon(
                            _showSearch ? Icons.close_rounded : Icons.search_rounded,
                            color: const Color(0xFF0F172A),
                            size: 22,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: const CircleBorder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Support Client Button
                        IconButton(
                          onPressed: () async {
                            final url = Uri.parse('tel:0700000000');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF0F172A), size: 22),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: const CircleBorder(),
                          ),
                          tooltip: 'Service Client',
                        ),
                      ],
                    ),
                  ],
                ),

                // Collapsible Search Input Bar
                if (_showSearch) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher plat, gaz, adresse, code #...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _kPrimary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Segmented Tabs: En cours (X) vs Historique (Y)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_activeItems.isNotEmpty) ...[
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'En cours (${_activeItems.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                    color: _selectedTab == 0 ? _kPrimary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Historique (${_historyItems.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                  color: _selectedTab == 1 ? _kPrimary : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Category Filter Chips (Horizontal Scroller)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _CategoryFilterChip(
                        label: 'Tous',
                        iconText: '',
                        selected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      _CategoryFilterChip(
                        label: 'Repas',
                        iconText: '🍔',
                        selected: _selectedCategory == ClientOrderKind.food,
                        onTap: () => setState(() => _selectedCategory = ClientOrderKind.food),
                      ),
                      const SizedBox(width: 8),
                      _CategoryFilterChip(
                        label: 'Gaz',
                        iconText: '🔥',
                        selected: _selectedCategory == ClientOrderKind.gas,
                        onTap: () => setState(() => _selectedCategory = ClientOrderKind.gas),
                      ),
                      const SizedBox(width: 8),
                      _CategoryFilterChip(
                        label: 'Colis',
                        iconText: '📦',
                        selected: _selectedCategory == ClientOrderKind.parcel,
                        onTap: () => setState(() => _selectedCategory = ClientOrderKind.parcel),
                      ),
                      const SizedBox(width: 8),
                      _CategoryFilterChip(
                        label: 'Taxi',
                        iconText: '🚖',
                        selected: _selectedCategory == ClientOrderKind.taxi,
                        onTap: () => setState(() => _selectedCategory = ClientOrderKind.taxi),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Scrollable Orders List Content ──────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _kPrimary,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
                              const SizedBox(height: 10),
                              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            if (_selectedTab == 0) ...[
                              // ACTIVE ORDERS SECTION
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 18, color: _kPrimary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Livraisons actives',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'TEMPS RÉEL',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (activeList.isEmpty)
                                _EmptyOrderCard(
                                  message: _selectedCategory == null
                                      ? 'Aucune livraison en cours actuellement.'
                                      : 'Aucune commande active pour cette catégorie.',
                                )
                              else
                                ...activeList.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ActiveOrderCard(item: item, onRefresh: _load),
                                  ),
                                ),
                            ] else ...[
                              // HISTORY ORDERS SECTION
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history_rounded, size: 18, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Historique récent',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${historyList.length} au total',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (historyList.isEmpty)
                                _EmptyOrderCard(
                                  message: 'Aucun historique de commande pour le moment.',
                                )
                              else
                                ...historyList.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _HistoryOrderCard(item: item, onRefresh: _load),
                                  ),
                                ),
                            ],

                            const SizedBox(height: 16),

                            // Assurance & Guarantee Banner
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEFF6FF), Color(0xFFF1F5F9)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: _kPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Garantie Famanh Protect',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Livraison sécurisée et assistance 24/7 sur toutes vos courses à Adiaké.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Category Filter Chip Component
// ═══════════════════════════════════════════════════════════════

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.iconText,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconText.isNotEmpty) ...[
              Text(iconText, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Active Order Card Component (Matching HTML design)
// ═══════════════════════════════════════════════════════════════

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.item, required this.onRefresh});

  final ClientOrderListItem item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final orderKindStr = item.kind == ClientOrderKind.gas
        ? 'gas'
        : item.kind == ClientOrderKind.parcel
            ? 'parcel'
            : 'food';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Accent Line
          Container(
            height: 4,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [Color(0xFF006194), Color(0xFF0052FF), Color(0xFF10B981)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category / Dish Image Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.kind == ClientOrderKind.gas
                                ? Icons.propane_tank_rounded
                                : (item.kind == ClientOrderKind.parcel
                                    ? Icons.inventory_2_rounded
                                    : (item.kind == ClientOrderKind.taxi
                                        ? Icons.local_taxi_rounded
                                        : Icons.restaurant_rounded)),
                            color: _kPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 16, color: _kPrimary),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#FMN-${item.id} • ${_formatDateTimeFr(item.createdAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Live Status Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.stepLabel.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Order Items Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${_fmtFcfa(item.amountFcfa)} FCFA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: _kPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.payments_rounded, size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'Espèces à la livraison',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item.deliveryAddress ?? 'Adiaké, Côte d\'Ivoire',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Tracking Progress Steps Indicator
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StepIndicator(
                          icon: Icons.check_circle_rounded,
                          label: 'Validé',
                          active: true,
                          color: const Color(0xFF059669),
                        ),
                        _StepIndicator(
                          icon: Icons.kitchen_rounded,
                          label: 'Préparé',
                          active: item.progressFactor >= 0.50,
                          color: const Color(0xFF2563EB),
                        ),
                        _StepIndicator(
                          icon: Icons.two_wheeler_rounded,
                          label: 'En route',
                          active: item.progressFactor >= 0.85,
                          color: _kBrandBlue,
                        ),
                        _StepIndicator(
                          icon: Icons.home_rounded,
                          label: 'Livré',
                          active: item.progressFactor >= 1.0,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress Bar Line
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: item.progressFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (item.kind == ClientOrderKind.taxi) {
                              Navigator.of(context).pushNamed(AppRoutes.taxi);
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClientOrderMapScreen(
                                  orderKind: orderKindStr,
                                  orderId: item.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.near_me_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'Suivre sur la carte',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    if (item.driverPhone != null && item.driverPhone!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri(scheme: 'tel', path: item.driverPhone!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF059669)),
                          label: Text(
                            item.driverName ?? 'Livreur',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5),
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: active ? color : const Color(0xFFCBD5E1)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? color : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// History Order Card Component
// ═══════════════════════════════════════════════════════════════

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.item, required this.onRefresh});

  final ClientOrderListItem item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isCancelled = item.status == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.kind == ClientOrderKind.gas
                          ? Icons.propane_tank_rounded
                          : (item.kind == ClientOrderKind.parcel
                              ? Icons.inventory_2_rounded
                              : (item.kind == ClientOrderKind.taxi
                                  ? Icons.local_taxi_rounded
                                  : Icons.restaurant_rounded)),
                      color: isCancelled ? Colors.red : const Color(0xFF059669),
                      size: 20,
                    ),

                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#FMN-${item.id} • ${_formatDateTimeFr(item.createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCancelled ? 'ANNULÉE' : 'LIVRÉ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isCancelled ? Colors.red : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Items summary & amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
                Text(
                  '${_fmtFcfa(item.amountFcfa)} FCFA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrderCard extends StatelessWidget {
  const _EmptyOrderCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
