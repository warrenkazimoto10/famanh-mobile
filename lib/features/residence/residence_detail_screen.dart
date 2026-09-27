import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adiake_livraison_express/l10n/app_localizations.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/money_text.dart';
import '../../widgets/error_view.dart';
import 'residence_booking_screen.dart';

class ResidenceDetailScreen extends StatefulWidget {
  const ResidenceDetailScreen({
    super.key,
    required this.residenceId,
    this.initialRange,
    this.initialGuests,
  });

  final int residenceId;
  final DateTimeRange? initialRange;
  final int? initialGuests;

  @override
  State<ResidenceDetailScreen> createState() => _ResidenceDetailScreenState();
}

class _ResidenceDetailScreenState extends State<ResidenceDetailScreen> {
  bool _loading = true;
  String? _error;
  ResidenceDto? _residence;
  List<ResidenceReviewDto> _reviews = const [];
  bool _isFavorite = false;

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
      final residence = await ApiClient.getResidence(widget.residenceId);
      if (!mounted) return;
      setState(() {
        _residence = residence;
        _loading = false;
      });
      try {
        final reviews = await ApiClient.getResidenceReviews(widget.residenceId);
        if (mounted) setState(() => _reviews = reviews);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'apartment':
        return 'Résidence';
      case 'villa':
        return 'Villa VIP';
      case 'house':
        return 'Maison';
      case 'studio':
        return 'Studio';
      case 'hotel':
        return 'Hôtel';
      default:
        return 'Résidence';
    }
  }

  Future<void> _openItinerary(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coordonnées : $lat, $lng')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final l10n = AppLocalizations.of(context)!;

    if (_loading) return const Scaffold(backgroundColor: Color(0xFFFAF8FF), body: Center(child: CircularProgressIndicator(color: FamanhColors.primary)));
    if (_error != null) return Scaffold(backgroundColor: const Color(0xFFFAF8FF), body: ErrorView(error: _error!, onRetry: _load));
    if (_residence == null) return Scaffold(backgroundColor: const Color(0xFFFAF8FF), body: Center(child: Text(l10n.residenceUnknown)));

    final r = _residence!;
    final galleryList = [
      if (r.imageUrl != null && r.imageUrl!.isNotEmpty) r.imageUrl!,
      ...r.gallery,
    ];
    final lat = r.lat ?? 5.2863;
    final lng = r.lng ?? -3.2981;

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
                    
                    Row(
                      children: [
                        Text(
                          r.type.toLowerCase() == 'hotel' ? 'Détail Hôtel' : 'Détail Résidence',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: FamanhColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDDB8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF2A1700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: FamanhColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.support_agent_rounded, size: 18),
                            color: const Color(0xFF825100),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Conciergerie VIP Famanh disponible 24h/7')),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006C49),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
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

          // ── BODY SCROLLVIEW ────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 110),
                  children: [
                    // Hero Image Carousel Banner
                    _DetailHeroCarousel(
                      images: galleryList,
                      badgeLabel: r.badgeLabel ?? 'Certifié Prestige',
                      isFavorite: _isFavorite,
                      onToggleFavorite: () => setState(() => _isFavorite = !_isFavorite),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Primary Identity & Meta
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFDDB8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFF2A1700), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getTypeLabel(r.type),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2A1700)),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.rating} (${r.reviewsCount} avis)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Text(
                            r.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF131B2E),
                                ),
                          ),
                          const SizedBox(height: 6),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_rounded, size: 18, color: FamanhColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF3F4850)),
                                    children: [
                                      TextSpan(text: '${r.address ?? "Avenue des Cocotiers, Adiaké"} • '),
                                      TextSpan(
                                        text: 'À 5 min du débarcadère',
                                        style: TextStyle(color: FamanhColors.primary, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Capacity Pill Grid
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaPill(icon: Icons.group_rounded, label: '${r.capacity > 0 ? r.capacity : 8} voyageurs'),
                              _MetaPill(icon: Icons.bed_rounded, label: '${r.bedrooms} chambres • ${r.beds} lits'),
                              _MetaPill(icon: Icons.bathtub_rounded, label: '${r.bathrooms} SDB'),
                              _MetaPill(icon: Icons.pool_rounded, label: 'Piscine à débordement', highlight: true),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Verified Host Spotlight Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFEAEDFF),
                                      backgroundImage: (r.hostAvatar != null && r.hostAvatar!.isNotEmpty)
                                          ? CachedNetworkImageProvider(r.hostAvatar!)
                                          : null,
                                      child: (r.hostAvatar == null || r.hostAvatar!.isEmpty)
                                          ? Icon(Icons.person_rounded, color: FamanhColors.primary)
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF006C49),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            r.hostName ?? 'Famille Kouassi',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.verified_rounded, size: 16, color: FamanhColors.primary),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.hostSubtitle ?? 'Superhôte • Répond en moins de 15 min',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF707881)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Secondary Gallery Preview Row
                          const Text(
                            'APERÇU DES ESPACES',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAEDFF),
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(galleryList.length > 1 ? galleryList[1] : galleryList.first),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAEDFF),
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(galleryList.length > 2 ? galleryList[2] : galleryList.first),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Description Section
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
                                Text(
                                  r.type.toLowerCase() == 'hotel' ? 'À propos de cet hôtel' : 'À propos de cette villa',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF131B2E),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r.description ?? l10n.residenceNoDescription,
                                  style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF3F4850)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Équipements & Prestations VIP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Équipements d’exception',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF131B2E),
                                    ),
                              ),
                              Text(
                                '${r.amenities.length} inclus',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: FamanhColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 3.0,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: r.amenities.map((a) => _VipAmenityCard(label: a)).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Localisation & Carte Interactive Real OpenStreetMap
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Localisation & Accès',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF131B2E),
                                          ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.navigation_rounded, size: 14, color: FamanhColors.primary),
                                        const SizedBox(width: 3),
                                        Text(
                                          r.locationArea ?? 'Adiaké',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FamanhColors.primary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Real Interactive Map (FlutterMap + Marker Pin)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: 180,
                                    width: double.infinity,
                                    child: Stack(
                                      children: [
                                        FlutterMap(
                                          options: MapOptions(
                                            initialCenter: LatLng(lat, lng),
                                            initialZoom: 14.5,
                                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              userAgentPackageName: 'com.adiake.app',
                                            ),
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: LatLng(lat, lng),
                                                  width: 50,
                                                  height: 50,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: FamanhColors.primary,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: FamanhColors.primary.withValues(alpha: 0.4),
                                                          blurRadius: 10,
                                                          spreadRadius: 3,
                                                        ),
                                                      ],
                                                      border: Border.all(color: Colors.white, width: 2.5),
                                                    ),
                                                    child: const Icon(Icons.villa_rounded, color: Colors.white, size: 24),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Overlay Action Banner
                                        Positioned(
                                          bottom: 10,
                                          left: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.8),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: const BoxDecoration(color: Color(0xFF6CF8BB), shape: BoxShape.circle),
                                                    ),
                                                    
                                                  ],
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _openItinerary(lat, lng),
                                                  icon: const Icon(Icons.directions_rounded, size: 14),
                                                  label: const Text('ITINÉRAIRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: FamanhColors.primary,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ],
                      ),
                    ),
                  ],
                ),

                // Sticky Reservation Action Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      border: const Border(top: BorderSide(color: Color(0xFFEAEDFF))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  MoneyText(
                                    r.pricePerNight,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FamanhColors.primary),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('/ nuit', style: TextStyle(fontSize: 12, color: Color(0xFF707881))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ResidenceBookingScreen(
                                      residence: r,
                                      initialRange: widget.initialRange,
                                      initialGuests: widget.initialGuests,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              label: const Text('RÉSERVER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FamanhColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReview() {
    int rating = 5;
    final ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx2).bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(ctx2).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded, color: Color(0xFFCA8A04), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Donner mon avis VIP',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: FamanhColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final active = idx < rating;
                    return IconButton(
                      onPressed: () => setLocalState(() => rating = idx + 1),
                      icon: Icon(
                        active ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: active ? const Color(0xFFFACC15) : const Color(0xFFBFC7D2),
                        size: 38,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Partagez votre expérience dans cet établissement…',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF707881)),
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx2);
                      try {
                        await ApiClient.addResidenceReview(widget.residenceId, rating, ctrl.text);
                        if (!mounted) return;
                        nav.pop();
                        _load();
                        messenger.showSnackBar(SnackBar(
                          content: const Text('Merci pour votre avis VIP !'),
                          backgroundColor: const Color(0xFF006C49),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FamanhColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Publier mon avis', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeroCarousel extends StatefulWidget {
  const _DetailHeroCarousel({
    required this.images,
    required this.badgeLabel,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final List<String> images;
  final String badgeLabel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  State<_DetailHeroCarousel> createState() => _DetailHeroCarouselState();
}

class _DetailHeroCarouselState extends State<_DetailHeroCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            onPageChanged: (v) => setState(() => _index = v),
            itemCount: widget.images.length,
            itemBuilder: (context, i) {
              return CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(color: const Color(0xFFEAEDFF)),
                errorWidget: (ctx, url, error) => Container(color: const Color(0xFFEAEDFF)),
              );
            },
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          // Top Action Badges
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFFFFB95F), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        widget.badgeLabel.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lien de la villa copié dans le presse-papier !')),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF131B2E)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onToggleFavorite,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: widget.isFavorite ? const Color(0xFFBA1A1A) : const Color(0xFF825100),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Left Gallery Floating Pill & 360 Badge
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_index + 1} / ${widget.images.length} photos',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007BB9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.threed_rotation_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Visite 360°',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(
                    widget.images.length,
                    (idx) => Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: _index == idx ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _index == idx ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, this.highlight = false});
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF6CF8BB).withValues(alpha: 0.5) : const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: highlight ? const Color(0xFF00714D) : FamanhColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFF00714D) : const Color(0xFF131B2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipAmenityCard extends StatelessWidget {
  const _VipAmenityCard({required this.label});
  final String label;

  IconData _iconForLabel(String text) {
    final t = text.toLowerCase();
    if (t.contains('piscine')) return Icons.pool_rounded;
    if (t.contains('cuisine') || t.contains('chef')) return Icons.restaurant_rounded;
    if (t.contains('clim') || t.contains('climatisation')) return Icons.ac_unit_rounded;
    if (t.contains('groupe') || t.contains('électrogène')) return Icons.bolt_rounded;
    if (t.contains('wifi') || t.contains('fibre')) return Icons.wifi_rounded;
    if (t.contains('tv') || t.contains('canal') || t.contains('netflix')) return Icons.tv_rounded;
    if (t.contains('garage') || t.contains('parking')) return Icons.directions_car_rounded;
    if (t.contains('jardin') || t.contains('baobab') || t.contains('parc')) return Icons.park_rounded;
    if (t.contains('gardiennage') || t.contains('sécurité') || t.contains('sécurisé')) return Icons.shield_rounded;
    if (t.contains('ponton') || t.contains('bateau')) return Icons.directions_boat_rounded;
    if (t.contains('plage') || t.contains('lagune') || t.contains('vue')) return Icons.beach_access_rounded;
    if (t.contains('petit') || t.contains('buffet')) return Icons.restaurant_rounded;
    if (t.contains('majordome') || t.contains('service')) return Icons.room_service_rounded;
    if (t.contains('jacuzzi') || t.contains('spa') || t.contains('massage')) return Icons.hot_tub_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Color _boxColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('piscine')) return const Color(0xFF6CF8BB);
    if (t.contains('groupe')) return const Color(0xFFFFDDB8);
    if (t.contains('cuisine') || t.contains('clim') || t.contains('tv')) return const Color(0xFFCCE5FF);
    if (t.contains('jardin') || t.contains('parc')) return const Color(0xFFD2F7D6);
    return const Color(0xFFEAEDFF);
  }

  Color _iconColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('piscine')) return const Color(0xFF00714D);
    if (t.contains('groupe')) return const Color(0xFF653E00);
    if (t.contains('jardin')) return const Color(0xFF1E6B24);
    return FamanhColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _boxColor(label),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForLabel(label), size: 16, color: _iconColor(label)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});
  final ResidenceReviewDto review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFCCE5FF),
                child: Text(
                  review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FamanhColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF131B2E))),
                    Row(
                      children: List.generate(
                        5,
                        (idx) => Icon(
                          idx < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: idx < review.rating ? const Color(0xFFF59E0B) : const Color(0xFFBFC7D2),
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF707881)),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF3F4850)),
            ),
          ],
        ],
      ),
    );
  }
}
