import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';

enum RevenueDateFilter { today, last7Days, thisMonth, custom }

class RevenueTransactionItem {
  const RevenueTransactionItem({
    required this.id,
    required this.type, // 'food', 'gas', 'parcel'
    required this.date,
    required this.amountFcfa,
    required this.title,
    required this.subtitle,
  });

  final int id;
  final String type;
  final DateTime date;
  final int amountFcfa;
  final String title;
  final String subtitle;
}

class DriverRevenuesScreen extends StatefulWidget {
  const DriverRevenuesScreen({super.key});

  @override
  State<DriverRevenuesScreen> createState() => _DriverRevenuesScreenState();
}

class _DriverRevenuesScreenState extends State<DriverRevenuesScreen> {
  bool _loading = true;
  String? _error;

  RevenueDateFilter _activeFilter = RevenueDateFilter.today;
  DateTimeRange? _customDateRange;

  List<RevenueTransactionItem> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gas = await ApiClient.getDriverGasOrders();
      final parcel = await ApiClient.getDriverParcelOrders();
      final food = await ApiClient.getDriverFoodOrders();

      final list = <RevenueTransactionItem>[];

      for (final g in gas) {
        if (g.status == 'delivered_paid') {
          list.add(
            RevenueTransactionItem(
              id: g.id,
              type: 'gas',
              date: g.createdAt,
              amountFcfa: g.priceFcfa,
              title: 'Livraison Gaz • ${g.brand ?? 'B12'} ${g.size ?? ''}'.trim(),
              subtitle: 'Bouteille de gaz (${g.qty}x)',
            ),
          );
        }
      }

      for (final p in parcel) {
        if (p.status == 'delivered_paid') {
          list.add(
            RevenueTransactionItem(
              id: p.id,
              type: 'parcel',
              date: p.createdAt,
              amountFcfa: p.deliveryFeeFcfa,
              title: 'Colis Express • ${p.packageLabel ?? 'Paquet'}',
              subtitle: 'Course coursier livrée',
            ),
          );
        }
      }

      for (final f in food) {
        if (f.status == 'delivered_paid') {
          list.add(
            RevenueTransactionItem(
              id: f.id,
              type: 'food',
              date: f.createdAt,
              amountFcfa: f.subtotalFcfa + f.deliveryFeeFcfa,
              title: 'Repas • ${f.stops.firstOrNull?.restaurantNameSnapshot ?? 'Restaurant'}',
              subtitle: 'Commande livrée & payée',
            ),
          );
        }
      }

