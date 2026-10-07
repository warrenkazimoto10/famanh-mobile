import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/custom_location_api_client.dart';

class TaxiAddressSearchResult {
  final String title;
  final String subtitle;
  final LatLng latLng;
  final bool isPinpointMap;
  final String? zoneType;

  const TaxiAddressSearchResult({
    required this.title,
    required this.subtitle,
    required this.latLng,
    this.isPinpointMap = false,
    this.zoneType,
  });
}

class TaxiAddressSearchSheet extends StatefulWidget {
  final String initialQuery;
  final bool isPickup;
  final LatLng currentCenter;
  final List<Map<String, dynamic>> customZones;
  final List<Map<String, dynamic>> customLandmarks;

  const TaxiAddressSearchSheet({
    super.key,
    this.initialQuery = '',
    required this.isPickup,
    required this.currentCenter,
    this.customZones = const [],
    this.customLandmarks = const [],
  });

  static Future<TaxiAddressSearchResult?> show(
    BuildContext context, {
    String initialQuery = '',
    required bool isPickup,
    required LatLng currentCenter,
    List<Map<String, dynamic>> customZones = const [],
    List<Map<String, dynamic>> customLandmarks = const [],
  }) {
    return showModalBottomSheet<TaxiAddressSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaxiAddressSearchSheet(
        initialQuery: initialQuery,
        isPickup: isPickup,
        currentCenter: currentCenter,
        customZones: customZones,
        customLandmarks: customLandmarks,
      ),
    );
  }

  @override
  State<TaxiAddressSearchSheet> createState() => _TaxiAddressSearchSheetState();
}

class _TaxiAddressSearchSheetState extends State<TaxiAddressSearchSheet> {
  late final TextEditingController _searchCtrl;
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _popularNeighborhoods = const [
    {
      'title': 'Grand Marché d\'Adiaké',
      'subtitle': 'Centre-Ville • Zone Commerciale',
      'lat': 5.2863,
      'lng': -3.2981,
      'type': 'market',
      'icon': Icons.storefront_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Mairie d\'Adiaké',
      'subtitle': 'Quartier Administratif',
      'lat': 5.2885,
      'lng': -3.2970,
      'type': 'admin',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF0284C7),
    },
    {
      'title': 'Hôpital Général d\'Adiaké',
      'subtitle': 'Quartier Hôpital • Santé 24/7',
      'lat': 5.2910,
      'lng': -3.2950,
      'type': 'hospital',
      'icon': Icons.local_hospital_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'title': 'Débarcadère Lagune',
      'subtitle': 'Port lagunaire • Liaisons Assinie & Aby',
      'lat': 5.2820,
      'lng': -3.3010,
      'type': 'boat',
      'icon': Icons.directions_boat_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Quartier Résidentiel',
      'subtitle': 'Zone paisible • Villas & Résidences',
      'lat': 5.2930,
      'lng': -3.2960,
      'type': 'zone',
      'icon': Icons.home_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'title': 'Quartier Roa / Anga',
      'subtitle': 'Zone Nord-Est Adiaké',
      'lat': 5.2900,
      'lng': -3.2890,
      'type': 'zone',
      'icon': Icons.holiday_village_rounded,
      'color': Color(0xFF64748B),
    },
    {
      'title': 'Assinie-Mafia (Carrefour)',
      'subtitle': 'Route balnéaire & Hôtels',
      'lat': 5.1320,
      'lng': -3.2800,
      'type': 'intercity',
      'icon': Icons.beach_access_rounded,
      'color': Color(0xFFEC4899),
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _searchCtrl.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final remoteResults = await CustomLocationApiClient.search(query);
      if (mounted) {
        setState(() {
          _searchResults = remoteResults;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      height: mediaQuery.size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Drag Handle ──────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Title & Close Button ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isPickup ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.isPickup ? Icons.radio_button_checked : Icons.location_on,
                    color: widget.isPickup ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isPickup ? 'Point de ramassage (Départ)' : 'Où souhaitez-vous aller ? (Destination)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Search Input Box ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher un quartier, repère ou rue...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFEAB308), size: 22),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Bouton "Pointer sur la carte" ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).pop(
                  TaxiAddressSearchResult(
                    title: 'Point précis sur la carte',
                    subtitle: 'Emplacement sélectionné au curseur',
                    latLng: widget.currentCenter,
                    isPinpointMap: true,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF9C3), Color(0xFFFEF08A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFACC15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAB308),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pointer précisément sur la carte',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF854D0E),
                            ),
                          ),
                          Text(
                            'Déplacez le curseur pour cibler votre porte exacte',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFA16207),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF854D0E)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Horizontal Chips for Popular Neighborhoods ──────────
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QUARTIERS ET REPÈRES POPULAIRES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _popularNeighborhoods.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _popularNeighborhoods[index];
                return ActionChip(
                  avatar: Icon(item['icon'] as IconData, size: 16, color: item['color'] as Color),
                  label: Text(
                    item['title'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(
                      TaxiAddressSearchResult(
                        title: item['title'] as String,
                        subtitle: item['subtitle'] as String,
                        latLng: LatLng((item['lat'] as num).toDouble(), (item['lng'] as num).toDouble()),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Results List / Suggested Places ──────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEAB308), strokeWidth: 2.5),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: [
                      if (_searchResults.isNotEmpty) ...[
                        Text(
                          'RÉSULTATS CORRESPONDANTS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._searchResults.map((res) {
                          final title = res['name'] ?? res['label'] ?? 'Repère Adiaké';
                          final subtitle = res['description'] ?? res['type'] ?? 'Zone répertoriée';
                          final lat = (res['lat'] as num?)?.toDouble() ?? widget.currentCenter.latitude;
                          final lng = (res['lng'] as num?)?.toDouble() ?? widget.currentCenter.longitude;

                          return _buildResultTile(
                            title: title,
                            subtitle: subtitle,
                            icon: Icons.place_rounded,
                            iconColor: const Color(0xFFEAB308),
                            onTap: () {
                              Navigator.of(context).pop(
                                TaxiAddressSearchResult(
                                  title: title,
                                  subtitle: subtitle,
                                  latLng: LatLng(lat, lng),
                                ),
                              );
                            },
                          );
                        }),
                      ] else ...[
                        ..._popularNeighborhoods.map((item) {
                          return _buildResultTile(
                            title: item['title'] as String,
                            subtitle: item['subtitle'] as String,
                            icon: item['icon'] as IconData,
                            iconColor: item['color'] as Color,
                            onTap: () {
                              Navigator.of(context).pop(
                                TaxiAddressSearchResult(
                                  title: item['title'] as String,
                                  subtitle: item['subtitle'] as String,
                                  latLng: LatLng((item['lat'] as num).toDouble(), (item['lng'] as num).toDouble()),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        tileColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}
