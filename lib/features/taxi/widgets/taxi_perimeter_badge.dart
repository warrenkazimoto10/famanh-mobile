import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiPerimeterBadge extends StatelessWidget {
  final double distanceKm;
  final double urbanPerimeterKm;
  final double baseFare;
  final double perKmFare;
  final double totalFare;
  final bool isNight;

  const TaxiPerimeterBadge({
    super.key,
    required this.distanceKm,
    this.urbanPerimeterKm = 3.5,
    this.baseFare = 200.0,
    this.perKmFare = 150.0,
    required this.totalFare,
    this.isNight = false,
  });

  bool get isUrban => distanceKm <= urbanPerimeterKm;

  @override
  Widget build(BuildContext context) {
    if (distanceKm <= 0.1) {
      return const SizedBox.shrink();
    }

    final isInside = isUrban;
    final extraKm = (distanceKm - urbanPerimeterKm).clamp(0.0, 999.0);
    final extraCost = extraKm * perKmFare;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInside ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInside ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isInside ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isInside ? Icons.check_circle_rounded : Icons.radar_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isInside
                      ? 'Zone Urbaine d\'Adiaké (${distanceKm.toStringAsFixed(1)} km)'
                      : 'Zone Périurbaine (${distanceKm.toStringAsFixed(1)} km)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isInside ? const Color(0xFF14532D) : const Color(0xFF78350F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isInside ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isInside ? 'Tarif Forfaitaire' : 'Calcul Kilométrique',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isInside ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isInside
                ? 'Course standard incluse dans le rayon urbain (${urbanPerimeterKm.toStringAsFixed(1)} km). Pas de frais de distance supplémentaire.'
                : 'Trajet au-delà de la zone urbaine (${urbanPerimeterKm.toStringAsFixed(1)} km) : Forfait base + ${extraKm.toStringAsFixed(1)} km extra (${extraCost.toStringAsFixed(0)} F).',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isInside ? const Color(0xFF166534) : const Color(0xFF92400E),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
