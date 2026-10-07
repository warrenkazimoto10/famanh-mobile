import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class LandmarkItem {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final Color color;
  final LatLng coords;
  final String description;

  const LandmarkItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.coords,
    required this.description,
  });
}

class TaxiVisualLandmarksGrid extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(LandmarkItem item) onLandmarkSelected;

  const TaxiVisualLandmarksGrid({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onLandmarkSelected,
  });

  static Future<LandmarkItem?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return showModalBottomSheet<LandmarkItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: TaxiVisualLandmarksGrid(
          title: title,
          subtitle: subtitle,
          onLandmarkSelected: (item) => Navigator.of(ctx).pop(item),
        ),
      ),
    );
  }

  @override
  State<TaxiVisualLandmarksGrid> createState() => _TaxiVisualLandmarksGridState();
}

class _TaxiVisualLandmarksGridState extends State<TaxiVisualLandmarksGrid> {
  String _selectedCategory = 'all';

  static const List<LandmarkItem> defaultLandmarks = [
    LandmarkItem(
      id: 'marche',
      name: 'Grand Marché Central',
      category: 'commerce',
      icon: Icons.storefront_rounded,
      color: Color(0xFFE11D48),
      coords: LatLng(5.2863, -3.2981),
      description: 'Gare routière & Étalages centraux',
    ),
    LandmarkItem(
      id: 'hopital',
      name: 'Hôpital Général',
      category: 'sante',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF0284C7),
      coords: LatLng(5.2910, -3.3050),
      description: 'Urgences & Maternité d\'Adiaké',
    ),
    LandmarkItem(
      id: 'debarcadere',
      name: 'Débarcadère / Quai Lagunaire',
      category: 'transport',
      icon: Icons.directions_boat_rounded,
      color: Color(0xFF0D9488),
      coords: LatLng(5.2815, -3.3012),
      description: 'Embarcadère pirogues vers Assinie & îles',
    ),
    LandmarkItem(
      id: 'lycee',
      name: 'Lycée Moderne Konan Camille',
      category: 'education',
      icon: Icons.school_rounded,
      color: Color(0xFF7C3AED),
      coords: LatLng(5.2930, -3.2940),
      description: 'Quartier scolaire & Collèges',
    ),
    LandmarkItem(
      id: 'carrefour_roa',
      name: 'Carrefour Roa & Station',
      category: 'transport',
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFFEA580C),
      coords: LatLng(5.2890, -3.3020),
      description: 'Axe principal & Liaison Grand-Bassam',
    ),
    LandmarkItem(
      id: 'prefecture',
      name: 'Sous-Préfecture & Mairie',
      category: 'admin',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF475569),
      coords: LatLng(5.2875, -3.2995),
      description: 'Centre administratif & État civil',
    ),
    LandmarkItem(
      id: 'mosquee',
      name: 'Grande Mosquée Centrale',
      category: 'culte',
      icon: Icons.mosque_rounded,
      color: Color(0xFF16A34A),
      coords: LatLng(5.2850, -3.2970),
      description: 'Quartier Mosquée / Centre-Est',
    ),
    LandmarkItem(
      id: 'eglise',
      name: 'Mission Catholique (Paroisse)',
      category: 'culte',
      icon: Icons.church_rounded,
      color: Color(0xFFD97706),
      coords: LatLng(5.2880, -3.3035),
      description: 'Paroisse Ste Thérèse de l\'Enfant Jésus',
    ),
    LandmarkItem(
      id: 'aviation',
      name: 'Quartier Aviation / Stade',
      category: 'residence',
      icon: Icons.stadium_rounded,
      color: Color(0xFF4F46E5),
      coords: LatLng(5.2950, -3.2990),
      description: 'Complexe sportif & Zone d\'habitation',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'all'
        ? defaultLandmarks
        : defaultLandmarks.where((l) => l.category == _selectedCategory).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.place_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tous les repères', Icons.auto_awesome_rounded),
                _buildFilterChip('commerce', 'Marchés', Icons.storefront_rounded),
                _buildFilterChip('transport', 'Gares & Ports', Icons.directions_boat_rounded),
                _buildFilterChip('sante', 'Santé', Icons.local_hospital_rounded),
                _buildFilterChip('education', 'Écoles', Icons.school_rounded),
                _buildFilterChip('culte', 'Lieux de Culte', Icons.church_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Landmarks Grid (visual cards with large icons)
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                return _buildLandmarkCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = key),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandmarkCard(LandmarkItem item) {
    return InkWell(
      onTap: () => widget.onLandmarkSelected(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
