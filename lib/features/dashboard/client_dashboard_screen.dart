import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/client_bottom_nav.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/staggered_item.dart';
import '../orders/client_orders_screen.dart';
import '../tracking/client_tracking_screen.dart';
import '../profile/profile_screen.dart';
import '../residence/residence_detail_screen.dart';
import '../residence/residence_list_screen.dart';
import '../services/client_services_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Root — Tab Shell
// ═══════════════════════════════════════════════════════════════

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  late int _tab;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await ApiClient.me();
      if (!mounted) return;
      setState(() {
        _isAdmin = user.role == 'admin' || user.role == 'superadmin';
      });
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamanhColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _tab,
              children: const [
                _HomeTab(),
                ClientOrdersScreen(),
                ClientServicesScreen(),
                ProfileScreen(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClientBottomNavBar(
              currentIndex: _tab,
              onTap: (i) {
                if (_isAdmin && i == 4) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
                } else {
                  setState(() => _tab = i);
                }
              },
              isAdmin: _isAdmin,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Home Tab
// ═══════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: FamanhColors.background,
      body: Column(
        children: [
          // ── TOP FIXED HEADER BAR WITH FAMANH LOGO ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
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
                // Official Famanh Logo Image
                Image.asset(
                  'assets/logo.png',
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const BrandLogo(size: 34, radius: 8),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                   
                    const Text(
                      'Accueil',
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
                // Notification Icon & User Avatar Initials
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: FamanhColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 20),
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

          // ── SCROLLABLE BODY CONTENT ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  // 1. HERO GRADIENT HEADER BANNER
                  _HeroHeaderBanner(),

                  // 2. MAIN CONTENT SECTIONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Express Services ("Que souhaitez-vous ?")
                        StaggeredItem(index: 0, delayMs: 0, child: _ExpressServicesPortals()),

                        const SizedBox(height: 24),

                        // Section 2: Promotional VIP Hero Banner (Publicité Back-office)
                        StaggeredItem(index: 1, delayMs: 80, child: _VipHeroPromoCard()),

                        const SizedBox(height: 24),

                        // Section 3: Live Order Tracking Widget ("Suivi en direct")
                        StaggeredItem(index: 2, delayMs: 160, child: const _LiveOrderTrackingWidget()),

                        const SizedBox(height: 24),

                        // Section 4: Local Tastes & Popular Picks ("Populaire à Adiaké")
                        StaggeredItem(index: 3, delayMs: 240, child: _PopularInCitySection()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 1. Hero Gradient Header Banner
// ═══════════════════════════════════════════════════════════════

class _HeroHeaderBanner extends StatefulWidget {
  @override
  State<_HeroHeaderBanner> createState() => _HeroHeaderBannerState();
}

class _HeroHeaderBannerState extends State<_HeroHeaderBanner> {
  bool _uploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final me = await ApiClient.uploadAvatar(file);
      ApiSession.currentUser.value = me;
      if (mounted) AppToast.showSuccess(context, 'Photo de profil mise à jour.');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF006194), Color(0xFF007BB9), Color(0xFFDAE2FD)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F006194),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: ValueListenableBuilder<UserMeDto?>(
        valueListenable: ApiSession.currentUser,
        builder: (context, me, _) {
          final fullName = (me?.name?.trim().isNotEmpty ?? false) ? me!.name!.trim() : 'Camara Ibrahim';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar photo placed directly to the LEFT of greeting text (No emoji, No location pill, No gold badge)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Image with upload camera button
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _uploading
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                )
                              : (me?.avatarUrl != null && me!.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      me.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                                    )
                                  : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                        ),
                        if (!_uploading)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 9, color: FamanhColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Greeting & Full Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreetingText(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Floating Omnisearch Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: FamanhColors.darkNavy.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: FamanhColors.primary, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Où voulez-vous être livré ?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF707881),
                        ),
                      ),
                    ),
                    const Icon(Icons.mic_rounded, color: FamanhColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 18, color: FamanhColors.outlineVariant),
                    const SizedBox(width: 8),
                    const Icon(Icons.tune_rounded, color: FamanhColors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }
}

// ═══════════════════════════════════════════════════════════════
// 2. Express Services Portals (Section 1 - Sans les badges)
// ═══════════════════════════════════════════════════════════════

class _ExpressServicesPortals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Que souhaitez-vous ?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: FamanhColors.onSurface,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FamanhColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, size: 12, color: FamanhColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'SERVICES EXPRESS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: FamanhColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PortalCard(
                icon: Icons.restaurant_rounded,
                label: 'Repas',
                subtitle: 'Lagune & City',
                gradientColors: const [Color(0xFFFFF7ED), Color(0xFFFFFFFF)],
                borderColor: const Color(0xFFFED7AA),
                iconBgColor: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.foodHub),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PortalCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Gaz',
                subtitle: 'B6 • B12 • B28',
                gradientColors: const [Color(0xFFFEF3C7), Color(0xFFFFFFFF)],
                borderColor: const Color(0xFFFDE68A),
                iconBgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.gasOrder),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PortalCard(
                icon: Icons.inventory_2_rounded,
                label: 'Colis',
                subtitle: 'Moto & Bateau',
                gradientColors: const [Color(0xFFECFDF5), Color(0xFFFFFFFF)],
                borderColor: const Color(0xFFA7F3D0),
                iconBgColor: const Color(0xFFD1FAE5),
                iconColor: const Color(0xFF059669),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.parcelExpress),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PortalCard(
                icon: Icons.hotel_rounded,
                label: 'Hôtels',
                subtitle: 'Assinie & Aby',
                gradientColors: const [Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
                borderColor: const Color(0xFFBFDBFE),
                iconBgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResidenceListScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ── BANNIÈRE OFFICIELLE TAXI ADIAKÉ ──────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.taxi),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF0F172A), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Taxi Communal Adiaké',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '200 F',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Partagé par place ou Course Express privatisée',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEAB308), size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _PortalCard extends StatefulWidget {
  const _PortalCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.borderColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<_PortalCard> createState() => _PortalCardState();
}

