import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/api_client.dart';
import '../../../data/api_session.dart';
import '../../../theme/adiake_colors.dart';
import '../../../widgets/skeleton_loader.dart';
import 'admin_pricing_screen.dart';
import 'admin_resets_screen.dart';
import 'admin_revenue_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kCardShadow = [
  BoxShadow(color: Color(0x0E000000), blurRadius: 16, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x06000000), blurRadius: 32, offset: Offset(0, 8)),
];

const _kLightShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

// Terminal statuses — orders in these states are considered done
const _kDoneStatuses = {'delivered_paid', 'cancelled', 'checked_out', 'empty_returned'};

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  AdminStatsDto? _stats;
  bool _loading = true;
  String? _error;
  List<AdminOrderDto> _activeOrders = const [];
  bool _ordersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await AdminApi.adminStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
      _loadActiveOrders();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadActiveOrders() async {
    if (!mounted) return;
    setState(() => _ordersLoading = true);
    try {
      final results = await Future.wait([
        AdminApi.adminOrders(type: 'gas'),
        AdminApi.adminOrders(type: 'parcel'),
        AdminApi.adminOrders(type: 'food'),
        AdminApi.adminOrders(type: 'residence'),
      ]);
      final all = results.expand((r) => r.items).toList();
      final active = all.where((o) => !_kDoneStatuses.contains(o.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() { _activeOrders = active; _ordersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _ordersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final p = isWide ? 28.0 : 16.0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AdiakeColors.primaryContainer,
      child: CustomScrollView(
        slivers: [
          // ── Hero header (always visible) ─────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroHeader(stats: _stats, loading: _loading, onRefresh: _load),
          ),

          // ── Loading skeleton ─────────────────────────────────────────────
          if (_loading)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 24, p, 0),
              sliver: SliverToBoxAdapter(child: _Skeleton(isWide: isWide)),
            )

          // ── Error state ──────────────────────────────────────────────────
          else if (_error != null)
            SliverFillRemaining(child: _ErrorView(error: _error!, onRetry: _load))

          // ── Content ──────────────────────────────────────────────────────
          else if (_stats != null) ...[

            // Alert banner — urgent, shown first
            if (_stats!.pendingOrders > 0 || _stats!.pendingResets > 0)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(p, 20, p, 0),
                sliver: SliverToBoxAdapter(
                  child: _AlertBanner(
                    stats: _stats!,
                    onOrders: () => widget.onNavigate(1),
                    onResets: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResetsScreen())),
                  ),
                ),
              ),

            // Commandes par type — horizontal strip
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 28, p, 0),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel(
                  title: 'Commandes',
                  action: 'Tout voir',
                  onAction: () => widget.onNavigate(1),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 12),
              sliver: SliverToBoxAdapter(
                child: _OrderTypeStrip(
                  stats: _stats!,
                  padLeft: p,
                  onTap: () => widget.onNavigate(1),
                ),
              ),
            ),

            // Équipe
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 28, p, 0),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel(
                  title: 'Équipe',
                  action: 'Gérer',
                  onAction: () => widget.onNavigate(2),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 12, p, 0),
              sliver: SliverToBoxAdapter(child: _TeamRow(stats: _stats!)),
            ),

            // Accès rapide
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 28, p, 0),
              sliver: const SliverToBoxAdapter(
                child: _SectionLabel(title: 'Accès rapide'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 12, p, 0),
              sliver: SliverToBoxAdapter(
                child: _QuickActions(onNavigate: widget.onNavigate),
              ),
            ),

            // Commandes en cours
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 28, p, 0),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel(
                  title: 'Commandes en cours',
                  action: _activeOrders.isNotEmpty ? 'Tout voir' : null,
                  onAction: () => widget.onNavigate(1),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(p, 12, p, 0),
              sliver: SliverToBoxAdapter(
                child: _ActiveOrdersSection(
                  orders: _activeOrders,
                  loading: _ordersLoading,
                  onTap: (_) => widget.onNavigate(1),
                ),
              ),
            ),

            SliverPadding(padding: EdgeInsets.only(bottom: isWide ? 32 : 100)),
          ],
        ],
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.stats, required this.loading, required this.onRefresh});
  final AdminStatsDto? stats;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final user = ApiSession.currentUser.value;
    final name = user?.name?.split(' ').first ?? 'Admin';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final date = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());
    final revenue = stats != null ? _fmtRevenue(stats!.totalRevenueFcfa) : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdiakeColors.primary, Color(0xFF8B0000)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: greeting + refresh
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '$greeting, $name',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onRefresh,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Revenue spotlight card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.trending_up_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    'REVENUS (commandes livrées)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  ),
                  const Spacer(),
                  if (!loading && stats != null && stats!.pendingOrders > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text('${stats!.pendingOrders} en attente',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C))),
                    ),
                ]),
                const SizedBox(height: 8),
                loading
                    ? Container(height: 36, width: 160, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(8)))
                    : Text(
                        revenue != null ? '$revenue F CFA' : '— F CFA',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                      ),
                if (!loading && stats != null) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  // Breakdown row
                  Row(children: [
                    _RevPill('Gaz', stats!.revenueGas, const Color(0xFFFF8A65)),
                    const SizedBox(width: 8),
                    _RevPill('Colis', stats!.revenueParcel, const Color(0xFFCE93D8)),
                    const SizedBox(width: 8),
                    _RevPill('Repas', stats!.revenueFood, const Color(0xFFEF9A9A)),
                    const SizedBox(width: 8),
                    _RevPill('Hôtels', stats!.revenueResidence, const Color(0xFF80CBC4)),
                  ]),
                  const SizedBox(height: 10),
                  // GMV line
                  Row(children: [
                    const Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white54),
                    const SizedBox(width: 5),
                    Text('Volume total (GMV) : ${_fmtRevenue(stats!.totalGmvFcfa)} F CFA',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.60), fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),

          // Team pills
          if (!loading && stats != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              _HeroPill(icon: Icons.people_rounded, label: '${stats!.clients} client${stats!.clients > 1 ? 's' : ''}'),
              const SizedBox(width: 8),
              _HeroPill(icon: Icons.delivery_dining_rounded, label: '${stats!.drivers} livreur${stats!.drivers > 1 ? 's' : ''}'),
              const SizedBox(width: 8),
              _HeroPill(icon: Icons.inventory_2_rounded, label: '${stats!.gasOrders + stats!.parcelOrders + stats!.foodOrders} cmd${(stats!.gasOrders + stats!.parcelOrders + stats!.foodOrders) > 1 ? 's' : ''}'),
            ]),
          ],
        ],
      ),
    );
  }
}

