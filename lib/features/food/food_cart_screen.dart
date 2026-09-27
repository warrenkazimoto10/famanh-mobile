import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../theme/adiake_colors.dart';
import '../../widgets/brand_logo.dart';
import 'food_cart.dart';
import 'food_checkout_screen.dart';

const _kPrimary = Color(0xFF006194);
const _kBg = Color(0xFFFAF8FF);

class FoodCartScreen extends StatefulWidget {
  const FoodCartScreen({super.key});

  @override
  State<FoodCartScreen> createState() => _FoodCartScreenState();
}

class _FoodCartScreenState extends State<FoodCartScreen> {
  @override
  void initState() {
    super.initState();
    FoodCart.instance.addListener(_onCart);
  }

  void _onCart() => setState(() {});

  @override
  void dispose() {
    FoodCart.instance.removeListener(_onCart);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = FoodCart.instance;
    final lines = cart.lines;

    final byRestaurant = <int, List<FoodCartLine>>{};
    for (final l in lines) {
      byRestaurant.putIfAbsent(l.restaurant.id, () => []).add(l);
    }

    final subtotal = cart.subtotalFcfa;

    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Header Bar
          Container(
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
                      'Votre Panier Restaurant',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
                if (lines.isNotEmpty)
                  IconButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Vider le panier ?'),
                          content: const Text('Voulez-vous vraiment retirer tous les plats du panier ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('VIDER', style: TextStyle(color: FamanhColors.error, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) cart.clear();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: FamanhColors.error),
                  ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: FamanhColors.outline),
                        SizedBox(height: 16),
                        Text(
                          'Votre panier est vide',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Ajoutez de délicieux plats pour commander !',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: FamanhColors.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // Grouped Cart Lines
                      for (final entry in byRestaurant.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            entry.value.first.restaurant.name,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _kPrimary,
                            ),
                          ),
                        ),

                        for (final line in entry.value) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: (line.dish.imageUrl != null && line.dish.imageUrl!.isNotEmpty)
                                        ? line.dish.imageUrl!
                                        : 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 64,
                                      height: 64,
                                      color: FamanhColors.surfaceVariant,
                                      child: const Icon(Icons.restaurant_rounded, color: FamanhColors.outline),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.dish.name,
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF131B2E),
                                        ),
                                      ),
                                      if (line.note != null && line.note!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Note: ${line.note!}',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: FamanhColors.outline,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        '${NumberFormat('#,###', 'fr').format(line.dish.priceFcfa * line.qty)} FCFA',
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _kPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Clear Interactive Stepper Widget [-] [qty] [+]
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => cart.setQty(line, line.qty - 1),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF131B2E)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          '${line.qty}',
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF131B2E),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => cart.setQty(line, line.qty + 1),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: _kPrimary,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _kPrimary.withValues(alpha: 0.25),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),

          // Bottom Order Total Summary & Checkout Button
          if (lines.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sous-total plats',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: FamanhColors.outline),
                        ),
                        Text(
                          '${NumberFormat('#,###', 'fr').format(subtotal)} FCFA',
                          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total à payer',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF131B2E),
                          ),
                        ),
                        Text(
                          '${NumberFormat('#,###', 'fr').format(subtotal)} FCFA',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '* Les frais de livraison (500 FCFA) seront ajoutés à l\'étape suivante.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: FamanhColors.outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FoodCheckoutScreen()),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          'PASSER LA COMMANDE',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
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
