import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litebalance/services/security_service.dart';

void main() {
  // Обов'язкова ініціалізація для тестів, які взаємодіють з нативними плагінами
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      'isPinSet повинен повертати false, якщо ПІН-код не встановлено',
      () async {
        final isSet = await SecurityService.isPinSet();
        expect(isSet, false);
      },
    );

    test(
      'setPinCode та verifyPinCode повинні успішно працювати для правильного ПІН-коду',
      () async {
        const testPin = '1234';
        await SecurityService.setPinCode(testPin);

        final isSet = await SecurityService.isPinSet();
        expect(isSet, true);

        final isValid = await SecurityService.verifyPinCode(testPin);
        expect(isValid, true);
      },
    );

    test(
      'verifyPinCode повинен повертати false для неправильного ПІН-коду',
      () async {
        await SecurityService.setPinCode('1234');

        final isValid = await SecurityService.verifyPinCode('0000');
        expect(isValid, false);
      },
    );

    test(
      'setBiometricsEnabled та isBiometricsEnabled зберігають стан',
      () async {
        await SecurityService.setBiometricsEnabled(true);

        final isEnabled = await SecurityService.isBiometricsEnabled();
        expect(isEnabled, true);
      },
    );

    test(
      'disableSecurity повинен видаляти всі дані (ПІН та біометрію)',
      () async {
        await SecurityService.setPinCode('1234');
        await SecurityService.setBiometricsEnabled(true);

        await SecurityService.disableSecurity();

        final isPinSet = await SecurityService.isPinSet();
        final isBioEnabled = await SecurityService.isBiometricsEnabled();

        expect(isPinSet, false);
        expect(isBioEnabled, false);
      },
    );

    test('Хешування повинно бути детермінованим та стійким', () async {
      const pin = '5555';

      // Встановлюємо ПІН
      await SecurityService.setPinCode(pin);

      // 👇 ФІКС: додано const для конструктора, як просив лінтер
      final storedHash1 = await const FlutterSecureStorage().read(
        key: 'user_secure_pin_hash',
      );

      // Встановлюємо той самий ПІН ще раз
      await SecurityService.setPinCode(pin);
      final storedHash2 = await const FlutterSecureStorage().read(
        key: 'user_secure_pin_hash',
      );

      // Хеш має бути однаковим для того самого ПІН-коду
      expect(storedHash1, storedHash2);

      // Хеш НЕ повинен містити сам ПІН-код у відкритому вигляді
      expect(storedHash1!.contains(pin), false);

      // Мінімальна зміна ПІН-коду повинна дати зовсім інший хеш
      await SecurityService.setPinCode('5556');
      final storedHash3 = await const FlutterSecureStorage().read(
        key: 'user_secure_pin_hash',
      );
      expect(storedHash1 != storedHash3, true);
    });
  });
}
