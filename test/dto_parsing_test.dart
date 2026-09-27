import 'package:flutter_test/flutter_test.dart';
import 'package:adiake_livraison_express/data/api_client.dart';

void main() {
  group('FoodDishDto.fromJson', () {
    test('parse un JSON complet', () {
      final dish = FoodDishDto.fromJson({
        'id': 10,
        'restaurant_id': 1,
        'name': 'Attiéké',
        'price_fcfa': 2500,
        'description': 'Avec poisson',
      });

      expect(dish.id, 10);
      expect(dish.restaurantId, 1);
      expect(dish.name, 'Attiéké');
      expect(dish.priceFcfa, 2500);
    });

    test('est robuste aux champs manquants / types string', () {
      final dish = FoodDishDto.fromJson({
        'id': '11', // string au lieu d'int
        'price_fcfa': '1000',
      });

      expect(dish.id, 11);
      expect(dish.priceFcfa, 1000);
      expect(dish.name, '');
      expect(dish.restaurantId, 0);
    });
  });

  group('FoodRestaurantDto.fromJson', () {
    test('parse les tags depuis une chaîne séparée par des virgules', () {
      final r = FoodRestaurantDto.fromJson({
        'id': 1,
        'name': 'Chez Test',
        'phone': '0700000000',
        'tags': 'rapide, local, halal',
      });

      expect(r.id, 1);
      expect(r.tags, ['rapide', 'local', 'halal']);
    });

    test('gère l\'absence de tags et de gallery', () {
      final r = FoodRestaurantDto.fromJson({
        'id': 2,
        'name': 'Sans Tags',
        'phone': '0700000001',
      });

      expect(r.tags, isEmpty);
      expect(r.gallery, isEmpty);
    });
  });
}
