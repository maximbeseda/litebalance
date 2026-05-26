import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Оновіть цей імпорт, якщо ваш database.dart знаходиться в іншій папці
import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/utils/import_recognizer.dart';

void main() {
  group('ImportRecognizer Tests', () {
    group('1. Розпізнавання іконок (getIconForName)', () {
      test('Повинен знаходити правильну іконку для їжі', () {
        // Очікуємо код іконки Icons.restaurant (0xe532)
        expect(ImportRecognizer.getIconForName('кафе'), 0xe532);
        expect(
          ImportRecognizer.getIconForName('Моє улюблене КАФЕ'),
          0xe532,
        ); // Перевірка регістру
        expect(ImportRecognizer.getIconForName('dinner'), 0xe532);
      });

      test('Повинен знаходити правильну іконку для транспорту', () {
        // Очікуємо код іконки Icons.directions_car (0xe1d7)
        expect(ImportRecognizer.getIconForName('Таксі Uklon'), 0xe1d7);
        expect(ImportRecognizer.getIconForName('бензин на окко'), 0xe1d7);
      });

      test('Повинен повертати дефолтну іконку, якщо слово невідоме', () {
        // Очікуємо код іконки Icons.category
        expect(
          ImportRecognizer.getIconForName('Якесь незрозуміле слово'),
          Icons.category.codePoint,
        );
      });
    });

    group('2. Вгадування типу категорії (guessType)', () {
      test('Повинен розпізнавати Доходи', () {
        expect(
          ImportRecognizer.guessType('Зарплата за травень', isFrom: false),
          CategoryType.income,
        );
        expect(
          ImportRecognizer.guessType('bonus', isFrom: false),
          CategoryType.income,
        );
      });

      test('Повинен розпізнавати Рахунки', () {
        expect(
          ImportRecognizer.guessType('Картка монобанку', isFrom: true),
          CategoryType.account,
        );
        expect(
          ImportRecognizer.guessType('готівка usd', isFrom: false),
          CategoryType.account,
        );
      });

      test('Повинен розпізнавати Витрати', () {
        expect(
          ImportRecognizer.guessType('продукти АТБ', isFrom: false),
          CategoryType.expense,
        );
        expect(
          ImportRecognizer.guessType('Комуналка', isFrom: false),
          CategoryType.expense,
        );
      });

      test('Повинен використовувати isFrom для невідомих слів', () {
        // Якщо слово невідоме, але гроші йдуть "ВІД" нього, це скоріше за все Рахунок
        expect(
          ImportRecognizer.guessType('Невідома назва', isFrom: true),
          CategoryType.account,
        );
        // Якщо гроші йдуть "ДО" нього, це Витрата
        expect(
          ImportRecognizer.guessType('Невідома назва', isFrom: false),
          CategoryType.expense,
        );
      });
    });

    group('3. Розпізнавання колонок CSV', () {
      test('Повинен розпізнавати колонки дати (isDate)', () {
        expect(ImportRecognizer.isDate('дата'), true);
        expect(ImportRecognizer.isDate('time'), true);
        expect(ImportRecognizer.isDate('some random header'), false);
      });

      test('Повинен розпізнавати колонки звідки (isFrom)', () {
        expect(ImportRecognizer.isFrom('счет списания'), true);
        expect(ImportRecognizer.isFrom('від'), true);
      });

      test('Повинен розпізнавати колонки куди (isTo)', () {
        expect(ImportRecognizer.isTo('категория'), true);
        expect(ImportRecognizer.isTo('target'), true);
      });

      test('Повинен розпізнавати колонки суми та валюти', () {
        expect(ImportRecognizer.isAmountFrom('сумма'), true);
        expect(ImportRecognizer.isCurrencyFrom('валюта'), true);

        // Для 'To' використовується .contains(), тому можна передавати довші фрази
        expect(ImportRecognizer.isAmountTo('сумма (в валюте)'), true);
        expect(
          ImportRecognizer.isCurrencyTo('валюта зачисления на карту'),
          true,
        );
      });
    });
  });
}
