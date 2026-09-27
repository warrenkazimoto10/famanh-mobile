import 'package:flutter_test/flutter_test.dart';
import 'package:adiake_livraison_express/widgets/money_text.dart';

void main() {
  group('MoneyText.fmt', () {
    test('ajoute des séparateurs de milliers', () {
      expect(MoneyText.fmt(0), '0');
      expect(MoneyText.fmt(500), '500');
      expect(MoneyText.fmt(1000), '1 000');
      expect(MoneyText.fmt(15000), '15 000');
      expect(MoneyText.fmt(1234567), '1 234 567');
    });
  });
}
