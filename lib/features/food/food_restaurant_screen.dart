import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../data/api_client.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import 'food_cart.dart';
import 'food_cart_screen.dart';

const _kPrimary = Color(0xFF006194);
const _kBg = Color(0xFFFAF8FF);

class FoodRestaurantScreen extends StatefulWidget {
  const FoodRestaurantScreen({super.key, required this.restaurantId});
  final int restaurantId;

  @override
  State<FoodRestaurantScreen> createState() => _FoodRestaurantScreenState();
}

class _FoodRestaurantScreenState extends State<FoodRestaurantScreen> {
  bool _loading = true;
  String? _error;
  FoodRestaurantDetailDto? _detail;
  String _selectedCategory = 'Populaires';

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    FoodCart.instance.addListener(_sync);
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FoodCart.instance.removeListener(_sync);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ApiClient.getFoodRestaurant(widget.restaurantId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  List<String> get _categories {
    return ['Populaires', 'Poissons & Poulets', 'Brochettes', 'Accompagnements', 'Boissons'];
  }

  List<FoodDishDto> get _filteredDishes {
    if (_detail == null) return [];
    if (_selectedCategory == 'Populaires') return _detail!.dishes;
    final catClean = _selectedCategory.toLowerCase().replaceAll('&', '').trim();
    return _detail!.dishes.where((d) {
      final text = '${d.name} ${d.description ?? ''}'.toLowerCase();
      if (catClean.contains('poisson') || catClean.contains('poulet')) {
        return text.contains('poisson') || text.contains('poulet') || text.contains('tilapia') || text.contains('carpe');
      }
      if (catClean.contains('brochette')) {
        return text.contains('brochette') || text.contains('boeuf') || text.contains('kankankan');
      }
      if (catClean.contains('accompagnement')) {
        return text.contains('alloco') || text.contains('attieke') || text.contains('riz') || text.contains('frite');
      }
      if (catClean.contains('boisson')) {
        return text.contains('jus') || text.contains('boisson') || text.contains('eau') || text.contains('soda');
      }
      return true;
    }).toList();
  }

  void _addDishToCart(FoodDishDto dish) {
    if (_detail == null) return;
    FoodCart.instance.add(dish, _detail!);
  }

  void _removeDishFromCart(FoodDishDto dish) {
    if (_detail == null) return;
    final currentQty = FoodCart.instance.getQty(dish.id);
    FoodCart.instance.setDishQty(dish, _detail!, currentQty - 1);
  }

  @override
  Widget build(BuildContext context) {
    final cartTotal = FoodCart.instance.subtotalFcfa;
    final cartQty = FoodCart.instance.totalQty;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFCCCCCC)),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) return const SizedBox.shrink();

    final detail = _detail!;
    final filteredDishes = _filteredDishes;
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // 1. Top Bar Header
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF131B2E)),
                            ),
                            const BrandLogo(size: 26),
                            const SizedBox(width: 8),
                            const Text(
                              'Fiche Restaurant & Menu',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Shopping Cart Header Button
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FoodCartScreen()),
                              ),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: cartQty > 0 ? const Color(0xFF283044) : const Color(0xFFF2F3FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 19,
                                      color: cartQty > 0 ? Colors.white : FamanhColors.onSurfaceVariant,
                                    ),
                                    if (cartQty > 0)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6CF8BB),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$cartQty',
                                            style: const TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF002113),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: _kPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Immersive Hero Banner
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: (detail.imageUrl != null && detail.imageUrl!.isNotEmpty)
                              ? detail.imageUrl!
                              : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: FamanhColors.surfaceVariant),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF283044).withValues(alpha: 0.90),
                              ],
                              stops: const [0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6CF8BB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: Color(0xFF006C49), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Ouvert actuellement • Ferme à 23h00',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF00714D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              detail.name,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFFDDB8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${detail.address ?? "Quartier Commerce, Adiaké"} • Spécialités Braisées',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
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
                ),

                // 3. Key Metrics Bar
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F3FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.timer_rounded, size: 16, color: _kPrimary),
                              SizedBox(width: 6),
                              Text(
                                '20–35 min',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF131B2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Sticky Category Nav Tabs
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? _kPrimary : const Color(0xFFE2E7FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF3F4850),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // 5. Menu Content Stream ("Sélection du Chef")
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CARTE DU MOMENT',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: _kPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sélection du Chef',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Dish Items Stream
                if (filteredDishes.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Aucun plat dans cette catégorie.',
                          style: TextStyle(fontFamily: 'Inter', fontStyle: FontStyle.italic, color: FamanhColors.outline),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final dish = filteredDishes[i];
                        final currentQty = FoodCart.instance.getQty(dish.id);
                        return _RestaurantDishCard(
                          dish: dish,
                          currentQty: currentQty,
                          onAdd: () => _addDishToCart(dish),
                          onRemove: () => _removeDishFromCart(dish),
                        );
                      },
                      childCount: filteredDishes.length,
                    ),
                  ),

                SliverToBoxAdapter(child: SizedBox(height: cartQty > 0 ? 110 : 40)),
              ],
            ),

            // Sticky Bottom Cart Bar
            if (cartQty > 0)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                left: 16,
                right: 16,
                child: _RestaurantCartBar(
                  qty: cartQty,
                  total: cartTotal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FoodCartScreen()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Dish Card ────────────────────────────────────────────────────────────────

class _RestaurantDishCard extends StatelessWidget {
  const _RestaurantDishCard({
    required this.dish,
    required this.currentQty,
    required this.onAdd,
    required this.onRemove,
  });

  final FoodDishDto dish;
  final int currentQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final photoUrl = (dish.imageUrl != null && dish.imageUrl!.isNotEmpty)
        ? dish.imageUrl!
        : 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dish.description ?? 'Recette authentique braisée à la perfection.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: FamanhColors.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${NumberFormat('#,###', 'fr').format(dish.priceFcfa)} FCFA',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 92,
                    height: 92,
                    color: FamanhColors.surfaceVariant,
                    child: const Icon(Icons.restaurant_rounded, color: FamanhColors.outline),
                  ),
                ),
              ),
              Positioned(
                bottom: -10,
                right: -4,
                child: currentQty == 0
                    ? GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _kPrimary.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF283044),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: onRemove,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove_rounded, size: 14, color: Color(0xFF131B2E)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$currentQty',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: onAdd,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: _kPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sticky Cart Bar ──────────────────────────────────────────────────────────

class _RestaurantCartBar extends StatelessWidget {
  const _RestaurantCartBar({
    required this.qty,
    required this.total,
    required this.onTap,
  });

  final int qty;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF283044),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$qty plat${qty > 1 ? "s" : ""} sélectionné${qty > 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF93CCFF),
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'fr').format(total)} FCFA',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Text(
                    'Commander',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