class _RevPill extends StatelessWidget {
  const _RevPill(this.label, this.amount, this.color);
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(_fmtRevenue(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
      ]),
    ),
  );
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Alert banner ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.stats, required this.onOrders, required this.onResets});
  final AdminStatsDto stats;
  final VoidCallback onOrders;
  final VoidCallback onResets;

  @override
  Widget build(BuildContext context) {
    final count = (stats.pendingOrders > 0 ? 1 : 0) + (stats.pendingResets > 0 ? 1 : 0);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8F0), Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCC80)),
        boxShadow: _kLightShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFFFFCC80), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.notification_important_rounded, size: 17, color: Color(0xFFE65100)),
            ),
            const SizedBox(width: 10),
            Text(
              '$count action${count > 1 ? 's requises' : ' requise'}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE65100), fontSize: 13.5),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFFFCC80)),
        if (stats.pendingOrders > 0)
          _AlertRow(
            icon: Icons.receipt_long_rounded,
            color: AdiakeColors.primaryContainer,
            text: '${stats.pendingOrders} commande${stats.pendingOrders > 1 ? 's' : ''} sans livreur',
            onTap: onOrders,
          ),
        if (stats.pendingResets > 0)
          _AlertRow(
            icon: Icons.lock_reset_rounded,
            color: const Color(0xFF6A1B9A),
            text: '${stats.pendingResets} reset${stats.pendingResets > 1 ? 's' : ''} MDP en attente',
            onTap: onResets,
          ),
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.icon, required this.color, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdiakeColors.primary)),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AdiakeColors.outline),
        ]),
      ),
    );
  }
}

// ── Order type strip ──────────────────────────────────────────────────────────

