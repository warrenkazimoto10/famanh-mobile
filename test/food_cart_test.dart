import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adiake_livraison_express/data/api_client.dart';
import 'package:adiake_livraison_express/features/food/food_cart.dart';

const _resto = FoodRestaurantDto(id: 1, name: 'Chez Test', phone: '0700000000');
const _dishA = FoodDishDto(id: 10, restaurantId: 1, name: 'Attiéké', priceFcfa: 2500);
const _dishB = FoodDishDto(id: 11, restaurantId: 1, name: 'Alloco', priceFcfa: 1000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FoodCart.instance.clear();
  });

  test('add cumule la quantité pour le même plat/note', () {
    final cart = FoodCart.instance;
    cart.add(_dishA, _resto, qty: 1);
    cart.add(_dishA, _resto, qty: 2);

    expect(cart.lines.length, 1);
    expect(cart.totalQty, 3);
  });

  test('subtotalFcfa calcule le bon total multi-plats', () {
    final cart = FoodCart.instance;
    cart.add(_dishA, _resto, qty: 2); // 5000
    cart.add(_dishB, _resto, qty: 3); // 3000

    expect(cart.subtotalFcfa, 8000);
  });

  test('setQty à 0 retire la ligne', () {
    final cart = FoodCart.instance;
    cart.add(_dishA, _resto, qty: 1);
    cart.setQty(cart.lines.first, 0);

    expect(cart.isEmpty, isTrue);
  });

  test('buildOrderItemsPayload produit le format attendu par l’API', () {
    final cart = FoodCart.instance;
    cart.add(_dishA, _resto, qty: 2, note: 'sans piment');

    final payload = cart.buildOrderItemsPayload();
    expect(payload, [
      {'dish_id': 10, 'qty': 2, 'note': 'sans piment'},
    ]);
  });

  test('clear vide le panier', () {
    final cart = FoodCart.instance;
    cart.add(_dishA, _resto, qty: 1);
    cart.clear();

    expect(cart.isEmpty, isTrue);
    expect(cart.subtotalFcfa, 0);
  });
}
