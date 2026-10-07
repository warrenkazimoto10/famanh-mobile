import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import 'screens/admin_audit_log_screen.dart';
import 'screens/admin_drivers_screen.dart';
import 'screens/admin_gas_screen.dart';
import 'screens/admin_orders_screen.dart';
import 'screens/admin_pricing_screen.dart';
import 'screens/admin_resets_screen.dart';
import 'screens/admin_residences_admin_screen.dart';
import 'screens/admin_restaurants_screen.dart';
import 'screens/admin_revenue_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/admin_stats_screen.dart';
import 'screens/admin_taxi_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_zones_screen.dart';


// ─── Shell ────────────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  static const _navItems = [
    _NavItem(label: 'Home', icon: Icons.dashboard_outlined,    activeIcon: Icons.dashboard_rounded),
    _NavItem(label: 'Commandes',        icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded),
    _NavItem(label: 'Utilisateurs',     icon: Icons.people_outline,        activeIcon: Icons.people_rounded),
    _NavItem(label: 'Restaurants',      icon: Icons.storefront_outlined,   activeIcon: Icons.storefront_rounded),
    _NavItem(label: 'Rés./Hôtels',      icon: Icons.hotel_outlined,        activeIcon: Icons.hotel_rounded),
  ];

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  int _index = 0;
  int _pendingResets = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingResets();
  }

  Future<void> _loadPendingResets() async {
    try {
      final stats = await AdminApi.adminStats();
      if (mounted) setState(() => _pendingResets = stats.pendingResets);
    } catch (_) {}
  }

  void navigateTo(int index) => setState(() => _index = index);

  Widget _currentScreen() => switch (_index) {
        0 => AdminStatsScreen(onNavigate: navigateTo),
        1 => const AdminOrdersScreen(),
        2 => const AdminUsersScreen(),
        3 => const AdminRestaurantsScreen(),
        4 => const AdminResidencesAdminScreen(),
        _ => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return isWide
        ? _WideScaffold(index: _index, onSelect: (i) => setState(() => _index = i), pendingResets: _pendingResets, child: _currentScreen())
        : _NarrowScaffold(index: _index, onSelect: (i) => setState(() => _index = i), pendingResets: _pendingResets, child: _currentScreen());
  }
}

// ─── Wide layout ──────────────────────────────────────────────────────────────

class _WideScaffold extends StatelessWidget {
  const _WideScaffold({required this.index, required this.onSelect, required this.pendingResets, required this.child});
  final int index;
  final ValueChanged<int> onSelect;
  final int pendingResets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Row(
        children: [
          _Sidebar(index: index, onSelect: onSelect, pendingResets: pendingResets),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect, required this.pendingResets});
  final int index;
  final ValueChanged<int> onSelect;
  final int pendingResets;

