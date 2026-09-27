import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/api_session.dart';
import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/client_bottom_nav.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/staggered_item.dart';

class DeliveryCategoriesScreen extends StatefulWidget {
  const DeliveryCategoriesScreen({super.key});

  @override
  State<DeliveryCategoriesScreen> createState() =>
      _DeliveryCategoriesScreenState();
}

class _DeliveryCategoriesScreenState
    extends State<DeliveryCategoriesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _DeliveryHero()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      // Section label
                      StaggeredItem(
                        index: 0,
                        delayMs: 0,
                        child: _SectionLabel(),
                      ),
                      const SizedBox(height: 16),

                      // Repas — featured large card
                      StaggeredItem(
                        index: 1,
                        delayMs: 80,
                        child: _FeaturedDeliveryCard(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A2540), Color(0xFF0052FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          icon: Icons.restaurant_rounded,
                          badge: "L'ÉLITE",
                          badgeColor: const Color(0xFFFFD700),
                          badgeTextColor: AdiakeColors.primary,
                          title: 'Repas\nGastronomiques',
                          subtitle:
                              "Les meilleures tables de la région, livrées directement à votre résidence.",
                          chips: const ['Restaurants', 'Hot'],
                          ctaLabel: 'Commander maintenant',
                          onTap: () =>
                              Navigator.of(context).pushNamed(AppRoutes.foodHub),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Gaz + Colis side by side
                      StaggeredItem(
                        index: 2,
                        delayMs: 80,
                        child: Row(
                          children: [
                            Expanded(
                              child: _CompactDeliveryCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF78350F),
                                    Color(0xFFB45309)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                icon: Icons.local_fire_department_rounded,
                                badge: 'SÉCURITÉ',
                                title: 'Bouteilles\nde Gaz',
                                info: 'Dès 5 000 FCFA',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.gasOrder),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CompactDeliveryCard(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF14532D),
                                    Color(0xFF16A34A)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                icon: Icons.inventory_2_rounded,
                                badge: 'EXPRESS',
                                title: 'Colis\nExpress',
                                info: '< 60 min',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.parcelExpress),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info banner
                      StaggeredItem(
                        index: 3,
                        delayMs: 80,
                        child: _DeliveryInfoBanner(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClientBottomNavBar(
              currentIndex: _tab,
              isAdmin: false,
              onTap: (i) {
                setState(() => _tab = i);
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.dashboard,
                  (r) => false,
                  arguments: i,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _DeliveryHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2540), Color(0xFF0052FF), Color(0xFF0094FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -40, right: -40, child: _Blob(size: 160, opacity: 0.07)),
          Positioned(bottom: 10, left: -20, child: _Blob(size: 100, opacity: 0.06)),

          Padding(
            padding: EdgeInsets.fromLTRB(22, top + 16, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    // User avatar from session
                    ValueListenableBuilder<UserMeDto?>(
                      valueListenable: ApiSession.currentUser,
                      builder: (_, me, __) {
                        final avatar = me?.avatarUrl;
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 2,
                            ),
                            color: Colors.white.withOpacity(0.14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (avatar == null || avatar.isEmpty)
                              ? const Icon(Icons.person_rounded,
                                  color: Colors.white, size: 22)
                              : Image.network(avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 22)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Category pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.22), width: 1),
                  ),
                  child: const Text(
                    'LIVRAISON EXPRESS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  "L'Excellence\nà votre porte",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez le service qui vous correspond.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Stats row
                Row(
                  children: [
                    _StatPill(icon: Icons.timer_outlined, label: '< 45 min'),
                    const SizedBox(width: 10),
                    _StatPill(icon: Icons.star_rounded, label: '4.8 ★'),
                    const SizedBox(width: 10),
                    _StatPill(icon: Icons.local_shipping_rounded, label: '3 services'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

// ─── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Nos catégories',
          style: TextStyle(
            color: AdiakeColors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AdiakeColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '3',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Featured Card ─────────────────────────────────────────────────────────────

class _FeaturedDeliveryCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final String title;
  final String subtitle;
  final List<String> chips;
  final String ctaLabel;
  final VoidCallback onTap;

  const _FeaturedDeliveryCard({
    required this.gradient,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 24,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AdiakeColors.primaryContainer.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 13, color: badgeTextColor),
                        const SizedBox(width: 5),
                        Text(
                          badge,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Chips
                  Wrap(
                    spacing: 6,
                    children: chips
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                c.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  // CTA
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaLabel,
                          style: TextStyle(
                            color: AdiakeColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: AdiakeColors.primary, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Icon(icon, color: Colors.white, size: 52),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact Card ──────────────────────────────────────────────────────────────

class _CompactDeliveryCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String badge;
  final String title;
  final String info;
  final VoidCallback onTap;

  const _CompactDeliveryCard({
    required this.gradient,
    required this.icon,
    required this.badge,
    required this.title,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 22,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(icon, color: Colors.white, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              info,
              style: TextStyle(
                color: Colors.white.withOpacity(0.80),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Banner ───────────────────────────────────────────────────────────────

class _DeliveryInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AdiakeColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AdiakeColors.tertiaryFixedDim.withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdiakeColors.tertiaryFixedDim.withOpacity(0.40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.verified_rounded,
              color: AdiakeColors.onTertiaryFixedVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livraison garantie',
                  style: TextStyle(
                    color: AdiakeColors.tertiaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Suivi en temps réel • Paiement à la livraison',
                  style: TextStyle(
                    color: AdiakeColors.onTertiaryFixedVariant,
                    fontSize: 11.5,
                    height: 1.4,
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
