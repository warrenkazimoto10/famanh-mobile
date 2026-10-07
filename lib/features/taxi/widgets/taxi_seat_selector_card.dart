import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiSeatSelectorCard extends StatelessWidget {
  final String rideType; // 'shared' or 'private'
  final int seatsBooked; // 1, 2, 3
  final bool isNight;
  final int baseSeatFare;
  final int privateFare;
  final Function(String newType, int newSeats) onChanged;

  const TaxiSeatSelectorCard({
    super.key,
    required this.rideType,
    required this.seatsBooked,
    required this.isNight,
    this.baseSeatFare = 200,
    this.privateFare = 800,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSeatPrice = isNight ? (baseSeatFare * 1.5).round() : baseSeatFare;
    final effectivePrivatePrice = isNight ? (privateFare * 1.5).round() : privateFare;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tabs (Partagé vs Privé)
          Row(
            children: [
              Expanded(
                child: _buildTypeTab(
                  isSelected: rideType == 'shared',
                  title: 'Covoiturage Partagé',
                  subtitle: '$effectiveSeatPrice F / place',
                  icon: Icons.groups_rounded,
                  badge: 'ÉCONOMIQUE',
                  badgeColor: const Color(0xFF10B981),
                  onTap: () => onChanged('shared', seatsBooked > 0 ? seatsBooked : 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTypeTab(
                  isSelected: rideType == 'private',
                  title: 'Taxi Privatisé',
                  subtitle: '$effectivePrivatePrice F direct',
                  icon: Icons.local_taxi_rounded,
                  badge: 'VIP SEUL',
                  badgeColor: const Color(0xFFF59E0B),
                  onTap: () => onChanged('private', 1),
                ),
              ),
            ],
          ),

          if (rideType == 'shared') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Visual Seats Selector
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Driver icon (fixed)
                      _buildSeatIcon(
                        isDriver: true,
                        isSelected: false,
                        label: 'Chauffeur',
                      ),
                      const SizedBox(width: 6),
                      // Passenger Seats
                      [1, 2, 3].map((sIndex) {
                        final isChosen = sIndex <= seatsBooked;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () => onChanged('shared', sIndex),
                            borderRadius: BorderRadius.circular(8),
                            child: _buildSeatIcon(
                              isDriver: false,
                              isSelected: isChosen,
                              label: 'Place $sIndex',
                            ),
                          ),
                        );
                      }).toList(),
                    ].expand((i) => i is List ? i as List<Widget> : [i as Widget]).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$seatsBooked place${seatsBooked > 1 ? 's' : ''} réservée${seatsBooked > 1 ? 's' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Total : ${effectiveSeatPrice * seatsBooked} FCFA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required bool isSelected,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade700),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(isSelected ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatIcon({
    required bool isDriver,
    required bool isSelected,
    required String label,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDriver
            ? Colors.grey.shade300
            : (isSelected ? const Color(0xFF0284C7) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDriver
              ? Colors.grey.shade400
              : (isSelected ? const Color(0xFF0284C7) : Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Icon(
          isDriver ? Icons.airline_seat_recline_normal_rounded : (isSelected ? Icons.person_rounded : Icons.person_outline_rounded),
          size: 18,
          color: isDriver ? Colors.grey.shade700 : (isSelected ? Colors.white : Colors.grey.shade400),
        ),
      ),
    );
  }
}
