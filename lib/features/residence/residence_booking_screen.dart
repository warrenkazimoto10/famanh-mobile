import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/money_text.dart';

class ResidenceBookingScreen extends StatefulWidget {
  const ResidenceBookingScreen({
    super.key,
    required this.residence,
    this.initialRange,
    this.initialGuests,
  });

  final ResidenceDto residence;
  final DateTimeRange? initialRange;
  final int? initialGuests;

  @override
  State<ResidenceBookingScreen> createState() => _ResidenceBookingScreenState();
}

class _ResidenceBookingScreenState extends State<ResidenceBookingScreen> {
  DateTimeRange? _dateRange;
  int _guests = 2;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = widget.initialRange ?? DateTimeRange(
      start: now.add(const Duration(days: 2)),
      end: now.add(const Duration(days: 5)),
    );
    _guests = widget.initialGuests ?? (widget.residence.capacity > 0 ? (widget.residence.capacity > 2 ? 2 : widget.residence.capacity) : 2);
  }

  int get _nights => _dateRange?.duration.inDays ?? 1;
  int get _total => widget.residence.pricePerNight * (_nights < 1 ? 1 : _nights);
  int get _depositAmount => (_total * 0.10).ceil(); // 10% deposit

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: FamanhColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: FamanhColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (res != null) {
      setState(() => _dateRange = res);
    }
  }

  Future<void> _submit() async {
    if (_dateRange == null) {
      setState(() => _error = 'Veuillez choisir vos dates de séjour.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      await ApiClient.bookResidence(
        residenceId: widget.residence.id,
        checkIn: fmt.format(_dateRange!.start),
        checkOut: fmt.format(_dateRange!.end),
        guests: _guests,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF6CF8BB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00714D), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Réservation Confirmée !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF131B2E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre séjour a bien été réservé. Le paiement s\'effectuera en espèces à votre arrivée.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF707881)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FamanhColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('RETOUR À L\'ACCUEIL', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final df = DateFormat('dd MMM yyyy');
    final r = widget.residence;

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
                      'Réservation VIP',
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

          // ── BODY FORM ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Residence Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: r.imageUrl!, fit: BoxFit.cover)
                              : Container(color: const Color(0xFFEAEDFF)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFDDB8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                r.type.toUpperCase(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF2A1700)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.address ?? 'Adiaké • Bord de lagune',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF707881)),
                            ),
                            const SizedBox(height: 4),
                            MoneyText(
                              r.pricePerNight,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: FamanhColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date Selection Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATES DU SÉJOUR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDates,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, color: FamanhColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dateRange == null
                                    ? const Text('Sélectionner vos dates', style: TextStyle(fontWeight: FontWeight.w700))
                                    : Text(
                                        '${df.format(_dateRange!.start)} → ${df.format(_dateRange!.end)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                      ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: FamanhColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_nights nuit${_nights > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Travelers Stepper Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.group_rounded, color: FamanhColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('VOYAGEURS VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5)),
                            Text(
                              '$_guests personne${_guests > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_guests > 1) setState(() => _guests--);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAEDFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF131B2E)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('$_guests', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          GestureDetector(
                            onTap: () {
                              final maxCap = r.capacity > 0 ? r.capacity : 20;
                              if (_guests < maxCap) setState(() => _guests++);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: FamanhColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notes Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NOTES PARTICULIÈRES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Précisez vos besoins (arrivée tardive, lit bébé, transfert bateau lagonaire...)',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF707881)),
                          filled: true,
                          fillColor: const Color(0xFFF2F3FF),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MODE DE RÈGLEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5)),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.payments_rounded, color: Color(0xFF00714D), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paiement en espèces à l\'arrivée',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                ),
                                Text(
                                  'Règlement direct lors de la remise des clés',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF707881)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Breakdown Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RÉCAPITULATIF FINANCIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5)),
                      const SizedBox(height: 12),
                      _PriceRow(label: 'Tarif par nuit (${widget.residence.pricePerNight} FCFA x $_nights)', value: '$_total FCFA'),
                      const SizedBox(height: 8),
                      const _PriceRow(label: 'Service Conciergerie VIP', value: 'Inclus', isGreen: true),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total du séjour', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF131B2E))),
                          MoneyText(_total, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF131B2E))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDDB8).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Acompte requis pour confirmer (10%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF653E00))),
                            MoneyText(_depositAmount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF653E00))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FamanhColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('PASSER AU PAIEMENT DE L\'ACOMPTE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.isGreen = false});
  final String label;
  final String value;
  final bool isGreen;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF707881))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isGreen ? const Color(0xFF00714D) : const Color(0xFF131B2E),
          ),
        ),
      ],
    );
  }
}
