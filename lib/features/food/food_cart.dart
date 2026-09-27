import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api_client.dart';

class FoodCartLine {
  FoodCartLine({
    required this.dish,
    required this.restaurant,
    required this.qty,
    this.note,
  });

  final FoodDishDto dish;
  final FoodRestaurantDto restaurant;
  int qty;
  final String? note;

  Map<String, dynamic> toJson() => {
        'dish': dish.toJson(),
        'restaurant': restaurant.toJson(),
        'qty': qty,
        'note': note,
      };

  factory FoodCartLine.fromJson(Map<String, dynamic> json) => FoodCartLine(
        dish: FoodDishDto.fromJson(json['dish']),
        restaurant: FoodRestaurantDto.fromJson(json['restaurant']),
        qty: json['qty'] ?? 1,
        note: json['note'],
      );
}

/// Panier multi-restaurants avec persistance locale.
class FoodCart extends ChangeNotifier {
  FoodCart._();
  static final instance = FoodCart._();

  final List<FoodCartLine> _lines = [];

  List<FoodCartLine> get lines => List.unmodifiable(_lines);

  int get totalQty => _lines.fold(0, (s, l) => s + l.qty);

  int get subtotalFcfa => _lines.fold(0, (s, l) => s + l.dish.priceFcfa * l.qty);

  bool get isEmpty => _lines.isEmpty;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('food_cart_v1');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _lines.clear();
        for (final item in list) {
          _lines.add(FoodCartLine.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_lines.map((l) => l.toJson()).toList());
      await prefs.setString('food_cart_v1', raw);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void clear() {
    _lines.clear();
    _save();
    notifyListeners();
  }

  void add(FoodDishDto dish, FoodRestaurantDto restaurant, {int qty = 1, String? note}) {
    final i = _lines.indexWhere((l) => l.dish.id == dish.id && l.note == note);
    if (i >= 0) {
      _lines[i].qty += qty;
    } else {
      _lines.add(FoodCartLine(dish: dish, restaurant: restaurant, qty: qty, note: note));
    }
    _save();
    notifyListeners();
  }

  void setQty(FoodCartLine line, int qty) {
    final i = _lines.indexOf(line);
    if (i < 0) return;
    if (qty <= 0) {
      _lines.removeAt(i);
    } else {
      _lines[i].qty = qty;
    }
    _save();
    notifyListeners();
  }

  int getQty(int dishId) {
    final index = _lines.indexWhere((l) => l.dish.id == dishId);
    return index >= 0 ? _lines[index].qty : 0;
  }

  void setDishQty(FoodDishDto dish, FoodRestaurantDto restaurant, int qty) {
    final index = _lines.indexWhere((l) => l.dish.id == dish.id);
    if (qty <= 0) {
      if (index >= 0) _lines.removeAt(index);
    } else {
      if (index >= 0) {
        _lines[index].qty = qty;
      } else {
        _lines.add(FoodCartLine(dish: dish, restaurant: restaurant, qty: qty));
      }
    }
    _save();
    notifyListeners();
  }

  void removeLine(FoodDishDto dish) {
    _lines.removeWhere((l) => l.dish.id == dish.id);
    _save();
    notifyListeners();
  }

  List<Map<String, dynamic>> buildOrderItemsPayload() {
    return [
      for (final l in _lines) {'dish_id': l.dish.id, 'qty': l.qty, if (l.note != null && l.note!.trim().isNotEmpty) 'note': l.note!.trim()},
    ];
  }
}

