import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import 'driver_job_detail_screen.dart';
import 'driver_jobs_screen.dart';

class DriverJobSuccessScreen extends StatefulWidget {
  const DriverJobSuccessScreen({
    super.key,
    required this.orderId,
    required this.orderType,
    required this.earningsFcfa,
    this.distanceKm = 8.4,
    this.durationMinutes = 24,
    this.pickupName = 'Restaurant Le Lagon',
    this.pickupAddress = 'Centre-Ville Adiaké',
    this.dropoffName = 'Kouassi Jean-Philippe',
    this.dropoffAddress = 'Quartier Résidentiel, Villa 14',
    this.itemSummary = 'Pack 2x Tchêp & Alloco + Jus d\'ananas',
  });

  final String orderId;
  final String orderType; // 'food', 'parcel', 'gas'
  final int earningsFcfa;
  final double distanceKm;
  final int durationMinutes;
  final String pickupName;
  final String pickupAddress;
  final String dropoffName;
  final String dropoffAddress;
  final String itemSummary;

  @override
  State<DriverJobSuccessScreen> createState() => _DriverJobSuccessScreenState();
}

class _DriverJobSuccessScreenState extends State<DriverJobSuccessScreen> {
  bool _loadingNext = true;
  bool _acceptingNext = false;
  DriverJobItem? _recommendedJob;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedNextJob();
  }

  Future<void> _fetchRecommendedNextJob() async {
    try {
      final gas = await ApiClient.getDriverGasOrders();
      final parcel = await ApiClient.getDriverParcelOrders();
      final food = await ApiClient.getDriverFoodOrders();

      final pending = <DriverJobItem>[
        for (final f in food)
          if (f.status == 'pending')
            DriverJobItem(
              kind: DriverJobKind.food,
              id: f.id,
              status: f.status,
              createdAt: f.createdAt,
              title: 'Repas • ${f.stops.firstOrNull?.restaurantNameSnapshot ?? 'Restaurant'}',
              subtitle: '${f.stops.length} arrêt(s) • Adiaké',
              amountFcfa: f.deliveryFeeFcfa > 0 ? f.deliveryFeeFcfa : 1200,
            ),
        for (final p in parcel)
          if (p.status == 'pending')
            DriverJobItem(
              kind: DriverJobKind.parcel,
              id: p.id,
              status: p.status,
              createdAt: p.createdAt,
              title: 'Colis Express • ${p.packageLabel ?? 'Colis'}',
              subtitle: 'Ramassage → Livraison Adiaké',
              amountFcfa: p.deliveryFeeFcfa,
            ),
        for (final g in gas)
          if (g.status == 'pending')
            DriverJobItem(
              kind: DriverJobKind.gas,
              id: g.id,
              status: g.status,
              createdAt: g.createdAt,
              title: 'Gaz • ${g.brand ?? ''} ${g.size ?? ''}'.trim(),
              subtitle: 'Bouteille de gaz (${g.qty}x) • Adiaké',
              amountFcfa: g.priceFcfa,
            ),
      ];

      if (mounted) {
        setState(() {
          _recommendedJob = pending.isNotEmpty ? pending.first : null;
          _loadingNext = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recommendedJob = null;
          _loadingNext = false;
        });
      }
    }
  }

  Future<void> _acceptNextJob(DriverJobItem job) async {
    if (_acceptingNext) return;
    setState(() => _acceptingNext = true);
    try {
      switch (job.kind) {
        case DriverJobKind.gas:
          await ApiClient.driverAcceptGasOrder(job.id);
          break;
        case DriverJobKind.parcel:
          await ApiClient.driverAcceptParcelOrder(job.id);
          break;
        case DriverJobKind.food:
          await ApiClient.driverAcceptFoodOrder(job.id);
          break;
      }
      if (!mounted) return;
      AppToast.showSuccess(context, 'Nouvelle course acceptée !');
      // Rediriger directement sur le détail de la nouvelle mission
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DriverJobDetailScreen(kind: job.kind, id: job.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _acceptingNext = false);
    }
  }

  String _formatFcfa(int amount) {
    final s = amount.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        sb.write(' ');
      }
      sb.write(s[i]);
    }
    return '${sb.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = widget.orderType == 'food'
        ? 'Repas'
        : (widget.orderType == 'gas' ? 'Recharge Gaz' : 'Colis Express');

    return Scaffold(
      backgroundColor: FamanhColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: FamanhColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mission Terminée',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: FamanhColors.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Celebration Header Card
            Container(
              decoration: BoxDecoration(
                color: FamanhColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Animated green check icon with ring
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Livraison terminée avec succès !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: FamanhColors.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: FamanhColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Course #${widget.orderId} • $orderLabel validée',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FamanhColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Earnings Breakdown Card
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006C49), Color(0xFF005236)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF006C49).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
                        'GAINS DE CETTE COURSE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Solde mis à jour',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '+${_formatFcfa(widget.earningsFcfa)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF6CF8BB), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Tarif garanti • Crédité au portefeuille livreur',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Mission Synthesis Card
            Container(
              decoration: BoxDecoration(
                color: FamanhColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYNTHÈSE DU TRAJET',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: FamanhColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Distance & Duration metrics
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.straighten_rounded, color: FamanhColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Distance',
                                    style: GoogleFonts.inter(fontSize: 10, color: FamanhColors.outline, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${widget.distanceKm.toStringAsFixed(1)} km',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: FamanhColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: FamanhColors.secondary, size: 20),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Durée',
                                    style: GoogleFonts.inter(fontSize: 10, color: FamanhColors.outline, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${widget.durationMinutes} min',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Pickup Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEFF6FF),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: FamanhColors.primary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POINT DE RETRAIT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: FamanhColors.outline, letterSpacing: 0.8),
                            ),
                            Text(
                              widget.pickupName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
                            ),
                            Text(
                              widget.pickupAddress,
                              style: GoogleFonts.inter(fontSize: 12, color: FamanhColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 13, top: 4, bottom: 4),
                    child: SizedBox(
                      height: 16,
                      child: VerticalDivider(thickness: 1.5, color: FamanhColors.outlineVariant),
                    ),
                  ),
                  // Dropoff Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF0FDF4),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: FamanhColors.secondary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DESTINATION CLIENT',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: FamanhColors.outline, letterSpacing: 0.8),
                            ),
                            Text(
                              widget.dropoffName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: FamanhColors.onSurface),
                            ),
                            Text(
                              widget.dropoffAddress,
                              style: GoogleFonts.inter(fontSize: 12, color: FamanhColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: FamanhColors.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),

                  // Item Summary
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 18, color: FamanhColors.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.itemSummary,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FamanhColors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Recommended Next Priority Job Card (Dynamiquement chargé depuis la BD)
            if (_loadingNext)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FamanhColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: FamanhColors.primary),
                  ),
                ),
              )
            else if (_recommendedJob != null)
              Container(
                decoration: BoxDecoration(
                  color: FamanhColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FamanhColors.primary.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: FamanhColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
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
                            const SizedBox(width: 8),
                            Text(
                              'COURSE PRIORITAIRE EN ATTENTE (BD)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: FamanhColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'À proximité',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _recommendedJob!.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: FamanhColors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '+${_formatFcfa(_recommendedJob!.amountFcfa)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FamanhColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recommendedJob!.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FamanhColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _acceptingNext ? null : () => _acceptNextJob(_recommendedJob!),
                        style: FilledButton.styleFrom(
                          backgroundColor: FamanhColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: _acceptingNext
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 20),
                        label: Text(
                          'Accepter la course suivante',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FamanhColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: FamanhColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aucune autre mission en attente dans la base de données. Vous êtes prioritaire pour la prochaine commande !',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FamanhColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // 5. Back to missions button
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FamanhColors.onSurface,
                  side: const BorderSide(color: FamanhColors.outlineVariant, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: FamanhColors.surfaceContainerLow,
                ),
                child: Text(
                  'Retour aux missions disponibles',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