class _OrderTypeStrip extends StatelessWidget {
  const _OrderTypeStrip({required this.stats, required this.padLeft, required this.onTap});
  final AdminStatsDto stats;
  final double padLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _OrderData(Icons.local_fire_department_rounded, const Color(0xFFE65100), const Color(0xFFFFF3E0), 'Gaz', stats.gasOrders),
      _OrderData(Icons.inventory_2_rounded, const Color(0xFF6A1B9A), const Color(0xFFF3E5F5), 'Colis', stats.parcelOrders),
      _OrderData(Icons.restaurant_rounded, AdiakeColors.primaryContainer, const Color(0xFFFFEBEE), 'Nourriture', stats.foodOrders),
      _OrderData(Icons.hotel_rounded, const Color(0xFF00695C), const Color(0xFFE0F2F1), 'Résidence', stats.residenceBookings),
    ];

    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: padLeft, right: padLeft - 10),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _OrderCard(data: items[i], onTap: onTap),
        ),
      ),
    );
  }
}

class _OrderData {
  const _OrderData(this.icon, this.color, this.bg, this.label, this.count);
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final int count;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.data, required this.onTap});
  final _OrderData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _kLightShadow,
          border: Border.all(color: data.color.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: [
          Container(height: 4, color: data.color.withValues(alpha: 0.75)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: data.bg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(data.icon, color: data.color, size: 17),
                ),
                const Spacer(),
                Text(
                  '${data.count}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: data.color, letterSpacing: -0.5),
                ),
                Text(data.label, style: const TextStyle(fontSize: 10.5, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Team row ──────────────────────────────────────────────────────────────────

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.stats});
  final AdminStatsDto stats;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _TeamCard(
        icon: Icons.people_alt_rounded,
        label: 'Clients',
        value: stats.clients,
        color: const Color(0xFF1565C0),
        bg: const Color(0xFFE3F2FD),
      )),
      const SizedBox(width: 12),
      Expanded(child: _TeamCard(
        icon: Icons.delivery_dining_rounded,
        label: 'Livreurs',
        value: stats.drivers,
        color: const Color(0xFF2E7D32),
        bg: const Color(0xFFE8F5E9),
      )),
    ]);
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.icon, required this.label, required this.value, required this.color, required this.bg});
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _kCardShadow,
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tabActions = [
      (Icons.receipt_long_rounded, 'Commandes', const Color(0xFFE65100), const Color(0xFFFFF3E0), 1),
      (Icons.people_rounded, 'Utilisateurs', const Color(0xFF1565C0), const Color(0xFFE3F2FD), 2),
      (Icons.storefront_rounded, 'Restaurants', AdiakeColors.primaryContainer, const Color(0xFFFFEBEE), 3),
      (Icons.hotel_rounded, 'Rés./Hôtels', const Color(0xFF00695C), const Color(0xFFE0F2F1), 4),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: tabActions.length,
          itemBuilder: (_, i) {
            final (icon, label, color, bg, tabIndex) = tabActions[i];
            return _QuickActionCard(
              icon: icon,
              label: label,
              color: color,
              bg: bg,
              onTap: () => onNavigate(tabIndex),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuickActionCard(
            icon: Icons.attach_money_rounded,
            label: 'Tarification',
            color: const Color(0xFF1565C0),
            bg: const Color(0xFFE3F2FD),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPricingScreen())),
          )),
          const SizedBox(width: 12),
          Expanded(child: _QuickActionCard(
            icon: Icons.bar_chart_rounded,
            label: 'Revenus acteurs',
            color: const Color(0xFF2E7D32),
            bg: const Color(0xFFE8F5E9),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRevenueScreen())),
          )),
        ]),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color), maxLines: 1),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color.withValues(alpha: 0.45)),
          ]),
        ),
      ),
    );
  }
}

// ── Active orders section ─────────────────────────────────────────────────────

class _ActiveOrdersSection extends StatelessWidget {
  const _ActiveOrdersSection({required this.orders, required this.loading, required this.onTap});
  final List<AdminOrderDto> orders;
  final bool loading;
  final ValueChanged<AdminOrderDto> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: List.generate(3, (_) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SkeletonLoader(width: double.infinity, height: 72, borderRadius: 14),
        ),
      ));
    }

    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFFBDBDBD)),
            SizedBox(height: 8),
            Text('Aucune commande en cours', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: orders.map((o) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ActiveOrderItem(order: o, onTap: () => onTap(o)),
      )).toList(),
    );
  }
}

class _ActiveOrderItem extends StatelessWidget {
  const _ActiveOrderItem({required this.order, required this.onTap});
  final AdminOrderDto order;
  final VoidCallback onTap;

