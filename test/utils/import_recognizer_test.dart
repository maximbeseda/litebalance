import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Оновіть цей імпорт, якщо ваш database.dart знаходиться в іншій папці
import 'package:litebalance/database/app_database.dart';
import 'package:litebalance/utils/import_recognizer.dart';

void main() {
  group('ImportRecognizer Tests', () {
    group('1. Розпізнавання іконок (getIconForName)', () {
      test('Ресторан/їжа -> Icons.restaurant', () {
        expect(ImportRecognizer.getIconForName('ресторан'), Icons.restaurant.codePoint);
        expect(ImportRecognizer.getIconForName('Best DINNER'), Icons.restaurant.codePoint);
      });

      test('Кафе -> Icons.coffee (окремий концепт)', () {
        expect(ImportRecognizer.getIconForName('Моє улюблене КАФЕ'), Icons.coffee.codePoint);
      });

      test('Транспорт vs пальне — різні іконки', () {
        expect(ImportRecognizer.getIconForName('Таксі Uklon'), Icons.directions_car.codePoint);
        expect(ImportRecognizer.getIconForName('бензин на окко'), Icons.local_gas_station.codePoint);
      });

      // Регресія: коди мають відповідати ПОТОЧНИМ Material Icons. Старі
      // хардкоди «поплили» після міграції шрифту (0xe4a1 став pets тощо).
      test('Коди концептів = поточні Icons.* (не застарілі гліфи)', () {
        expect(ImportRecognizer.getIconForName('Miete'), Icons.home.codePoint);
        expect(ImportRecognizer.getIconForName('Gehalt'), Icons.payments.codePoint);
        expect(ImportRecognizer.getIconForName('Lebensmittel'), Icons.shopping_cart.codePoint);
        expect(ImportRecognizer.getIconForName('Apotheke'), Icons.medication.codePoint);
        expect(ImportRecognizer.getIconForName('Sparkonto'), Icons.savings.codePoint);
        expect(ImportRecognizer.getIconForName('银行卡'), Icons.credit_card.codePoint);
      });

      test('Невідоме слово -> дефолтна Icons.category', () {
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

      // Регресія: розширення мовних ключів НЕ повинно ламати наявні
      // англ. категорії (напр. "Utilities" не має стати рахунком через
      // випадковий збіг підрядка).
      test('Регресія: англійські категорії семпла класифікуються вірно', () {
        const accounts = ['Bank Card', 'Monobank', 'Cash', 'Savings Account'];
        for (final n in accounts) {
          expect(
            ImportRecognizer.guessType(n, isFrom: true),
            CategoryType.account,
            reason: '"$n" має бути рахунком',
          );
        }

        const incomes = ['Salary', 'Dividends', 'Gifts'];
        for (final n in incomes) {
          expect(
            ImportRecognizer.guessType(n, isFrom: false),
            CategoryType.income,
            reason: '"$n" має бути доходом',
          );
        }

        // Найризикованіший кейс: "Utilities" (містив би fi 'tili').
        const expenses = [
          'Utilities',
          'Rent',
          'Groceries',
          'Shopping',
          'Transport',
          'Entertainment',
          'Internet',
          'Restaurants',
          'Subscriptions',
        ];
        for (final n in expenses) {
          expect(
            ImportRecognizer.guessType(n, isFrom: false),
            CategoryType.expense,
            reason: '"$n" має бути витратою',
          );
        }
      });

      test('Розпізнає доходи/рахунки різними мовами', () {
        // Доходи (localized "salary")
        for (final n in ['Gehalt', 'Salaire', 'Salário', '給料', '급여', 'راتب', 'משכורת', 'Maaş', 'Wynagrodzenie']) {
          expect(
            ImportRecognizer.guessType(n, isFrom: false),
            CategoryType.income,
            reason: '"$n" має бути доходом',
          );
        }
        // Рахунки (localized "cash"/"card"/"bank")
        for (final n in ['Contanti', 'Gotówka', '現金', '현금', 'نقد', 'מזומן', 'Nakit', 'Tunai', 'Käteinen']) {
          expect(
            ImportRecognizer.guessType(n, isFrom: false),
            CategoryType.account,
            reason: '"$n" має бути рахунком',
          );
        }
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

    group('4. Робастна класифікація колонок (classifyColumn)', () {
      test('Заголовки згенерованого семпла класифікуються точно', () {
        const headers = [
          'Date',
          'Type',
          'Category (From)',
          'Amount (From)',
          'Currency (From)',
          'Category (To)',
          'Amount (To)',
          'Currency (To)',
          'Comment',
        ];
        final roles = headers.map(ImportRecognizer.classifyColumn).toList();
        expect(roles[0], ImportColumnRole.date);
        expect(roles[1], ImportColumnRole.none); // Type — модель його не використовує
        expect(roles[2], ImportColumnRole.from);
        expect(roles[3], ImportColumnRole.amountFrom); // 👈 ключовий фікс
        expect(roles[4], ImportColumnRole.currencyFrom);
        expect(roles[5], ImportColumnRole.to);
        expect(roles[6], ImportColumnRole.amountTo);
        expect(roles[7], ImportColumnRole.currencyTo);
        expect(roles[8], ImportColumnRole.note);
      });

      // Регресія: раніше "Amount (From)" ставав категорією «Куди» через ключ 'a'
      // у isTo, зсуваючи всі колонки.
      test('Регресія: "Amount (From)" — це сума, а не категорія', () {
        expect(ImportRecognizer.classifyColumn('Amount (From)'),
            ImportColumnRole.amountFrom);
        expect(ImportRecognizer.classifyColumn('Category (From)'),
            ImportColumnRole.from);
        expect(ImportRecognizer.classifyColumn('Category (To)'),
            ImportColumnRole.to);
      });

      test('Банківські заголовки (укр/рос)', () {
        expect(ImportRecognizer.classifyColumn('Дата'), ImportColumnRole.date);
        expect(ImportRecognizer.classifyColumn('Счет списания'),
            ImportColumnRole.from);
        expect(ImportRecognizer.classifyColumn('Счет зачисления'),
            ImportColumnRole.to);
        expect(ImportRecognizer.classifyColumn('Сумма'),
            ImportColumnRole.amountFrom);
        expect(ImportRecognizer.classifyColumn('Валюта'),
            ImportColumnRole.currencyFrom);
        expect(ImportRecognizer.classifyColumn('Примітка'),
            ImportColumnRole.note);
      });

      test('Прості заголовки: Category → ціль, Account → джерело', () {
        expect(ImportRecognizer.classifyColumn('Category'), ImportColumnRole.to);
        expect(
            ImportRecognizer.classifyColumn('Account'), ImportColumnRole.from);
        expect(ImportRecognizer.classifyColumn('Type'), ImportColumnRole.none);
      });
    });
  });
}
