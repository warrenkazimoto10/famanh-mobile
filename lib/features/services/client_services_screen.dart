import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/staggered_item.dart';
import '../events/event_catalog_screen.dart';
import '../residence/residence_list_screen.dart';

class ClientServicesScreen extends StatefulWidget {
  const ClientServicesScreen({super.key});

  @override
  State<ClientServicesScreen> createState() => _ClientServicesScreenState();
}

class _ClientServicesScreenState extends State<ClientServicesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AdiakeColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 0,
              delayMs: 0,
              child: _HeroHeader(topPadding: top),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([

                // ── Section label ────────────────────────────────
                StaggeredItem(
                  index: 1,
                  delayMs: 80,
                  child: _SectionLabel(),
                ),
                const SizedBox(height: 16),

                // ── Livraison Express (featured) ──────────────────
                StaggeredItem(
                  index: 2,
                  delayMs: 80,
                  child: _FeaturedCard(
                    pulseCtrl: _pulse,
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.deliveryCategories),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Taxi + Hôtels (2-col grid) ────────────────────
                StaggeredItem(
                  index: 3,
                  delayMs: 80,
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompactCard(
                          icon: Icons.local_taxi_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFD97706),
                          title: 'Taxi\nCommunal',
                          badge: 'Partagé · Express',
                          badgeColor: const Color(0xFFD97706),
                          isAvailable: true,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pushNamed(AppRoutes.taxi);
                          },
                        ),
                      ),

                      const SizedBox(width: 12),
                      Expanded(
                        child: _CompactCard(
                          icon: Icons.hotel_rounded,
                          iconBg: AdiakeColors.tertiaryFixed,
                          iconColor: AdiakeColors.tertiaryContainer,
                          title: 'Hôtels\n& VIP',
                          badge: 'Luxe · VIP',
                          badgeColor: AdiakeColors.tertiaryContainer,
                          isAvailable: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ResidenceListScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Événements & Billetterie ──────────────────────
                StaggeredItem(
                  index: 4,
                  delayMs: 80,
                  child: _CompactCard(
                    icon: Icons.confirmation_number_rounded,
                    iconBg: const Color(0xFFFFDDB8),
                    iconColor: const Color(0xFF825100),
                    title: 'Événements\n& Billetterie',
                    badge: 'NEW 🎉',
                    badgeColor: const Color(0xFFFFB95F),
                    isAvailable: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EventCatalogScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Promo Banner ──────────────────────────────────
                StaggeredItem(
                  index: 5,
                  delayMs: 80,
                  child: _PromoBanner(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Hero Header
// ═══════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final double topPadding;
  const _HeroHeader({required this.topPadding});

  @override
  Widget build(BuildContext context) {
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
          // Decorative circles
          Positioned(
            top: -50,
            right: -50,
            child: _Blob(size: 180, opacity: 0.08),
          ),
          Positioned(
            top: 30,
            right: 70,
            child: _Blob(size: 80, opacity: 0.06),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: _Blob(size: 120, opacity: 0.07),
          ),
          Positioned(
            bottom: -20,
            right: 40,
            child: _Blob(size: 70, opacity: 0.05),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.white.withOpacity(0.90),
                        size: 12,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'FAMANH · VOTRE QUOTIDIEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nos Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tout ce dont vous avez besoin,\nau bout des doigts.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: '< 45 min',
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      icon: Icons.star_rounded,
                      label: '4.8 / 5',
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      icon: Icons.inventory_2_outlined,
                      label: '500+ livraisons',
                    ),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
          width: 1,
        ),
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
}

// ═══════════════════════════════════════════════════════════════
// Section Label
// ═══════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Nos services',
          style: TextStyle(
            color: AdiakeColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AdiakeColors.primaryContainer,
            borderRadius: BorderRadius.circular(30),
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

// ═══════════════════════════════════════════════════════════════
// Featured Card — Livraison Express
// ═══════════════════════════════════════════════════════════════

class _FeaturedCard extends StatelessWidget {
  final AnimationController pulseCtrl;
  final VoidCallback? onTap;

  const _FeaturedCard({required this.pulseCtrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 24,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2540), Color(0xFF0052FF), Color(0xFF0094FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0052FF).withOpacity(0.30),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Shimmer sweep overlay
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (context, _) {
                final v = pulseCtrl.value;
                final x = -1.5 + v * 3.0;
                return Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(x - 0.5, -1),
                          end: Alignment(x + 0.5, 1),
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left — text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ['Repas', 'Gaz', 'Colis']
                              .map((l) => _LabelChip(l))
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Livraison\nExpress',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Repas chauds, gaz et colis\nlivrés à domicile rapidement.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // CTA button with breathing pulse
                        AnimatedBuilder(
                          animation: pulseCtrl,
                          builder: (context, child) {
                            final scale = 1.0 +
                                0.025 *
                                    math.sin(
                                        pulseCtrl.value * 2 * math.pi);
                            return Transform.scale(
                              scale: scale,
                              alignment: Alignment.centerLeft,
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 11),
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
                                  'Commander',
                                  style: TextStyle(
                                    color: AdiakeColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AdiakeColors.primary,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right — icon
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Live indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(),
                            const SizedBox(width: 5),
                            const Text(
                              'En ligne',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  const _LabelChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.17),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      );
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

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
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF4ADE80),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Compact Card
// ═══════════════════════════════════════════════════════════════

class _CompactCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String badge;
  final Color badgeColor;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _CompactCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 22,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? iconBg
                        : AdiakeColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isAvailable
                        ? iconColor
                        : AdiakeColors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AdiakeColors.primary.withOpacity(0.09)
                        : AdiakeColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAvailable
                        ? Icons.arrow_forward_rounded
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: isAvailable
                        ? AdiakeColors.primary
                        : AdiakeColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isAvailable
                    ? AdiakeColors.primary
                    : AdiakeColors.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isAvailable
                    ? badgeColor.withOpacity(0.10)
                    : AdiakeColors.surfaceVariant,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                badge.toUpperCase(),
                style: TextStyle(
                  color: isAvailable
                      ? badgeColor
                      : AdiakeColors.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Promo Banner
// ═══════════════════════════════════════════════════════════════

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AdiakeColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AdiakeColors.tertiaryFixedDim.withOpacity(0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AdiakeColors.tertiaryFixedDim.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AdiakeColors.tertiaryFixedDim.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: AdiakeColors.onTertiaryFixedVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livraison rapide garantie',
                  style: TextStyle(
                    color: AdiakeColors.tertiaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Commandez maintenant et soyez livré en moins de 45 min.',
                  style: TextStyle(
                    color: AdiakeColors.onTertiaryFixedVariant,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AdiakeColors.onTertiaryFixedVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}
