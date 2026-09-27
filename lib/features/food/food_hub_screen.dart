import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/api_client.dart';
import '../../data/api_session.dart';
import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import '../delivery/gas_delivery_location_screen.dart';
import 'food_cart.dart';
import 'food_cart_screen.dart';
import 'food_restaurant_screen.dart';

const _kPrimary = Color(0xFF006194); // Famanh primary blue
const _kBg = Color(0xFFFAF8FF);

class FoodHubScreen extends StatefulWidget {
  const FoodHubScreen({super.key});

  @override
  State<FoodHubScreen> createState() => _FoodHubScreenState();
}

class _FoodHubScreenState extends State<FoodHubScreen> {
  bool _loading = true;
  String? _error;
  List<FoodRestaurantDto> _restaurants = const [];
  List<FoodDishWithRestaurantDto> _dishes = const [];
  String? _selectedTag;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    ApiSession.refreshMe();
    _searchCtrl.addListener(() => setState(() {}));
    FoodCart.instance.addListener(_sync);
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    FoodCart.instance.removeListener(_sync);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.getFoodRestaurants(),
        ApiClient.getAllFoodDishes(),
      ]);
      if (!mounted) return;
      setState(() {
        _restaurants = results[0] as List<FoodRestaurantDto>;
        _dishes = results[1] as List<FoodDishWithRestaurantDto>;
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

  List<String> get _categoryPills {
    return ['Tous', '🔥 Braisés & Maquis', '🍗 Poulet & Garba', '🍔 Burgers & Street', '🍹 Jus & Glaces'];
  }

  List<FoodDishWithRestaurantDto> get _filteredDishes {
    var list = _dishes;
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((d) =>
        d.name.toLowerCase().contains(q) ||
        d.restaurantName.toLowerCase().contains(q) ||
        (d.description?.toLowerCase().contains(q) ?? false),
      ).toList();
    }
    if (_selectedTag != null && _selectedTag != 'Tous') {
      final tagClean = _selectedTag!.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
      if (tagClean.isNotEmpty) {
        list = list.where((d) =>
          d.name.toLowerCase().contains(tagClean) ||
          d.restaurantName.toLowerCase().contains(tagClean) ||
          (d.description?.toLowerCase().contains(tagClean) ?? false)
        ).toList();
      }
    }
    return list;
  }

  void _openRestaurant(int restaurantId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FoodRestaurantScreen(restaurantId: restaurantId)),
    );
    if (mounted) setState(() {});
  }

  void _addToCart(FoodDishWithRestaurantDto dish) {
    final restMatch = _restaurants.firstWhere(
      (r) => r.id == dish.restaurantId,
      orElse: () => FoodRestaurantDto(
        id: dish.restaurantId,
        name: dish.restaurantName,
        phone: '',
        imageUrl: dish.restaurantImageUrl,
      ),
    );

    final dishDto = FoodDishDto(
      id: dish.id,
      restaurantId: dish.restaurantId,
      name: dish.name,
      description: dish.description,
      priceFcfa: dish.priceFcfa,
      imageUrl: dish.imageUrl,
    );

    FoodCart.instance.add(dishDto, restMatch);
  }

  void _removeFromCart(FoodDishWithRestaurantDto dish) {
    final currentQty = FoodCart.instance.getQty(dish.id);
    final restMatch = _restaurants.firstWhere(
      (r) => r.id == dish.restaurantId,
      orElse: () => FoodRestaurantDto(
        id: dish.restaurantId,
        name: dish.restaurantName,
        phone: '',
        imageUrl: dish.restaurantImageUrl,
      ),
    );

    final dishDto = FoodDishDto(
      id: dish.id,
      restaurantId: dish.restaurantId,
      name: dish.name,
      description: dish.description,
      priceFcfa: dish.priceFcfa,
      imageUrl: dish.imageUrl,
    );

    FoodCart.instance.setDishQty(dishDto, restMatch, currentQty - 1);
  }

  @override
  Widget build(BuildContext context) {
    final cartQty = FoodCart.instance.totalQty;
    final cartTotal = FoodCart.instance.subtotalFcfa;
    final filteredDishes = _filteredDishes;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              color: _kPrimary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. En-tête officiel & recherche contextuelle
                  SliverToBoxAdapter(
                    child: _HeaderSection(
                      cartQty: cartQty,
                      searchCtrl: _searchCtrl,
                      selectedCategory: _selectedTag ?? 'Tous',
                      categories: _categoryPills,
                      dishesCount: _dishes.length,
                      onCategorySelected: (cat) {
                        setState(() {
                          _selectedTag = cat == 'Tous' ? null : cat;
                        });
                      },
                    ),
                  ),

                  // 2. Section "Restaurants Coup de Cœur"
                  if (!_loading && _error == null && _restaurants.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _FeaturedRestaurantsSection(
                        restaurants: _restaurants,
                        onTap: (r) => _openRestaurant(r.id),
                        onSeeAll: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AllRestaurantsScreen(initialRestaurants: _restaurants),
                            ),
                          );
                        },
                      ),
                    ),

                  // 3. Section Title "Plats populaires"
                  if (!_loading && _error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  'Plats populaires',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF131B2E),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${filteredDishes.length} suggestions du chef',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: FamanhColors.outline,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.filter_list_rounded, color: FamanhColors.outline),
                          ],
                        ),
                      ),
                    ),

                  // 4. Loading State
                  if (_loading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => const _DishCardSkeleton(),
                        childCount: 5,
                      ),
                    )

                  // Error State
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFCCCCCC)),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _load,
                              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )

                  // Empty State
                  else if (filteredDishes.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.search_off_rounded, size: 56, color: Color(0xFFCCCCCC)),
                            SizedBox(height: 12),
                            Text('Aucun plat trouvé dans cette catégorie.',
                              style: TextStyle(fontSize: 14, color: Colors.black45, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    )

                  // Dish List (Plats populaires)
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final dish = filteredDishes[i];
                          final currentQty = FoodCart.instance.getQty(dish.id);
                          return _DishCardTile(
                            dish: dish,
                            currentQty: currentQty,
                            onTap: () => _openRestaurant(dish.restaurantId),
                            onAdd: () => _addToCart(dish),
                            onRemove: () => _removeFromCart(dish),
                          );
                        },
                        childCount: filteredDishes.length,
                      ),
                    ),

                  SliverToBoxAdapter(child: SizedBox(height: cartQty > 0 ? 110 : 40)),
                ],
              ),
            ),

            // 5. Barre Flottante Panier Actif
            if (cartQty > 0)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                left: 16,
                right: 16,
                child: _FloatingCartBar(
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

// ── Header & Categories Widget ────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.cartQty,
    required this.searchCtrl,
    required this.selectedCategory,
    required this.categories,
    required this.dishesCount,
    required this.onCategorySelected,
  });

  final int cartQty;
  final TextEditingController searchCtrl;
  final String selectedCategory;
  final List<String> categories;
  final int dishesCount;
  final ValueChanged<String> onCategorySelected;

  static Future<void> _pickLocation(BuildContext context) async {
    final res = await Navigator.of(context).push<DeliveryLocationResult>(
      MaterialPageRoute(builder: (_) => const GasDeliveryLocationScreen()),
    );
    if (res != null) {
      try {
        await ApiClient.updateMe(
          preferredAddress: res.addressLabel,
          preferredLat: res.location.latitude,
          preferredLng: res.location.longitude,
        );
        await ApiSession.refreshMe();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF131B2E)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const BrandLogo(size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: const [
                          Text(
                            'FAMANH CI',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF131B2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Cart Button in Header
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
                    width: 34,
                    height: 34,
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

          const SizedBox(height: 14),

          // Contextual Location & Rush status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<UserMeDto?>(
                valueListenable: ApiSession.currentUser,
                builder: (context, user, _) {
                  final locationText = (user?.preferredAddress != null && user!.preferredAddress!.trim().isNotEmpty)
                      ? user.preferredAddress!
                      : 'Adiaké, Quartier Commerce';

                  return GestureDetector(
                    onTap: () => _pickLocation(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: _kPrimary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded, size: 14, color: FamanhColors.outline),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6CF8BB).withValues(alpha: 0.3),
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
                    const SizedBox(width: 4),
                    
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF131B2E)),
              decoration: const InputDecoration(
                hintText: 'Rechercher un plat, poisson braisé, attiéké...',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: FamanhColors.outline),
                prefixIcon: Icon(Icons.search_rounded, color: FamanhColors.outline, size: 20),
                suffixIcon: Icon(Icons.tune_rounded, color: FamanhColors.outline, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Category Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                final displayLabel = cat == 'Tous' ? 'Tous ($dishesCount)' : cat;

                return GestureDetector(
                  onTap: () => onCategorySelected(cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? _kPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(color: FamanhColors.surfaceContainerHighest.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? _kPrimary.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      displayLabel,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF131B2E),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Restaurants Coup de Cœur ─────────────────────────────────────────────────

class _FeaturedRestaurantsSection extends StatelessWidget {
  const _FeaturedRestaurantsSection({
    required this.restaurants,
    required this.onTap,
    required this.onSeeAll,
  });

  final List<FoodRestaurantDto> restaurants;
  final ValueChanged<FoodRestaurantDto> onTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.stars_rounded, color: _kPrimary, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Restaurants Coup de Cœur',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: const [
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: _kPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = restaurants[i];
              return _FeaturedCardTile(restaurant: r, onTap: () => onTap(r));
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedCardTile extends StatelessWidget {
  const _FeaturedCardTile({required this.restaurant, required this.onTap});
  final FoodRestaurantDto restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (restaurant.imageUrl != null && restaurant.imageUrl!.isNotEmpty)
        ? restaurant.imageUrl!
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 275,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
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
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    restaurant.description ?? 'Spécialités braisées & Attiéké',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.schedule_rounded, size: 14, color: _kPrimary),
                          SizedBox(width: 4),
                          Text(
                            '20–35 min',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: const [
                          Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFFFB95F)),
                          SizedBox(width: 4),
                          Text(
                            'Recettes d\'antan',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFDDB8),
                            ),
                          ),
                        ],
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

// ── Plats Populaires Card Tile ───────────────────────────────────────────────

class _DishCardTile extends StatelessWidget {
  const _DishCardTile({
    required this.dish,
    required this.currentQty,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  final FoodDishWithRestaurantDto dish;
  final int currentQty;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final photoUrl = (dish.imageUrl != null && dish.imageUrl!.isNotEmpty)
        ? dish.imageUrl!
        : (dish.allPhotoUrls.isNotEmpty
            ? dish.allPhotoUrls.first
            : 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
            children: [
              // Dish Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: FamanhColors.surfaceVariant,
                    child: const Icon(Icons.restaurant_rounded, color: FamanhColors.outline),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Dish Info & Interactive Add/Stepper Button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dish.restaurantName} • ${dish.description ?? "Spécialité locale"}',
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
                          '${NumberFormat('#,###', 'fr').format(dish.priceFcfa)} FCFA',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),

                        // If qty == 0: Add button. If qty > 0: Stepper [-] [qty] [+]
                        if (currentQty == 0)
                          InkWell(
                            onTap: onAdd,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _kPrimary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ajouter',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F3FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: onRemove,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.remove_rounded, size: 14, color: Color(0xFF131B2E)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$currentQty',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF131B2E),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: onAdd,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
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
      ),
    );
  }
}

class _DishCardSkeleton extends StatelessWidget {
  const _DishCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: FamanhColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 14, color: FamanhColors.surfaceVariant),
                const SizedBox(height: 6),
                Container(width: 100, height: 10, color: FamanhColors.surfaceVariant),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 70, height: 14, color: FamanhColors.surfaceVariant),
                    Container(width: 60, height: 24, color: FamanhColors.surfaceVariant),
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

// ── Floating Cart Bar ─────────────────────────────────────────────────────────

class _FloatingCartBar extends StatelessWidget {
  const _FloatingCartBar({
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
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6CF8BB),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF002113),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$qty article${qty > 1 ? "s" : ""} sélectionné${qty > 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'fr').format(total)} FCFA',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF93CCFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Text(
                    'Voir panier',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
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

// ── Tous les Restaurants Screen ──────────────────────────────────────────────

class AllRestaurantsScreen extends StatefulWidget {
  const AllRestaurantsScreen({super.key, this.initialRestaurants});

  final List<FoodRestaurantDto>? initialRestaurants;

  @override
  State<AllRestaurantsScreen> createState() => _AllRestaurantsScreenState();
}

class _AllRestaurantsScreenState extends State<AllRestaurantsScreen> {
  bool _loading = false;
  String? _error;
  List<FoodRestaurantDto> _restaurants = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialRestaurants != null && widget.initialRestaurants!.isNotEmpty) {
      _restaurants = widget.initialRestaurants!;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.getFoodRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<FoodRestaurantDto> get _filtered {
    if (_searchQuery.trim().isEmpty) return _restaurants;
    final q = _searchQuery.trim().toLowerCase();
    return _restaurants.where((r) {
      final name = r.name.toLowerCase();
      final desc = (r.description ?? '').toLowerCase();
      final tags = r.tags.join(' ').toLowerCase();
      return name.contains(q) || desc.contains(q) || tags.contains(q);
    }).toList();
  }

  void _openRestaurant(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodRestaurantScreen(restaurantId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tous les Restaurants',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_restaurants.length} établissements à Adiaké',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF006194),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Field Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant, spécialité...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF006194)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF006194)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant_rounded, size: 54, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Aucun restaurant trouvé pour "$_searchQuery"'
                                      : 'Aucun restaurant disponible',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFF006194),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final r = list[index];
                                final image = (r.imageUrl != null && r.imageUrl!.isNotEmpty)
                                    ? r.imageUrl!
                                    : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop&q=80';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    elevation: 2,
                                    shadowColor: Colors.black.withValues(alpha: 0.06),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _openRestaurant(r.id),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Banner Image
                                          Stack(
                                            children: [
                                              AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child: Image.network(
                                                  image,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: const Color(0xFFE2E8F0),
                                                    child: const Icon(Icons.restaurant, size: 48, color: Color(0xFF94A3B8)),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 12,
                                                right: 12,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.95),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '4.8',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 12,
                                                left: 12,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF006194),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.schedule_rounded, size: 12, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '20-35 min',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Content Details
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        r.name,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w800,
                                                          color: const Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'Ouvert',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF15803D),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (r.description != null && r.description!.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    r.description!,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFF64748B),
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF006194)),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        (r.address != null && r.address!.isNotEmpty) ? r.address! : 'Adiaké, Côte d\'Ivoire',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF475569),
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
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
