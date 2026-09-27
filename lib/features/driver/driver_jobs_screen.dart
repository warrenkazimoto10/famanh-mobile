import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/slidable_accept_button.dart';
import 'driver_job_detail_screen.dart';

enum DriverJobKind { gas, parcel, food }

class DriverJobItem {
  const DriverJobItem({
    required this.kind,
    required this.id,
    required this.status,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    required this.amountFcfa,
    this.pickupAddress = 'Centre-Ville Adiaké',
    this.dropoffAddress = 'Quartier Résidentiel',
  });

  final DriverJobKind kind;
  final int id;
  final String status;
  final DateTime createdAt;
  final String title;
  final String subtitle;
  final int amountFcfa;
  final String pickupAddress;
  final String dropoffAddress;
}

class DriverJobsScreen extends StatefulWidget {
  const DriverJobsScreen({super.key, this.onOpenFullMap});

  final VoidCallback? onOpenFullMap;

  @override
  DriverJobsScreenState createState() => DriverJobsScreenState();
}

class DriverJobsScreenState extends State<DriverJobsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool _loading = true;
  String? _error;
  List<DriverJobItem> _available = const [];
  List<DriverJobItem> _mine = const [];
  int _todayRevenue = 0;
  int _todayTrips = 0;
  DriverJobKind? _selectedCategory;

  Set<String> _notifiedJobKeys = {};
  Timer? _pollTimer;

  void reload() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  bool _isAvailableStatus(String s) => s == 'pending';

  bool _isMineStatus(String s) =>
      s == 'accepted' ||
      s == 'depot_selected' ||
      s == 'at_depot' ||
      s == 'picked_up' ||
      s == 'en_route' ||
      s == 'stop_picked_up';

  static bool _sameCalendarDay(DateTime dt, DateTime day) {
    final local = dt.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    return d == day;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'depot_selected':
        return 'Dépôt sélectionné';
      case 'at_depot':
        return 'Au dépôt';
      case 'picked_up':
        return 'Récupéré';
      case 'en_route':
        return 'En route';
      case 'delivered_paid':
        return 'Livrée & payée';
      case 'empty_returned':
        return 'Vide retourné';
      case 'stop_picked_up':
        return 'Ramassage restaurant';
      default:
        return status.replaceAll('_', ' ');
    }
  }

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

  String _fmt(int num) {
    final s = num.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }

  Future<void> _quickAccept(DriverJobItem it) async {
    if (_mine.isNotEmpty) {
      if (mounted) {
        AppToast.showError(context, "Vous avez déjà une course en cours. Veuillez la terminer avant d’en accepter une autre.");
      }
      return;
    }
    try {
      switch (it.kind) {
        case DriverJobKind.gas:
          await ApiClient.driverAcceptGasOrder(it.id);
          break;
        case DriverJobKind.parcel:
          await ApiClient.driverAcceptParcelOrder(it.id);
          break;
        case DriverJobKind.food:
          await ApiClient.driverAcceptFoodOrder(it.id);
          break;
      }
      if (!mounted) return;
      AppToast.showSuccess(context, 'Mission acceptée avec succès !');
      await _load();
      await _openDetail(it);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    }
  }

  Future<void> _openDetail(DriverJobItem it) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DriverJobDetailScreen(kind: it.kind, id: it.id)),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _previewAvailable(DriverJobItem it) async {
    final b = _PremiumJobList._badge(it.kind);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: b.$1, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: Icon(b.$3, color: b.$2, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.title,
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: FamanhColors.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTimeFr(it.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FamanhColors.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SheetRow(label: 'Détail', value: it.subtitle),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Montant', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: FamanhColors.onSurfaceVariant)),
                  Text(
                    '${_fmt(it.amountFcfa)} FCFA',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: FamanhColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SlidableAcceptButton(
                label: 'Glisser pour accepter la course',
                onAccept: () async {
                  Navigator.of(ctx).pop();
                  await _quickAccept(it);
                },
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Ignorer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final gas = await ApiClient.getDriverGasOrders();
      final parcel = await ApiClient.getDriverParcelOrders();
      final food = await ApiClient.getDriverFoodOrders();

      final all = <DriverJobItem>[
        for (final g in gas)
          DriverJobItem(
            kind: DriverJobKind.gas,
            id: g.id,
            status: g.status,
            createdAt: g.createdAt,
            title: 'Livraison Gaz • ${g.brand ?? 'B12'} ${g.size ?? ''}'.trim(),
            subtitle: 'Qté ${g.qty} bouteille(s) • Dépôt vers client',
            amountFcfa: g.priceFcfa,
            pickupAddress: 'Dépôt Gaz Adiaké',
            dropoffAddress: 'Client Résidentiel',
          ),
        for (final p in parcel)
          DriverJobItem(
            kind: DriverJobKind.parcel,
            id: p.id,
            status: p.status,
            createdAt: p.createdAt,
            title: 'Colis Express • ${p.packageLabel ?? 'Paquet'}',
            subtitle: 'Livraison express sécurisée',
            amountFcfa: p.deliveryFeeFcfa,
            pickupAddress: 'Point de ramassage',
            dropoffAddress: 'Destination Colis',
          ),
        for (final f in food)
          DriverJobItem(
            kind: DriverJobKind.food,
            id: f.id,
            status: f.status,
            createdAt: f.createdAt,
            title: 'Repas Chauds • ${f.stops.firstOrNull?.restaurantNameSnapshot ?? 'Restaurant'}',
            subtitle: '${f.stops.length} arrêt(s) • ${_fmt(f.subtotalFcfa)} + ${_fmt(f.deliveryFeeFcfa)} FCFA',
            amountFcfa: f.subtotalFcfa + f.deliveryFeeFcfa,
            pickupAddress: f.stops.firstOrNull?.restaurantNameSnapshot ?? 'Restaurant',
            dropoffAddress: 'Quartier Client',
          ),
      ];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      int todayTrips = 0;
      int todayRevenue = 0;
      int yesterdayRevenue = 0;
      int activeTrips = 0;

      for (final g in gas) {
        if (_isMineStatus(g.status)) activeTrips++;
        if (g.status == 'delivered_paid') {
          if (_sameCalendarDay(g.createdAt, today)) {
            todayTrips++;
            todayRevenue += g.priceFcfa;
          } else if (_sameCalendarDay(g.createdAt, yesterday)) {
            yesterdayRevenue += g.priceFcfa;
          }
        }
      }
      for (final p in parcel) {
        if (_isMineStatus(p.status)) activeTrips++;
        if (p.status == 'delivered_paid') {
          if (_sameCalendarDay(p.createdAt, today)) {
            todayTrips++;
            todayRevenue += p.deliveryFeeFcfa;
          } else if (_sameCalendarDay(p.createdAt, yesterday)) {
            yesterdayRevenue += p.deliveryFeeFcfa;
          }
        }
      }
      for (final f in food) {
        if (_isMineStatus(f.status)) activeTrips++;
        if (f.status == 'delivered_paid') {
          final amt = f.subtotalFcfa + f.deliveryFeeFcfa;
          if (_sameCalendarDay(f.createdAt, today)) {
            todayTrips++;
            todayRevenue += amt;
          } else if (_sameCalendarDay(f.createdAt, yesterday)) {
            yesterdayRevenue += amt;
          }
        }
      }

      final available = all.where((e) => _isAvailableStatus(e.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final mine = all.where((e) => _isMineStatus(e.status)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final currentKeys = available.map((j) => '${j.kind.name}_${j.id}').toSet();
      final newArrivals = available.where((j) => !_notifiedJobKeys.contains('${j.kind.name}_${j.id}')).toList();

      if (newArrivals.isNotEmpty && _notifiedJobKeys.isNotEmpty) {
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        final freshJob = newArrivals.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && mine.isEmpty) {
            _previewAvailable(freshJob);
          }
        });
      }
      _notifiedJobKeys = currentKeys;

      if (!mounted) return;
      setState(() {
        _available = available;
        _mine = mine;
        _todayRevenue = todayRevenue;
        _todayTrips = todayTrips;
        _loading = false;
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

  @override
  Widget build(BuildContext context) {
    final filteredAvailable = _selectedCategory == null
        ? _available
        : _available.where((e) => e.kind == _selectedCategory).toList();

    final foodCount = _available.where((e) => e.kind == DriverJobKind.food).length;
    final gasCount = _available.where((e) => e.kind == DriverJobKind.gas).length;
    final parcelCount = _available.where((e) => e.kind == DriverJobKind.parcel).length;

    return RefreshIndicator(
      color: FamanhColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. REVENUS D'AUJOURD'HUI Hero Card (Bleu Nuit Gradient)
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF003859), Color(0xFF006194)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003859).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'REVENUS D\'AUJOURD\'HUI',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_fmt(_todayRevenue)} FCFA',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6CF8BB), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$_todayTrips course(s) effectuée(s) aujourd\'hui',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Metrics Cards Row (EN ATTENTE & ESPÈCES)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: FamanhColors.outlineVariant.withValues(alpha: 0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: FamanhColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.local_shipping_rounded, color: FamanhColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EN ATTENTE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: FamanhColors.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_available.length} courses',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: FamanhColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: FamanhColors.outlineVariant.withValues(alpha: 0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: FamanhColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.payments_rounded, color: FamanhColors.secondary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ESPÈCES',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: FamanhColors.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_fmt(_todayRevenue)} F',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: FamanhColors.onSurface,
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
                  const SizedBox(height: 16),

                  // 3. TabBar (Missions disponibles vs En cours)
                  Container(
                    decoration: BoxDecoration(
                      color: FamanhColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabs,
                      indicator: BoxDecoration(
                        color: FamanhColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: FamanhColors.primary,
                      unselectedLabelColor: FamanhColors.outline,
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(text: 'Missions disponibles (${_available.length})'),
                        Tab(text: 'En cours (${_mine.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Category Filter Chips (Tous, Repas, Gaz, Colis)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipPill(
                          label: 'Tous (${_available.length})',
                          selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: '🍔 Repas ($foodCount)',
                          selected: _selectedCategory == DriverJobKind.food,
                          onTap: () => setState(() => _selectedCategory = DriverJobKind.food),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: '🔥 Gaz & Énergie ($gasCount)',
                          selected: _selectedCategory == DriverJobKind.gas,
                          onTap: () => setState(() => _selectedCategory = DriverJobKind.gas),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipPill(
                          label: '📦 Colis Express ($parcelCount)',
                          selected: _selectedCategory == DriverJobKind.parcel,
                          onTap: () => setState(() => _selectedCategory = DriverJobKind.parcel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: FamanhColors.primary))
                  : (_error != null)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                style: GoogleFonts.inter(color: FamanhColors.error, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _PremiumJobList(
                              items: filteredAvailable,
                              statusLabel: _statusLabel,
                              formatDate: _formatDateTimeFr,
                              showAccept: true,
                              onDetail: _openDetail,
                              onAccept: _quickAccept,
                              onPreview: _previewAvailable,
                            ),
                            _PremiumJobList(
                              items: _mine,
                              statusLabel: _statusLabel,
                              formatDate: _formatDateTimeFr,
                              showAccept: false,
                              onDetail: _openDetail,
                              onAccept: null,
                              onPreview: null,
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

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          color: selected ? FamanhColors.primary : FamanhColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : FamanhColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PremiumJobList extends StatelessWidget {
  const _PremiumJobList({
    required this.items,
    required this.statusLabel,
    required this.formatDate,
    required this.showAccept,
    required this.onDetail,
    required this.onAccept,
    required this.onPreview,
  });

  final List<DriverJobItem> items;
  final String Function(String) statusLabel;
  final String Function(DateTime) formatDate;
  final bool showAccept;
  final Future<void> Function(DriverJobItem) onDetail;
  final Future<void> Function(DriverJobItem)? onAccept;
  final Future<void> Function(DriverJobItem)? onPreview;

  static (Color bg, Color fg, IconData icon) _badge(DriverJobKind k) {
    switch (k) {
      case DriverJobKind.gas:
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D), Icons.propane_tank_rounded);
      case DriverJobKind.food:
        return (const Color(0xFFFFEDD5), const Color(0xFFC2410C), Icons.restaurant_rounded);
      case DriverJobKind.parcel:
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8), Icons.inventory_2_rounded);
    }
  }

  String _fmt(int num) {
    final s = num.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: FamanhColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 48, color: FamanhColors.outline),
            const SizedBox(height: 12),
            Text(
              'Aucune mission disponible pour le moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FamanhColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vous serez notifié dès qu\'une nouvelle course arrive.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: FamanhColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final it = items[i];
        final b = _badge(it.kind);
        return Container(
          decoration: BoxDecoration(
            color: FamanhColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FamanhColors.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: b.$1,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(b.$3, color: b.$2, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FamanhColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'GARANTI + POURBOIRE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: FamanhColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_fmt(it.amountFcfa)} FCFA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: FamanhColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Addresses Timeline Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FamanhColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: FamanhColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            it.pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FamanhColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 3.5, top: 2, bottom: 2),
                      child: SizedBox(
                        height: 10,
                        child: VerticalDivider(thickness: 1, color: FamanhColors.outlineVariant),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: FamanhColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            it.dropoffAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FamanhColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Metrics Row Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded, size: 16, color: FamanhColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        '1.4 km',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FamanhColors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.timer_outlined, size: 16, color: FamanhColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        '~12 min',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FamanhColors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.shopping_bag_outlined, size: 16, color: FamanhColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        'Détails',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FamanhColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action Button
              if (showAccept && onAccept != null)
                SlidableAcceptButton(
                  label: 'Glisser pour accepter la course',
                  onAccept: () async {
                    await onAccept!(it);
                  },
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => onDetail(it),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FamanhColors.primary,
                      side: const BorderSide(color: FamanhColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Ouvrir le suivi de course',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: FamanhColors.outline, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: FamanhColors.onSurface, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidableAcceptButton extends StatefulWidget {
  const _SlidableAcceptButton({
    required this.label,
    required this.onAccept,
  });

  final String label;
  final Future<void> Function() onAccept;

  @override
  State<_SlidableAcceptButton> createState() => _SlidableAcceptButtonState();
}

class _SlidableAcceptButtonState extends State<_SlidableAcceptButton> {
  double _dragPosition = 0.0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 54;
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: FamanhColors.primaryContainer,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: FamanhColors.primaryContainer.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _dragPosition + 52,
                height: 54,
                decoration: BoxDecoration(
                  color: FamanhColors.primary,
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragPosition / (maxDrag == 0 ? 1 : maxDrag))).clamp(0.2, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition,
                top: 4,
                bottom: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: _submitting
                      ? null
                      : (details) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: _submitting
                      ? null
                      : (details) async {
                          if (_dragPosition >= maxDrag * 0.70) {
                            setState(() {
                              _dragPosition = maxDrag;
                              _submitting = true;
                            });
                            HapticFeedback.heavyImpact();
                            try {
                              await widget.onAccept();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _submitting = false;
                                  _dragPosition = 0.0;
                                });
                              }
                            }
                          } else {
                            setState(() {
                              _dragPosition = 0.0;
                            });
                          }
                        },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: _submitting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: FamanhColors.primary),
                          )
                        : const Icon(Icons.arrow_forward_rounded, color: FamanhColors.primary, size: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