  static const _typeColors = {
    'gas':       Color(0xFFE65100),
    'parcel':    Color(0xFF6A1B9A),
    'food':      Color(0xFFB71C1C),
    'residence': Color(0xFF00695C),
  };
  static const _typeBgs = {
    'gas':       Color(0xFFFFF3E0),
    'parcel':    Color(0xFFF3E5F5),
    'food':      Color(0xFFFFEBEE),
    'residence': Color(0xFFE0F2F1),
  };
  static const _typeIcons = {
    'gas':       Icons.local_fire_department_rounded,
    'parcel':    Icons.inventory_2_rounded,
    'food':      Icons.restaurant_rounded,
    'residence': Icons.hotel_rounded,
  };
  static const _typeLabels = {
    'gas': 'Gaz', 'parcel': 'Colis', 'food': 'Repas', 'residence': 'Réservation',
  };

  String _statusLabel(String s) => switch (s) {
    'pending'        => 'En attente',
    'accepted'       => 'Acceptée',
    'confirmed'      => 'Confirmée',
    'en_route'       => 'En route',
    'picked_up'      => 'Ramassé',
    'depot_selected' => 'Dépôt sélect.',
    'at_depot'       => 'Au dépôt',
    'checked_in'     => 'Arrivé',
    _                => s,
  };

  Color _statusColor(String s) => switch (s) {
    'pending'        => const Color(0xFFE65100),
    'accepted'       => const Color(0xFF1565C0),
    'confirmed'      => const Color(0xFF1565C0),
    'en_route'       => const Color(0xFF2E7D32),
    'picked_up'      => const Color(0xFF2E7D32),
    'at_depot'       => const Color(0xFF6A1B9A),
    'depot_selected' => const Color(0xFF6A1B9A),
    'checked_in'     => const Color(0xFF00695C),
    _                => const Color(0xFF757575),
  };

  String _elapsed(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[order.type] ?? AdiakeColors.primaryContainer;
    final bg    = _typeBgs[order.type]    ?? const Color(0xFFF5F5F5);
    final icon  = _typeIcons[order.type]  ?? Icons.receipt_long_rounded;
    final label = _typeLabels[order.type] ?? order.type;
    final sc    = _statusColor(order.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: _kLightShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Type icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('#${order.id} · $label',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdiakeColors.primary)),
                  const Spacer(),
                  Text(_elapsed(order.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (order.clientName != null) ...[
                    const Icon(Icons.person_outline_rounded, size: 12, color: AdiakeColors.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Expanded(child: Text(order.clientName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AdiakeColors.onSurfaceVariant, fontWeight: FontWeight.w500))),
                  ] else const Spacer(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusLabel(order.status),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: sc)),
                  ),
                ]),
              ],
            )),

            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color.withValues(alpha: 0.4)),
          ]),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdiakeColors.primary, letterSpacing: -0.3)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Row(children: [
            Text(action!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AdiakeColors.primaryContainer)),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AdiakeColors.primaryContainer),
          ]),
        ),
    ]);
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Order type strip
      Row(children: List.generate(4, (i) => Padding(
        padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
        child: const SkeletonLoader(width: 120, height: 128, borderRadius: 18),
      ))),
      const SizedBox(height: 28),
      // Section label
      const SkeletonLoader(width: 80, height: 16, borderRadius: 6),
      const SizedBox(height: 12),
      // Team row
      Row(children: const [
        Expanded(child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 18)),
        SizedBox(width: 12),
        Expanded(child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 18)),
      ]),
      const SizedBox(height: 28),
      const SkeletonLoader(width: 100, height: 16, borderRadius: 6),
      const SizedBox(height: 12),
      // Quick actions
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: List.generate(4, (_) => const SkeletonLoader(width: double.infinity, height: 64, borderRadius: 16)),
      ),
    ]);
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: AdiakeColors.outline),
          ),
          const SizedBox(height: 20),
          const Text(
            'Impossible de charger',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdiakeColors.primary),
          ),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AdiakeColors.onSurfaceVariant, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
          ),
        ]),
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────

String _fmtRevenue(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return NumberFormat('#,###', 'fr').format((v / 1000).round()) + ' k';
  return NumberFormat('#,###', 'fr').format(v);
}
