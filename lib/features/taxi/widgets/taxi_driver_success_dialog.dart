import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiDriverSuccessDialog extends StatelessWidget {
  final String passengerName;
  final double fareCollected;
  final double commissionDeducted;
  final double driverNetEarnings;
  final double updatedBalance;
  final VoidCallback onDismiss;

  const TaxiDriverSuccessDialog({
    super.key,
    required this.passengerName,
    required this.fareCollected,
    required this.commissionDeducted,
    required this.driverNetEarnings,
    required this.updatedBalance,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String passengerName,
    required double fareCollected,
    required double commissionDeducted,
    required double driverNetEarnings,
    required double updatedBalance,
    required VoidCallback onDismiss,
  }) {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaxiDriverSuccessDialog(
        passengerName: passengerName,
        fareCollected: fareCollected,
        commissionDeducted: commissionDeducted,
        driverNetEarnings: driverNetEarnings,
        updatedBalance: updatedBalance,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── CÉLÉBRATION BADGE ──────────────────────────────────
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.price_check_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 16),

            // Titre & Sous-titre
            Text(
              'Course Validée & Encaissée ! 💰',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Passager : $passengerName',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── DÉCOMPOSITION FINANCIÈRE SAAS ─────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // Espèces perçues
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Espèces perçues (Client)',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                      Text(
                        '+${fareCollected.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Commission prélevée
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Commission plateforme',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                      Text(
                        '-${commissionDeducted.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.white12),
                  ),

                  // Revenu net chauffeur
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gain Net Réel Chauffeur',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '+${driverNetEarnings.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFEAB308),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Solde Portefeuille Résiduel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF334155).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wallet_rounded, size: 16, color: Color(0xFFFEF08A)),
                  const SizedBox(width: 6),
                  Text(
                    'Nouveau solde portefeuille : ${updatedBalance.toStringAsFixed(0)} FCFA',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFEF08A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── BOUTON CONTINUER ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
                icon: const Icon(Icons.local_taxi_rounded, size: 20),
                label: Text(
                  'Prêt pour de nouvelles courses',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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