      // Trier par date décroissante
      list.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _allTransactions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<RevenueTransactionItem> get _filteredTransactions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_activeFilter) {
      case RevenueDateFilter.today:
        return _allTransactions.where((t) {
          final d = t.date.toLocal();
          return DateTime(d.year, d.month, d.day) == today;
        }).toList();

      case RevenueDateFilter.last7Days:
        final start = today.subtract(const Duration(days: 7));
        return _allTransactions.where((t) {
          final d = t.date.toLocal();
          return d.isAfter(start) || DateTime(d.year, d.month, d.day) == today;
        }).toList();

      case RevenueDateFilter.thisMonth:
        final startMonth = DateTime(now.year, now.month, 1);
        return _allTransactions.where((t) {
          final d = t.date.toLocal();
          return d.isAfter(startMonth) || (d.year == now.year && d.month == now.month);
        }).toList();

      case RevenueDateFilter.custom:
        if (_customDateRange == null) return _allTransactions;
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        return _allTransactions.where((t) {
          final d = t.date.toLocal();
          return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _customDateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: FamanhColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: FamanhColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _activeFilter = RevenueDateFilter.custom;
      });
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

  String _formatDateFr(DateTime dt) {
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mo/$yyyy à $hh:$mm';
  }

  String _getFilterPeriodLabel() {
    final now = DateTime.now();
    switch (_activeFilter) {
      case RevenueDateFilter.today:
        return 'Aujourd\'hui (${now.day}/${now.month}/${now.year})';
      case RevenueDateFilter.last7Days:
        return '7 derniers jours';
      case RevenueDateFilter.thisMonth:
        return 'Ce mois-ci';
      case RevenueDateFilter.custom:
        if (_customDateRange == null) return 'Période personnalisée';
        final s = _customDateRange!.start;
        final e = _customDateRange!.end;
        return '${s.day}/${s.month} - ${e.day}/${e.month}/${e.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTransactions;
    int totalRevenue = 0;
    int foodRevenue = 0;
    int gasRevenue = 0;
    int parcelRevenue = 0;

    for (final item in filteredList) {
      totalRevenue += item.amountFcfa;
      if (item.type == 'food') {
        foodRevenue += item.amountFcfa;
      } else if (item.type == 'gas') {
        gasRevenue += item.amountFcfa;
      } else if (item.type == 'parcel') {
        parcelRevenue += item.amountFcfa;
      }
    }

    return Scaffold(
      backgroundColor: FamanhColors.surface,
      body: RefreshIndicator(
        color: FamanhColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed(
                  [
                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revenus Livreur',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: FamanhColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gains réels & filtrage par date',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: FamanhColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: FamanhColors.primary, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date Filters Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _DateFilterChip(
                            label: 'Aujourd\'hui',
                            selected: _activeFilter == RevenueDateFilter.today,
                            onTap: () => setState(() => _activeFilter = RevenueDateFilter.today),
                          ),
                          const SizedBox(width: 8),
                          _DateFilterChip(
                            label: '7 derniers jours',
                            selected: _activeFilter == RevenueDateFilter.last7Days,
                            onTap: () => setState(() => _activeFilter = RevenueDateFilter.last7Days),
                          ),
                          const SizedBox(width: 8),
                          _DateFilterChip(
                            label: 'Ce mois-ci',
                            selected: _activeFilter == RevenueDateFilter.thisMonth,
                            onTap: () => setState(() => _activeFilter = RevenueDateFilter.thisMonth),
                          ),
                          const SizedBox(width: 8),
                          _DateFilterChip(
                            label: _activeFilter == RevenueDateFilter.custom && _customDateRange != null
                                ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                                : 'Personnalisé 📅',
                            selected: _activeFilter == RevenueDateFilter.custom,
                            onTap: _selectCustomDateRange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: FamanhColors.primary)),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: FamanhColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(_error!, style: GoogleFonts.inter(color: FamanhColors.error, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    else ...[
                      // Total Revenue Hero Card (Bleu Nuit Gradient)
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
                                  'TOTAL DES REVENUS GAGNÉS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getFilterPeriodLabel(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_fmt(totalRevenue)} FCFA',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF6CF8BB), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${filteredList.length} course(s) livrée(s) et payée(s)',
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
                      const SizedBox(height: 16),

                      // Category Breakdown Grid (Repas, Gaz, Colis)
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryRevenueCard(
                              label: '🍔 Repas',
                              amount: '${_fmt(foodRevenue)} F',
                              count: filteredList.where((t) => t.type == 'food').length,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CategoryRevenueCard(
                              label: '🔥 Gaz',
                              amount: '${_fmt(gasRevenue)} F',
                              count: filteredList.where((t) => t.type == 'gas').length,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CategoryRevenueCard(
                              label: '📦 Colis',
                              amount: '${_fmt(parcelRevenue)} F',
                              count: filteredList.where((t) => t.type == 'parcel').length,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Transactions List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HISTORIQUE DES TRANSACTIONS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: FamanhColors.primary,
                            ),
                          ),
                          Text(
                            '${filteredList.length} résultat(s)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FamanhColors.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (filteredList.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 44, color: FamanhColors.outline),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun revenu enregistré sur cette période.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: FamanhColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Essayez de changer le filtre de date ci-dessus.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: FamanhColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final iconInfo = _getItemIconInfo(item.type);

                            return Container(
                              decoration: BoxDecoration(
                                color: FamanhColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: FamanhColors.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: iconInfo.$1,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(iconInfo.$3, color: iconInfo.$2, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: FamanhColors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDateFr(item.date),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: FamanhColors.outline,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '+${_fmt(item.amountFcfa)} F',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: FamanhColors.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: FamanhColors.secondaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Payée',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: FamanhColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // Demande de Virement CTA
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () {
                            AppToast.showSuccess(context, 'Demande de transfert de solde soumise.');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: FamanhColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.account_balance_rounded, size: 20),
                          label: Text(
                            'Demander un virement / Transfert',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color bg, Color fg, IconData icon) _getItemIconInfo(String type) {
    switch (type) {
      case 'gas':
        return (const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.propane_tank_rounded);
      case 'parcel':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8), Icons.inventory_2_rounded);
      case 'food':
      default:
        return (const Color(0xFFFFEDD5), const Color(0xFFEA580C), Icons.restaurant_rounded);
    }
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FamanhColors.primary : FamanhColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FamanhColors.primary : FamanhColors.outlineVariant.withValues(alpha: 0.4),
          ),
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

class _CategoryRevenueCard extends StatelessWidget {
  const _CategoryRevenueCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  final String label;
  final String amount;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: FamanhColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FamanhColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: FamanhColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$count course(s)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: FamanhColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
