import 'package:math_expressions/math_expressions.dart';

class CalculatorHelper {
  /// Приймає рядок виразу (наприклад, "150+20*2") і повертає результат обчислення.
  /// Якщо вираз неповний (наприклад, "150+"), просто повертає його як є.
  static String calculate(String expression) {
    if (expression.isEmpty) return '0';

    try {
      // 1. Очищаємо рядок: міняємо коми на крапки (для десяткових дробів)
      String sanitized = expression.replaceAll(',', '.');

      // 2. Міняємо візуальні символи на ті, які розуміє парсер
      sanitized = sanitized.replaceAll('×', '*').replaceAll('÷', '/');

      // 3. Створюємо парсер і розпізнаємо математичний вираз
      final Parser p = Parser();
      final Expression exp = p.parse(sanitized);

      // 4. Виконуємо обчислення
      final ContextModel cm = ContextModel();
      final double eval = exp.evaluate(EvaluationType.REAL, cm);

      // 5. Форматуємо результат
      // Якщо число ціле (наприклад, 150.0), повертаємо без нулів після крапки ("150")
      if (eval == eval.toInt()) {
        return eval.toInt().toString();
      }

      // Якщо є копійки, обмежуємо до 2 знаків і прибираємо зайві нулі
      return double.parse(eval.toStringAsFixed(2)).toString();
    } catch (e) {
      // Якщо виникає помилка парсингу (наприклад, користувач ввів "50 +" і ще не ввів друге число),
      // ми просто нічого не робимо і залишаємо текст на екрані без змін.
      return expression;
    }
  }

  /// Допоміжний метод: перевіряє, чи закінчується рядок на математичний оператор
  static bool endsWithOperator(String text) {
    if (text.isEmpty) return false;
    final lastChar = text[text.length - 1];
    return ['+', '-', '*', '/', '×', '÷'].contains(lastChar);
  }
}