  @override
  Widget build(BuildContext context) {
    final user = ApiSession.currentUser.value;
    final initials = (user?.name?.isNotEmpty == true) ? user!.name![0].toUpperCase() : 'A';

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0C000000), blurRadius: 24, offset: Offset(4, 0))],
      ),
      child: Column(
        children: [
          // ── Logo header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AdiakeColors.primary, AdiakeColors.primaryContainer.withValues(alpha: 0.85)],
              ),
            ),
            child: Row(
              children: [
                const BrandLogo(size: 36, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Famanh', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.3)),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Nav items ──
          for (int i = 0; i < AdminShell._navItems.length; i++)
            _SidebarTile(item: AdminShell._navItems[i], active: index == i, onTap: () => onSelect(i)),
          const Spacer(),
          // ── Admin tools ──
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
          _SidebarActionTile(
            icon: Icons.delivery_dining_rounded,
            label: 'Livreurs',
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDriversScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.propane_tank_rounded,
            label: 'Gestion du Gaz',
            color: const Color(0xFFE65100),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminGasScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.local_taxi_rounded,
            label: 'Taxi & Portefeuilles',
            color: const Color(0xFFD97706),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminTaxiScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.map_rounded,
            label: 'Cartographie & Quartiers',
            color: const Color(0xFF0284C7),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminZonesScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.attach_money_rounded,
            label: 'Tarification',

            color: const Color(0xFF1565C0),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPricingScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.bar_chart_rounded,
            label: 'Revenus acteurs',
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRevenueScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.settings_rounded,
            label: 'Réglages généraux',
            color: const Color(0xFF455A64),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSettingsScreen())),
          ),
          _SidebarActionTile(
            icon: Icons.history_rounded,
            label: 'Journal d\'audit',
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAuditLogScreen())),
          ),
          // ── Password resets shortcut ──
          if (pendingResets > 0) ...[
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Material(
                color: const Color(0xFFFFF3F3),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResetsScreen())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_reset_rounded, size: 18, color: AdiakeColors.primaryContainer),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Demandes MDP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdiakeColors.primaryContainer))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AdiakeColors.primaryContainer, borderRadius: BorderRadius.circular(999)),
                          child: Text('$pendingResets', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          // ── User footer ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdiakeColors.primaryContainer.withValues(alpha: 0.12),
                  child: Text(initials, style: const TextStyle(color: AdiakeColors.primaryContainer, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                      const Text('Administrateur', style: TextStyle(fontSize: 11, color: AdiakeColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  color: AdiakeColors.outline,
                  tooltip: 'Déconnexion',
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.active, required this.onTap});
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? AdiakeColors.primaryContainer.withValues(alpha: 0.09) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: active ? AdiakeColors.primaryContainer : Colors.transparent, width: 3),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(active ? item.activeIcon : item.icon, size: 19,
                    color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? AdiakeColors.primaryContainer : AdiakeColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Narrow layout ────────────────────────────────────────────────────────────

class _NarrowScaffold extends StatelessWidget {
  const _NarrowScaffold({required this.index, required this.onSelect, required this.pendingResets, required this.child});
  final int index;
  final ValueChanged<int> onSelect;
  final int pendingResets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AdiakeColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandLogo(size: 26, radius: 7),
            const SizedBox(width: 8),
            const Text('Famanh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(999)),
              child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ],
        ),
        actions: [
          if (pendingResets > 0)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResetsScreen())),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: AdiakeColors.secondary, shape: BoxShape.circle, border: Border.all(color: AdiakeColors.primary, width: 1.5)),
                    child: Text('$pendingResets', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'drivers') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDriversScreen()));
              if (v == 'taxi') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminTaxiScreen()));
              if (v == 'zones') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminZonesScreen()));
              if (v == 'gas') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminGasScreen()));
              if (v == 'pricing') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPricingScreen()));
              if (v == 'revenue') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRevenueScreen()));
              if (v == 'settings') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
              if (v == 'audit') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAuditLogScreen()));
              if (v == 'logout') _logout(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'drivers', child: ListTile(leading: Icon(Icons.delivery_dining_rounded, color: Color(0xFF1565C0)), title: Text('Livreurs'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'taxi', child: ListTile(leading: Icon(Icons.local_taxi_rounded, color: Color(0xFFD97706)), title: Text('Taxi & Portefeuilles'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'zones', child: ListTile(leading: Icon(Icons.map_rounded, color: Color(0xFF0284C7)), title: Text('Cartographie & Quartiers'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'gas', child: ListTile(leading: Icon(Icons.propane_tank_rounded, color: Color(0xFFE65100)), title: Text('Gestion du Gaz'), contentPadding: EdgeInsets.zero)),

              const PopupMenuItem(value: 'pricing', child: ListTile(leading: Icon(Icons.attach_money_rounded), title: Text('Tarification'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'revenue', child: ListTile(leading: Icon(Icons.bar_chart_rounded), title: Text('Revenus acteurs'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_rounded, color: Color(0xFF455A64)), title: Text('Réglages généraux'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'audit', child: ListTile(leading: Icon(Icons.history_rounded, color: Color(0xFF6A1B9A)), title: Text('Journal d\'audit'), contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout_rounded, color: Colors.red), title: Text('Déconnexion', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x18000000),
        indicatorColor: AdiakeColors.primaryContainer.withValues(alpha: 0.10),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: AdminShell._navItems.map((item) => NavigationDestination(
          icon: Icon(item.icon, color: AdiakeColors.onSurfaceVariant),
          selectedIcon: Icon(item.activeIcon, color: AdiakeColors.primaryContainer),
          label: item.label,
        )).toList(),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Future<void> _logout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.logout_rounded, color: AdiakeColors.error, size: 22),
        SizedBox(width: 10),
        Text('Déconnexion', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ]),
      content: const Text('Voulez-vous vraiment vous déconnecter de l\'administration ?'),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AdiakeColors.error, foregroundColor: Colors.white),
          child: const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;
  await ApiClient.logout();
  if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}

class _SidebarActionTile extends StatelessWidget {
  const _SidebarActionTile({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    ),
  );
}

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
