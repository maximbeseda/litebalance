import 'package:flutter_test/flutter_test.dart';
import 'package:coin_flow/database/app_database.dart';
import 'package:coin_flow/services/backup_service.dart';

void main() {
  group('BackupService - Encryption & Decryption Engine', () {
    // Дані для тестів
    const Category dummyCategory = Category(
      id: 'cat_1',
      name: 'Test Category',
      type: CategoryType.expense,
      currency: 'UAH',
      amount: 0,
      icon: 1,
      bgColor: 1,
      iconColor: 1,
      isArchived: false,
      includeInTotal: true,
      sortOrder: 0,
    );

    final Transaction dummyTransaction = Transaction(
      id: 'tx_1',
      fromId: 'acc_1',
      toId: 'cat_1',
      title: 'Test Tx',
      amount: 100,
      date: DateTime(2026, 1, 1),
      currency: 'UAH',
      baseAmount: 100,
      baseCurrency: 'UAH',
    );

    final Subscription dummySubscription = Subscription(
      id: 'sub_1',
      name: 'Test Sub',
      amount: 50,
      currency: 'UAH',
      accountId: 'acc_1',
      categoryId: 'cat_1',
      periodicity: 'monthly',
      nextPaymentDate: DateTime(2026, 2, 1),
      isAutoPay: false,
    );

    test(
      'Повний цикл: Експорт -> Шифрування -> Розшифрування -> Перевірка JSON',
      () {
        const String testPassword = 'SuperSecretPassword123!';

        // 1. Створюємо зашифрований рядок (Payload)
        final String encryptedString = BackupService.generateEncryptedPayload(
          testPassword,
          [dummyCategory],
          [dummyTransaction],
          [dummySubscription],
        );

        // Перевіряємо формат: iv:encrypted_data
        expect(encryptedString.contains(':'), isTrue);
        // Перевіряємо, що в зашифрованому рядку немає відкритого тексту
        expect(encryptedString.contains('Test Category'), isFalse);

        // 2. Розшифровуємо назад у Map
        final Map<String, dynamic> decryptedJson = BackupService.decryptPayload(
          testPassword,
          encryptedString,
        );

        // 3. Перевіряємо цілісність даних
        expect(decryptedJson['version'], 1);

        final List importedCategories = decryptedJson['categories'] as List;
        final Map<String, dynamic> firstCat = Map<String, dynamic>.from(
          importedCategories.first as Map,
        );
        expect(firstCat['name'], 'Test Category');

        final List importedTransactions = decryptedJson['transactions'] as List;
        final Map<String, dynamic> firstTx = Map<String, dynamic>.from(
          importedTransactions.first as Map,
        );
        expect(firstTx['id'], 'tx_1');

        final List importedSubscriptions =
            decryptedJson['subscriptions'] as List;
        final Map<String, dynamic> firstSub = Map<String, dynamic>.from(
          importedSubscriptions.first as Map,
        );
        expect(firstSub['periodicity'], 'monthly');
      },
    );

    test(
      'decryptPayload викидає помилку ArgumentError при неправильному паролі',
      () {
        const String correctPassword = 'MyPassword';
        const String wrongPassword = 'HackerPassword';

        // Створюємо бекап з правильним паролем
        final String encryptedString = BackupService.generateEncryptedPayload(
          correctPassword,
          [],
          [],
          [],
        );

        // Спроба розшифрувати неправильним паролем має викликати помилку ArgumentError
        // (це стандартна поведінка AES при невірному ключі/паддінгу)
        expect(
          () => BackupService.decryptPayload(wrongPassword, encryptedString),
          throwsArgumentError,
        );
      },
    );
  });
}
