import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import 'event_detail_screen.dart';

class EventCatalogScreen extends StatefulWidget {
  const EventCatalogScreen({super.key});

  @override
  State<EventCatalogScreen> createState() => _EventCatalogScreenState();
}

class _EventCatalogScreenState extends State<EventCatalogScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<EventDto>> _future;
  String? _selectedCategory;
  late final TabController _tabCtrl;

  static const _categories = ['Tous', 'Concert', 'Festival', 'Culture', 'Sport', 'Soirée VIP', 'Foire'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _reload();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    final cat = _tabCtrl.index == 0 ? null : _categories[_tabCtrl.index];
    setState(() => _selectedCategory = cat);
    _reload();
  }

  void _reload() {
    setState(() {
      _future = EventApi.fetchEvents(category: _selectedCategory);
    });
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF0A2540),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A2540), Color(0xFF1A3A6B), Color(0xFF825100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30, right: -30,
                      child: Container(width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        )),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, top + 56, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('🎟️ Événements',
                              style: TextStyle(color: Colors.white, fontSize: 26,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text('Adiaké & ses environs',
                              style: TextStyle(color: Colors.white.withOpacity(0.7),
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                color: const Color(0xFF0A2540),
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AdiakeColors.tertiaryFixedDim,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: _categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
            ),
          ),
        ],
        body: FutureBuilder<List<EventDto>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('${snap.error}', textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            final events = snap.data ?? [];
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎪', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      _selectedCategory == null
                          ? 'Aucun événement disponible\npour le moment.'
                          : 'Aucun événement "$_selectedCategory"\ndisponible.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            // Featured events carousel
            final featured = events.where((e) => e.isFeatured).toList();
            final regular = events.where((e) => !e.isFeatured).toList();

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
                children: [
                  // Featured carousel
                  if (featured.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text('⭐ À la Une',
                              style: TextStyle(fontWeight: FontWeight.w800,
                                  fontSize: 16, color: Color(0xFF131B2E))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: featured.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (ctx, i) => _FeaturedCard(
                          event: featured[i],
                          onTap: () => _openDetail(featured[i].id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Regular grid
                  if (regular.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Tous les Événements',
                          style: const TextStyle(fontWeight: FontWeight.w800,
                              fontSize: 16, color: Color(0xFF131B2E))),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: regular.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _EventListTile(
                        event: regular[i],
                        onTap: () => _openDetail(regular[i].id),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(int eventId) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId)),
    );
  }
}

// ─── Featured Card (horizontal scroll) ───────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final EventDto event;
  final VoidCallback onTap;
  const _FeaturedCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(event.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A3A6B))),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB95F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(event.category,
                      style: const TextStyle(color: Color(0xFF2A1700),
                          fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
              Positioned(
                bottom: 14, left: 14, right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 13),
                      const SizedBox(width: 3),
                      Expanded(child: Text(event.locationName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    ]),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event.ticketTypes.isEmpty ? 'Gratuit' :
                          'Dès ${NumberFormat('#,###', 'fr').format(event.minPriceFcfa)} FCFA',
                          style: const TextStyle(color: Color(0xFF6FFBBE),
                              fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            DateFormat('dd MMM', 'fr').format(event.startsAt),
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 11),
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

// ─── Regular Event List Tile ─────────────────────────────────────────────────

class _EventListTile extends StatelessWidget {
  final EventDto event;
  final VoidCallback onTap;
  const _EventListTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdiakeColors.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100, height: 100,
                child: Image.network(event.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AdiakeColors.surfaceContainer)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdiakeColors.primaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(event.category,
                          style: TextStyle(color: AdiakeColors.primary,
                              fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                    const SizedBox(height: 5),
                    Text(event.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 14, color: Color(0xFF131B2E))),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: AdiakeColors.outline),
                      const SizedBox(width: 4),
                      Text(DateFormat('d MMM y • HH:mm', 'fr').format(event.startsAt),
                          style: TextStyle(fontSize: 11, color: AdiakeColors.outline)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 11, color: AdiakeColors.outline),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.locationName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AdiakeColors.outline))),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      event.ticketTypes.isEmpty ? 'Entrée libre'
                          : 'Dès ${NumberFormat('#,###', 'fr').format(event.minPriceFcfa)} FCFA',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                          color: AdiakeColors.secondary),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
