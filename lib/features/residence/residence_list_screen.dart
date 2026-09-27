import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/money_text.dart';
import 'residence_detail_screen.dart';
import 'my_residence_bookings_screen.dart';
import '../../widgets/staggered_item.dart';
import '../../widgets/skeleton_loader.dart';

class ResidenceListScreen extends StatefulWidget {
  const ResidenceListScreen({super.key});

  @override
  State<ResidenceListScreen> createState() => _ResidenceListScreenState();
}

class _ResidenceListScreenState extends State<ResidenceListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)..addListener(_onTab);

  bool _loading = true;
  String? _error;
  List<ResidenceDto> _list = const [];

  DateTimeRange? _range;
  int _guests = 2;
  String _selectedDestination = 'Tous';
  bool _sortAscending = true;
  final Set<int> _favorites = {};

  bool get _isHotelTab => _tab.index == 1;

  void _onTab() {
    if (_tab.indexIsChanging) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiClient.getResidences();
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

  List<ResidenceDto> get _results {
    final filtered = _list.where((r) {
      final isHotel = r.type.toLowerCase() == 'hotel';
      final typeOk = _isHotelTab ? isHotel : !isHotel;

      // Filter destination chip
      final destOk = _selectedDestination == 'Tous' ||
          (r.locationArea != null && r.locationArea!.contains(_selectedDestination)) ||
          (r.address != null && r.address!.contains(_selectedDestination)) ||
          r.name.contains(_selectedDestination);

      // Filter guests capacity
      final capacityOk = r.capacity == 0 || r.capacity >= _guests;
      return typeOk && destOk && capacityOk;
    }).toList();

    filtered.sort((a, b) => _sortAscending
        ? a.pricePerNight.compareTo(b.pricePerNight)
        : b.pricePerNight.compareTo(a.pricePerNight));

    return filtered;
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range ?? DateTimeRange(start: now.add(const Duration(days: 2)), end: now.add(const Duration(days: 5))),
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
    if (res != null) setState(() => _range = res);
  }

  String _formatRangeLabel() {
    if (_range == null) return '18 - 21 Oct. • 3 nuits';
    final nights = _range!.end.difference(_range!.start).inDays;
    return '${_range!.start.day} - ${_range!.end.day} ${_monthName(_range!.start.month)} • $nights nuit${nights > 1 ? 's' : ''}';
  }

  String _monthName(int month) {
    const months = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final resultsList = _results;

    return Scaffold(
      backgroundColor: FamanhColors.background,
      body: Column(
        children: [
          // ── TOP FIXED HEADER BAR (Identical to Home Page) ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(Navigator.canPop(context) ? 8 : 16, topPadding + 6, 16, 10),
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
                if (Navigator.canPop(context))
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
                      'Catalog',
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
                        icon: const Icon(Icons.event_note_outlined, size: 18),
                        color: FamanhColors.onSurfaceVariant,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyResidenceBookingsScreen()),
                          );
                        },
                        tooltip: 'Mes Réservations',
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

          // ── MAIN FEED CONTENT ──────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: FamanhColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // Top Mode Selector (Segmented Control)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEDFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tab.animateTo(0);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isHotelTab ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !_isHotelTab
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.villa_rounded, size: 18, color: !_isHotelTab ? FamanhColors.primary : const Color(0xFF3F4850)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Résidences',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: !_isHotelTab ? FamanhColors.primary : const Color(0xFF3F4850),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tab.animateTo(1);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isHotelTab ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isHotelTab
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.hotel_rounded, size: 18, color: _isHotelTab ? FamanhColors.primary : const Color(0xFF3F4850)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hôtels',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _isHotelTab ? FamanhColors.primary : const Color(0xFF3F4850),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Box Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCE5FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.travel_explore_rounded, color: FamanhColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rechercher un séjour d\'exception',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF131B2E),
                                        ),
                                  ),
                                  const Text(
                                    'Résidences privées & suites d\'élite',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF707881)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick Destination Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Tous',
                              'Assinie-Mafia',
                              'Adiaké Lagune',
                              'Grand-Bassam',
                            ].map((dest) {
                              final isSelected = _selectedDestination == dest;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(dest),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _selectedDestination = dest),
                                  selectedColor: FamanhColors.primary,
                                  backgroundColor: const Color(0xFFEAEDFF),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF3F4850),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: BorderSide.none,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date Selection Field
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
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                                  ),
                                  child: Icon(Icons.calendar_today_rounded, color: FamanhColors.primary, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DATES DU SÉJOUR',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5),
                                      ),
                                      Text(
                                        _formatRangeLabel(),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFBFC7D2)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Travelers Stepper
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                                ),
                                child: Icon(Icons.group_rounded, color: FamanhColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'VOYAGEURS VIP',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF707881), letterSpacing: 0.5),
                                    ),
                                    Text(
                                      '$_guests personne${_guests > 1 ? 's' : ''}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
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
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF131B2E)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '$_guests',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_guests < 20) setState(() => _guests++);
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
                        const SizedBox(height: 14),

                        // Search Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.search_rounded, size: 20),
                            label: const Text('Rechercher les disponibilités', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FamanhColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Results Header & Sort Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${resultsList.length} établissement${resultsList.length > 1 ? 's' : ''} trouvé${resultsList.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006C49),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => setState(() => _sortAscending = !_sortAscending),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAEDFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Trier: ${_sortAscending ? 'Prix min' : 'Prix max'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3F4850)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF3F4850)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Feed Content
                  if (_loading) ...[
                    for (int i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: SkeletonLoader(width: double.infinity, height: 260, borderRadius: 20),
                      ),
                  ] else if (_error != null) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFBA1A1A)),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                          ],
                        ),
                      ),
                    ),
                  ] else if (resultsList.isEmpty) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 50),
                        child: Column(
                          children: [
                            Icon(
                              _isHotelTab ? Icons.hotel_outlined : Icons.villa_outlined,
                              size: 64,
                              color: const Color(0xFFBFC7D2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isHotelTab ? 'Aucun hôtel trouvé' : 'Aucune résidence trouvée',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Essayez de modifier votre destination ou le nombre de voyageurs.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF707881)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    for (int i = 0; i < resultsList.length; i++)
                      StaggeredItem(
                        index: i,
                        child: _CatalogCard(
                          residence: resultsList[i],
                          isFavorite: _favorites.contains(resultsList[i].id),
                          onToggleFavorite: () {
                            setState(() {
                              if (_favorites.contains(resultsList[i].id)) {
                                _favorites.remove(resultsList[i].id);
                              } else {
                                _favorites.add(resultsList[i].id);
                              }
                            });
                          },
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ResidenceDetailScreen(
                                  residenceId: resultsList[i].id,
                                  initialRange: _range,
                                  initialGuests: _guests,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.residence,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final ResidenceDto residence;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  String _badgeText() {
    if (residence.badgeLabel != null && residence.badgeLabel!.isNotEmpty) {
      return residence.badgeLabel!.toUpperCase();
    }
    return residence.type.toLowerCase() == 'hotel' ? 'HÔTEL PRESTIGE' : 'RÉSIDENCE VIP';
  }

  IconData _badgeIcon() {
    final label = _badgeText();
    if (label.contains('ECO') || label.contains('ÉCO')) return Icons.eco_rounded;
    return Icons.verified_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Header Banner with Overlay Badges
              Stack(
                children: [
                  Hero(
                    tag: 'residence_img_${residence.id}',
                    child: AspectRatio(
                      aspectRatio: 1.7,
                      child: residence.imageUrl != null && residence.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: residence.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(color: const Color(0xFFEAEDFF)),
                              errorWidget: (ctx, url, error) => Container(
                                color: const Color(0xFFEAEDFF),
                                child: Icon(Icons.villa_rounded, color: FamanhColors.primary, size: 40),
                              ),
                            )
                          : Container(color: const Color(0xFFEAEDFF)),
                    ),
                  ),

                  // Ambient Gradient Scrim
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Left Badges
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: FamanhColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(_badgeIcon(), color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                _badgeText(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
                              const SizedBox(width: 3),
                              Text(
                                '${residence.rating} (${residence.reviewsCount} avis)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Right Favorite Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? const Color(0xFFBA1A1A) : const Color(0xFF3F4850),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  // Floating Price Badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          MoneyText(
                            residence.pricePerNight,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FamanhColors.primary),
                          ),
                          const SizedBox(width: 2),
                          const Text(' /nuit', style: TextStyle(fontSize: 11, color: Color(0xFF707881))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Card Content Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      residence.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF131B2E),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 15, color: FamanhColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            residence.address ?? 'Adiaké • Bord de Lagune',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF707881)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Amenities Chips Grid
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: residence.amenities.take(4).map((amenity) => _AmenityChip(label: amenity)).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Bottom Action Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6CF8BB).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF00714D)),
                              SizedBox(width: 4),
                              Text(
                                'Paiement à l\'arrivée',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF00714D)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: FamanhColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                residence.type.toLowerCase() == 'hotel' ? 'Disponibilités' : 'Voir la villa',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});
  final String label;

  IconData _iconForLabel(String text) {
    final t = text.toLowerCase();
    if (t.contains('piscine')) return Icons.pool_rounded;
    if (t.contains('cuisine') || t.contains('chef')) return Icons.restaurant_rounded;
    if (t.contains('clim')) return Icons.ac_unit_rounded;
    if (t.contains('groupe') || t.contains('électrogène')) return Icons.bolt_rounded;
    if (t.contains('wifi') || t.contains('fibre')) return Icons.wifi_rounded;
    if (t.contains('tv') || t.contains('canal') || t.contains('netflix')) return Icons.tv_rounded;
    if (t.contains('garage') || t.contains('parking')) return Icons.directions_car_rounded;
    if (t.contains('jardin') || t.contains('baobab') || t.contains('parc')) return Icons.park_rounded;
    if (t.contains('sécurité') || t.contains('gardiennage') || t.contains('sécurisé')) return Icons.shield_rounded;
    if (t.contains('ponton') || t.contains('bateau')) return Icons.directions_boat_rounded;
    if (t.contains('plage') || t.contains('vue') || t.contains('lagune')) return Icons.beach_access_rounded;
    if (t.contains('petit') || t.contains('buffet')) return Icons.restaurant_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForLabel(label), size: 12, color: const Color(0xFF3F4850)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3F4850)),
          ),
        ],
      ),
    );
  }
}
