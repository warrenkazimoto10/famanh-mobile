import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/money_text.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/skeleton_loader.dart';

class MyResidenceBookingsScreen extends StatefulWidget {
  const MyResidenceBookingsScreen({super.key});

  @override
  State<MyResidenceBookingsScreen> createState() => _MyResidenceBookingsScreenState();
}

class _MyResidenceBookingsScreenState extends State<MyResidenceBookingsScreen> {
  bool _loading = true;
  String? _error;
  List<ResidenceBookingDto> _list = const [];

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
      final rows = await ApiClient.getMyResidenceBookings();
      if (!mounted) return;
      setState(() {
        _list = rows;
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: FamanhColors.background,
      body: Column(
        children: [
          // ── TOP FIXED HEADER BAR (Identical to Home Page) ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(8, topPadding + 6, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              border: Border(
                bottom: BorderSide(
                  color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
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
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: FamanhColors.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                Image.asset(
                  'assets/logo.png',
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const BrandLogo(size: 32, radius: 8),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    const Text(
                      'Mes Réservations',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FamanhColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: FamanhColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 18),
                        color: FamanhColors.onSurfaceVariant,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<UserMeDto?>(
                      valueListenable: ApiSession.currentUser,
                      builder: (context, me, _) {
                        final name = me?.name ?? 'CI';
                        final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C';
                        return Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: FamanhColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── LIST CONTENT ──────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: FamanhColors.primary,
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (context, i) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: SkeletonLoader(width: double.infinity, height: 120, borderRadius: 16),
                      ),
                    )
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                          ],
                        )
                      : _list.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 70, color: const Color(0xFFBFC7D2)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Aucune réservation trouvée',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Vous n\'avez pas encore effectué de réservation.'),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: FamanhColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Réserver un séjour', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(height: 60),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _list.length,
                              itemBuilder: (context, i) {
                                final b = _list[i];
                                return StaggeredItem(
                                  index: i,
                                  child: _BookingTile(booking: b),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});
  final ResidenceBookingDto booking;

  Color _getStatusColor() {
    switch (booking.status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF00714D);
      case 'cancelled':
        return const Color(0xFFBA1A1A);
      case 'completed':
        return const Color(0xFF006194);
      default:
        return const Color(0xFF825100);
    }
  }

  String _getStatusLabel() {
    switch (booking.status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmée';
      case 'cancelled':
        return 'Annulée';
      case 'completed':
        return 'Terminée';
      default:
        return 'En attente d\'acompte';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              MoneyText(
                booking.totalPrice,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: FamanhColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Réservation Séjour #${booking.id}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF131B2E)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF707881)),
              const SizedBox(width: 6),
              Text(
                'Du ${df.format(booking.checkIn)} au ${df.format(booking.checkOut)}',
                style: const TextStyle(color: Color(0xFF707881), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note : ${booking.notes!}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF3F4850)),
            ),
          ],
        ],
      ),
    );
  }
}
