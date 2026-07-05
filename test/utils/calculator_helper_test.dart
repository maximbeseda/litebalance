import 'package:flutter_test/flutter_test.dart';

// Шлях до вашого файлу калькулятора
import 'package:litebalance/utils/calculator_helper.dart';

void main() {
  group('CalculatorHelper Tests', () {
    test('Повинен повертати "0" для порожнього рядка', () {
      expect(CalculatorHelper.calculate(''), '0');
    });

    test('Повинен правильно рахувати математику з пріоритетом операцій', () {
      const expression = '150+20*2';
      final result = CalculatorHelper.calculate(expression);
      expect(result, '190');
    });

    test('Повинен замінювати візуальні символи (×, ÷, коми)', () {
      expect(CalculatorHelper.calculate('10,5×2'), '21');
      expect(CalculatorHelper.calculate('10÷2'), '5');
    });

    test('Повинен повертати цілі числа без нулів після крапки', () {
      expect(CalculatorHelper.calculate('5+5'), '10');
    });

    test('Повинен обмежувати результат до 2 знаків після крапки', () {
      expect(CalculatorHelper.calculate('10/3'), '3.33');
    });

    test('Повинен повертати оригінальний рядок, якщо вираз неповний', () {
      expect(CalculatorHelper.calculate('50+'), '50+');
    });
  });
}
