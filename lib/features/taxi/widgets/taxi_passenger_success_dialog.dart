import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiPassengerSuccessDialog extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final VoidCallback onDismiss;

  const TaxiPassengerSuccessDialog({
    super.key,
    required this.rideData,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required Map<String, dynamic> rideData, required VoidCallback onDismiss}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaxiPassengerSuccessDialog(rideData: rideData, onDismiss: onDismiss),
    );
  }

  @override
  State<TaxiPassengerSuccessDialog> createState() => _TaxiPassengerSuccessDialogState();
}

class _TaxiPassengerSuccessDialogState extends State<TaxiPassengerSuccessDialog> {
  int _rating = 5;
  final Set<String> _selectedCompliments = {'Conduite prudente', 'Ponctuel'};

  final List<String> _compliments = [
    'Ponctuel ⏱️',
    'Conduite prudente 🛡️',
    'Taxi propre ✨',
    'Très poli 🤝',
    'Bonne musique 🎵',
  ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.rideData['driver'] as Map<String, dynamic>?;
    final driverName = driver?['name'] ?? 'Chauffeur Taxi Adiaké';
    final vehiclePlate = driver?['vehicle_plate'] ?? '1234-AB-01';
    final fare = (widget.rideData['fare_amount'] as num?)?.toDouble() ?? 200.0;
    final pickup = widget.rideData['pickup_address'] ?? 'Point de départ';
    final dropoff = widget.rideData['dropoff_address'] ?? 'Destination';
    final seats = widget.rideData['seats_booked'] ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── CÉLÉBRATION ICON ──────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),

            // Titre & Sous-titre
            Text(
              'Course Terminée ! 🎉',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Merci d\'avoir voyagé avec Famanh Taxi Adiaké',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // ── RÉCAPITULATIF FINANCIER ───────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Montant réglé en espèces',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        '${fare.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  // Trajet
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pickup ➔ $dropoff',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        'Chauffeur : $driverName ($vehiclePlate) • $seats place(s)',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── NOTATION ÉTOILES DU CHAUFFEUR ────────────────────
            Text(
              'Comment s\'est passé votre trajet ?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  icon: Icon(
                    starNumber <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFEAB308),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _rating = starNumber);
                  },
                );
              }),
            ),
            const SizedBox(height: 12),

            // Compliments rapides
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _compliments.map((comp) {
                final isSelected = _selectedCompliments.contains(comp);
                return FilterChip(
                  label: Text(
                    comp,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFEF08A),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (val) {
                        _selectedCompliments.add(comp);
                      } else {
                        _selectedCompliments.remove(comp);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── BOUTON FINAL ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDismiss();
                },
                child: Text(
                  'Terminer & Retour à l\'accueil',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