class _PortalCardState extends State<_PortalCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.94,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.borderColor.withValues(alpha: 0.7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: widget.iconColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: FamanhColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: FamanhColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 3. VIP Hero Promotional Banner (Publicité Back-office)
// ═══════════════════════════════════════════════════════════════

class _VipHeroPromoCard extends StatefulWidget {
  const _VipHeroPromoCard();

  @override
  State<_VipHeroPromoCard> createState() => _VipHeroPromoCardState();
}

class _VipHeroPromoCardState extends State<_VipHeroPromoCard> {
  final PageController _pageController = PageController();
  List<AdvertisementDto> _ads = [];
  bool _loading = true;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAds() async {
    final ads = await ApiClient.getAdvertisements();
    if (mounted) {
      setState(() {
        _ads = ads;
        _loading = false;
      });
      if (_ads.length > 1) {
        _startAutoPlay();
      }
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _ads.isEmpty || !_pageController.hasClients) return;
      final nextPage = (_currentIndex + 1) % _ads.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _handleAdTap(AdvertisementDto ad) {
    ApiClient.trackAdvertisementClick(ad.id);
    _showAdDetailsModal(ad);
  }

  void _showAdDetailsModal(AdvertisementDto ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (ad.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ad.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: FamanhColors.primaryContainer,
                    child: const Center(
                      child: Icon(Icons.campaign, size: 48, color: FamanhColors.primary),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FamanhColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ad.badgeLabel.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (ad.advertiserName != null && ad.advertiserName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Par ${ad.advertiserName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FamanhColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ad.title,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: FamanhColors.onSurface,
              ),
            ),
            if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ad.subtitle!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.4,
                  color: FamanhColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (ad.advertiserPhone != null && ad.advertiserPhone!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${ad.advertiserPhone}')),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Appeler l\'annonceur'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: FamanhColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: FamanhColors.onSurfaceVariant,
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: double.infinity,
        height: 190,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Default banner fallback if empty array
    final displayAds = _ads.isNotEmpty
        ? _ads
        : [
            const AdvertisementDto(
              id: 0,
              title: 'Lagoon Resort & Spa',
              subtitle: 'Piscine à débordement, groupe électrogène & navette nautique.',
              badgeLabel: 'VIP EXCLUSIF',
              imageUrl:
                  'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&auto=format&fit=crop&q=80',
              ctaLabel: 'Réserver',
              targetType: 'residence',
              advertiserName: 'Lagoon Resort Adiaké',
              advertiserPhone: '0708091011',
            ),
          ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: displayAds.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final ad = displayAds[index];
              return GestureDetector(
                onTap: () => _handleAdTap(ad),
                child: Stack(
                  children: [
                    // Image Backdrop
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          ad.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: FamanhColors.primaryContainer,
                            child: const Center(
                              child: Icon(Icons.campaign, size: 48, color: FamanhColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Gradient Scrim Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.black.withValues(alpha: 0.30),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),

                    // Content Inside Card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: FamanhColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ad.badgeLabel.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ad.advertiserName ?? 'Adiaké Express',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Title & Action Button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      ad.title,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        ad.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.90),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _handleAdTap(ad),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: FamanhColors.onSurface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 0,
                                ),
                                child: Text(
                                  ad.ctaLabel.isNotEmpty ? ad.ctaLabel : 'Voir l\'offre',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (displayAds.length > 1) ...[
          const SizedBox(height: 10),
          // Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              displayAds.length,
              (idx) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: _currentIndex == idx ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentIndex == idx ? FamanhColors.primary : FamanhColors.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 4. Live Order Tracking Widget (Données Réelles BD + Animé)
// ═══════════════════════════════════════════════════════════════

class _LiveOrderTrackingWidget extends StatefulWidget {
  const _LiveOrderTrackingWidget();

  @override
  State<_LiveOrderTrackingWidget> createState() => _LiveOrderTrackingWidgetState();
}

class _LiveOrderTrackingWidgetState extends State<_LiveOrderTrackingWidget> {
  late Future<_RealActiveOrder?> _future;
  Timer? _timer;

  static const _finalStatuses = {
    'delivered_paid', 'empty_returned', 'delivered', 'cancelled', 'completed'
  };

  @override
  void initState() {
    super.initState();
    _future = _fetchActiveOrder();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _future = _fetchActiveOrder();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<_RealActiveOrder?> _fetchActiveOrder() async {
    try {
      final results = await Future.wait([
        ApiClient.getGasOrders(),
        ApiClient.getParcelOrders(),
        ApiClient.getFoodOrders(),
      ]);

      final gasOrders = results[0] as List<GasOrderDto>;
      final parcelOrders = results[1] as List<ParcelOrderDto>;
      final foodOrders = results[2] as List<FoodOrderDto>;

      _RealActiveOrder? newest;

      for (final g in gasOrders.where((o) => !_finalStatuses.contains(o.status.toLowerCase()))) {
        final candidate = _RealActiveOrder(
          kind: ClientOrderKind.gas,
          id: g.id,
          title: 'Livraison Gaz ${g.brand ?? 'B6/B12'}',
          subtitle: 'Taille : ${g.size ?? 'B12'} • Qté ${g.qty}',
          status: g.status,
          createdAt: g.createdAt,
        );
        if (newest == null || candidate.createdAt.isAfter(newest.createdAt)) {
          newest = candidate;
        }
      }

      for (final p in parcelOrders.where((o) => !_finalStatuses.contains(o.status.toLowerCase()))) {
        final candidate = _RealActiveOrder(
          kind: ClientOrderKind.parcel,
          id: p.id,
          title: 'Express Colis #${p.id}',
          subtitle: 'Colis : ${p.packageLabel ?? 'Express'}',
          status: p.status,
          createdAt: p.createdAt,
        );
        if (newest == null || candidate.createdAt.isAfter(newest.createdAt)) {
          newest = candidate;
        }
      }

      for (final f in foodOrders.where((o) => !_finalStatuses.contains(o.status.toLowerCase()))) {
        final candidate = _RealActiveOrder(
          kind: ClientOrderKind.food,
          id: f.id,
          title: 'Repas Express #${f.id}',
          subtitle: 'Livraison repas en cours',
          status: f.status,
          createdAt: f.createdAt,
        );
        if (newest == null || candidate.createdAt.isAfter(newest.createdAt)) {
          newest = candidate;
        }
      }

      return newest;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Suivi en direct',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FamanhColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                _LivePulsingDot(),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ClientDashboardScreen(initialTab: 1)),
              ),
              child: const Text(
                'Historique',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FamanhColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        FutureBuilder<_RealActiveOrder?>(
          future: _future,
          builder: (context, snap) {
            final activeOrder = snap.data;

            if (snap.connectionState == ConnectionState.waiting && activeOrder == null) {
              return Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: FamanhColors.primary),
                ),
              );
            }

            if (activeOrder == null) {
              // NO ACTIVE COURSE - Animated Empty State
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: FamanhColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: FamanhColors.outline, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aucune course actuellement',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FamanhColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Vos livraisons en cours s\'afficheront ici',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: FamanhColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // ACTIVE REAL ORDER FOUND IN BD
            final orderKindStr = activeOrder.kind == ClientOrderKind.gas
                ? 'gas'
                : activeOrder.kind == ClientOrderKind.parcel
                    ? 'parcel'
                    : 'food';

            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClientOrderMapScreen(
                    orderKind: orderKindStr,
                    orderId: activeOrder.id,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeOrder.statusBadgeText.withValues(alpha: 0.25), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: activeOrder.progressBarColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header Row: Icon + Title + Status Pill
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: activeOrder.statusBadgeBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            activeOrder.kind == ClientOrderKind.gas
                                ? Icons.propane_tank_rounded
                                : (activeOrder.kind == ClientOrderKind.parcel
                                    ? Icons.inventory_2_rounded
                                    : Icons.restaurant_rounded),
                            color: activeOrder.statusBadgeText,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    activeOrder.title,
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: FamanhColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: FamanhColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#FMN-${activeOrder.id}',
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: FamanhColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                activeOrder.dynamicSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: FamanhColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: activeOrder.statusBadgeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: activeOrder.statusBadgeText.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            activeOrder.statusLabel.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: activeOrder.statusBadgeText,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Dynamic Progress Bar & Step Label
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              activeOrder.stepText,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: activeOrder.statusBadgeText,
                              ),
                            ),
                            Text(
                              '${(activeOrder.progressFactor * 100).toInt()}%',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: activeOrder.statusBadgeText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: activeOrder.progressFactor,
                            child: Container(
                              decoration: BoxDecoration(
                                color: activeOrder.progressBarColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Bottom Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.two_wheeler_rounded, size: 16, color: FamanhColors.outline),
                            SizedBox(width: 6),
                            Text(
                              'Livraison Famanh Express',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: FamanhColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClientOrderMapScreen(
                                orderKind: orderKindStr,
                                orderId: activeOrder.id,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 14),
                          label: const Text('Carte GPS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FamanhColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LivePulsingDot extends StatefulWidget {
  const _LivePulsingDot();

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _anim = Tween<double>(begin: 0.3, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: FamanhColors.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RealActiveOrder {
  const _RealActiveOrder({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
  });

  final ClientOrderKind kind;
  final int id;
  final String title;
  final String subtitle;
  final String status;
  final DateTime createdAt;

  double get progressFactor {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0.20;
      case 'accepted':
      case 'depot_selected':
      case 'preparing':
      case 'stop_preparing':
      case 'stop_ready':
      case 'ready':
        return 0.55;
      case 'at_depot':
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return 0.85;
      case 'delivered_paid':
      case 'empty_returned':
        return 1.0;
      default:
        return 0.20;
    }
  }

  String get stepText {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Étape 1/3 • Recherche de livreur';
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
      case 'stop_ready':
      case 'ready':
        return 'Étape 2/3 • Préparation en cours';
      case 'at_depot':
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return 'Étape 3/3 • En cours d\'acheminement';
      default:
        return 'Commande enregistrée';
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Assigné';
      case 'preparing':
      case 'stop_preparing':
        return 'En cuisine';
      case 'stop_ready':
      case 'ready':
        return 'Prête';
      case 'picked_up':
      case 'stop_picked_up':
      case 'at_depot':
        return 'Récupérée';
      case 'en_route':
        return 'En route';
      default:
        return 'En cours';
    }
  }

  String get dynamicSubtitle {
    switch (status.toLowerCase()) {
      case 'pending':
        return kind == ClientOrderKind.food
            ? 'Transmise au restaurant • Recherche de livreur'
            : 'En attente d\'attribution à un coursier';
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
        return kind == ClientOrderKind.food
            ? 'Le restaurant prépare votre repas'
            : 'Un coursier a accepté votre livraison';
      case 'stop_ready':
      case 'ready':
        return 'Commande prête, le livreur arrive pour le retrait';
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return 'Le livreur est en chemin vers votre adresse';
      default:
        return subtitle;
    }
  }

  Color get statusBadgeBg {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFFBEB);
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
        return const Color(0xFFEFF6FF);
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return const Color(0xFFECFDF5);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get statusBadgeText {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
        return const Color(0xFF2563EB);
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF475569);
    }
  }

  Color get progressBarColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'accepted':
      case 'preparing':
      case 'stop_preparing':
        return const Color(0xFF3B82F6);
      case 'picked_up':
      case 'stop_picked_up':
      case 'en_route':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF006194);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 5. Popular In City Section (Restaurants & Hôtels Residences - Sans Gaz)
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// 5. Popular In City Section (Restaurants & Hôtels Residences - Onglets Filtres)
// ═══════════════════════════════════════════════════════════════

class _PopularInCitySection extends StatefulWidget {
  const _PopularInCitySection();

  @override
  State<_PopularInCitySection> createState() => _PopularInCitySectionState();
}

class _PopularInCitySectionState extends State<_PopularInCitySection> {
  int _selectedTabIndex = 0; // 0 = Restaurants, 1 = Résidences & Hôtels
  List<ResidenceDto> _residences = [];
  bool _isLoadingResidences = false;

  @override
  void initState() {
    super.initState();
    _fetchResidences();
  }

  Future<void> _fetchResidences() async {
    setState(() => _isLoadingResidences = true);
    try {
      final list = await ApiClient.getResidences();
      if (mounted) {
        setState(() {
          _residences = list;
          _isLoadingResidences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingResidences = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurantsTab = _selectedTabIndex == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with dynamic subtitle and "Voir tout" link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Populaire à Adiaké',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FamanhColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRestaurantsTab
                        ? 'Saveurs locales & Gastronomie'
                        : 'Résidences & Hôtels VIP Adiaké',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: FamanhColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                if (isRestaurantsTab) {
                  Navigator.of(context).pushNamed(AppRoutes.foodHub);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResidenceListScreen()),
                  );
                }
              },
              child: const Text(
                'Voir tout',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FamanhColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Interactive Filter Tabs (Restaurants vs Résidences / Hôtels)
        Row(
          children: [
            _buildTabChip(
              index: 0,
              label: 'Restaurants',
              icon: Icons.restaurant_rounded,
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              index: 1,
              label: 'Résidences & Hôtels',
              icon: Icons.hotel_rounded,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Horizontal List of Filtered Items
        if (isRestaurantsTab)
          _buildRestaurantsList(context)
        else
          _buildResidencesList(context),
      ],
    );
  }

  Widget _buildTabChip({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
          });
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? FamanhColors.primary : FamanhColors.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.8)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FamanhColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : FamanhColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : FamanhColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantsList(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Card 1: Restaurant Item
          _PopularCardTile(
            title: "Grillades & Poissons d'Adiaké",
            subtitle: 'Carpe braisée, Attiéké frais, Poulet Kédjénou',
            price: 'Dès 2 500 FCFA',
            badgeText: '4.9 (180+)',
            badgeIcon: Icons.star_rounded,
            badgeColor: const Color(0xFFFFF3CD),
            badgeTextColor: FamanhColors.tertiary,
            timeText: '20 - 30 min',
            imageUrl:
                'https://lh3.googleusercontent.com/aida/AEtjO1WNPFYOuaSDmU7EWlyaNrSHIZNp4YY9cC0uL2JzgKp9CDH-oUab9DuwdE6qMd_5YtHL0vQ6Zqn3nQP6QcRkHY_5dbo7mBmKWfU4m3_LFG_iBYxSz9c-QCU04zt5FAt4jh7X_Z2340Z2LGYCQV0JcOeWGrlj6dzotYiQFOeDvFaFejKFQWq8jxLbd-0He9xsluuHxnQ-m8UKlBqWKetLnuCsnPnIXj5-_GZWkAgdPurDNJoH3J_TDBs2CYA',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.foodHub),
          ),

          const SizedBox(width: 12),

          // Card 2: Maquis Chez Tante Marie
          _PopularCardTile(
            title: 'Maquis Chez Tante Marie',
            subtitle: 'Kédjénou de Poulet, Placali sauce graine, Foutou',
            price: 'Dès 3 000 FCFA',
            badgeText: '4.8 (120+)',
            badgeIcon: Icons.star_rounded,
            badgeColor: const Color(0xFFFFF3CD),
            badgeTextColor: FamanhColors.tertiary,
            timeText: '15 - 25 min',
            imageUrl:
                'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.foodHub),
          ),

          const SizedBox(width: 12),

          // Card 3: Saveurs de la Lagune
          _PopularCardTile(
            title: 'Saveurs de la Lagune',
            subtitle: 'Capitaine grillé, Sauce Kédjénou, Aloko',
            price: 'Dès 2 000 FCFA',
            badgeText: '4.7 (95+)',
            badgeIcon: Icons.star_rounded,
            badgeColor: const Color(0xFFFFF3CD),
            badgeTextColor: FamanhColors.tertiary,
            timeText: '25 - 35 min',
            imageUrl:
                'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.foodHub),
          ),
        ],
      ),
    );
  }

  Widget _buildResidencesList(BuildContext context) {
    if (_isLoadingResidences && _residences.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_residences.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _residences.asMap().entries.map((entry) {
            final idx = entry.key;
            final res = entry.value;
            final isLast = idx == _residences.length - 1;

            return Padding(
              padding: EdgeInsets.only(right: isLast ? 0.0 : 12.0),
              child: _PopularCardTile(
                title: res.name,
                subtitle: '${res.locationArea ?? "Adiaké"} • ${res.bedrooms} Ch. • ${res.capacity > 0 ? res.capacity : 2} pers.',
                price: '${res.pricePerNight} FCFA / Nuit',
                badgeText: (res.badgeLabel != null && res.badgeLabel!.isNotEmpty) ? res.badgeLabel! : 'Luxe VIP',
                badgeIcon: Icons.hotel_rounded,
                badgeColor: FamanhColors.primaryFixed,
                badgeTextColor: FamanhColors.primary,
                timeText: res.locationArea ?? 'Adiaké',
                imageUrl: (res.imageUrl != null && res.imageUrl!.isNotEmpty)
                    ? res.imageUrl!
                    : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResidenceDetailScreen(residenceId: res.id),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Fallback if empty array
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _PopularCardTile(
            title: 'Lagoon Resort & Spa VIP',
            subtitle: 'Vue panoramique Lagune, Piscine & Navette',
            price: '35 000 FCFA / Nuit',
            badgeText: 'Luxe VIP',
            badgeIcon: Icons.hotel_rounded,
            badgeColor: FamanhColors.primaryFixed,
            badgeTextColor: FamanhColors.primary,
            timeText: 'Assinie • Aby',
            imageUrl:
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDLFDPbE3E-DO9zD5PpSO6J-fjVp0yxQJwy5oelLbQBZ7vknei9kekQYmKoZqdC-q8kxhnBgdfzXKH4xKJfo0jqRIMfZ2xtHGhfoCSG6wTlsC6zo6_XTsrSqD6CmCOptMxAvXBacbzYYIHGshWhYmnI3eeEXONdxAxE_4_qgmM5NYAiRlyfojdzJ-uHPvdBnFFsNWGp59vD0oC6wCdmSWuuheKcpyOJRC7uArUtDH5q9yp-LiXLZOQ-',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResidenceListScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _PopularCardTile(
            title: 'Résidence Hôtel Petit Paris',
            subtitle: 'Suite junior climatisée, WiFi HD, Garage',
            price: '25 000 FCFA / Nuit',
            badgeText: 'Top Vente',
            badgeIcon: Icons.star_rounded,
            badgeColor: const Color(0xFFFFF3CD),
            badgeTextColor: FamanhColors.tertiary,
            timeText: 'Adiaké Centre',
            imageUrl:
                'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResidenceListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularCardTile extends StatelessWidget {
  const _PopularCardTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badgeText,
    required this.badgeIcon,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.timeText,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final String badgeText;
  final IconData badgeIcon;
  final Color badgeColor;
  final Color badgeTextColor;
  final String timeText;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 20,
      onTap: onTap,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: FamanhColors.surfaceVariant),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeTextColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: FamanhColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: FamanhColors.outline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: FamanhColors.primary,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: FamanhColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_rounded, color: FamanhColors.primary, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
